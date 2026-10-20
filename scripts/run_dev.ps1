# run_dev.ps1 - Finds the PC IP reachable from your device and runs Flutter.
# Usage:
#   .\scripts\run_dev.ps1                  (auto-detect IP)
#   .\scripts\run_dev.ps1 --emulator       (force 10.0.2.2 for Android emulator)
#   .\scripts\run_dev.ps1 -d <device-id>   (target a specific device)
#   .\scripts\run_dev.ps1 -fresh           (start at onboarding, signed out, every launch)
#   .\scripts\run_dev.ps1 -writeOnly       (only write .dart_tool/dev_host.json for VS Code F5)

param(
    [string]$d = "",
    [switch]$emulator,
    [switch]$fresh,
    [switch]$writeOnly
)

function Test-Port {
    param([string]$ip, [int]$port, [int]$timeoutMs = 800)
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $result = $tcp.BeginConnect($ip, $port, $null, $null)
        $ok = $result.AsyncWaitHandle.WaitOne($timeoutMs)
        return ($ok -and $tcp.Connected)
    } catch {
        return $false
    } finally {
        $tcp.Close()
    }
}

# The phone's Wi-Fi IPv4 address read over adb, or $null when no phone answers.
function Get-PhoneIp {
    $adb = $null
    if ($env:ANDROID_HOME) {
        $sdkAdb = Join-Path $env:ANDROID_HOME "platform-tools\adb.exe"
        if (Test-Path $sdkAdb) { $adb = $sdkAdb }
    }
    if (-not $adb) {
        $cmd = Get-Command adb -ErrorAction SilentlyContinue
        if (-not $cmd) { return $null }
        $adb = $cmd.Source
    }
    $target = @()
    if ($d) { $target = @("-s", $d) }
    $out = & $adb @target shell ip -4 addr show wlan0 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    $m = [regex]::Match(($out -join " "), 'inet (\d+\.\d+\.\d+\.\d+)')
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

# True when $a and $b share the first $prefix bits (same subnet).
function Test-SameNetwork {
    param([string]$a, [string]$b, [int]$prefix)
    $ba = [System.Net.IPAddress]::Parse($a).GetAddressBytes()
    $bb = [System.Net.IPAddress]::Parse($b).GetAddressBytes()
    for ($i = 0; $i -lt 4; $i++) {
        $bits = [Math]::Max(0, [Math]::Min(8, $prefix - 8 * $i))
        $mask = (0xFF -shl (8 - $bits)) -band 0xFF
        if (($ba[$i] -band $mask) -ne ($bb[$i] -band $mask)) { return $false }
    }
    return $true
}

if ($emulator -or $d -match "emulator") {
    $hostIp = "10.0.2.2"
    Write-Host "Mode: emulator -- using $hostIp" -ForegroundColor Yellow
} else {
    # Step 1 - check backend is actually running on this machine
    $backendRunning = Test-Port -ip "127.0.0.1" -port 5000
    if (-not $backendRunning) {
        Write-Host ""
        Write-Host "ERROR: Nothing is listening on localhost:5000" -ForegroundColor Red
        Write-Host "Start your backend server first, then rerun this script." -ForegroundColor Red
        Write-Host ""
        exit 1
    }
    Write-Host "Backend detected on localhost:5000" -ForegroundColor Green

    # Step 2 - the PC's usable IPv4 addresses (no loopback, no 169.254 link-local)
    $candidates = @(Get-NetIPAddress -AddressFamily IPv4 -Type Unicast |
        Where-Object { $_.IPAddress -notlike "169.254.*" -and $_.IPAddress -notlike "127.*" })

    if (-not $candidates) {
        Write-Host "ERROR: No network interfaces found. Connect to WiFi and try again." -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "PC addresses:" -ForegroundColor Cyan
    foreach ($c in $candidates) {
        Write-Host "  $($c.IPAddress)  ($($c.InterfaceAlias))" -ForegroundColor Gray
    }
    Write-Host ""

    # Step 3 - ask the phone (USB or wireless debugging) for its Wi-Fi address
    # and use the PC address on the same network, e.g. 192.168.137.1 when the
    # phone is on the PC's hotspot.
    $hostIp = $null
    $phoneIp = Get-PhoneIp
    if ($phoneIp) {
        Write-Host "Phone address: $phoneIp" -ForegroundColor Cyan
        $match = $candidates |
            Where-Object { Test-SameNetwork $_.IPAddress $phoneIp $_.PrefixLength } |
            Select-Object -First 1
        if ($match) {
            $hostIp = $match.IPAddress
        } else {
            Write-Host "Warning: the phone ($phoneIp) is not on any of the PC's networks." -ForegroundColor Yellow
            Write-Host "Connect both to the same Wi-Fi (or the phone to the PC's hotspot)." -ForegroundColor Yellow
        }
    } else {
        Write-Host "No phone found over adb, so its network is unknown." -ForegroundColor Yellow
    }

    # Fallback: the Wi-Fi adapter, else the first address.
    if (-not $hostIp) {
        $wifi = $candidates | Where-Object { $_.InterfaceAlias -like "Wi-Fi*" } | Select-Object -First 1
        $hostIp = if ($wifi) { $wifi.IPAddress } else { $candidates[0].IPAddress }
        Write-Host "Using $hostIp as best guess." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "If the app still can't reach the server, check:" -ForegroundColor Yellow
        Write-Host "  1. Phone and PC are on the SAME WiFi network" -ForegroundColor Yellow
        Write-Host "  2. Windows Firewall allows inbound on port 5000" -ForegroundColor Yellow
        Write-Host "     Run as admin: netsh advfirewall firewall add rule name=`"Node 5000`" dir=in action=allow protocol=TCP localport=5000" -ForegroundColor DarkGray
        Write-Host ""
    }

    Write-Host "Using DEV_HOST = $hostIp" -ForegroundColor Green
    Write-Host ""
    Write-Host "NOTE: --dart-define is compiled in. If your IP changes later," -ForegroundColor DarkGray
    Write-Host "      stop the app (Ctrl+C) and rerun this script - hot restart is not enough." -ForegroundColor DarkGray
    Write-Host ""
}

# -writeOnly: VS Code's launch configs run this first (preLaunchTask) and read
# the file with --dart-define-from-file, so F5 gets DEV_HOST and hot reload on save.
if ($writeOnly) {
    $json = "{`"DEV_HOST`": `"$hostIp`"}"
    # ASCII, not PowerShell's default UTF-8 with BOM, which the JSON reader rejects.
    Set-Content -Path "$PSScriptRoot\..\.dart_tool\dev_host.json" -Value $json -Encoding ascii
    Write-Host "Wrote .dart_tool/dev_host.json (DEV_HOST = $hostIp)" -ForegroundColor Green
    exit 0
}

$define = @("--dart-define=DEV_HOST=$hostIp")
if ($fresh) { $define += "--dart-define=FRESH_START=true" }

if ($d) {
    Write-Host "flutter run $define --flavor development -t lib/main_development.dart -d $d" -ForegroundColor Cyan
    flutter run $define --flavor development -t lib/main_development.dart -d $d
} else {
    Write-Host "flutter run $define --flavor development -t lib/main_development.dart" -ForegroundColor Cyan
    flutter run $define --flavor development -t lib/main_development.dart
}

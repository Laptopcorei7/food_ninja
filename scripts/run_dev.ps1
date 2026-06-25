# run_dev.ps1 - Finds the PC IP reachable from your device and runs Flutter.
# Usage:
#   .\scripts\run_dev.ps1                  (auto-detect IP)
#   .\scripts\run_dev.ps1 --emulator       (force 10.0.2.2 for Android emulator)
#   .\scripts\run_dev.ps1 -d <device-id>   (target a specific device)

param(
    [string]$d = "",
    [switch]$emulator
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

    # Step 2 - collect all non-loopback, non-APIPA IPv4 addresses
    $candidates = Get-NetIPAddress -AddressFamily IPv4 -Type Unicast |
        Where-Object { $_.IPAddress -notlike "169.254.*" -and $_.IPAddress -ne "127.0.0.1" } |
        Sort-Object InterfaceMetric

    if (-not $candidates) {
        Write-Host "ERROR: No network interfaces found. Connect to WiFi and try again." -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "Network interfaces found:" -ForegroundColor Cyan
    foreach ($c in $candidates) {
        Write-Host "  $($c.IPAddress)  (metric $($c.InterfaceMetric), origin: $($c.PrefixOrigin))" -ForegroundColor Gray
    }
    Write-Host ""

    # Step 3 - pick the best candidate
    # Prefer addresses where the PC itself can reach port 5000 via that IP
    # (confirms the interface routes back to localhost)
    $hostIp = $null
    foreach ($c in $candidates) {
        if (Test-Port -ip $c.IPAddress -port 5000) {
            $hostIp = $c.IPAddress
            break
        }
    }

    # Fallback: just take the lowest-metric address (most likely the WiFi adapter)
    if (-not $hostIp) {
        $hostIp = $candidates[0].IPAddress
        Write-Host "Warning: Could not self-test port 5000 on any interface." -ForegroundColor Yellow
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

$define = "--dart-define=DEV_HOST=$hostIp"

if ($d) {
    Write-Host "flutter run $define --flavor development -t lib/main_development.dart -d $d" -ForegroundColor Cyan
    flutter run $define --flavor development -t lib/main_development.dart -d $d
} else {
    Write-Host "flutter run $define --flavor development -t lib/main_development.dart" -ForegroundColor Cyan
    flutter run $define --flavor development -t lib/main_development.dart
}

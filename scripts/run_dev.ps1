# run_dev.ps1 - Detects local IP and runs Flutter (development flavor) with it as DEV_HOST.
# Usage:
#   .\scripts\run_dev.ps1                   (auto-detect IP, development flavor)
#   .\scripts\run_dev.ps1 --emulator        (force emulator - uses 10.0.2.2)
#   .\scripts\run_dev.ps1 -d <device-id>    (target a specific device)

param(
    [string]$d = "",
    [switch]$emulator
)

if ($emulator -or $d -match "emulator") {
    $hostIp = "10.0.2.2"
    Write-Host "Target: emulator -- using $hostIp" -ForegroundColor Yellow
} else {
    # Prefer DHCP address, non-loopback, non-APIPA
    $hostIp = (Get-NetIPAddress -AddressFamily IPv4 -Type Unicast |
        Where-Object {
            $_.IPAddress -notlike "169.254.*" -and
            $_.IPAddress -ne "127.0.0.1" -and
            $_.PrefixOrigin -eq "Dhcp"
        } |
        Sort-Object InterfaceMetric |
        Select-Object -First 1).IPAddress

    # Fallback: any non-loopback, non-APIPA address
    if (-not $hostIp) {
        $hostIp = (Get-NetIPAddress -AddressFamily IPv4 -Type Unicast |
            Where-Object {
                $_.IPAddress -notlike "169.254.*" -and $_.IPAddress -ne "127.0.0.1"
            } |
            Select-Object -First 1).IPAddress
    }

    if (-not $hostIp) {
        Write-Error "Could not detect a local IP address. Connect to a network and try again."
        exit 1
    }

    Write-Host "Detected IP: $hostIp" -ForegroundColor Green
}

$define = "--dart-define=DEV_HOST=$hostIp"
$target = "-t lib/main_development.dart"
$flavor = "--flavor development"

if ($d) {
    Write-Host "Running: flutter run $define $flavor $target -d $d" -ForegroundColor Cyan
    Write-Host ""
    flutter run $define --flavor development -t lib/main_development.dart -d $d
} else {
    Write-Host "Running: flutter run $define $flavor $target" -ForegroundColor Cyan
    Write-Host ""
    flutter run $define --flavor development -t lib/main_development.dart
}

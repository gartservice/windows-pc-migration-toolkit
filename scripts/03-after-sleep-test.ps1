# Standalone sleep/battery diagnostics after a sleep test.
# Run in PowerShell as Administrator immediately after waking the laptop.
$ErrorActionPreference = 'Continue'
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) { Write-Error 'Run PowerShell as Administrator.'; exit 1 }

$desktop = [Environment]::GetFolderPath('Desktop')
$out = Join-Path $desktop ('After-Sleep-Test-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $out -Force | Out-Null

$reports = @(
    @{ Arg='/batteryreport'; Output='battery-report-after.html' },
    @{ Arg='/sleepstudy'; Output='sleepstudy-after.html' },
    @{ Arg='/systemsleepdiagnostics'; Output='system-sleep-diagnostics-after.html' },
    @{ Arg='/systempowerreport'; Output='system-power-report-after.html' }
)
foreach ($r in $reports) {
    & powercfg $r.Arg /output (Join-Path $out $r.Output)
}

(@{
    'last-wake.txt' = @('/lastwake')
    'power-requests.txt' = @('/requests')
    'wake-timers.txt' = @('/waketimers')
    'wake-armed-devices.txt' = @('/devicequery', 'wake_armed')
    'available-sleep-states.txt' = @('/a')
}).GetEnumerator() | ForEach-Object {
    $powerArgs = @($_.Value)
    & powercfg @powerArgs 2>&1 | Out-File (Join-Path $out $_.Key) -Encoding UTF8
}

Write-Host "Reports saved to $out" -ForegroundColor Green
Write-Host 'Note: HTML reports may include device info. Do not commit them to a public repository.'

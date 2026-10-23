# Preview or install an approved selection of WinGet applications.
# Default is PREVIEW ONLY. Add -Install to actually install software.
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot '..\config\apps.example.json'),
    [switch]$Install
)
$ErrorActionPreference = 'Stop'
$configPathResolved = (Resolve-Path -LiteralPath $ConfigPath).Path
$config = Get-Content -LiteralPath $configPathResolved -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $config.packages) { throw 'Config must contain a non-empty packages array.' }

$packages = @($config.packages | Where-Object { $_.enabled -eq $true })
Write-Host ('Approved packages: ' + $packages.Count) -ForegroundColor Cyan
foreach ($item in $packages) {
    if ($item.id -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid package ID: $($item.id)" }
    Write-Host (' - ' + $item.id)
}

if (-not $Install) {
    Write-Host "`nPREVIEW ONLY. Add -Install to perform installation." -ForegroundColor Yellow
    exit 0
}
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'WinGet is unavailable. Update Microsoft App Installer first.'
}

$failed = @()
foreach ($item in $packages) {
    Write-Host ("`nInstalling: " + $item.id) -ForegroundColor Cyan
    & winget install --id $item.id --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed: $($item.id) (exit code $LASTEXITCODE)"
        $failed += $item.id
    }
}
if ($failed.Count -gt 0) {
    Write-Warning ('Some packages did not install: ' + ($failed -join ', '))
    exit 1
}
Write-Host 'All enabled apps installed or already present.' -ForegroundColor Green

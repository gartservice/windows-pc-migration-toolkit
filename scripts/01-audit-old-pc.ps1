# Old laptop software inventory
# Run in PowerShell as Administrator.
# Creates a ZIP on the Desktop containing software inventory only.
# It does NOT modify or uninstall anything.

$ErrorActionPreference = "Continue"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$desktop = [Environment]::GetFolderPath("Desktop")
$outDir = Join-Path $desktop "OldLaptop-Audit-$timestamp"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

# 1) Basic system info
$systemFile = Join-Path $outDir "system-info.txt"
$computer = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$os = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1

@"
Computer manufacturer: $($computer.Manufacturer)
Computer model:        $($computer.Model)
Windows:               $($os.Caption)
Windows version:       $($os.Version)
Architecture:          $($os.OSArchitecture)
CPU:                   $($cpu.Name)
RAM GB:                $([math]::Round($computer.TotalPhysicalMemory / 1GB, 1))
BIOS version:          $($bios.SMBIOSBIOSVersion)
BIOS date:             $($bios.ReleaseDate)
"@ | Out-File $systemFile -Encoding utf8

# 2) Traditional installed programs from registry
$programs = @()
$registrySources = @(
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"; Scope = "Machine"; Arch = "64-bit/Native" },
    @{ Path = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"; Scope = "Machine"; Arch = "32-bit" },
    @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"; Scope = "Current user"; Arch = "User" }
)

foreach ($source in $registrySources) {
    Get-ItemProperty $source.Path -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and $_.DisplayName.Trim() -ne "" } |
        ForEach-Object {
            $programs += [PSCustomObject]@{
                Name             = $_.DisplayName
                Version          = $_.DisplayVersion
                Publisher        = $_.Publisher
                InstallDate      = $_.InstallDate
                Scope            = $source.Scope
                Architecture     = $source.Arch
                InstallLocation  = $_.InstallLocation
                SystemComponent  = $_.SystemComponent
                ReleaseType      = $_.ReleaseType
                WindowsInstaller = $_.WindowsInstaller
            }
        }
}

$programs |
    Sort-Object Name, Version -Unique |
    Export-Csv (Join-Path $outDir "installed-programs.csv") -NoTypeInformation -Encoding UTF8

# 3) WinGet inventory/export
$winget = Get-Command winget -ErrorAction SilentlyContinue
if ($winget) {
    & winget list --accept-source-agreements 2>&1 |
        Out-File (Join-Path $outDir "winget-list.txt") -Encoding utf8

    & winget export `
        --output (Join-Path $outDir "winget-export.json") `
        --include-versions `
        --accept-source-agreements `
        --disable-interactivity 2>&1 |
        Out-File (Join-Path $outDir "winget-export-log.txt") -Encoding utf8

    & winget source list 2>&1 |
        Out-File (Join-Path $outDir "winget-sources.txt") -Encoding utf8
}
else {
    "WinGet is not installed/available on this Windows installation." |
        Out-File (Join-Path $outDir "winget-not-available.txt") -Encoding utf8
}

# 4) Microsoft Store / AppX apps
Get-AppxPackage |
    Select-Object Name, Version, PublisherId, Architecture, IsFramework, NonRemovable |
    Sort-Object Name |
    Export-Csv (Join-Path $outDir "store-apps.csv") -NoTypeInformation -Encoding UTF8

# 5) Startup programs
Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue |
    Select-Object Name, Command, Location, User |
    Sort-Object Name |
    Export-Csv (Join-Path $outDir "startup-items.csv") -NoTypeInformation -Encoding UTF8

# 6) Printers
if (Get-Command Get-Printer -ErrorAction SilentlyContinue) {
    Get-Printer |
        Select-Object Name, DriverName, PortName, Type, Shared, Published |
        Sort-Object Name |
        Export-Csv (Join-Path $outDir "printers.csv") -NoTypeInformation -Encoding UTF8
}

# 7) Windows activation status
$activationFile = Join-Path $outDir "windows-activation.txt"
try {
    & cscript.exe //Nologo "$env:SystemRoot\System32\slmgr.vbs" /dlv 2>&1 |
        Out-File $activationFile -Encoding utf8
}
catch {
    "Could not query Windows activation: $($_.Exception.Message)" |
        Out-File $activationFile -Encoding utf8
}

# 8) Office installation details
$officeInfo = Join-Path $outDir "office-installation.txt"
$officeRegPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun\Configuration"
)

$officeFound = $false
foreach ($path in $officeRegPaths) {
    if (Test-Path $path) {
        $officeFound = $true
        $o = Get-ItemProperty $path
        @"
Registry path:       $path
ProductReleaseIds:   $($o.ProductReleaseIds)
VersionToReport:     $($o.VersionToReport)
Platform:            $($o.Platform)
ClientCulture:       $($o.ClientCulture)
UpdateChannel:       $($o.UpdateChannel)
CDNBaseUrl:          $($o.CDNBaseUrl)

"@ | Out-File $officeInfo -Append -Encoding utf8
    }
}

$officeLicenseFile = Join-Path $outDir "office-license-status.txt"
$osppCandidates = @(
    "$env:ProgramFiles\Microsoft Office\Office16\OSPP.VBS",
    "${env:ProgramFiles(x86)}\Microsoft Office\Office16\OSPP.VBS",
    "$env:ProgramFiles\Microsoft Office\Office15\OSPP.VBS",
    "${env:ProgramFiles(x86)}\Microsoft Office\Office15\OSPP.VBS"
) | Where-Object { $_ -and (Test-Path $_) }

if ($osppCandidates.Count -gt 0) {
    foreach ($ospp in $osppCandidates) {
        "===== $ospp =====" | Out-File $officeLicenseFile -Append -Encoding utf8
        & cscript.exe //Nologo $ospp /dstatus 2>&1 |
            Out-File $officeLicenseFile -Append -Encoding utf8
        "" | Out-File $officeLicenseFile -Append -Encoding utf8
    }
}
else {
    "OSPP.VBS was not found. This can be normal for some Microsoft 365 / Store installations." |
        Out-File $officeLicenseFile -Encoding utf8
}

if (-not $officeFound) {
    "No Office Click-to-Run configuration registry key was found." |
        Out-File $officeInfo -Append -Encoding utf8
}

# 9) Summary
$programCount = ($programs | Sort-Object Name, Version -Unique).Count
$readme = @"
OLD LAPTOP SOFTWARE AUDIT
Generated: $(Get-Date)

This package contains an inventory only. Nothing was uninstalled or changed.

Most useful files:
- installed-programs.csv    Full desktop-program inventory from Windows registry
- winget-export.json        Apps WinGet was able to map to installable package IDs
- winget-export-log.txt     Shows apps WinGet could NOT map
- winget-list.txt           Human-readable WinGet inventory
- office-installation.txt   Office edition/version details, where detectable
- office-license-status.txt Office activation/license status (normally only partial key)
- windows-activation.txt    Windows activation information
- startup-items.csv         Startup software
- printers.csv              Installed printers/drivers
- store-apps.csv            Microsoft Store/AppX packages

Traditional installed programs found: $programCount

Next step:
Upload this ZIP for review before installing applications on the new laptop.
"@

$readme | Out-File (Join-Path $outDir "README.txt") -Encoding utf8

# 10) Compress results
$zip = "$outDir.zip"
Compress-Archive -Path "$outDir\*" -DestinationPath $zip -Force

Write-Host ""
Write-Host "Audit complete." -ForegroundColor Green
Write-Host "ZIP created:" -ForegroundColor Cyan
Write-Host $zip
Write-Host ""
Write-Host "Upload that ZIP for review."

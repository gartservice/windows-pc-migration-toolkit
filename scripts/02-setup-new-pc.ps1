# Windows PC initial setup & diagnostics (best suited to Dell Windows 11 machines)
# Run from Windows PowerShell as Administrator. Review arguments first.
param(
    [string]$TimeZoneId = '',
    [switch]$ApplyDellUpdates,
    [switch]$InstallMicrosoft365,
    [switch]$SkipBaseApps,
    [switch]$SkipPowerConfiguration
)

$ErrorActionPreference = 'Continue'

# ---------------- USER SETTINGS ----------------
# Dell BIOS/firmware updates are OPT-IN via -ApplyDellUpdates.
# Microsoft 365 is OPT-IN via -InstallMicrosoft365; confirm licence first.
# Use -SkipBaseApps if you plan to use 04-install-approved-apps.ps1 instead.
$LidCloseAction      = 1        # 0=Do nothing, 1=Sleep, 2=Hibernate, 3=Shut down
$HibernateAfterMinutesOnBattery = 60
$HibernateAfterMinutesOnAC      = 180
# ------------------------------------------------

# Require administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    Write-Host 'ERROR: Run Windows PowerShell as Administrator.' -ForegroundColor Red
    exit 1
}

$Desktop = [Environment]::GetFolderPath('Desktop')
$ReportRoot = Join-Path $Desktop ("Laptop-Setup-Reports-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $ReportRoot -Force | Out-Null
$LogFile = Join-Path $ReportRoot 'setup-transcript.txt'
Start-Transcript -Path $LogFile -Force

function Section($name) {
    Write-Host "`n================ $name ================" -ForegroundColor Cyan
}

function Save-Text($name, $content) {
    $content | Out-File -FilePath (Join-Path $ReportRoot $name) -Encoding UTF8 -Width 300
}

function Install-WingetPackage($id) {
    Write-Host "Installing/updating $id ..." -ForegroundColor Yellow
    & winget install --id $id --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "WinGet returned code $LASTEXITCODE for $id"
    }
}

Section 'SYSTEM INVENTORY'
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor
$bios = Get-CimInstance Win32_BIOS
$sysInfo = [PSCustomObject]@{
    Manufacturer = $cs.Manufacturer
    Model = $cs.Model
    CPU = ($cpu.Name -join '; ')
    RAM_GB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    Windows = $os.Caption
    Version = $os.Version
    Build = $os.BuildNumber
    BIOS_Version = ($bios.SMBIOSBIOSVersion -join '; ')
    BIOS_Date = $bios.ReleaseDate
}
$sysInfo | Format-List
$sysInfo | Format-List | Out-String | Save-Text 'system-info.txt'

# Memory inventory (inventory only; this is NOT a true RAM stress test)
Get-CimInstance Win32_PhysicalMemory |
    Select-Object Manufacturer, PartNumber,
        @{N='CapacityGB';E={[math]::Round($_.Capacity/1GB,1)}},
        Speed, ConfiguredClockSpeed |
    Format-Table -AutoSize |
    Out-String | Save-Text 'memory-inventory.txt'

# Disk inventory / reliability
Get-PhysicalDisk |
    Select-Object FriendlyName, MediaType, HealthStatus, OperationalStatus,
        @{N='SizeGB';E={[math]::Round($_.Size/1GB,1)}} |
    Format-Table -AutoSize |
    Out-String | Save-Text 'disk-health.txt'

try {
    $diskReliability = foreach ($disk in Get-PhysicalDisk) {
        $r = Get-StorageReliabilityCounter -PhysicalDisk $disk -ErrorAction Stop
        [PSCustomObject]@{
            Disk = $disk.FriendlyName
            TemperatureC = $r.Temperature
            WearPercent = $r.Wear
            PowerOnHours = $r.PowerOnHours
            ReadErrorsTotal = $r.ReadErrorsTotal
            WriteErrorsTotal = $r.WriteErrorsTotal
        }
    }
    $diskReliability | Format-Table -AutoSize | Out-String | Save-Text 'disk-reliability.txt'
} catch {
    "Storage reliability counters unavailable: $($_.Exception.Message)" | Save-Text 'disk-reliability.txt'
}

Section 'TIME / TIME ZONE'
if (-not [string]::IsNullOrWhiteSpace($TimeZoneId)) {
    try { Set-TimeZone -Id $TimeZoneId }
    catch { Write-Warning "Could not set time zone '$TimeZoneId': $($_.Exception.Message)" }
} else {
    Write-Host 'Keeping current time zone. Pass -TimeZoneId to change it.'
}
Set-Service W32Time -StartupType Automatic -ErrorAction SilentlyContinue
Start-Service W32Time -ErrorAction SilentlyContinue
w32tm /resync /force
Get-TimeZone | Format-List

Section 'WINDOWS ACTIVATION'
$windowsAppId = '55c92734-d682-4d71-983e-d6ec3f16059f'
function Get-WindowsLicenseInfo {
    Get-CimInstance SoftwareLicensingProduct |
        Where-Object {
            $_.ApplicationID -eq $windowsAppId -and
            $_.Name -like 'Windows*' -and
            $_.PartialProductKey
        }
}
$licenseBefore = Get-WindowsLicenseInfo
$activeBefore = $licenseBefore | Where-Object LicenseStatus -eq 1 | Select-Object -First 1
if (-not $activeBefore) {
    Write-Host 'Windows is not currently reporting Licensed. Attempting online activation...' -ForegroundColor Yellow
    & cscript.exe //Nologo "$env:SystemRoot\System32\slmgr.vbs" /ato | Tee-Object -FilePath (Join-Path $ReportRoot 'activation-attempt.txt')
    Start-Sleep -Seconds 5
}
$licenseAfter = Get-WindowsLicenseInfo
$statusMap = @{0='Unlicensed';1='Licensed';2='OOBGrace';3='OOTGrace';4='NonGenuineGrace';5='Notification';6='ExtendedGrace'}
$licenseReport = $licenseAfter | Select-Object Name, Description, PartialProductKey,
    @{N='Status';E={$statusMap[[int]$_.LicenseStatus]}}
$licenseReport | Format-Table -AutoSize
$licenseReport | Format-Table -AutoSize | Out-String | Save-Text 'windows-activation.txt'
$oemKeyPresent = -not [string]::IsNullOrWhiteSpace((Get-CimInstance SoftwareLicensingService).OA3xOriginalProductKey)
"OEM firmware key present: $oemKeyPresent" | Add-Content (Join-Path $ReportRoot 'windows-activation.txt')

Section 'WINGET / BASE APPLICATIONS'
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warning 'WinGet is not available. Update/install Microsoft App Installer, then rerun this script.'
} else {
    winget source update

    if (-not $SkipBaseApps) {
        $apps = @(
            'Google.Chrome',
            'LastPass.LastPass',
            '7zip.7zip',
            'Adobe.Acrobat.Reader.64-bit'
        )
        foreach ($app in $apps) { Install-WingetPackage $app }

        # Dell Command Update - prefer Universal package, fall back to classic package.
        if ($cs.Manufacturer -match 'Dell') {
            & winget install --id Dell.CommandUpdate.Universal --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
            if ($LASTEXITCODE -ne 0) {
                Install-WingetPackage 'Dell.CommandUpdate'
            }
        }
    } else {
        Write-Host 'Base app installation skipped. Use the separate approved-app installer.'
    }

    if ($InstallMicrosoft365) {
        Write-Host 'Installing Microsoft 365 Apps package...' -ForegroundColor Yellow
        Install-WingetPackage 'Microsoft.Office'
    } else {
        Write-Host 'Office skipped intentionally. Confirm the exact Office/Microsoft 365 licence first.' -ForegroundColor DarkYellow
    }
}

Section 'DELL DRIVER / BIOS / FIRMWARE UPDATE'
if ($ApplyDellUpdates -and $cs.Manufacturer -notmatch 'Dell') {
    Write-Warning 'Dell updates requested on a non-Dell machine. Skipping.'
}
if ($ApplyDellUpdates -and $cs.Manufacturer -match 'Dell') {
    Write-Warning 'Firmware/BIOS changes were explicitly requested. Keep AC power connected.'
    $dcuCandidates = @(
        "$env:ProgramFiles\Dell\CommandUpdate\dcu-cli.exe",
        "${env:ProgramFiles(x86)}\Dell\CommandUpdate\dcu-cli.exe"
    ) | Where-Object { $_ -and (Test-Path $_) }
    $dcu = $dcuCandidates | Select-Object -First 1

    if ($dcu) {
        Write-Host "Dell Command Update found: $dcu" -ForegroundColor Green
        & $dcu /scan -silent -outputLog=(Join-Path $ReportRoot 'dell-update-scan.log')
        & $dcu /applyUpdates -silent -reboot=disable -outputLog=(Join-Path $ReportRoot 'dell-update-apply.log')
    } else {
        Write-Warning 'Dell Command Update CLI not found yet. Open Dell Command Update after this script and apply all recommended BIOS/firmware/driver updates.'
    }
}

Section 'SECURITY BASELINE'
try { Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True } catch { Write-Warning $_ }
try { Set-MpPreference -DisableRealtimeMonitoring $false } catch { Write-Warning $_ }
try { Set-MpPreference -PUAProtection Enabled } catch { Write-Warning $_ }
try { Update-MpSignature } catch { Write-Warning $_ }
try { Start-MpScan -ScanType QuickScan } catch { Write-Warning $_ }

Get-MpComputerStatus |
    Select-Object AntivirusEnabled, AntispywareEnabled, RealTimeProtectionEnabled,
        BehaviorMonitorEnabled, IoavProtectionEnabled, NISEnabled,
        AntivirusSignatureLastUpdated, QuickScanEndTime |
    Format-List |
    Out-String | Save-Text 'defender-status.txt'

Get-NetFirewallProfile |
    Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction |
    Format-Table -AutoSize |
    Out-String | Save-Text 'firewall-status.txt'

try {
    "Secure Boot: $(Confirm-SecureBootUEFI)" | Save-Text 'secure-boot.txt'
} catch {
    "Secure Boot query failed: $($_.Exception.Message)" | Save-Text 'secure-boot.txt'
}
try {
    Get-Tpm | Format-List | Out-String | Save-Text 'tpm-status.txt'
} catch {
    "TPM query failed: $($_.Exception.Message)" | Save-Text 'tpm-status.txt'
}

Section 'POWER SETTINGS'
if (-not $SkipPowerConfiguration) {
# Balanced does not prevent Intel Turbo Boost under load, but avoids needless idle drain.
powercfg /setactive SCHEME_BALANCED
powercfg /hibernate on

# Closing the lid = Sleep, not immediate Hibernate.
powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION $LidCloseAction
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION $LidCloseAction

# Safety net: if it remains asleep for a while, transition to Hibernate.
$hibDcSeconds = [int]($HibernateAfterMinutesOnBattery * 60)
$hibAcSeconds = [int]($HibernateAfterMinutesOnAC * 60)
powercfg /setdcvalueindex SCHEME_CURRENT SUB_SLEEP HIBERNATEIDLE $hibDcSeconds
powercfg /setacvalueindex SCHEME_CURRENT SUB_SLEEP HIBERNATEIDLE $hibAcSeconds

# Prevent scheduled wake timers while running on battery.
powercfg /setdcvalueindex SCHEME_CURRENT SUB_SLEEP RTCWAKE 0

powercfg /setactive SCHEME_CURRENT
} else {
    Write-Host 'Power configuration unchanged; collecting current diagnostics only.'
}

# Save current power settings / sleep capabilities.
powercfg /a | Save-Text 'available-sleep-states.txt'
powercfg /query SCHEME_CURRENT SUB_BUTTONS LIDACTION | Save-Text 'lid-action.txt'
powercfg /query SCHEME_CURRENT SUB_SLEEP | Save-Text 'sleep-power-settings.txt'
powercfg /requests | Save-Text 'power-requests.txt'
powercfg /waketimers | Save-Text 'wake-timers.txt'
powercfg /devicequery wake_armed | Save-Text 'wake-armed-devices.txt'
powercfg /lastwake | Save-Text 'last-wake.txt'

Section 'BATTERY HEALTH / POWER REPORTS'
# Built-in HTML reports.
powercfg /batteryreport /output (Join-Path $ReportRoot 'battery-report.html')
powercfg /sleepstudy /output (Join-Path $ReportRoot 'sleepstudy-before-test.html')
powercfg /systemsleepdiagnostics /output (Join-Path $ReportRoot 'system-sleep-diagnostics-before-test.html')
powercfg /systempowerreport /output (Join-Path $ReportRoot 'system-power-report-before-test.html')

# Try to calculate battery health directly from WMI.
try {
    $static = Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction Stop | Select-Object -First 1
    $full   = Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction Stop | Select-Object -First 1
    if ($static.DesignedCapacity -gt 0 -and $full.FullChargedCapacity -gt 0) {
        $health = [math]::Round(($full.FullChargedCapacity / $static.DesignedCapacity) * 100, 1)
        @"
Design capacity:      $($static.DesignedCapacity) mWh
Full charge capacity: $($full.FullChargedCapacity) mWh
Estimated health:     $health %
"@ | Save-Text 'battery-health.txt'
        Write-Host "Estimated battery health: $health%" -ForegroundColor Green
    }
} catch {
    "Battery WMI health data unavailable. Use battery-report.html instead.`n$($_.Exception.Message)" | Save-Text 'battery-health.txt'
}

try {
    $cycle = Get-CimInstance -Namespace root\wmi -ClassName BatteryCycleCount -ErrorAction Stop | Select-Object -First 1
    "Cycle count: $($cycle.CycleCount)" | Add-Content (Join-Path $ReportRoot 'battery-health.txt')
} catch { }

# Relevant power events for the last 2 days.
$startTime = (Get-Date).AddDays(-2)
try {
    Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Kernel-Power'; StartTime=$startTime} |
        Select-Object TimeCreated, Id, LevelDisplayName, Message |
        Format-List | Out-String | Save-Text 'kernel-power-events.txt'
} catch { }
try {
    Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Power-Troubleshooter'; StartTime=$startTime} |
        Select-Object TimeCreated, Id, Message |
        Format-List | Out-String | Save-Text 'power-troubleshooter-events.txt'
} catch { }

Section 'SYSTEM RESTORE'
try {
    Enable-ComputerRestore -Drive 'C:\'
    Checkpoint-Computer -Description 'Fresh Windows Setup' -RestorePointType MODIFY_SETTINGS
    Write-Host 'Initial System Restore point created.' -ForegroundColor Green
} catch {
    Write-Warning "System Restore point was not created: $($_.Exception.Message)"
}

Section 'UPDATE WINGET APPLICATIONS'
if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget upgrade --all --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
}

Section 'CREATE AFTER-SLEEP TEST HELPER'
$afterSleepScript = @'
# Run this as Administrator immediately after waking from the sleep test.
$Desktop = [Environment]::GetFolderPath('Desktop')
$Out = Join-Path $Desktop ("After-Sleep-Test-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $Out -Force | Out-Null
powercfg /batteryreport /output (Join-Path $Out 'battery-report-after.html')
powercfg /sleepstudy /output (Join-Path $Out 'sleepstudy-after.html')
powercfg /systemsleepdiagnostics /output (Join-Path $Out 'system-sleep-diagnostics-after.html')
powercfg /systempowerreport /output (Join-Path $Out 'system-power-report-after.html')
powercfg /lastwake | Out-File (Join-Path $Out 'last-wake.txt') -Encoding UTF8
powercfg /requests | Out-File (Join-Path $Out 'power-requests.txt') -Encoding UTF8
powercfg /waketimers | Out-File (Join-Path $Out 'wake-timers.txt') -Encoding UTF8
powercfg /devicequery wake_armed | Out-File (Join-Path $Out 'wake-armed-devices.txt') -Encoding UTF8
Write-Host "Done. Reports saved to: $Out" -ForegroundColor Green
'@
$afterSleepPath = Join-Path $Desktop 'After-Sleep-Test.ps1'
Set-Content -Path $afterSleepPath -Value $afterSleepScript -Encoding UTF8

Section 'FINISHED'
Write-Host "Reports: $ReportRoot" -ForegroundColor Green
Write-Host "After-sleep helper: $afterSleepPath" -ForegroundColor Green
Write-Host 'NEXT: reboot once if Dell/Windows updates require it, then run Windows Update until no important updates remain.' -ForegroundColor Yellow
Write-Host 'For the sleep test: charge to 80-100%, unplug AC, note battery %, close lid for 30 minutes, reopen, note battery %, then run After-Sleep-Test.ps1 as Administrator.' -ForegroundColor Yellow
Write-Host 'For a true RAM test: use F12 -> Diagnostics (Dell ePSA) and/or MemTest86. Windows inventory above is not a stress test.' -ForegroundColor Yellow

Stop-Transcript
Start-Process 'ms-settings:windowsupdate'

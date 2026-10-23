# Windows PC Migration Toolkit

Reusable PowerShell scripts for **moving from an old Windows PC to a clean Windows PC**, without blindly copying old drivers, OEM bloatware or licensing problems.

Typical use case: retire an older Windows 10 ThinkPad and configure a refurbished/new Windows 11 business laptop. The toolkit is deliberately general so scripts for backups, profiles, printers, data verification and other future workflows can be added.

> **Project status:** personal toolkit / starting point. Test and review commands before using them on production machines. Scripts have not been executed on an actual Windows machine in this package build.

## Goals

- Inventory installed software, Office details, printers and startup apps on the **old** PC.
- Review the inventory and select which apps are actually worth migrating.
- Reinstall only approved apps on the **new** PC with WinGet.
- Check Windows activation, Defender, firewall, battery and sleep behavior.
- Keep generated reports and licence information **out of Git**.

## Quick start

Open **Windows PowerShell as Administrator**. On Windows 10/11, `powershell.exe -NoProfile -ExecutionPolicy Bypass -File` lets you run a reviewed, locally saved script without permanently changing your execution policy.

### Step 1 — Inventory the OLD PC (Windows 10/11)

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\01-audit-old-pc.ps1
```

Find `OldLaptop-Audit-YYYYMMDD-HHMMSS.zip` on the old PC's Desktop. **Do not commit the ZIP.** It contains inventory, printer details and activation information. Review it locally or share it privately for software selection.

### Step 2 — Decide what to reinstall

Read `docs/migration-checklist.md`. Remove drivers, Lenovo/Dell OEM tools from the old device, obsolete installers, unused software and redundant runtimes. Confirm paid-product licensing separately.

Edit `config/apps.example.json` and set `enabled` for the apps to approve. Add WinGet package IDs after verifying with `winget search`/`winget show`. For real use, copy this file to `config/apps.local.json` (ignored by Git) if it contains private selections.

### Step 3 — Install approved apps on the NEW PC

**Preview only** (does not install anything):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\04-install-approved-apps.ps1 -ConfigPath .\config\apps.example.json
```

**Actually install:**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\04-install-approved-apps.ps1 -ConfigPath .\config\apps.example.json -Install
```

### Step 4 — Configure/diagnose the NEW PC

The setup script installs a default set of apps unless `-SkipBaseApps` is supplied. To avoid duplicates when using the app installer, use:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\02-setup-new-pc.ps1 -SkipBaseApps -TimeZoneId 'W. Australia Standard Time'
```

To leave existing power settings intact, add `-SkipPowerConfiguration`.

**Firmware updates are opt-in**, not automatic:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\02-setup-new-pc.ps1 -SkipBaseApps -TimeZoneId 'W. Australia Standard Time' -ApplyDellUpdates
```

Only use `-ApplyDellUpdates` on a supported **Dell** PC, with a charged battery and AC adapter connected. BIOS/firmware updates can require a restart, and unattended updates carry risk.

`-InstallMicrosoft365` is also opt-in and should be used **only after confirming the correct Office licence**. Perpetual Office 2021/2024 keys may require their own installation package rather than Microsoft 365 Apps.

This script also tries online activation when Windows is not licensed (same edition/licence required), applies baseline Windows security checks, installs apps unless skipped, and sets up balanced power/Sleep-to-Hibernate unless skipped. It **does not split disks, copy user documents, disable encryption, or configure backup destinations**.

### Step 5 — Investigate battery drain on lid-close

With AC unplugged, note charge percentage, close the lid for approximately 30 minutes, wake up, then run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\03-after-sleep-test.ps1
```

Inspect `battery-report-after.html` and `sleepstudy-after.html` on the Desktop. Read `docs/battery-and-sleep.md`.

## Included scripts

| Script | Where to run | Purpose |
| --- | --- | --- |
| `scripts/01-audit-old-pc.ps1` | Old PC | Installed applications, WinGet export, Office and printer inventory |
| `scripts/02-setup-new-pc.ps1` | New Windows PC (best suited to Dell) | Base setup, Windows activation, security, device and power diagnostics |
| `scripts/03-after-sleep-test.ps1` | New PC | Collect diagnostic reports after a timed sleep test |
| `scripts/04-install-approved-apps.ps1` | New PC | Preview/WinGet install from a curated JSON app list |

## Requirements

- Windows 10/11 (Windows PowerShell 5.1) for auditing; Windows 11 recommended for setup.
- Administrator privileges for diagnostics/management.
- Network connection and Windows Package Manager (`winget`) for installs.
- Dell Command Update only on compatible Dell machines.

## Safety and privacy

**Do not upload audit exports, licences, product keys, user profiles, printer information, system reports or credentials to a public GitHub repository.** `.gitignore` covers common generated files, but always inspect `git status` before committing. A D: partition on the same SSD is **not** a backup. Create an independent backup strategy before migrating data.

For security specifics, see [SECURITY.md](SECURITY.md). For the full workflow, see [Migration checklist](docs/migration-checklist.md).

## Contributing / future scripts

Add future files under `scripts/` with numbered prefixes, make non-destructive operations the default, provide a short usage example, and update this README. Good next additions: user-profile migration, browser bookmarks export, printer migration, backup verification and Windows Update auditing.

## License

MIT — see [LICENSE](LICENSE).

# Migration checklist

## Before leaving the old PC

- [ ] Back up important files to external storage/cloud and verify a restore by opening a few files.
- [ ] Run `scripts/01-audit-old-pc.ps1` and review the exported inventory privately.
- [ ] Identify apps needed for accounting, tax filing, banking, PDFs, Office and password management.
- [ ] Check whether each program uses account-based, device-bound, subscription or product-key activation.
- [ ] Export browser bookmarks only if account sync is not enabled.
- [ ] Record printer model, printer/scanner workflows, and any specialist USB/smart-card devices.
- [ ] Record custom macros, Outlook data files, templates, local databases and relevant app data.
- [ ] Verify access to Office/other licence accounts **without exposing keys**.

## Before preparing the new PC

- [ ] Check battery report, SSD health and RAM diagnostics.
- [ ] Verify Windows 11 activation (digital licence is tied to device/edition).
- [ ] Confirm hardware drivers using OEM support tools.
- [ ] Review the app inventory and create an approved installation list.
- [ ] Keep BitLocker/encryption choices explicit; recovery keys must be backed up if enabled.
- [ ] Keep the Windows system partition sufficiently large; do not resize SSD partitions without backups.

## New PC and handover

- [ ] Review `config/apps.example.json` and preview approved installations.
- [ ] Install software with `scripts/04-install-approved-apps.ps1 -Install`.
- [ ] Run and review `scripts/02-setup-new-pc.ps1`.
- [ ] Install the **correct licensed Office edition** and sign into user-specific apps.
- [ ] Migrate documents and custom app data separately (not handled by these scripts).
- [ ] Verify Office activation, accounting data, printers/scanners, Excel macros, browser access.
- [ ] Configure independent regular file backups, and **test a restore**.
- [ ] Remove temporary setup accounts and sign out of all setup tools/password managers.
- [ ] Keep the old machine untouched until migration and verification are complete.

## How to interpret the audit

**Probably reinstall:** Chrome/Edge alternatives, 1Password/LastPass, PDF tools, Microsoft Office, accounting apps and specialist plugins actually in use.

**Do not blindly migrate:** Lenovo utilities, model-specific drivers, old antivirus suites, vendor support agents, obsolete VC++/.NET runtimes or Windows components. Dependencies should be installed by their corresponding applications when needed.

**Needs investigation:** licence-managed apps, Office, tax software, bank certificates, Outlook data files, accounting databases, printers/scanners and browser extensions.

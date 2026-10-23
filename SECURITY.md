# Security and privacy

This repository contains **scripts and example configuration only**. Its audit output is private operational information and must not be committed to GitHub.

## What the audit may reveal

The exported program inventory, installed printer ports, startup commands, Windows/Office licensing status and software data may include local usernames, organization names, internal paths, partial keys, addresses or network destinations. Do not publish the generated ZIP or report directory.

Scripts deliberately **do not extract complete product keys, passwords, browser cookies or password-vault contents**. Transfer or re-activate licensed applications using legitimate account credentials/keys provided by their owner.

## Before running

- Inspect PowerShell source and the application's WinGet publisher before installing.
- Run elevated commands only on devices you own or administer with authorization.
- Back up important data before editing partitions or doing a clean Windows install (not automated here).
- Firmware updates via `-ApplyDellUpdates` are opt-in; ensure AC power, stability and a suitable Dell model.
- Review `git status` before pushing changes and scan new files for secrets.
- Antivirus is not a substitute for independent backup; a separate D: partition is not an independent backup.

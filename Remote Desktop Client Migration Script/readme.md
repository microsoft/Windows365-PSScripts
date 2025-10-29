# Windows App Installer MultiTool

A PowerShell utility to detect and install the Windows 365 "Windows App" client, optionally set its auto-update registry key, and remove legacy "Remote Desktop" installs when present. This README documents the script behavior, parameters, examples, logs and troubleshooting.

## What it does
- Detects whether the Windows App (`MicrosoftCorporationII.Windows365`) is installed.
- Installs the Windows App from one of three sources:
  - Microsoft Store (via winget id `9N1F85V9T8BN`) — `Store` (default)
  - WinGet CDN package (`Microsoft.WindowsApp`) — `WinGet`
  - Direct MSIX download (FWLINK) and `Add-AppxPackage` — `MSIX`
- Optionally writes `HKLM:\SOFTWARE\Microsoft\WindowsApp\DisableAutomaticUpdates` to control auto updates.
- Optionally uninstalls legacy "Remote Desktop" via registry/MSI or package uninstall methods.
- Writes logs to console and to the configured log file.

## Files
- `Windows App Installer.ps1` — main script.
- Runtime logs:
  - Default log: `%windir%\Temp\MultiTool.log` (can be changed with `-logpath`)
  - Store install trace: `%windir%\Temp\WindowsAppStoreInstall.log`
  - WinGet install trace: `%windir%\Temp\WindowsAppWinGetInstall.log`

## Requirements
- Windows (modern Windows 10/11 recommended).
- PowerShell (script compatible with Windows PowerShell 5.1 and later).
- Administrative privileges to install packages and write to HKLM.
- Internet access for Store/WinGet/MSIX downloads.
- Winget and/or Microsoft Store available for corresponding install methods (use `MSIX` when Store is blocked).

## Parameters
- `-source` (string)  
  Where to source the installer payload. Allowed values: `Store` (default), `WinGet`, `MSIX`.
- `-DisableAutoUpdate` (int)  
  Sets the registry DWORD `HKLM:\SOFTWARE\Microsoft\WindowsApp\DisableAutomaticUpdates`. Allowed values:
  - `0` — Enable updates (default)
  - `1` — Disable updates from all locations
  - `2` — Disable updates from Microsoft Store
  - `3` — Disable updates from the CDN
- `-SkipRemoteDesktopUninstall` (switch)  
  If present, skip attempting to remove legacy Remote Desktop.
- `-logpath` (string)  
  Path to the primary log file (default: `$env:windir\temp\MultiTool.log`).

## High-level functions (what they do)
- `update-log` — logging helper (console / file / both).
- `invoke-WAInstallCheck` — returns 0 if Windows App is present, 1 otherwise.
- `install-windowsappstore` — triggers Store install (uses winget id `9N1F85V9T8BN`) and logs to temp file.
- `install-windowsappwinget` — triggers WinGet install for `Microsoft.WindowsApp` and logs to temp file.
- `install-windowsappMSIX` — downloads MSIX via FWLINK and installs with `Add-AppxPackage`.
- `uninstall-MSRDCreg` — primary uninstall of legacy Remote Desktop via registry MSI uninstall string.
- `uninstall-MSRDC` — secondary uninstall via `Get-Package` / `Uninstall-Package`.
- `invoke-disableautoupdate` — creates/sets `DisableAutomaticUpdates` DWORD.

## Usage examples (run elevated)
Default (Store) install:
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\Windows App Installer.ps1"
```

Install via WinGet and disable Store updates (set key = 2):
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\Windows App Installer.ps1" -source WinGet -DisableAutoUpdate 2
```

Install via MSIX and skip removing legacy Remote Desktop:
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\Windows App Installer.ps1" -source MSIX -SkipRemoteDesktopUninstall
```

Specify an alternate log file:
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\Windows App Installer.ps1" -logpath "C:\Temp\WinAppInstall.log"
```

## Exit behavior & logs
- On fatal install failures the script calls `exit 1`.
- Normal success writes completion messages to logs and returns normally.
- Check logs for details:
  - Primary: `%windir%\Temp\MultiTool.log` (or the `-logpath` you supplied)
  - Install traces: `%windir%\Temp\WindowsAppStoreInstall.log`, `%windir%\Temp\WindowsAppWinGetInstall.log`

## Troubleshooting
- Permission / access denied:
  - Run PowerShell as Administrator.
- Winget not found or Microsoft Store disabled:
  - Use `-source MSIX` to attempt a direct MSIX install.
- `Add-AppxPackage` errors:
  - Ensure sideloading is allowed or that the package signature and system policy permit the install.
- Remote Desktop uninstall fails:
  - The script tries registry/MSI first then package uninstall. Manual removal may be required if uninstall strings are missing.
- For diagnostics:
  - Inspect the three logs listed above for error messages and stack traces.

## Known limitations
- Script assumes availability of `winget` for Store/WinGet flows; environments with Store disabled may fail unless `MSIX` chosen.
- Error handling is present but could be more granular (some functions catch and log but do not standardize exit codes).
- Not explicitly tested on Windows LTSC or older Windows 10 branches — behavior may vary.

## Recommended next steps
- Add a `-WhatIf`/dry-run mode.
- Add explicit checks for `winget`/Store presence before choosing install path.
- Convert `update-log` to structured logging (timestamped JSON) for automation.
- Add more granular exit codes to represent specific failure types.

## License
No license is specified. Add a `LICENSE` file if you intend to publish or share.

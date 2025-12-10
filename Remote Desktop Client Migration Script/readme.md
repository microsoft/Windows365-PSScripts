# Remote Desktop Client Migration Script

## Overview
This PowerShell script automates the migration from the legacy Microsoft Remote Desktop client to the new Windows App for Windows 365.  It works by installing Windows App from an MSIX as a provisioned package, which means that every new and existing user of a given computer will get Windows App installed.

 It performs the following actions:
- Installs the Windows App via MSIX package download
- Optionally uninstalls the legacy Remote Desktop client
- Sets registry keys to control auto-update behavior
- Logs all actions to a specified log file

## Features
- **Automated Installation:** Downloads and installs the latest Windows App MSIX package.
- **Legacy Client Removal:** Uninstalls the old Remote Desktop client using registry and package methods (unless skipped).
- **Auto-Update Control:** Sets registry keys to enable/disable automatic updates for the Windows App.
- **Comprehensive Logging:** Logs all operations to a file and/or console for troubleshooting.

## Parameters
| Parameter                | Description                                                      | Default Value                      |
|--------------------------|------------------------------------------------------------------|------------------------------------|
| `DisableAutoUpdate`      | Controls auto-update registry key (0=Enable, 1-3=Disable modes)  | `0`                                |
| `SkipRemoteDesktopUninstall` | If set, skips uninstalling the legacy Remote Desktop client     | Not set (uninstall performed)      |
| `logpath`                | Path to log file                                                 | `%windir%\temp\RDC-Migration.log` |

### `DisableAutoUpdate` Values
- `0`: Enables updates (default)
- `1`: Disables updates from all locations
- `2`: Disables updates from Microsoft Store
- `3`: Disables updates from CDN location

## Known Limitations

- Script will not uninstall Remote Desktop if it has been installed in the User context. 
- Script must be run with the System account. It is intended to be deployed from Intune or other systems management platforms. PSEXEC can be used for validation purposes.

## Usage
Run the script using the System account. It is intended for mass deployment through Intune or other systems management platforms:

```powershell
# Example: Enable updates and uninstall legacy client
.\Remote Desktop Client Migration Script.ps1

# Example: Disable all updates and skip uninstall
.\Remote Desktop Client Migration Script.ps1 -DisableAutoUpdate 1 -SkipRemoteDesktopUninstall




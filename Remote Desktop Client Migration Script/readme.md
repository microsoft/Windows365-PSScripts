# Remote Desktop Client Migration Script

## Overview
This PowerShell script automates the migration from the legacy Remote Desktop client to the new **Windows App** (formerly Windows 365). It handles the installation of Windows App from multiple sources and optionally uninstalls the old Remote Desktop client.

**Version:** 1.0  
**Copyright:** Microsoft Corporation. All rights reserved. Licensed under the MIT license.

## What it does
- Detects whether the Windows App (`MicrosoftCorporationII.Windows365`) is already installed
- Installs the Windows App from one of three sources:
  - Microsoft Store (via winget id `9N1F85V9T8BN`) — `Store` (default)
  - WinGet CDN package (`Microsoft.WindowsApp`) — `WinGet`
  - Direct MSIX download (FWLINK) and `Add-AppxPackage` — `MSIX`
- Validates successful Windows App installation
- Optionally uninstalls legacy "Remote Desktop" client using two fallback methods:
  - Primary: Registry-based MSI uninstall
  - Fallback: Package-based uninstall
- Optionally configures automatic update behavior via registry key
- Comprehensive logging to console and file

## Prerequisites
- Windows 10/11 operating system
- PowerShell 5.1 or later
- Administrator privileges (required for package installation and registry modifications)
- Internet connectivity (for downloading Windows App)
- WinGet (if using WinGet installation method)
- Microsoft Store access (if using Store installation method, or use `MSIX` when Store is blocked)

## Parameters

### `-source`
Specifies where to source the Windows App installer payload.

**Type:** String  
**Valid Values:** `Store`, `WinGet`, `MSIX`  
**Default:** `Store`  
**Required:** No

- `Store`: Installs from Microsoft Store (ID: 9N1F85V9T8BN)
- `WinGet`: Installs from WinGet CDN using package ID `Microsoft.WindowsApp`
- `MSIX`: Downloads and installs directly from MSIX package (use when Store is blocked)

### `-DisableAutoUpdate`
Controls the automatic update behavior for Windows App by setting the registry key `HKLM:\SOFTWARE\Microsoft\WindowsApp\DisableAutomaticUpdates`.

**Type:** Integer  
**Valid Values:** `0`, `1`, `2`, `3`  
**Default:** `0`  
**Required:** No

- `0`: Enables updates (default)
- `1`: Disables updates from all locations
- `2`: Disables updates from Microsoft Store only
- `3`: Disables updates from CDN location only

### `-SkipRemoteDesktopUninstall`
Prevents the script from uninstalling the Remote Desktop client.

**Type:** Switch  
**Default:** `$false`  
**Required:** No

### `-logpath`
Specifies the location and filename for the script log.

**Type:** String  
**Default:** `$env:windir\temp\RDC-Migration.log`  
**Required:** No

## Usage Examples

### Basic Usage (Microsoft Store - Default)
```powershell
.\Remote Desktop Client Migration Script.ps1
```

### Install from WinGet
```powershell
.\Remote Desktop Client Migration Script.ps1 -source WinGet
```

### Install from MSIX (Direct Download)
```powershell
.\Remote Desktop Client Migration Script.ps1 -source MSIX
```

### Disable All Auto-Updates
```powershell
.\Remote Desktop Client Migration Script.ps1 -DisableAutoUpdate 1
```

### Disable Store Updates Only
```powershell
.\Remote Desktop Client Migration Script.ps1 -source WinGet -DisableAutoUpdate 2
```

### Keep Remote Desktop Client Installed
```powershell
.\Remote Desktop Client Migration Script.ps1 -SkipRemoteDesktopUninstall
```

### Custom Log Location
```powershell
.\Remote Desktop Client Migration Script.ps1 -logpath "C:\Logs\RDC-Migration.log"
```

### Full Example with All Parameters
```powershell
.\Remote Desktop Client Migration Script.ps1 -source Store -DisableAutoUpdate 2 -logpath "C:\Logs\migration.log"
```

### Run with Execution Policy Bypass
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\Remote Desktop Client Migration Script.ps1" -source MSIX -SkipRemoteDesktopUninstall
```

## How It Works

The script follows this workflow:

1. **Pre-Installation Check**: Verifies if Windows App is already installed
   - If found, skips installation
   - If not found, proceeds to installation

2. **Installation**: Installs Windows App from the specified source
   - **Store**: Uses WinGet with Store ID `9N1F85V9T8BN`
   - **WinGet**: Uses WinGet CDN package `Microsoft.WindowsApp`
   - **MSIX**: Downloads from `https://go.microsoft.com/fwlink/?linkid=2262633` and installs via `Add-AppxPackage`

3. **Validation**: Confirms successful Windows App installation
   - Checks for AppX package `MicrosoftCorporationII.Windows365`
   - Exits with error code 1 if not found

4. **Uninstallation** (unless `-SkipRemoteDesktopUninstall` is used):
   - **Primary Method**: Registry-based MSI uninstall using `MsiExec.exe /x`
   - **Fallback Method**: Package-based uninstall using `Uninstall-Package`

5. **Configuration**: Applies auto-update registry settings if specified

6. **Completion**: Logs final status and exits

## Log Files

### Main Script Log
- **Default Location:** `%windir%\temp\RDC-Migration.log`
- **Configurable via:** `-logpath` parameter
- **Contains:** Detailed information about script execution with timestamps, actions, warnings, and errors

### Installation Process Logs
- **Store Installation:** `%windir%\temp\WindowsAppStoreInstall.log`
- **WinGet Installation:** `%windir%\temp\WindowsAppWinGetInstall.log`
- **MSIX Download:** Payload downloaded to `%windir%\temp\`

### Log Format
Each log entry includes:
- Log level (Information, Warning, Error, Comment)
- Timestamp in format: `MM/DD/YY HH:MM:SS AM/PM`
- Descriptive message

## Exit Codes
- **0**: Success (normal completion)
- **1**: Failure (Windows App installation failed or not detected after installation)

## Script Functions

The script includes the following key functions:

- **`update-log`**: Logging helper that writes to console and/or file with timestamps
- **`invoke-WAInstallCheck`**: Checks if Windows App is installed (returns 0 if present, 1 if not)
- **`install-windowsappstore`**: Installs Windows App from Microsoft Store via WinGet
- **`install-windowsappwinget`**: Installs Windows App from WinGet CDN
- **`install-windowsappMSIX`**: Downloads and installs Windows App from direct MSIX download
- **`uninstall-MSRDCreg`**: Primary method to uninstall Remote Desktop via registry MSI uninstall string
- **`uninstall-MSRDC`**: Fallback method to uninstall Remote Desktop via `Get-Package`/`Uninstall-Package`
- **`invoke-disableautoupdate`**: Creates/sets the `DisableAutomaticUpdates` registry key

## Registry Configuration

When using `-DisableAutoUpdate`, the script creates/modifies:

```
Registry Key: HKLM:\SOFTWARE\Microsoft\WindowsApp
Value Name: DisableAutomaticUpdates
Value Type: DWORD
```

## Troubleshooting

### Permission or Access Denied Errors
- Ensure PowerShell is running as Administrator
- Verify write permissions to log directory and registry

### Windows App Installation Fails
- **Check Internet Connectivity**: Ensure the device can reach Microsoft services
- **WinGet Not Found**: If using Store or WinGet source, verify WinGet is installed
- **Microsoft Store Disabled**: Use `-source MSIX` for direct MSIX installation
- **Review Logs**: Check installation logs in `%windir%\temp\` for specific errors

### AppX Package Installation Errors
- Ensure sideloading is allowed in Windows settings
- Verify package signature and system policy permit installation
- Check if Developer Mode is required

### Remote Desktop Uninstall Issues
- The script automatically tries two methods (registry-based MSI and package-based)
- Check the main log file for specific error messages
- Use `-SkipRemoteDesktopUninstall` to bypass uninstallation if problematic
- Manual removal may be required if uninstall strings are missing

### Script Exits with Error Code 1
- Windows App installation failed or was not detected after installation
- Review all log files for error details
- Try an alternative installation source

### WinGet Command Not Recognized
- Install App Installer from Microsoft Store
- Or use `-source MSIX` to bypass WinGet requirement

## Known Limitations
- Script assumes WinGet availability for Store/WinGet installation methods
- Error handling logs exceptions but may not provide granular exit codes for all failure types
- Not extensively tested on Windows LTSC or older Windows 10 branches
- Requires internet connectivity for all installation sources

## Additional Information

For more information about this script and other Windows 365 PowerShell scripts, visit:  
**https://github.com/microsoft/Windows365-PSScripts**

## License
Copyright (c) Microsoft Corporation. All rights reserved.  
Licensed under the MIT license. See LICENSE in the project root for license information.

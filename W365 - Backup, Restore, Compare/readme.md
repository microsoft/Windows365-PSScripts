# W365-BRC PowerShell Module

## Overview
W365-BRC (Windows 365 Backup, Restore, Compare) is a PowerShell module designed to help manage Windows 365 configurations. This module provides functionality to backup, restore, and compare Windows 365 policies and settings - Provisioning Policies, Azure Network Connections, and User Settings. Use cases for this tool are disaster recovery, dev to prod policy creation, and change control.

## Features
- **Backup**: Export Windows 365 configurations to JSON files
- **Restore**: Import Windows 365 configurations from JSON backups
- **Compare**: Compare current configurations with backed up versions

## Installation

### Option 1: Manual Installation
1. Download or clone this repository
2. Copy the `W365-BRC` folder to one of the PowerShell module paths:
   - `$env:USERPROFILE\Documents\PowerShell\Modules` (Current User)
   - `$env:ProgramFiles\PowerShell\Modules` (All Users)

### Option 2: Import Directly
```powershell
Import-Module "C:\path\to\W365-BRC\W365-BRC.psm1"
```

## Requirements
- PowerShell 5.1 or higher
- Microsoft Graph PowerShell SDK
- Appropriate permissions for Windows 365 management

## Prerequisites
Before using this module, ensure you have the Microsoft Graph PowerShell modules installed:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

## Functions

### Invoke-W365Backup
Creates timestamped backups of Windows 365 configuration objects.

**Syntax:**
```powershell
Invoke-W365Backup [-Object] <String> [[-Path] <String>]
```

**Parameters:**
- `Object`: Specifies which object type to backup
  - Valid values: "ProvisioningPolicy", "CustomImages", "UserSetting", "AzureNetworkConnection", "All"
- `Path`: Backup directory path (Default: "c:\W365-Policy-Backup\")

**Examples:**
```powershell
# Backup all Windows 365 configurations
Invoke-W365Backup -Object "All"

# Backup only provisioning policies to custom path
Invoke-W365Backup -Object "ProvisioningPolicy" -Path "C:\MyBackups\"

# Backup custom images
Invoke-W365Backup -Object "CustomImages"
```

### Invoke-W365Restore
Restores Windows 365 configuration objects from JSON backup files.

**Syntax:**
```powershell
Invoke-W365Restore [-Object] <String> [[-JSON] <String>]
```

**Parameters:**
- `Object`: Specifies which object type to restore
  - Valid values: "ProvisioningPolicy", "UserSetting", "AzureNetworkConnection"
- `JSON`: Path to the JSON backup file (If not specified, a file dialog opens)

**Examples:**
```powershell
# Restore a provisioning policy (file dialog will open)
Invoke-W365Restore -Object "ProvisioningPolicy"

# Restore a user setting from specific file
Invoke-W365Restore -Object "UserSetting" -JSON "C:\Backup\UserSetting.json"
```

### Invoke-W365Compare
Compares current Windows 365 configurations with backup files to identify differences.

**Syntax:**
```powershell
Invoke-W365Compare
```

**Example:**
```powershell
# Launch comparison tool
Invoke-W365Compare
```

## Required Permissions

The module requires Microsoft Graph API permissions:
- `CloudPC.Read.All` - For reading Windows 365 configurations
- `CloudPC.ReadWrite.All` - For modifying Windows 365 configurations
- `DeviceManagementConfiguration.Read.All` - For reading device management configurations

## Authentication

Before using the module functions, authenticate with Microsoft Graph:

```powershell
Connect-MgGraph -Scopes "CloudPC.ReadWrite.All", "DeviceManagementConfiguration.Read.All"
```

## Project Structure
```
W365-BRC/
├── Public/
│   ├── Invoke-W365Backup.ps1
│   ├── Invoke-W365Restore.ps1
│   └── Invoke-W365Compare.ps1
├── Private/
│   ├── Export-Json.ps1
│   ├── Invoke-FolderCheck.ps1
│   └── [Other helper functions...]
├── Tests/
│   └── W365-BRC.Tests.ps1
├── W365-BRC.psm1
├── W365-BRC.psd1
└── README.md
```

## Testing

Run the included Pester tests:

```powershell
# Install Pester if not already installed
Install-Module Pester -Force

# Run tests
Invoke-Pester -Path ".\Tests\W365-BRC.Tests.ps1"
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add or update tests
5. Submit a pull request

## License

This project is licensed under the MIT License.

## Support

For issues, questions, or contributions, please visit the GitHub repository.

## Changelog

### Version 1.0.0
- Initial release
- Basic backup, restore, and compare functionality
- Support for Provisioning Policies, User Settings, Custom Images, and Azure Network Connections

---

**Author:** Donna Ryan and Michael Morten Sonne  
**Organization:** Microsoft Corporation
**Created:** September 18, 2025
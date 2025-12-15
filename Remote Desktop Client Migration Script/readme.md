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
```
## How to deploy script with Intune


1. **Sign in** to [Microsoft Intune admin center](https://intune.microsoft.com)
2. **Navigate to**: **Devices** → **Scripts and remediations** → **Windows 10 and later**
3. **Click**: **Add** → **Windows 10 and later**

   *Alternative path: Devices → Scripts → Platform scripts*

#### Configure Basics

On the **Basics** page:

| Field | Value | Notes |
|-------|-------|-------|
| **Name** | `Windows App Migration - Automated` | Clear, descriptive name |
| **Description** | `Automates migration from legacy Remote Desktop client to Windows App. Installs Windows App as provisioned package, removes legacy client, and configures update settings.` | Detailed description for tracking |

Click **Next**

#### Configure Script Settings

On the **Script settings** page:

| Setting | Recommended Value | Explanation |
|---------|-------------------|-------------|
| **Script location** | Upload `Remote Desktop Client Migration Script.ps1` | Click folder icon to browse and select |
| **Run this script using the logged on credentials** | **No** | Must run as SYSTEM for provisioned package installation |
| **Enforce script signature check** | **No** | Unless you've code-signed the script |
| **Run script in 64 bit PowerShell Host** | **Yes** | Required for AppX cmdlets to work properly |

**Important Notes:**

⚠️ **Run as SYSTEM is critical** - The script must run with SYSTEM privileges to:
- Install provisioned packages (`Add-AppxProvisionedPackage`)
- Modify HKLM registry keys
- Uninstall system-level applications

⚠️ **64-bit PowerShell is required** - AppX cmdlets may not function correctly in 32-bit PowerShell

**Script settings explanation:**

```
┌─────────────────────────────────────────────────────────┐
│ Run as SYSTEM (not logged-on user)                     │
│ ✓ Access to all user profiles                          │
│ ✓ Can install provisioned packages                     │
│ ✓ Can modify system registry                           │
│ ✓ Can uninstall system-level apps                      │
└─────────────────────────────────────────────────────────┘
```


## Troubleshooting

### Problem: Script Reports Success but Windows App Not Available

**Symptoms:**
- Log shows "Installation Complete"
- Detection rule passes
- Users don't see Windows App in Start menu

**Diagnosis:**
```powershell
# Check provisioned packages
Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -like "*Windows365*"}

# Check user installation
Get-AppxPackage -Name *Windows365* -AllUsers
```

**Solutions:**
1. **User hasn't logged out/in:** Provisioned apps register at next logon
   - Solution: Have user sign out and back in
2. **Profile corruption:** Provisioned package installed but user profile damaged
   - Solution: Recreate user profile or manually install: `Add-AppxPackage -Register -DisableDevelopmentMode`

### Problem: Remote Desktop Uninstall Fails

**Symptoms:**
- Log shows "Something went wrong uninstalling Remote Desktop"
- Legacy client remains installed
- Error in log file

**Common causes:**

**Cause 1: User-context installation**
- Remote Desktop was installed per-user, not system-wide
- Script running as SYSTEM cannot access user-installed apps

**Solution:**
```powershell
# Deploy user-context remediation script
# Run as logged-on user
$MSRDC = Get-Package -Name "Remote Desktop" -ProviderName msi
if ($MSRDC) {
    $MSRDC | Uninstall-Package -Force
}
```

**Cause 2: Application in use**
- Remote Desktop client is currently running
- MSIEXEC cannot remove while processes are active

**Solution:**
```powershell
# Add to script before uninstall
Get-Process -Name "msrdcw" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3
# Then proceed with uninstall
```

**Cause 3: Corrupted installation**
- Registry entry exists but installation files are damaged

**Solution:**
```powershell
# Manual cleanup required
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | 
    Where-Object {$_.DisplayName -eq "Remote Desktop"}
```

### Problem: Download Fails

**Symptoms:**
- Log shows error during "Downloading payload"
- Network timeout or access denied errors

**Diagnosis:**
```powershell
# Test connectivity
Test-NetConnection -ComputerName "download.microsoft.com" -Port 443

# Test download manually
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2262633" -UseBasicParsing
```

**Solutions:**

1. **Proxy authentication required:**
   ```powershell
   # Modify script to use default credentials
   $WebClient = New-Object System.Net.WebClient
   $WebClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
   ```

2. **Firewall blocking:**
   - Allow outbound HTTPS to *.microsoft.com
   - Whitelist specific CDN endpoints

3. **Insufficient temp space:**
   - MSIX package is ~200MB
   - Ensure C:\Windows\temp has 500MB+ free

### Problem: Add-AppxProvisionedPackage Fails

**Symptoms:**
- "Deployment failed with HRESULT: 0x80073CF3"
- "The package could not be installed"

**Common error codes:**

| Error Code | Meaning | Solution |
|------------|---------|----------|
| 0x80073CF3 | Package failed update, higher version exists | Uninstall existing version first |
| 0x80073D02 | The requested state of the package conflicts | Remove conflicting package |
| 0x80073CF9 | Package install prerequisites not met | Check OS version compatibility |
| 0x80070002 | File not found | Verify download completed successfully |

**Generic solution:**
```powershell
# Reset app package state
Get-AppxPackage *Windows365* -AllUsers | Remove-AppxPackage -AllUsers
Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -like "*Windows365*"} | Remove-AppxProvisionedPackage -Online

# Retry installation
.\Remote Desktop Client Migration Script.ps1
```

---


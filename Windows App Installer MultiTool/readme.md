# Remote Desktop Migration Tool (Windows App Installer)
This tool uninstalls Remote Desktop (MSRDC) utilizing two different detection techniques, installs Windows App from three different sources, and can set auto update behavior.


## Installation
Download the script from the repository. It is ready to be run from commandline or deployed as a script/package.

## Parameters
### Source  (Store,WinGet,MSIX) (Default is Store)

This parameter controls where Windows App will be downloaded from. If your organization blocks complete access to the Microsoft Store, use with WinGet or MSIX. If both the Microsoft Store and the WinGet CDN are blocked, use MSIX to download from a URL.

If using "Store" option, a separate log will be created ($env:windir\temp\WindowsAppStoreInstall.log) that is the output from the store installer. 

If using the "WinGet" option a separate log will be created ($env:windir\temp\WindowsAppWinGetInstall.log) that is the output from the WinGet installer

IF using the "MSIX" option, logging will be in the main log for this script. The MSIX payload will be downloaded to $env:windir\temp\

### DisableAutoUpdate (0,1,2,3) (Default is 0)
See this link for a full explanation of each option. https://learn.microsoft.com/en-us/windows-app/configure-updates-windows#configure-update-behavior

### UninstallMSRDC (True/False) (Default is True)
This parameter tells the script to uninstall Remote Desktop if detected. Removal of Remote Desktop will only happen after Windows App has been installed successfully.

### Logpath (path to log file with name) (default is $env:windir\temp\MultiTool.log )

## Example
'.\Windows App Installer.ps1' -source Store -DisableAutoUpdate 0 -UninstallMSRDC True

## Logs and Payloads

All logs and payloads are created in $env:windir\temp\ by default.

MultiTool.log - The log recording the activity of the script.

WindowsAppStoreInstall.log - A log that is the output from the Microsoft Store Installer as it installed Windows App.

WindowsAppWinGetInstall.log - A log that is the output from the WinGet Installer as it installed Windows App.

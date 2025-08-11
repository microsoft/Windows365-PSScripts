# This script has been deprecated as the feature is now enabled by default.
For more information on RDP Shortpath, [follow this link](https://learn.microsoft.com/en-us/windows-365/enterprise/rdp-shortpath-public-networks)

# Enable RDP Shortpath with Proactive Remediation
This example solution comes with two scripts and is intended to enable the RDP Shortpath feature on Windows 365 Cloud PCs. This feature uses UDP packets, which allows for lower latency - enhancing the end user experience.

RDP Shortpath is enabled on the Cloud PC by changing a registry key and value. The key is HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations and the  value is ICEControl, DWORD type, and set to 2.

If UDP traffic is blocked on your network, which could be likely if on an enterprise network, RDP Shortpath will not function and the Windows 365 client will continue to communicate with TCP exclusively. For more information on RDP Shortpath, including how it functions and how your network can impact its traffic, see the following link.

[Use RDP Shortpath for public networks (preview) with Windows 365](https://docs.microsoft.com/en-us/windows-365/enterprise/rdp-shortpath-public-networks)

[If you need guidance on getting started with Proactive Remdiation, follow this link.](https://docs.microsoft.com/en-us/mem/analytics/proactive-remediations)

## Using this soluiton
> Note: The scripts are not signed. If your organization is blocking the execution of unsigned scripts, they will not run.
### Detection Script
The detection script checks if the computer is a Cloud PC or not. As the registry key that needs to be set must be set on the Cloud PC, not on the users' physical computer, the detection script checks if the computer is a Cloud PC or not.

Next it will check if the registry key value is correct. If it is, it returns Compliant. If the value of the key is not correct, or the key is not present, the script returns Non-Compliant.

### Remediation Script
The remediation script checks the value of the registry key. If the key is present but not correct, the script will update the value. If the key is not present, the script will create the registry key. Finally, the script will validate the value of the key again. If correct, it will return compliant. If not, non-compliant. 
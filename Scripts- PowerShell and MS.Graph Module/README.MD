# Example Scripts using Microsoft.Graph Module with PowerShell
## Purpose
The purpose of these scripts is to demonstrate functionality of the PowerShell functions contained in the Microsoft.Graph module with Windows 365. Each script is built off of the "Base Script.PS1" which is used to initiate the module installation, version check the module, and to authenticate against the MS Graph PowerShell public enterprise app.

The hope is that the scripts will help others build their own solutions without having to start from scratch. More scripts will be added in the future, with the goal of having a script for each function. Make sure to check back often!
***

### W365 - Basic Script.ps1
This script checks to see if the required PowerShell module is installed, checks to see if it is current, prompts the user to authenticate, and then sets the proper scope. It's everything you need to get started - just add your own code!
***

### W365 - Deprovision All Grace Period CloudPCs.ps1
This script Deprovisions all CloudPCs that are in a Grace Period.
***

### W365 - List CloudPCs by Grace Period.ps1
This script outputs a list of CloudPCs that are in a Grace Period.
***

### W365 - List CloudPCs by Image.ps1
This script outputs a list of CloudPCs sorted by the images used to create them
***

### W365 - List CloudPCs by OPNC-Hosted.ps1
This script outputs a list of CloudPCs sorted by the OPNC they are connected to, which also includes the Microsoft Hosted Network.
***

### W365 - List CloudPCs by Provisioning Policy.ps1
This script outputs a list of CloudPCs sorted by the Provisioning Policy assinged to them.
***
### W365 - List CloudPCs by Type.ps1
This script outputs a list of CloudPCs sorted by Business and Enterprise type.
***

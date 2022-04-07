# Windows 365 User Logon Activity Script
Currently Windows 365 does not have a way to report how often users are actually using their CloudPC. This example script aims to provide that information by scraping the Azure AD Logon logs for the Windows 365 portal and the Remote Desktop client. While this does provide a reasonable amount of information to determine usage, this approach is limited and has caveats. 

This script is provided as an example. Support will not be provided. 

## Caveats
1. As Windows 365 and Azure Virtual Desktop currently use the same Remote Desktop app to connect to their respective services, if users are connecting to both AVD and W365, the logon value from the Remote Desktop  app will not be accurate as we cannot differentiate between Windows 365 and Azure Virtual Desktop logons.

2. The data does not provide information regarding session activty or duration. It only provides logon details.

3. As the data is not coming directly from the Windows 365 service, it cannot be considered 100% accurate. This data can be considered "good enough".

## Required PowerShell Modules

This script uses two PowerShell modules to ingest data. Microsoft.Graph for CloudPC metadata and AzureADPreview to get the logon information. 

**If the computer running this script has the AzureAD module installed, there may be conflicts with the AzureADPreview module. It may be required to uninstall the AzureAD module to avoid the conflict**

## Usage

When the script is run, it will check if the Microsoft.Graph module is installed and will install it if not present. It will then check if the AzureADPreview module is installed and will install if not present. It will then attempt to connect both modules to Azure. As these are separate modules with separate Enterprise App connections, there will be two credential prompts.

Once the user has authenticated, the script will set the connection to Microsoft.Graph to Beta.

The script will then query all CloudPCs against their respective logons and output the data to the console and the CSV file.

## Output
The following are examples of both the console and the CSV output.

![CSV Output Example](CSV_Example.png)

![Console Output Example](console_example.png)

## Parameters

-Offset

This value is the amount of days back that logons should be collected for. The default value is 30. Setting this parameter in commandline is optional.

-Logpath

This value is where the CSV output should be written to, as well as the file name. The default value is "C:\CPC_Logon_Count.csv". Setting this parameter in commandline is optional.



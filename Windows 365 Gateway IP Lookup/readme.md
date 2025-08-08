# This script has been deprecated as the required gateways have been consolidated into subnets.
For more information on what subnets need to be whitelisted [follow this link](https://techcommunity.microsoft.com/discussions/windows365discussions/optimizing-rdp-connectivity-for-windows-365/3554327)

# Windows 365 and AVD Gateway IP Address Lookup Script
## Purpose
This script helps to easily retrieve the AVD Gateway IPs or CIDR Subnets associated with the Windows 365 and AVD services and outputs them as a list in a CSV format. This list can then be used by admins to import the data into their VPN solutions to minimize end user Cloud PC performance degradation and disconnects. 

It has been updated to support GCCH customers, provide CIDR notation or IP Address of the Gateways, and to provide a much simpler process than the previous version. 

### How it works
Default behavior will retrieve a JSON file containing the AVD Gateways from the web. 

On the first run of the script, it will save the downloaded information in a new CSV file (W365-Gateways.CSV).

On subsequent runs, the script it will import the data from the existing CSV file and compare it to a temporary CSV file for differences. If no difference is found, the script will exit. If a difference is found, the existing CSV (W365-Gateways.CSV) will be updated with the latest Gateway IP addresses.

Optionally, the data can be retrieved from Azure, but this is not recommended unless the JSON cannot be obtained from the web. If using Azure as the source, the script will check if the required modules (az.network and az.accounts) are installed. If they are not installed, the script will install and import them. The script can also check if the modules are out of date by changing the variable $CheckUpdates to $True. This is disabled by default to save time. The script will then prompt the user to provide Azure credentials. After successfully authenticating, the script will continue as normal.

If your VPN solution does not support using subnets, use the -IP parameter to create the CSV with IP addresses.

If you using Windows 365 in a GCCH tenant, use the -GOV parameter. 

## Usage

Download the script and save it to a folder, then run the script as Administrator from within the folder. Do not run the script from PowerShell ISE console.

## Parameters
### -IP  
This converts the CIDR subnets to IP addresses of the AVD Gateways. Only use this if your VPN solution does not accept subnets.

### -GOV 
Use this parameter to download the AVD Gateways for GCCH Tenants. 

### -Azure
Use this parameter to retrieve the data from Azure instead of the web. Only use this if default source isn't working. Not supported for use with the -GOV parameter.




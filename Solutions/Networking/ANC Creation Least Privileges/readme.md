# ANC Creation Least Privileges
## Introduction
This script is designed to apply the least required privileges to the Windows 365 App that will still allow it to create Azure Networking Connections (ANCs). The default role of Network Contributor must be removed from the app before this script will have any effect.

## Process
The script performs the following steps:
1. Prompt for Azure Subscription ID if not provided by parameter
2. Prompt for Azure Credentials
3. Prompt for AzureAD Credentials
4. Create temporary JSON files used to create the custom roles
5. Create the custom roles in Azure
6. Retrieve the AppID of Windows 365
7. Applies the created roles to the Windows 365 app
8. Cleans up temporary files

## Usage
To use this script from command line, the user can either supply the Subscription ID with the parameter "-SubscriptionID" or can run the script, which will then prompt for the ID.

**Example:**
`script_name.ps1 -SubscriptionID [your id]`


## Requirements
### PowerShell Modules
The following PowerShell modules are required for successful execution of this script. The script will check to see if each module is installed but will not remediate missing modules.
- Az.Resources
- Az.Accounts
- AzureAD

### Azure Subscription ID
Users of this script will be required to supply the Subscription ID of the Azure Subscription that holds the Windows 365 instance. The Subscription ID can be supplied at the command line using the "-SubscriptionID" parameter, or can supply the ID at the prompt if run without the parameter.

### Permissions
User will be required to have administrative level rights on the Azure Subscription.

*This script is provided without support or warranty.*
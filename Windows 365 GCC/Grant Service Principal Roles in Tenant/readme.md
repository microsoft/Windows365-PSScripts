# Set Permissions for Networking and Custom Image Management

When provisioning Windows 365 Cloud PCs without the Microsoft Hosted Network (MHN), you must define an Azure Network Connection (ANC) resource that the Cloud PCs will use to connect with other resources, including your on-premises infrastructure. This ANC allows GCC customers to use their own network. There's also an option to enable customers to use custom images when the Windows 365 Cloud PCs are provisioned.

## Instructions

Make sure you have Windows PowerShell version 5.1. Other versions may result in errors when running the script.

Gather the following information. It will be used later in these steps.
- Commercial Azure tenant ID.
- Commercial Azure Global administrator username and password.
- Azure Government tenant ID.
- Azure Government Global administrator credentials username and password.
- Subscription in the Azure Government tenant.
- Resource Group in the Azure Government tenant.
- Virtual Network in the Azure Government tenant.

1. Run the PowerShell script. 
2. Sign in to your Azure Government cloud tenant.
3. At the prompt, type one of the following options:
    - to grant permissions to create Azure Network Connections (ANC).
    - to grant permissions to create ANCs and upload custom images.
4. The script lists the subscriptions available for the Azure Government cloud tenant. Select the subscription that you want to use.
5. The resource groups for that subscription are listed. Select the group that you want to use.
6. Select your vNet.

The script grants the permissions and lists what was configured.

## Further Information
There is additional information on the usage of this script at https://learn.microsoft.com/en-us/windows-365/enterprise/set-up-tenants-windows-365-gcc
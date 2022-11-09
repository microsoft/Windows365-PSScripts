# Azure AD Tenant Mapping for GCC Customers Implementing Windows 365

The purpose of this script is to map accounts created in Azure AD in a public cloud tenant to a GCC/H tenant that will have Windows 365 Cloud PCs provisioned. For Windows 365 to function in the Government Community Cloud (GCC) environment, customers will need to prepare their 2 distinct tenants: (1) one tenant in the Commercial Azure environment with an onmicrosoft.com address; and (2) one tenant in the Azure Government environment with an onmicosoft.us address. 

## Information you will need
Before getting and running the PowerShell script, it will be helpful to have the following information on hand, as they will be necessary to complete the tenant mapping.
- Commercial Azure Global Administrator credentials (user/pass)
- Azure Government Global Administrator credentials (user/pass)

## Instructions
Please run the script below as administrator from Windows PowerShell 5.1. Some functions in the script may cause errors when run in Windows PowerShell 7.x environment. 
1. Run the script
2. Select Add by typing “A” at the prompt
3. You will be prompted to enter your credentials for your Commercial Tenant (GlobalAdmin@xxxxx.onmicrosoft.com)
4. After some checking and preparing work in script, you will be promted to enter your credentials for your Commercial Tenant (GlobalAdmin@xxxxx.onmicrosoft.com) again. If you are asked to consent permissions, please do so on behalf of your organization.
5. Next, you will be prompted to enter your credentials for your Azure Government Tenant (GlobalAdmin@yyyyy.onmicrosoft.us)
6. After some checking and preparing work in script, you will be promted to enter your credentials for your Azure Government Tenant (GlobalAdmin@yyyyy.onmicrosoft.us) again. If you are asked to consent permissions, please do so on behalf of your organization.
7. Once the mapping has completed, you should see the message, “Added tenant mapping successfully!”

## Confirming the Tenant Mapping

To confirm the tenant mapping at a later date, you can run the same script and at the operation prompt, type “G” to do a Get function.
Similar to when you mapped the tenants, you will need to enter the credentials of the two tenants as well as Global Administrator credentials.

If the tenant mapping already exists, “There is an exist mapping!” message will be presented. If no mapping exist between the two, you will see “There is no tenant mapping!”

## Further Information
Additional instructions on the usage of this script can be found at https://learn.microsoft.com/en-us/windows-365/enterprise/set-up-tenants-windows-365-gcc

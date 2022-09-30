# Azure AD Tenant Mapping for GCC Customers Implementing Windows 365

The purpose of this script is to map accounts created in Azure AD in a public cloud tenant to a GCC/H tenant that will have Windows 365 Cloud PCs provisioned. For Windows 365 to function in the Government Community Cloud (GCC) environment, customers will need to prepare their 2 distinct tenants: (1) one tenant in the Commercial Azure environment with an onmicrosoft.com address; and (2) one tenant in the Azure Government environment with an onmicosoft.us address. 

## Information you will need
Before getting and running the PowerShell script, it will be helpful to have the following information on hand, as they will be necessary to complete the tenant mapping.
- Commercial Azure Tenant ID
- Commercial Azure Global Administrator credentials (user/pass)
- Azure Government Tenant ID
- Azure Government Global Administrator credentials (user/pass)

## Instructions
Please run the script below from Windows PowerShell 5.1. Some functions in the script are known to cause errors when run in Windows PowerShell 7.x environment.

If the script has previously been run and the tenants have been successfully connected, the script will error out with HttpStatusCode ‘Conflict’. This warning can be ignored to execute "A" Add and "G" Get functions.

1. Run the script
2. To begin connecting the tenants, first select Init by typing “I” at the prompt
3. If the Init fails, make sure you are running the scripts in PowerShell 5.1
4. After the Initialization has completed, select Add by typing “A” at the prompt
5. You will first be asked to enter your Commercial Tenant ID, which you got by going to https://portal.azure.com/ in earlier steps to get.
6. Next, you will be asked to enter your Azure Government Tenant ID, which you got by going to https://portal.azure.us/ earlier.
7. You will be prompted to enter your credentials for your Commercial Tenant (GlobalAdmin@xxxxx.onmicrosoft.com)
8. Next, you will be prompted to enter your credentials for your Azure Government Tenant (GlobalAdmin@yyyyy.onmicrosoft.us) 
9. Once the mapping has completed, you should see the message, “Added tenant mapping successfully!”

## Confirming the Tenant Mapping

To confirm the tenant mapping at a later date, you can run the same script and at the operation prompt, type “G” to do a Get function.
Similar to when you mapped the tenants, you will need to enter the Tenant IDs of the two tenants as well as Global Administrator credentials.

If the tenant mapping already exists, “There is an exist mapping!” message will be presented. If no mapping exist between the two, you will see “There is no tenant mapping!”

## Further Information
Additional instructions on the usage of this script can be found at https://learn.microsoft.com/en-us/windows-365/enterprise/set-up-tenants-windows-365-gcc


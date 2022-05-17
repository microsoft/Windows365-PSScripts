<#
.SYNOPSIS
    Get/Add tenant mapping.
.DESCRIPTION
    For GCC (US Government Community Cloud) customers, the Azure Active Directory for tenant is in public cloud, but the Azure resources and Windows 365 Cloud PCs are in US government cloud. Tenant mapping is required for customer administrators to setup & config Windows 365 and for the end users at GCC customers to access their Windows 365 Cloud PCs. The setup and maintenance of the tenant mapping must be done while onboarding to the US Government cloud.
    This script can help administrators on getting/adding tenant mapping and its prerequisite work (provision required AAD applications to tenants).
#>

Add-Type @"
  using System;
  using System.Runtime.InteropServices;
  public class SFW {
     [DllImport("user32.dll")]
     [return: MarshalAs(UnmanagedType.Bool)]
     public static extern bool SetForegroundWindow(IntPtr hWnd);
  }
"@

$msGraphAppId = "00000003-0000-0000-c000-000000000000"
$firstPartyAppId = "0af06dc6-e4b5-4f28-818e-e78e62d137a5"
$publicCloudClientId = "e3871b3f-5821-4695-b8c0-551ebcdcc3d2"
$govCloudClientId = "be0df5cb-3aa5-444b-9586-e118fa3f7feb"

$publicCloudScope = "https://graph.microsoft.com/.default"
$govCloudScope = "0af06dc6-e4b5-4f28-818e-e78e62d137a5/.default"

<#
.SYNOPSIS
    Provision required AAD applications to public cloud tenant and government cloud tenant
.NOTES
    This function don't support PowerShell 7.
    You may see some errors when run "Init". If it is because the application already exists, you can ignore the errors.
#>
function Init {
    if (!(Get-Module -ListAvailable -Name AzureAD)) {
        Write-Host "Missing required module, will install module 'AzureAD'...`n" -ForegroundColor Green
        Install-Module AzureAD
    }

    Import-Module AzureAD

    Write-Host "Start provision required AAD applications for your tenants..."
    Write-Host "You may see some errors, if it is because the application already exists, you can ignore the errors.`n" -ForegroundColor Yellow

    Write-Host "Please log in with your public cloud admin account." -ForegroundColor Green
    Write-Host "Press Enter to continue...`n" -ForegroundColor Green
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Connect-AzureAD

    Write-Host "Provision 'Microsoft Graph' application..."
    try {
        New-AzureADServicePrincipal -AppId $msGraphAppId
    }
    catch {
        Write-Host "Provision failed." -ForegroundColor Red
        Write-Host $_
    }

    Write-Host "Provision 'Windows 365 Tenant Mapping 3P' application..."
    try {
        New-AzureADServicePrincipal -AppId $publicCloudClientId
    }
    catch {
        Write-Host "Provision failed." -ForegroundColor Red
        Write-Host $_
    }

    Write-Host "Please log in with your government cloud admin account." -ForegroundColor Green
    Write-Host "Press Enter to continue...`n" -ForegroundColor Green
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Connect-AzureAD

    Write-Host "Provision 'Cloud PC' application..."
    try {
        New-AzureADServicePrincipal -AppId $firstPartyAppId
    }
    catch {
        Write-Host "Provision failed." -ForegroundColor Red
        Write-Host $_
    }

    Write-Host "Provision 'Windows 365 Tenant Mapping Gov 3P' application..."
    try {
        New-AzureADServicePrincipal -AppId $govCloudClientId
    }
    catch {
        Write-Host "Provision failed." -ForegroundColor Red
        Write-Host $_
    }
}

function Get-TenantMapping {
    param (
        [guid]$PublicCloudTenantId,
        [guid]$GovCloudTenantId
    )

    # Install MSAL.PS module if missing
    if (!(Get-Module -ListAvailable -Name MSAL.PS)) {
        Write-Host "Missing required module, will install module 'MSAL.PS'...`n" -ForegroundColor Green
        Install-Module MSAL.PS
    }

    Import-Module MSAL.PS # https://github.com/AzureAD/MSAL.PS
    
    Write-Host "Please input your public tenant admin account and password in opened web browser!"
    Write-Host "Press Enter to continue...`n" -ForegroundColor Green
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    # Get token for public cloud tenant
    $publicTokenObject = Get-MsalToken -ClientId $publicCloudClientId -TenantId $PublicCloudTenantId -Interactive -Scope $publicCloudScope
    $publicToken = $publicTokenObject.AccessToken

    # Bring the current PowerShell window into the foreground and activate the window.
    $window = (Get-Process -id $pid).MainWindowHandle
    $foreground = [SFW]::SetForegroundWindow($window)

    Write-Host "Please input your government tenant admin account and password in opened web browser!"
    Write-Host "Press Enter to continue...`n" -ForegroundColor Green
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    # Get token for government cloud tenant
    $govTokenObject = Get-MsalToken -ClientId $govCloudClientId -TenantId $GovCloudTenantId -Interactive -Scope $govCloudScope
    $govToken = $govTokenObject.AccessToken

    $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/crossCloudGovernmentOrganizationMapping"
    $headers = @{"Authorization" = "Bearer " + $publicToken; "x-ms-cloudpc-usgovcloudtenantaadtoken" = "Bearer " + $govToken; }

    Write-Host "Sending request...`n"
    try {
        $response = Invoke-WebRequest $url -Method "GET" -Headers $headers
        if ("200" -eq $response.StatusCode) {
            Write-Host "There is an exist mapping!" -ForegroundColor Green
        }
        elseif ("204" -eq $response.StatusCode) {
            Write-Host "There is no tenant mapping!" -ForegroundColor Red
        }
        else {
            throw "Non-200 and Non-204 status code"
        }
    }
    catch {
        Write-Host "Encounter error when get tenant mapping! `nPlease contact support for help." -ForegroundColor Red
    }
}

function Add-TenantMapping {
    param (
        [guid]$PublicCloudTenantId,
        [guid]$GovCloudTenantId
    )
    
    # Install MSAL.PS module if missing
    if (!(Get-Module -ListAvailable -Name MSAL.PS)) {
        Write-Host "Missing required module, will install module 'MSAL.PS'...`n" -ForegroundColor Green
        Install-Module MSAL.PS
    }

    Import-Module MSAL.PS # https://github.com/AzureAD/MSAL.PS
    
    Write-Host "Please input your public tenant admin account and password in opened web browser!"
    Write-Host "Press Enter to continue...`n" -ForegroundColor Green
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    # Get token for public cloud tenant
    $publicTokenObject = Get-MsalToken -ClientId $publicCloudClientId -TenantId $PublicCloudTenantId -Interactive -Scope $publicCloudScope
    $publicToken = $publicTokenObject.AccessToken

    # Bring the current PowerShell window into the foreground and activate the window.
    $window = (Get-Process -id $pid).MainWindowHandle
    $foreground = [SFW]::SetForegroundWindow($window)

    Write-Host "Please input your government tenant admin account and password in opened web browser!"
    Write-Host "Press Enter to continue...`n" -ForegroundColor Green
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    # Get token for government cloud tenant
    $govTokenObject = Get-MsalToken -ClientId $govCloudClientId -TenantId $GovCloudTenantId -Interactive -Scope $govCloudScope
    $govToken = $govTokenObject.AccessToken

    $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/crossCloudGovernmentOrganizationMapping"
    $body = "{}"

    $headers = @{"Authorization" = "Bearer " + $publicToken; "x-ms-cloudpc-usgovcloudtenantaadtoken" = "Bearer " + $govToken; "Content-Type" = "application/json" }

    Write-Host "Sending request...`n"
    try {
        $response = Invoke-WebRequest $url -Method "POST" -Body $body -Headers $headers

        if ("200" -eq $response.StatusCode) {
            Write-Host "Added tenant mapping successfully!" -ForegroundColor Green
        }
        else {
            throw "Non-200 status code"
        }
    }
    catch {
        Write-Host "Failed to add tenant mapping! `nPlease check if there is already an exist mapping. If there is an exist mapping for public cloud tenant or government cloud tenant, will fail to add new mapping for the tenant; otherwise, please contact support for help." -ForegroundColor Red
    }
}

$init = New-Object System.Management.Automation.Host.ChoiceDescription '&Init', 'Provision required AAD applications to your tenants. Only need to run this once if you have not provisioned before.'
$add = New-Object System.Management.Automation.Host.ChoiceDescription '&Add', 'Add a new tenant mapping'
$get = New-Object System.Management.Automation.Host.ChoiceDescription '&Get', 'Get specific tenant mapping'
$skip = New-Object System.Management.Automation.Host.ChoiceDescription '&Skip', 'Do nothing and exit. Choose this when import this script as module'
$options = [System.Management.Automation.Host.ChoiceDescription[]]($init, $add, $get, $skip)

$title = 'Tenant mapping operations'
$message = 'Please select your operation:'
$result = $host.ui.PromptForChoice($title, $message, $options, 0)
Write-Host

switch ($result) {
    0 { Init }
    1 { 
        $publicCloudTenantID = Read-Host "Please enter your public cloud tenant ID"
        $publicCloudTenantID
        Write-Host

        $govCloudTenantID = Read-Host "Please enter your government cloud tenant ID"
        $govCloudTenantID
        Write-Host

        Add-TenantMapping -PublicCloudTenantId $publicCloudTenantID -GovCloudTenantId $govCloudTenantID
    }
    2 { 
        $publicCloudTenantID = Read-Host "Please enter your public cloud tenant ID"
        $publicCloudTenantID
        Write-Host

        $govCloudTenantID = Read-Host "Please enter your government cloud tenant ID"
        $govCloudTenantID
        Write-Host

        Get-TenantMapping -PublicCloudTenantId $publicCloudTenantID -GovCloudTenantId $govCloudTenantID
    }
}

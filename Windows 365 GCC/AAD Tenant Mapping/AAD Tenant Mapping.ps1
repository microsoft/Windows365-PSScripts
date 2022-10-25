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
    Provision required AAD applications and consent required permissions to public cloud tenant and government cloud tenant
.NOTES
    This function don't support PowerShell 7.
#>
function Init {
    if (!(Get-Module -ListAvailable -Name AzureAD)) {
        Write-Host "Missing required module, will install module 'AzureAD'...`n" -ForegroundColor Green
        Install-Module AzureAD
    }

    Import-Module AzureAD

    Write-Host "Start provision required AAD applications for your tenants..."

    $consentMaxRetryTimes = 6

    # For Government cloud tenant
    # Provsion applications
    Write-Host "Please log in with your public cloud admin account." -ForegroundColor Green
    Write-Host "Press Enter to continue...`n" -ForegroundColor Green
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Connect-AzureAD

    Write-Host "Provision 'Microsoft Graph' application..."
    $appIds = (Get-AzureADServicePrincipal -SearchString "Microsoft Graph")."AppId"
    if (($null -eq $appIds) -or !($appIds.Contains($msGraphAppId))) {
        try {
            New-AzureADServicePrincipal -AppId $msGraphAppId
        }
        catch {
            Write-Host "Provision failed." -ForegroundColor Red
            Write-Host $_
        }
    }
    else {
        Write-Host "'Microsoft Graph' application already exists in tenant." -ForegroundColor Green
        Write-Host $_
    }

    Write-Host "Provision 'Windows 365 Tenant Mapping 3P' application..."
    $appIds = (Get-AzureADServicePrincipal -SearchString "Windows 365 Tenant Mapping 3P")."AppId"
    if (($null -eq $appIds) -or !($appIds.Contains($publicCloudClientId))) {
        try {
            New-AzureADServicePrincipal -AppId $publicCloudClientId
        }
        catch {
            Write-Host "Provision failed." -ForegroundColor Red
            Write-Host $_
        }
    }
    else {
        Write-Host "'Windows 365 Tenant Mapping 3P' application already exists in tenant." -ForegroundColor Green
        Write-Host $_
    }
    
    # Consent permissions
    Write-Host "Consenting permissions for public cloud tenant..."
    $publicCloudTenant = Get-AzureADTenantDetail
    $publicCloudTenantID = $publicCloudTenant.ObjectId
    if ($publicCloudTenantID -eq "") {
        $publicCloudTenantID = Read-Host "Get Azure AD tenant ID failed. Please enter your public cloud tenant ID manually:" -ForegroundColor Green
        $publicCloudTenantID
        Write-Host
    }
    
    Write-Host "Please input your public tenant admin account and password in opened web browser, then consent on behalf of your organization." -ForegroundColor Green
    $publicTokenObject = Get-MsalToken -ClientId $publicCloudClientId -TenantId $publicCloudTenantID -Interactive -Scope $publicCloudScope
    $retryTimes = 0
    while (($null -eq $publicTokenObject.Scopes -or !$publicTokenObject.Scopes.Contains("https://graph.microsoft.com/CloudPC.Read.All") -or !$publicTokenObject.Scopes.Contains("https://graph.microsoft.com/CloudPC.ReadWrite.All")) -and ($retryTimes -lt $consentMaxRetryTimes)) {
        Write-Host "Consenting is in progress..."
        Start-Sleep -Seconds 10
        $publicTokenObject = Get-MsalToken -ClientId $publicCloudClientId -TenantId $publicCloudTenantID -Silent -ForceRefresh -Scope $publicCloudScope
        $retryTimes++
    }

    if ($null -eq $publicTokenObject.Scopes -or !$publicTokenObject.Scopes.Contains("https://graph.microsoft.com/CloudPC.Read.All") -or !$publicTokenObject.Scopes.Contains("https://graph.microsoft.com/CloudPC.ReadWrite.All")) {
        Write-Host "Consenting permission doesn't take effect after $consentMaxRetryTimes times retry, please wait for a while and try again."
    }
    else {
        Write-Host "Consenting permission completed." -ForegroundColor Green
    }

    # For Public cloud tenant
    # Provsion applications
    Write-Host "Please log in with your government cloud admin account." -ForegroundColor Green
    Write-Host "Press Enter to continue...`n" -ForegroundColor Green
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Connect-AzureAD

    Write-Host "Provision 'Cloud PC' application..."
    $appIds = (Get-AzureADServicePrincipal -SearchString "Cloud PC")."AppId"
    if ($null -eq $appIds -or !($appIds.Contains($firstPartyAppId))) {
        try {
            New-AzureADServicePrincipal -AppId $firstPartyAppId
        }
        catch {
            Write-Host "Provision failed." -ForegroundColor Red
            Write-Host $_
        }
    }
    else {
        Write-Host "'Cloud PC' application already exists in tenant." -ForegroundColor Green
        Write-Host $_
    }

    Write-Host "Provision 'Windows 365 Tenant Mapping Gov 3P' application..."
    $appIds = (Get-AzureADServicePrincipal -SearchString "Windows 365 Tenant Mapping Gov 3P")."AppId"
    if ($null -eq $appIds -or !($appIds.Contains($govCloudClientId))) {
        try {
            New-AzureADServicePrincipal -AppId $govCloudClientId
        }
        catch {
            Write-Host "Provision failed." -ForegroundColor Red
            Write-Host $_
        }
    }
    else {
        Write-Host "'Windows 365 Tenant Mapping Gov 3P' application already exists in tenant." -ForegroundColor Green
        Write-Host $_
    }

    # Consent permissions
    Write-Host "Consenting permissions..."
    $govCloudTenant = Get-AzureADTenantDetail
    $govCloudTenantID = $govCloudTenant.ObjectId
    if ($govCloudTenantID -eq "") {
        $govCloudTenantID = Read-Host "Get Azure AD tenant ID failed. Please enter your government cloud tenant ID manually:" -ForegroundColor Green
        $govCloudTenantID
        Write-Host
    }
    
    Write-Host "Please input your government tenant admin account and password in opened web browser, then consent on behalf of your organization" -ForegroundColor Green
    $govTokenObject = Get-MsalToken -ClientId $govCloudClientId -TenantId $govCloudTenantID -Interactive -Scope $govCloudScope
    $retryTimes = 0
    while (($null -eq $govTokenObject.Scopes -or !$govTokenObject.Scopes.Contains("0af06dc6-e4b5-4f28-818e-e78e62d137a5/EndUser.Access")) -and ($retryTimes -lt $consentMaxRetryTimes)) {
        Write-Host "Consenting is in progress..."
        Start-Sleep -Seconds 10
        $govTokenObject = Get-MsalToken -ClientId $govCloudClientId -TenantId $govCloudTenantID -Silent -ForceRefresh -Scope $govCloudScope
        $retryTimes++
    }

    if ($null -eq $govTokenObject.Scopes -or !$govTokenObject.Scopes.Contains("0af06dc6-e4b5-4f28-818e-e78e62d137a5/EndUser.Access")) {
        Write-Host "Consenting permission doesn't take effect after $consentMaxRetryTimes times retry, please wait for a while and try again."
    }
    else {
        Write-Host "Consenting permission completed." -ForegroundColor Green
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
        Write-Host "Encounter error when get tenant mapping! `nPlease retry or contact support for help." -ForegroundColor Red
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
        Write-Host "Failed to add tenant mapping! `nPlease check if there is already an exist mapping. If there is an exist mapping for public cloud tenant or government cloud tenant, will fail to add new mapping for the tenant; otherwise, please retry or contact support for help." -ForegroundColor Red
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
# SIG # Begin signature block
# MIIntwYJKoZIhvcNAQcCoIInqDCCJ6QCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDOs2QS7BIFJMUA
# WoymPFhsSg4/OSwAV/VBYgYqfS7Nh6CCDYEwggX/MIID56ADAgECAhMzAAACzI61
# lqa90clOAAAAAALMMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjIwNTEyMjA0NjAxWhcNMjMwNTExMjA0NjAxWjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQCiTbHs68bADvNud97NzcdP0zh0mRr4VpDv68KobjQFybVAuVgiINf9aG2zQtWK
# No6+2X2Ix65KGcBXuZyEi0oBUAAGnIe5O5q/Y0Ij0WwDyMWaVad2Te4r1Eic3HWH
# UfiiNjF0ETHKg3qa7DCyUqwsR9q5SaXuHlYCwM+m59Nl3jKnYnKLLfzhl13wImV9
# DF8N76ANkRyK6BYoc9I6hHF2MCTQYWbQ4fXgzKhgzj4zeabWgfu+ZJCiFLkogvc0
# RVb0x3DtyxMbl/3e45Eu+sn/x6EVwbJZVvtQYcmdGF1yAYht+JnNmWwAxL8MgHMz
# xEcoY1Q1JtstiY3+u3ulGMvhAgMBAAGjggF+MIIBejAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUiLhHjTKWzIqVIp+sM2rOHH11rfQw
# UAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1
# ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzAwMTIrNDcwNTI5MB8GA1UdIwQYMBaAFEhu
# ZOVQBdOCqhc3NyK1bajKdQKVMFQGA1UdHwRNMEswSaBHoEWGQ2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY0NvZFNpZ1BDQTIwMTFfMjAxMS0w
# Ny0wOC5jcmwwYQYIKwYBBQUHAQEEVTBTMFEGCCsGAQUFBzAChkVodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY0NvZFNpZ1BDQTIwMTFfMjAx
# MS0wNy0wOC5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAgEAeA8D
# sOAHS53MTIHYu8bbXrO6yQtRD6JfyMWeXaLu3Nc8PDnFc1efYq/F3MGx/aiwNbcs
# J2MU7BKNWTP5JQVBA2GNIeR3mScXqnOsv1XqXPvZeISDVWLaBQzceItdIwgo6B13
# vxlkkSYMvB0Dr3Yw7/W9U4Wk5K/RDOnIGvmKqKi3AwyxlV1mpefy729FKaWT7edB
# d3I4+hldMY8sdfDPjWRtJzjMjXZs41OUOwtHccPazjjC7KndzvZHx/0VWL8n0NT/
# 404vftnXKifMZkS4p2sB3oK+6kCcsyWsgS/3eYGw1Fe4MOnin1RhgrW1rHPODJTG
# AUOmW4wc3Q6KKr2zve7sMDZe9tfylonPwhk971rX8qGw6LkrGFv31IJeJSe/aUbG
# dUDPkbrABbVvPElgoj5eP3REqx5jdfkQw7tOdWkhn0jDUh2uQen9Atj3RkJyHuR0
# GUsJVMWFJdkIO/gFwzoOGlHNsmxvpANV86/1qgb1oZXdrURpzJp53MsDaBY/pxOc
# J0Cvg6uWs3kQWgKk5aBzvsX95BzdItHTpVMtVPW4q41XEvbFmUP1n6oL5rdNdrTM
# j/HXMRk1KCksax1Vxo3qv+13cCsZAaQNaIAvt5LvkshZkDZIP//0Hnq7NnWeYR3z
# 4oFiw9N2n3bb9baQWuWPswG0Dq9YT9kb+Cs4qIIwggd6MIIFYqADAgECAgphDpDS
# AAAAAAADMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMTAeFw0xMTA3MDgyMDU5MDlaFw0yNjA3MDgyMTA5MDla
# MH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMT
# H01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCr8PpyEBwurdhuqoIQTTS68rZYIZ9CGypr6VpQqrgG
# OBoESbp/wwwe3TdrxhLYC/A4wpkGsMg51QEUMULTiQ15ZId+lGAkbK+eSZzpaF7S
# 35tTsgosw6/ZqSuuegmv15ZZymAaBelmdugyUiYSL+erCFDPs0S3XdjELgN1q2jz
# y23zOlyhFvRGuuA4ZKxuZDV4pqBjDy3TQJP4494HDdVceaVJKecNvqATd76UPe/7
# 4ytaEB9NViiienLgEjq3SV7Y7e1DkYPZe7J7hhvZPrGMXeiJT4Qa8qEvWeSQOy2u
# M1jFtz7+MtOzAz2xsq+SOH7SnYAs9U5WkSE1JcM5bmR/U7qcD60ZI4TL9LoDho33
# X/DQUr+MlIe8wCF0JV8YKLbMJyg4JZg5SjbPfLGSrhwjp6lm7GEfauEoSZ1fiOIl
# XdMhSz5SxLVXPyQD8NF6Wy/VI+NwXQ9RRnez+ADhvKwCgl/bwBWzvRvUVUvnOaEP
# 6SNJvBi4RHxF5MHDcnrgcuck379GmcXvwhxX24ON7E1JMKerjt/sW5+v/N2wZuLB
# l4F77dbtS+dJKacTKKanfWeA5opieF+yL4TXV5xcv3coKPHtbcMojyyPQDdPweGF
# RInECUzF1KVDL3SV9274eCBYLBNdYJWaPk8zhNqwiBfenk70lrC8RqBsmNLg1oiM
# CwIDAQABo4IB7TCCAekwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFEhuZOVQ
# BdOCqhc3NyK1bajKdQKVMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1Ud
# DwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFHItOgIxkEO5FAVO
# 4eqnxzHRI4k0MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwubWljcm9zb2Z0
# LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcmwwXgYIKwYBBQUHAQEEUjBQME4GCCsGAQUFBzAChkJodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcnQwgZ8GA1UdIASBlzCBlDCBkQYJKwYBBAGCNy4DMIGDMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2RvY3MvcHJpbWFyeWNw
# cy5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AcABvAGwAaQBjAHkA
# XwBzAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAGfyhqWY
# 4FR5Gi7T2HRnIpsLlhHhY5KZQpZ90nkMkMFlXy4sPvjDctFtg/6+P+gKyju/R6mj
# 82nbY78iNaWXXWWEkH2LRlBV2AySfNIaSxzzPEKLUtCw/WvjPgcuKZvmPRul1LUd
# d5Q54ulkyUQ9eHoj8xN9ppB0g430yyYCRirCihC7pKkFDJvtaPpoLpWgKj8qa1hJ
# Yx8JaW5amJbkg/TAj/NGK978O9C9Ne9uJa7lryft0N3zDq+ZKJeYTQ49C/IIidYf
# wzIY4vDFLc5bnrRJOQrGCsLGra7lstnbFYhRRVg4MnEnGn+x9Cf43iw6IGmYslmJ
# aG5vp7d0w0AFBqYBKig+gj8TTWYLwLNN9eGPfxxvFX1Fp3blQCplo8NdUmKGwx1j
# NpeG39rz+PIWoZon4c2ll9DuXWNB41sHnIc+BncG0QaxdR8UvmFhtfDcxhsEvt9B
# xw4o7t5lL+yX9qFcltgA1qFGvVnzl6UJS0gQmYAf0AApxbGbpT9Fdx41xtKiop96
# eiL6SJUfq/tHI4D1nvi/a7dLl+LrdXga7Oo3mXkYS//WsyNodeav+vyL6wuA6mk7
# r/ww7QRMjt/fdW1jkT3RnVZOT7+AVyKheBEyIXrvQQqxP/uozKRdwaGIm1dxVk5I
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIZjDCCGYgCAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAsyOtZamvdHJTgAAAAACzDAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgl38wn5+t
# KH4w1oEpg3Qe1qxQubCyr7rGp1VRbrGR5jIwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQAwMAvA5oDps4Xu6QZhWADKdX7wNjD6wDKI67t36UHr
# BBSzyk0nnrts3BuspypH87MlxPUCHeoohfgIeLLqVhia52RN8UP0QzH8OxtwVl0B
# pEcy3OpvRdjZCbC7yqqiobUkgvFzXlPM3rChwVxZSiX0SFP9ozjtPcQL2aGNvDaz
# v5RUbq2PHSURnGHrJo8Z9EuzAangeykG7lWTBV+iVakDcoIVyJyMHn5u5Lma4I1e
# 98mtcx79mq8ezaBgkUaVbdSr5mPJOcBp5v6IBSBktlUh1jm0L/lkKFcuyUdZrbhx
# kScnP1A2glMfEhgDRK/F6aiL8Zc1uvS20gNgLAGuEkP+oYIXFjCCFxIGCisGAQQB
# gjcDAwExghcCMIIW/gYJKoZIhvcNAQcCoIIW7zCCFusCAQMxDzANBglghkgBZQME
# AgEFADCCAVkGCyqGSIb3DQEJEAEEoIIBSASCAUQwggFAAgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIGOAwFRMBjtelggwkSKvgaf23tV34RWCHa5G5dmt
# ToooAgZjKwD6x18YEzIwMjIwOTI2MDcxNjQzLjcwOFowBIACAfSggdikgdUwgdIx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1p
# Y3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEmMCQGA1UECxMdVGhh
# bGVzIFRTUyBFU046MTc5RS00QkIwLTgyNDYxJTAjBgNVBAMTHE1pY3Jvc29mdCBU
# aW1lLVN0YW1wIFNlcnZpY2WgghFlMIIHFDCCBPygAwIBAgITMwAAAYo+OI3SDgL6
# 6AABAAABijANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0Eg
# MjAxMDAeFw0yMTEwMjgxOTI3NDJaFw0yMzAxMjYxOTI3NDJaMIHSMQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQg
# SXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJjAkBgNVBAsTHVRoYWxlcyBUU1Mg
# RVNOOjE3OUUtNEJCMC04MjQ2MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFt
# cCBTZXJ2aWNlMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAt/+ut6GD
# AyAZvegBhagWd0GoqT8lFHMepoWNOLPPEEoLuya4X3n+K14FvlZwFmKwqap6B+6E
# kITSjkecTSB6QRA4kivdJydlLvKrg8udtBu67LKyjQqwRzDQTRhECxpU30tdBE/A
# eyP95k7qndhIu/OpT4QGyGJUiMDlmZAiDPY5FJkitUgGvwMBHwogJz8FVEBFnViA
# URTJ4kBDiU6ppbv4PI97+vQhpspDK+83gayaiRC3gNTGy3iOie6Psl03cvYIiFcA
# JRP4O0RkeFlv/SQoomz3JtsMd9ooS/XO0vSN9h2DVKONMjaFOgnN5Rk5iCqwmn6q
# sme+haoR/TrCBS0zXjXsWTgkljUBtt17UBbW8RL+9LNw3cjPJ8EYRglMNXCYLM6G
# zCDXEvE9T//sAv+k1c84tmoiZDZBqBgr/SvL+gVsOz3EoDZQ26qTa1bEn/npxMmX
# ctoZSe8SRDqgK0JUWhjKXgnyaOADEB+FtfIi+jdcUJbpPtAL4kWvVSRKipVv8MEu
# YRLexXEDEBi+V4tfKApZhE4ga0p+QCiawHLBZNoj3UQNzM5QVmGai3MnQFbZkhqb
# UDypo9vaWEeVeO35JfdLWjwRgvMX3VKZL57d7jmRjiVlluXjZFLx+rhJL7JYVptO
# PtF1MAtMYlp6OugnOpG+4W4MGHqj7YYfP0UCAwEAAaOCATYwggEyMB0GA1UdDgQW
# BBQj2kPY/WwZ1Jeup0lHhD4xkGkkAzAfBgNVHSMEGDAWgBSfpxVdAF5iXYP05dJl
# pxtTNRnpcjBfBgNVHR8EWDBWMFSgUqBQhk5odHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAx
# MCgxKS5jcmwwbAYIKwYBBQUHAQEEYDBeMFwGCCsGAQUFBzAChlBodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFRpbWUtU3Rh
# bXAlMjBQQ0ElMjAyMDEwKDEpLmNydDAMBgNVHRMBAf8EAjAAMBMGA1UdJQQMMAoG
# CCsGAQUFBwMIMA0GCSqGSIb3DQEBCwUAA4ICAQDF9MESsPXDeRtfFo1f575iPfF9
# ARWbeuuNfM583IfTxfzZf2dv/me3DNi/KcNNEnR1TKbZtG7Lsg0cy/pKIEQOJG2f
# YaWwIIKYwuyDJI2Q4kVi5mzbV/0C5+vQQsQcCvfsM8K5X2ffifJi7tqeG0r58Cjg
# we7xBYvguPmjUNxwTWvEjZIPfpjVUoaPCl6qqs0eFUb7bcLhzTEEYBnAj8MENhiP
# 5IJd4Pp5lFqHTtpec67YFmGuO/uIA/TjPBfctM5kUI+uzfyh/yIdtDNtkIz+e/xm
# XSFhiQER0uBjRobQZV6c+0TNtvRNLayU4u7Eekd7OaDXzQR0RuWGaSiwtN6Xc/Po
# NP0rezG6Ovcyow1qMoUkUEQ7qqD0Qq8QFwK0DKCdZSJtyBKMBpjUYCnNUZbYvTTW
# m4DXK5RYgf23bVBJW4Xo5w490HHo4TjWNqz17PqPyMCTnM8HcAqTnPeME0dPYvbd
# wzDMgbumydbJaq/06FImkJ7KXs9jxqDiE2PTeYnaj82n6Q//PqbHuxxJmwQO4fzd
# OgVqAEkG1XDmppVKW/rJxBN3IxyVr6QP9chY2MYVa0bbACI2dvU+R2QJlE5AjoMK
# y68WI1pmFT3JKBrracpy6HUjGrtV+/1U52brrElClVy5Fb8+UZWZLp82cuCztJMM
# SqW+kP5zyVBSvLM+4DCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUw
# DQYJKoZIhvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhv
# cml0eSAyMDEwMB4XDTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4MzIyNVowfDELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9z
# b2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAw
# ggIKAoICAQDk4aZM57RyIQt5osvXJHm9DtWC0/3unAcH0qlsTnXIyjVX9gF/bErg
# 4r25PhdgM/9cT8dm95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLAEBjoYH1qUoNEt6aO
# RmsHFPPFdvWGUNzBRMhxXFExN6AKOG6N7dcP2CZTfDlhAnrEqv1yaa8dq6z2Nr41
# JmTamDu6GnszrYBbfowQHJ1S/rboYiXcag/PXfT+jlPP1uyFVk3v3byNpOORj7I5
# LFGc6XBpDco2LXCOMcg1KL3jtIckw+DJj361VI/c+gVVmG1oO5pGve2krnopN6zL
# 64NF50ZuyjLVwIYwXE8s4mKyzbnijYjklqwBSru+cakXW2dg3viSkR4dPf0gz3N9
# QZpGdc3EXzTdEonW/aUgfX782Z5F37ZyL9t9X4C626p+Nuw2TPYrbqgSUei/BQOj
# 0XOmTTd0lBw0gg/wEPK3Rxjtp+iZfD9M269ewvPV2HM9Q07BMzlMjgK8QmguEOqE
# UUbi0b1qGFphAXPKZ6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJNmSLW6CmgyFdXzB0
# kZSU2LlQ+QuJYfM2BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6r1AFemzFER1y7435
# UsSFF5PAPBXbGjfHCBUYP3irRbb1Hode2o+eFnJpxq57t7c+auIurQIDAQABo4IB
# 3TCCAdkwEgYJKwYBBAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIEFgQUKqdS/mTE
# mr6CkTxGNSnPEP8vBO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMFwG
# A1UdIARVMFMwUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNV
# HSUEDDAKBggrBgEFBQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNV
# HQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo
# 0T2UkFvXzpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29m
# dC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5j
# cmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jv
# c29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDAN
# BgkqhkiG9w0BAQsFAAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL/Klv6lwUtj5OR2R4
# sQaTlz0xM7U518JxNj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu6WZnOlNN3Zi6th54
# 2DYunKmCVgADsAW+iehp4LoJ7nvfam++Kctu2D9IdQHZGN5tggz1bSNU5HhTdSRX
# ud2f8449xvNo32X2pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfgQJY4rPf5KYnDvBew
# VIVCs/wMnosZiefwC2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8sCXgU6ZGyqVvfSaN0
# DLzskYDSPeZKPmY7T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCrdTDFNLB62FD+Cljd
# QDzHVG2dY3RILLFORy3BFARxv2T5JL5zbcqOCb2zAVdJVGTZc9d/HltEAY5aGZFr
# DZ+kKNxnGSgkujhLmm77IVRrakURR6nxt67I6IleT53S0Ex2tVdUCbFpAUR+fKFh
# bHP+CrvsQWY9af3LwUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8CwYKiexcdFYmNcP7n
# tdAoGokLjzbaukz5m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9JZTmdHRbatGePu1+
# oDEzfbzL6Xu/OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQdVTNYs6Fw
# ZvKhggLUMIICPQIBATCCAQChgdikgdUwgdIxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJh
# dGlvbnMgTGltaXRlZDEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046MTc5RS00QkIw
# LTgyNDYxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WiIwoB
# ATAHBgUrDgMCGgMVAIDw82OvG1MFBB2n/4weVqpzV8ShoIGDMIGApH4wfDELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9z
# b2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJKoZIhvcNAQEFBQACBQDm224YMCIY
# DzIwMjIwOTI2MDgxNzI4WhgPMjAyMjA5MjcwODE3MjhaMHQwOgYKKwYBBAGEWQoE
# ATEsMCowCgIFAObbbhgCAQAwBwIBAAICEbgwBwIBAAICEc8wCgIFAObcv5gCAQAw
# NgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEKMAgC
# AQACAwGGoDANBgkqhkiG9w0BAQUFAAOBgQAn6doQMbiXiyQTrcxyQduptabHbVlw
# hEsbRLY3iXGZE88w/bvsP/Q2AyxTk3/ln1hjNBB0pgDIgAUXjkd9BSZ3PLFKB6Lx
# Lod5UsbS2feXrBksh+/lxAtoFTFGZIk12W3VzZXvE0FbdXs4i4WwkYtQ1SnHoY6b
# 99rkkwUZkAr0tTGCBA0wggQJAgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBD
# QSAyMDEwAhMzAAABij44jdIOAvroAAEAAAGKMA0GCWCGSAFlAwQCAQUAoIIBSjAa
# BgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEIHtcqCKT
# ytgC8YVhj1Wd6tkWV64KvVwzyuFGkLpMXyT5MIH6BgsqhkiG9w0BCRACLzGB6jCB
# 5zCB5DCBvQQg9L3gq3XfSr5+879/MPgxtZCFBoTtEeQ4foCSOU1UKb0wgZgwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAYo+OI3SDgL66AAB
# AAABijAiBCAaTP55pL1MaGp58u9IwI0dZzN66S7glh14y2g8LY2WqTANBgkqhkiG
# 9w0BAQsFAASCAgCdK2tlyRIvxY/PVIjUJDhSgpXpN1S8gf6GdfThBq8TZF6wqL88
# yMAeOk0Sw9t8DbzUsZE7PAMtIpAyuC1xXV33e3AjDtNo/DfgmNWSQmZuCkmEE19j
# ljrbJjGdLUwQ33ctSMLQ0bN8zn06M7wdCPn2/P8AucYxHNMcxOX+s0OrGORIpp2v
# JHZIFKnpObD12HJndiefKKeXAVAf9jGL3m5a+gK1Q3Vv4X2rkeRAwSnixGwFF+yh
# 88udwBQPZMezwNhw7eltVrpwC8eEZu053Kg2t72y35HxwN9SGbjNWvppKvf0l9vc
# Oxtf2FLAeXZ3NX70M9igtC7y/5JFQfweHwZwybsYVMmEdWo49Mhd4BZ1yOxvrRvM
# 8yUtiR4rww+z0wvQlZE7MvqxIUho4NEMG5tefARUN2fHiYjuYJO6LiyFThmlrun0
# Uy/Ew261CUf8dfLuafhgycoVlOuvIF/3GoWZWIbjcZWuefNkS+aTgfR3wir0v4kh
# MRnoPwRn+oCmPtVpYNvpxA7S0XaEnScNBSpB2VygbedPTpa1mryZvVTY+etZT4zE
# tUbB4s8V3AvVRS0zud2p9M8ZOf+J2WdcJIYX+kqx/Y5tljYg0ZcolSpH3NoMoSZv
# ksSdhEUvRXmazYm2JTlFvmiRh2qvVtxB8atR/FyGTzP4LFUT7oXAMOwPxw==
# SIG # End signature block

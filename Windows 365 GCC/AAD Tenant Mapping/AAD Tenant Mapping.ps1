<#
.SYNOPSIS
    Get/Add tenant mapping.
.DESCRIPTION
    For GCC (US Government Community Cloud) customers, the Azure Active Directory for tenant is in public cloud, but the Azure resources and Windows 365 Cloud PCs are in US government cloud. Tenant mapping is required for customer administrators to setup & config Windows 365 and for the end users at GCC customers to access their Windows 365 Cloud PCs. The setup and maintenance of the tenant mapping must be done while onboarding to the US Government cloud.
    This script can help administrators on getting/adding tenant mapping and its prerequisite work (provision required AAD applications to tenants).
#>

[CmdletBinding()]
param()

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

$graphBaseUri = "https://graph.microsoft.com"
$publicCloudScope = "$graphBaseUri/.default"
$govCloudScope = "$firstPartyAppId/.default"

$publicClientPermission = "$graphBaseUri/CloudPC.ReadWrite.All"
$govClientPermission = "$firstPartyAppId/EndUser.Access"

# The max retry times for provision application is 6. The total waiting time is about 60s.
$provisionMaxRetryTimes = 6
# The max retry times for consenting permission is 30. The total waiting time is about 5 minutes.
$consentMaxRetryTimes = 30

function Import-Modules {
    # Install AzureAD module if missing
    if (!(Get-Module -ListAvailable -Name AzureAD)) {
        Write-Host "Missing required module, will install module 'AzureAD'...`n" -ForegroundColor Green
        Install-Module AzureAD
    }

    if ($PSVersionTable.PSVersion.Major -gt 5) {
        Import-Module AzureAD -UseWindowsPowerShell | Out-Null
    }
    else {
        Import-Module AzureAD
    }

    # Install MSAL.PS module if missing
    if (!(Get-Module -ListAvailable -Name MSAL.PS)) {
        Write-Host "Missing required module, will install module 'MSAL.PS'...`n" -ForegroundColor Green
        Install-Module MSAL.PS
    }

    Import-Module MSAL.PS # https://github.com/AzureAD/MSAL.PS
}

function Install-PublicApps {
    if ($null -eq (Get-AzureADTenantDetail)) {
        Write-Host "Please input your public tenant admin account and password in opened web browser!"
        Connect-AzureAD | Out-String | Write-Verbose
    }

    Write-Host "Checking 'Microsoft Graph' application..."
    $interval = 10
    $totalTime = $interval * $provisionMaxRetryTimes
    $app = Get-AzureADServicePrincipal -SearchString "Microsoft Graph" | Where { $_.AppId -eq $msGraphAppId }
    if ($null -eq $app) {
        Write-Host "Provision 'Microsoft Graph' application..."
        New-AzureADServicePrincipal -AppId $msGraphAppId | Out-String | Write-Verbose

        $retryTimes = 0
        while (($null -eq $app) -and ($retryTimes -lt $provisionMaxRetryTimes)) {
            $retryTimes++
            $app = Get-AzureADServicePrincipal -SearchString "Microsoft Graph" | Where { $_.AppId -eq $msGraphAppId }
            Write-Host "Provisioning 'Microsoft Graph' application is in progress...($retryTimes/$provisionMaxRetryTimes)"
            Start-Sleep -Seconds $interval
        }

        if ($null -ne $app) {
            Write-Host "Provisioning 'Microsoft Graph' application completed.`n" -ForegroundColor Green
        }
        else {
            Write-Host "Provisioning 'Microsoft Graph' application failed after $provisionMaxRetryTimes times(total time: $totalTime seconds) retry, please wait for 10 minutes and try again. Exit...`n" -ForegroundColor Red
            Exit
        }
    }
    else {
        Write-Host "'Microsoft Graph' application already exists in tenant.`n" -ForegroundColor Green
    }

    Write-Host "Checking 'Windows 365 Tenant Mapping 3P' application..."
    $app = Get-AzureADServicePrincipal -SearchString "Windows 365 Tenant Mapping 3P" | Where { $_.AppId -eq $publicCloudClientId }
    if ($null -eq $app) {
        Write-Host "Provision 'Windows 365 Tenant Mapping 3P' application..."
        New-AzureADServicePrincipal -AppId $publicCloudClientId | Out-String | Write-Verbose
        
        $retryTimes = 0
        while (($null -eq $app) -and ($retryTimes -lt $provisionMaxRetryTimes)) {
            $retryTimes++
            $app = Get-AzureADServicePrincipal -SearchString "Windows 365 Tenant Mapping 3P" | Where { $_.AppId -eq $publicCloudClientId }
            Write-Host "Provisioning 'Windows 365 Tenant Mapping 3P' application is in progress...($retryTimes/$provisionMaxRetryTimes)"
            Start-Sleep -Seconds $interval
        }

        if ($null -ne $app) {
            Write-Host "Provisioning 'Windows 365 Tenant Mapping 3P' application completed.`n" -ForegroundColor Green
        }
        else {
            Write-Host "Provisioning 'Windows 365 Tenant Mapping 3P' application failed after $provisionMaxRetryTimes times(total time: $totalTime seconds) retry, please wait for 10 minutes and try again. Exit...`n" -ForegroundColor Red
            Exit
        }
    }
    else {
        Write-Host "'Windows 365 Tenant Mapping 3P' application already exists in tenant.`n" -ForegroundColor Green
    }
}

function Install-GovApps {
    if ($null -eq (Get-AzureADTenantDetail)) {
        Write-Host "Please input your government tenant admin account and password in opened web browser!"
        Connect-AzureAD | Out-String | Write-Verbose
    }

    Write-Host "Checking 'Cloud PC' application..."
    $interval = 10
    $totalTime = $interval * $provisionMaxRetryTimes
    $app = Get-AzureADServicePrincipal -SearchString "Cloud PC" | Where { $_.AppId -eq $firstPartyAppId }
    if ($null -eq $app) {
        Write-Host "Provision 'Cloud PC' application..."
        New-AzureADServicePrincipal -AppId $firstPartyAppId | Out-String | Write-Verbose
        
        $retryTimes = 0
        while (($null -eq $app) -and ($retryTimes -lt $provisionMaxRetryTimes)) {
            $retryTimes++
            $app = Get-AzureADServicePrincipal -SearchString "Cloud PC" | Where { $_.AppId -eq $firstPartyAppId }
            Write-Host "Provisioning 'Cloud PC' application is in progress...($retryTimes/$provisionMaxRetryTimes)"
            Start-Sleep -Seconds $interval
        }

        if ($null -ne $app) {
            Write-Host "Provisioning 'Cloud PC' application completed.`n" -ForegroundColor Green
        }
        else {
            Write-Host "Provisioning 'Cloud PC' application failed after $provisionMaxRetryTimes times(total time: $totalTime seconds) retry, please wait for 10 minutes and try again. Exit...`n" -ForegroundColor Red
            Exit
        }
    }
    else {
        Write-Host "'Cloud PC' application already exists in tenant.`n" -ForegroundColor Green
    }

    Write-Host "Checking 'Windows 365 Tenant Mapping Gov 3P' application..."
    $app = Get-AzureADServicePrincipal -SearchString "Windows 365 Tenant Mapping Gov 3P" | Where { $_.AppId -eq $govCloudClientId }
    if ($null -eq $app) {
        Write-Host "Provision 'Windows 365 Tenant Mapping Gov 3P' application..."
        New-AzureADServicePrincipal -AppId $govCloudClientId | Out-String | Write-Verbose
        
        $retryTimes = 0
        while (($null -eq $app) -and ($retryTimes -lt $provisionMaxRetryTimes)) {
            $retryTimes++
            $app = Get-AzureADServicePrincipal -SearchString "Windows 365 Tenant Mapping Gov 3P" | Where { $_.AppId -eq $govCloudClientId }
            Write-Host "Provisioning 'Windows 365 Tenant Mapping Gov 3P' application is in progress...($retryTimes/$provisionMaxRetryTimes)"
            Start-Sleep -Seconds $interval
        }

        if ($null -ne $app) {
            Write-Host "Provisioning 'Windows 365 Tenant Mapping Gov 3P' application completed.`n" -ForegroundColor Green
        }
        else {
            Write-Host "Provisioning 'Windows 365 Tenant Mapping Gov 3P' application failed after $provisionMaxRetryTimes times(total time: $totalTime seconds) retry, please wait for 10 minutes and try again. Exit...`n" -ForegroundColor Red
            Exit
        }
    }
    else {
        Write-Host "'Windows 365 Tenant Mapping Gov 3P' application already exists in tenant.`n" -ForegroundColor Green
    }
}

function Get-PublicTenantToken {
    param (
        [guid]$PublicCloudTenantId
    )

    Write-Host "Getting public cloud tenant token..."
    Write-Host "A web browser will open. Please input your public tenant admin account and password. If asked to consent permissions, please do so on behalf of your organization.`n" -ForegroundColor Green
    # Bring the current PowerShell window into the foreground and activate the window.
    $window = (Get-Process -id $pid).MainWindowHandle
    $foreground = [SFW]::SetForegroundWindow($window)

    # Consent permissions
    $publicTokenObject = Get-MsalToken -ClientId $publicCloudClientId -TenantId $PublicCloudTenantId -Interactive -Scope $publicCloudScope
    $interval = 10
    $totalTime = $interval * $consentMaxRetryTimes
    $retryTimes = 0
    while (($null -eq $publicTokenObject.Scopes -or !$publicTokenObject.Scopes.Contains($publicClientPermission)) -and ($retryTimes -lt $consentMaxRetryTimes)) {
        $retryTimes++
        Write-Host "Consenting permissions for public cloud tenant is in progress...($retryTimes/$consentMaxRetryTimes)"
        Start-Sleep -Seconds $interval
        $publicTokenObject = Get-MsalToken -ClientId $publicCloudClientId -TenantId $PublicCloudTenantId -Silent -ForceRefresh -Scope $publicCloudScope
    }

    Write-Verbose -Message "Scopes in public token:"
    Write-Verbose -Message ($publicTokenObject.Scopes -join ",")

    if ($null -eq $publicTokenObject.Scopes -or !$publicTokenObject.Scopes.Contains($publicClientPermission)) {
        Write-Host "Consenting permissions for public cloud tenant doesn't take effect after $consentMaxRetryTimes times(total time: $totalTime seconds) retry, please wait for 10 minutes and try again. Exit...`n" -ForegroundColor Red
        Exit
    }
    else {
        Write-Host "Permissions are consented`n" -ForegroundColor Green
    }

    $publicToken = $publicTokenObject.AccessToken

    return $publicToken
}

function Get-GovTenantToken {
    param (
        [guid]$GovCloudTenantId
    )

    Write-Host "Getting government cloud tenant token..."
    Write-Host "A web browser will open. Please input your government tenant admin account and password. If asked to consent permissions, please do so on behalf of your organization.`n" -ForegroundColor Green
    # Bring the current PowerShell window into the foreground and activate the window.
    $window = (Get-Process -id $pid).MainWindowHandle
    $foreground = [SFW]::SetForegroundWindow($window)
    
    # Consent permissions
    $govTokenObject = Get-MsalToken -ClientId $govCloudClientId -TenantId $GovCloudTenantId -Interactive -Scope $govCloudScope
    $interval = 10
    $totalTime = $interval * $consentMaxRetryTimes
    $retryTimes = 0
    while (($null -eq $govTokenObject.Scopes -or !$govTokenObject.Scopes.Contains($govClientPermission)) -and ($retryTimes -lt $consentMaxRetryTimes)) {
        $retryTimes++
        Write-Host "Consenting permissions for government cloud tenant is in progress...($retryTimes/$consentMaxRetryTimes)"
        Start-Sleep -Seconds $interval
        $govTokenObject = Get-MsalToken -ClientId $govCloudClientId -TenantId $GovCloudTenantId -Silent -ForceRefresh -Scope $govCloudScope
    }

    Write-Verbose -Message "Scopes in government token:"
    Write-Verbose -Message ($govTokenObject.Scopes -join ",")

    if ($null -eq $govTokenObject.Scopes -or !$govTokenObject.Scopes.Contains($govClientPermission)) {
        Write-Host "Consenting permissions for government cloud tenant doesn't take effect after $consentMaxRetryTimes times(total time: $totalTime seconds) retry, please wait for 10 minutes and try again. Exit...`n" -ForegroundColor Red
        Exit
    }
    else {
        Write-Host "Permissions are consented`n" -ForegroundColor Green
    }

    $govToken = $govTokenObject.AccessToken

    return $govToken
}

function Get-TenantMapping {

    Import-Modules

    Write-Host "Please input your public tenant admin account and password in opened web browser!"

    Connect-AzureAD | Out-String | Write-Verbose
    Install-PublicApps

    # Get token for public cloud tenant
    $publicCloudTenant = Get-AzureADTenantDetail
    $publicCloudTenantID = $publicCloudTenant.ObjectId
    $publicToken = Get-PublicTenantToken -PublicCloudTenantId $publicCloudTenantID

    # Bring the current PowerShell window into the foreground and activate the window.
    $window = (Get-Process -id $pid).MainWindowHandle
    $foreground = [SFW]::SetForegroundWindow($window)

    Write-Host "Please input your government tenant admin account and password in opened web browser!"

    Connect-AzureAD | Out-String | Write-Verbose
    Install-GovApps

    # Get token for government cloud tenant
    $govCloudTenant = Get-AzureADTenantDetail
    $govCloudTenantID = $govCloudTenant.ObjectId
    $govToken = Get-GovTenantToken -GovCloudTenantId $govCloudTenantID

    $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/crossCloudGovernmentOrganizationMapping"
    $headers = @{"Authorization" = "Bearer " + $publicToken; "x-ms-cloudpc-usgovcloudtenantaadtoken" = "Bearer " + $govToken; }

    Write-Host "Sending request...`n"
    try {
        $response = Invoke-WebRequest $url -Method "GET" -Headers $headers
        Write-Verbose $response
        
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
        Write-Host "Encounter error when get tenant mapping! `nPlease retry or contact support for help. If you have any questions or need assistance, please file a new service request in the Microsoft Intune admin center (intune.microsoft.com) -> Tenant Administration -> Help and support -> Windows 365." -ForegroundColor Red
        Write-Verbose $_.Exception.Message
        Write-Verbose (New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())).ReadToEnd()
    }
}

function Add-TenantMapping {
    
    Import-Modules
    
    Write-Host "Please input your public tenant admin account and password in opened web browser!"

    Connect-AzureAD | Out-String | Write-Verbose
    Install-PublicApps

    # Get token for public cloud tenant
    $publicCloudTenant = Get-AzureADTenantDetail
    $publicCloudTenantID = $publicCloudTenant.ObjectId
    $publicToken = Get-PublicTenantToken -PublicCloudTenantId $publicCloudTenantID

    # Bring the current PowerShell window into the foreground and activate the window.
    $window = (Get-Process -id $pid).MainWindowHandle
    $foreground = [SFW]::SetForegroundWindow($window)

    Write-Host "Please input your government tenant admin account and password in opened web browser!"

    Connect-AzureAD | Out-String | Write-Verbose
    Install-GovApps

    # Get token for government cloud tenant
    $govCloudTenant = Get-AzureADTenantDetail
    $govCloudTenantID = $govCloudTenant.ObjectId
    $govToken = Get-GovTenantToken -GovCloudTenantId $govCloudTenantID

    $url = "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/crossCloudGovernmentOrganizationMapping"
    $body = "{}"

    $headers = @{"Authorization" = "Bearer " + $publicToken; "x-ms-cloudpc-usgovcloudtenantaadtoken" = "Bearer " + $govToken; "Content-Type" = "application/json" }

    Write-Host "Sending request...`n"
    try {
        $response = Invoke-WebRequest $url -Method "POST" -Body $body -Headers $headers
        Write-Verbose $response

        if ("200" -eq $response.StatusCode) {
            Write-Host "Added tenant mapping successfully!" -ForegroundColor Green
        }
        else {
            throw "Non-200 status code"
        }
    }
    catch [System.Net.WebException] {
        Write-Verbose $_.Exception.Message
        Write-Verbose (New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())).ReadToEnd()

        Write-Verbose "Try to get tenant mapping..."
        try {
            $getResponse = Invoke-WebRequest $url -Method "GET" -Headers $headers
            Write-Verbose $getResponse
            
            if ("200" -eq $getResponse.StatusCode) {
                Write-Host "Failed to add tenant mapping because there is already an exist mapping between given tenants!" -ForegroundColor Red
                Exit
            }
            elseif ("204" -eq $getResponse.StatusCode) {
                Write-Verbose "There is no tenant mapping between given tenants."
                Write-Host "Failed to add tenant mapping! Please check if there is other tenant mapping for public cloud tenant or government cloud tenant. If yes, it will fail adding new mapping because we only support 1:1 mapping now; otherwise, please retry adding or contact support for help. If you have any questions or need assistance, please file a new service request in the Microsoft Intune admin center (intune.microsoft.com) -> Tenant Administration -> Help and support -> Windows 365." -ForegroundColor Red
                Exit
            }
            else {
                throw "Non-200 and Non-204 status code"
            }
        }
        catch [System.Net.WebException] {
            Write-Verbose "Encounter error when getting tenant mapping."
            Write-Verbose $_.Exception.Message
            Write-Verbose (New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())).ReadToEnd()
        }

        Write-Host "Encounter error when adding tenant mapping! Please retry or contact support for help. If you have any questions or need assistance, please file a new service request in the Microsoft Intune admin center (intune.microsoft.com) -> Tenant Administration -> Help and support -> Windows 365." -ForegroundColor Red
    }
}

$add = New-Object System.Management.Automation.Host.ChoiceDescription '&Add', 'Add a new tenant mapping'
$get = New-Object System.Management.Automation.Host.ChoiceDescription '&Get', 'Get specific tenant mapping'
$skip = New-Object System.Management.Automation.Host.ChoiceDescription '&Skip', 'Do nothing and exit. Choose this when import this script as module'
$options = [System.Management.Automation.Host.ChoiceDescription[]]($add, $get, $skip)

$title = 'Tenant mapping operations'
$message = 'Please select your operation:'
$result = $host.ui.PromptForChoice($title, $message, $options, 0)
Write-Host

switch ($result) {
    0 { 
        Add-TenantMapping
    }
    1 { 
        Get-TenantMapping
    }
}
# SIG # Begin signature block
# MIInngYJKoZIhvcNAQcCoIInjzCCJ4sCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCd7SLFB6jBET06
# WlggwB1v0N2/PbwHItroIGsBCYW/RKCCDYEwggX/MIID56ADAgECAhMzAAACzI61
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
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIZczCCGW8CAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAsyOtZamvdHJTgAAAAACzDAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgwzUesfhN
# K1HdEd/jWq9N8KfcTh4U1HxvuN647gNssqgwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQBkRnRPQzIzyirpUNBlrI/yyZ7gEFUxq4oThLHPLjcb
# PJyATxUUdjcY7sUv8heP42hlrwthyS+0enQOGs/TLb2WYONtMSfaQOG94fBV1SB8
# kClc4+4Z8g24+TAW9IBiksAah0xUewq3VmhHPe27zu2iO0Bt5gkbECss3iW05gC0
# MSqy34C0pnhE4LPzbOKNmbvuK1fp8soaWroYyoKcPPq5FEqUxu9esTEEalrad/Oe
# ZLs6fF0sLO7t4CYWXuWW3SquuM5sVcsW5JpUef8GwRH1tyV2KUlK27kqhie8PQT1
# tZ+jUyYZQkhnG8ScxbH3SJcZN4BwmCH2Rsfc5oTCGbBOoYIW/TCCFvkGCisGAQQB
# gjcDAwExghbpMIIW5QYJKoZIhvcNAQcCoIIW1jCCFtICAQMxDzANBglghkgBZQME
# AgEFADCCAVEGCyqGSIb3DQEJEAEEoIIBQASCATwwggE4AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIN/yal4tLzcN08yB/8nGsDhAE/5m7jDStDH9WJqc
# fLOBAgZja9AS2OcYEzIwMjIxMTEwMDgwMzA1LjU4OFowBIACAfSggdCkgc0wgcox
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1p
# Y3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJjAkBgNVBAsTHVRoYWxlcyBUU1Mg
# RVNOOjdCRjEtRTNFQS1CODA4MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFt
# cCBTZXJ2aWNloIIRVDCCBwwwggT0oAMCAQICEzMAAAHI+bDuZ+3qa0YAAQAAAcgw
# DQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcN
# MjIxMTA0MTkwMTM3WhcNMjQwMjAyMTkwMTM3WjCByjELMAkGA1UEBhMCVVMxEzAR
# BgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2Eg
# T3BlcmF0aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046N0JGMS1FM0VBLUI4
# MDgxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0G
# CSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC5y51+KE+DJFbCeci4kKpzdMK0WTRc
# 6KYVwqNT1tLpYWeDaX4WsiJ3SY9nspazoTCPbVf5mQaQzrH6jMeWY22cdJDjymMg
# V2UpciiHt9KjjUDifS1AiXCGzy4hgihynvbHAMEcpJnEZoRr/TvTuLI7D5pdlc1x
# PGA2JEQBJv22GUtkzvmZ8kiAFW9SZ0tlz5c5RjDP/y6XsgTO080fhyfwKfS0mEgV
# +nad62vwZg2iLIirG54bv6xK3bFeXv+KBzlwc9mdaF+X09oHj5K62sDzMCHNUdOe
# PhF9/EDhHeTgFFs90ajBB85/3ll5jEtMd/lrAHSepnE5j7K4ZaF/qGnlEZGi5z1t
# 5Vm/3wzV6thrnlLVqFmAYNAnJxW0TLzZGWYp9Nhja42aU8ta2cPuwOWlWSFhAYq5
# Nae7BAqr1lNIT7RXZwfwlpYFglAwi5ZYzze8s+jchP9L/mNPahk5L2ewmDDALBFS
# 1i3C2rz88m2+3VXpWgbhZ3b8wCJ+AQk6QcXsBE+oj1e/bz6uKolnmaMsbPzh0/av
# Kh7SXFhLPc9PkSsqhLT7Mmlg0BzFu/ZReJOTdaP+Zne26XPrPhedKXmDLQ8t6v4R
# WPPgb3oZxmArZ30b65jKUdbAGd4i/1gVCPrIx1b/iwSmQRuumIk16ZzFQKYGKlnt
# Jzfmu/i62Qnj9QIDAQABo4IBNjCCATIwHQYDVR0OBBYEFLVcL0mButLAsNOIklPi
# Irs1S+T1MB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRY
# MFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01p
# Y3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEF
# BQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAo
# MSkuY3J0MAwGA1UdEwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDQYJKoZI
# hvcNAQELBQADggIBAMPWclLIQ8OpKCd+QWJ8hu14lvs2RkJtGPnIEaJPV/19Ma9R
# vkJbuTd5Kne7FSqib0tbKRw19Br9h/DSWJsSKb1hGNQ1wvjaggWq2n/uuX2CDrWi
# IHw8H7q8sSaNeRjFRRHxaMooLlDl3H3oHbV9pJyjYw6a+NjEZRHsCf7jnb2VA88u
# psQpGNw1Bv6n6aRAfZd4xuyHkRAKRO5gCKYVOCe6LZk8UsS4GnEErnPYecqd4dQn
# 2LilwpZ0KoXUA5U3yBcgfRHQV+UxwKDlNby/3RXDH+Y/doTYiB7W4Twz1g0Gfnvv
# o/GYDXpn5zaz6Fgj72wlmGFEDxpJhpyuUvPtpT/no68RhERFBm224AWStX4z8n60
# J4Y2/QZ3vljiUosynn/TGg6+I8F0HasPkL9T4Hyq3VsGpAtVnXAdHLT/oeEnFs6L
# YiAYlo4JgsZfbPPRUBPqZnYFNasmZwrpIO/utfumyAL4J/W3RHVpYKQIcm2li7Iq
# N/tSh1FrN685/pXTVeSsBEcqsjttCgcUv6y6faWIkIGM3nWYNagSBQIS/AHeX5EV
# gAvRoiKxzlxNoZf9PwX6IBvP6PYYZW6bzmARBL24vNJ52hg/IRfFNuXB7AZ0DGoh
# loqjNEGjDj06cv7kKCihUx/dlKqnFzZALQTTeXpz+8KGRjKoxersvB3g+ceqMIIH
# cTCCBVmgAwIBAgITMwAAABXF52ueAptJmQAAAAAAFTANBgkqhkiG9w0BAQsFADCB
# iDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
# ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMp
# TWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIwMTAwHhcNMjEw
# OTMwMTgyMjI1WhcNMzAwOTMwMTgzMjI1WjB8MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQ
# Q0EgMjAxMDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOThpkzntHIh
# C3miy9ckeb0O1YLT/e6cBwfSqWxOdcjKNVf2AX9sSuDivbk+F2Az/1xPx2b3lVNx
# WuJ+Slr+uDZnhUYjDLWNE893MsAQGOhgfWpSg0S3po5GawcU88V29YZQ3MFEyHFc
# UTE3oAo4bo3t1w/YJlN8OWECesSq/XJprx2rrPY2vjUmZNqYO7oaezOtgFt+jBAc
# nVL+tuhiJdxqD89d9P6OU8/W7IVWTe/dvI2k45GPsjksUZzpcGkNyjYtcI4xyDUo
# veO0hyTD4MmPfrVUj9z6BVWYbWg7mka97aSueik3rMvrg0XnRm7KMtXAhjBcTyzi
# YrLNueKNiOSWrAFKu75xqRdbZ2De+JKRHh09/SDPc31BmkZ1zcRfNN0Sidb9pSB9
# fvzZnkXftnIv231fgLrbqn427DZM9ituqBJR6L8FA6PRc6ZNN3SUHDSCD/AQ8rdH
# GO2n6Jl8P0zbr17C89XYcz1DTsEzOUyOArxCaC4Q6oRRRuLRvWoYWmEBc8pnol7X
# KHYC4jMYctenIPDC+hIK12NvDMk2ZItboKaDIV1fMHSRlJTYuVD5C4lh8zYGNRiE
# R9vcG9H9stQcxWv2XFJRXRLbJbqvUAV6bMURHXLvjflSxIUXk8A8FdsaN8cIFRg/
# eKtFtvUeh17aj54WcmnGrnu3tz5q4i6tAgMBAAGjggHdMIIB2TASBgkrBgEEAYI3
# FQEEBQIDAQABMCMGCSsGAQQBgjcVAgQWBBQqp1L+ZMSavoKRPEY1Kc8Q/y8E7jAd
# BgNVHQ4EFgQUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXAYDVR0gBFUwUzBRBgwrBgEE
# AYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBMGA1UdJQQMMAoGCCsGAQUFBwMI
# MBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMB
# Af8EBTADAQH/MB8GA1UdIwQYMBaAFNX2VsuP6KJcYmjRPZSQW9fOmhjEMFYGA1Ud
# HwRPME0wS6BJoEeGRWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3By
# b2R1Y3RzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNybDBaBggrBgEFBQcBAQRO
# MEwwSgYIKwYBBQUHMAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2Vy
# dHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3J0MA0GCSqGSIb3DQEBCwUAA4IC
# AQCdVX38Kq3hLB9nATEkW+Geckv8qW/qXBS2Pk5HZHixBpOXPTEztTnXwnE2P9pk
# bHzQdTltuw8x5MKP+2zRoZQYIu7pZmc6U03dmLq2HnjYNi6cqYJWAAOwBb6J6Gng
# ugnue99qb74py27YP0h1AdkY3m2CDPVtI1TkeFN1JFe53Z/zjj3G82jfZfakVqr3
# lbYoVSfQJL1AoL8ZthISEV09J+BAljis9/kpicO8F7BUhUKz/AyeixmJ5/ALaoHC
# gRlCGVJ1ijbCHcNhcy4sa3tuPywJeBTpkbKpW99Jo3QMvOyRgNI95ko+ZjtPu4b6
# MhrZlvSP9pEB9s7GdP32THJvEKt1MMU0sHrYUP4KWN1APMdUbZ1jdEgssU5HLcEU
# BHG/ZPkkvnNtyo4JvbMBV0lUZNlz138eW0QBjloZkWsNn6Qo3GcZKCS6OEuabvsh
# VGtqRRFHqfG3rsjoiV5PndLQTHa1V1QJsWkBRH58oWFsc/4Ku+xBZj1p/cvBQUl+
# fpO+y/g75LcVv7TOPqUxUYS8vwLBgqJ7Fx0ViY1w/ue10CgaiQuPNtq6TPmb/wrp
# NPgkNWcr4A245oyZ1uEi6vAnQj0llOZ0dFtq0Z4+7X6gMTN9vMvpe784cETRkPHI
# qzqKOghif9lwY1NNje6CbaUFEMFxBmoQtB1VM1izoXBm8qGCAsswggI0AgEBMIH4
# oYHQpIHNMIHKMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUw
# IwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMSYwJAYDVQQLEx1U
# aGFsZXMgVFNTIEVTTjo3QkYxLUUzRUEtQjgwODElMCMGA1UEAxMcTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcGBSsOAwIaAxUA384TULvGNTQKUgNd
# AGK5wBjuy7KggYMwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAN
# BgkqhkiG9w0BAQUFAAIFAOcW90MwIhgPMjAyMjExMTAxMjA2MjdaGA8yMDIyMTEx
# MTEyMDYyN1owdDA6BgorBgEEAYRZCgQBMSwwKjAKAgUA5xb3QwIBADAHAgEAAgIQ
# VDAHAgEAAgIUcjAKAgUA5xhIwwIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEE
# AYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBBQUAA4GB
# AKo3dcHqSlf5qXP1LpLlBjeLMGyNm+vBw6OaEoDwqgaACQhxMPndqQBKeVzN48N+
# b6/cY4yULax1yKCSAkbtoeaFsWJfS/LbPXwMEbXCIMU2IErmY2otzq45hGyAfovn
# lnIZLMsGvMrNe6jqcfxBgQ+4WkLQOurxxyZW8oNYMWyeMYIEDTCCBAkCAQEwgZMw
# fDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
# ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMd
# TWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAHI+bDuZ+3qa0YAAQAA
# AcgwDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRAB
# BDAvBgkqhkiG9w0BCQQxIgQgSzR8w8MshiWMxq6qXu50cwwJo4S6ZnFzHojukcWo
# igMwgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHkMIG9BCBiAJjPzT9toy/HDqNypK8v
# QVbhN28DT2fEd+w+G4QDZjCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBD
# QSAyMDEwAhMzAAAByPmw7mft6mtGAAEAAAHIMCIEIEK567l7Nq5jmHpf2FLXOVjT
# 66qt6QuoqO6sWHPo94gsMA0GCSqGSIb3DQEBCwUABIICAC1PrcKFkNxYwijL+eXO
# B6gwsfZg1nQz8rFJKUyv9L7fEgjqQcSOtgNdKm7XlqKldT0vhrkvv5Ju+oM1R7dy
# ciUXzLsIF4it0tTicbqH7qnlaxm5q2BW/9Yznfua7p2BnL9A4sXno61MbNJllqbH
# 1NCkc7+dYvTcfGLzqTs7BjUhnqBTCY28KpujJU2s1yh78cV6ABfpQi/yEuHegqd7
# OL/EshQGTyDSqSC1c0osSrBNzgM4VzdVY4eiZGWkhTQsPlVJAVk6SFdPYDP2tzZK
# wq1rZCfhyZEDQQiXOYTiGerXCIb543+lfpfZ5fsLc0NeIQTxS5YHQLPKWqUCHqyu
# SHQup/c49nnB143eLFaKeDc909eAXoW3O3FBc156F36VJblq4nbeN3Bc58JXfqmz
# uYVxu5Foa39FhMkveIlr/0G0dF5rVT6h5SjY4bkDX4IXMUhmIO0T+yMNqHyP+Uhk
# dVPqBMcYSTNE1MtIDFhS99xhXaXt+I3JWoQmWmpIdrJnitFOp6O1JHL6nXK78OFA
# fpiX4Z89G8Kp1uC4CgCGUEYsKt+QjvfyVah+76VulNSCx5FYjg/QhBhYGTfhOjm0
# RK34Qlm+fORpb5L5Wa5KDi3GmNVYR/UototUy4ctVUGEt6HsDBNLoXBRUoRcL6So
# JBAqFal6AMH3MYPoDV2b2eo5
# SIG # End signature block

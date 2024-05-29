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
$publicCloudClientId = "afe4c380-772c-477c-8a25-598bfc30d325"
$govCloudClientId = "be0df5cb-3aa5-444b-9586-e118fa3f7feb"

$graphBaseUri = "https://graph.microsoft.com"
$publicCloudScope = "$graphBaseUri/.default"
$govCloudScope = "$firstPartyAppId/.default"

$publicClientPermission = "$graphBaseUri/cloudpc.readwrite.all"
$govClientPermission = "$firstPartyAppId/enduser.access"

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
# MIIoKQYJKoZIhvcNAQcCoIIoGjCCKBYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBjshFTNV0PXeUB
# CFUAUSEEEW/uHQ0fm1u0yVcg3Rn8kKCCDXYwggX0MIID3KADAgECAhMzAAADrzBA
# DkyjTQVBAAAAAAOvMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjMxMTE2MTkwOTAwWhcNMjQxMTE0MTkwOTAwWjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDOS8s1ra6f0YGtg0OhEaQa/t3Q+q1MEHhWJhqQVuO5amYXQpy8MDPNoJYk+FWA
# hePP5LxwcSge5aen+f5Q6WNPd6EDxGzotvVpNi5ve0H97S3F7C/axDfKxyNh21MG
# 0W8Sb0vxi/vorcLHOL9i+t2D6yvvDzLlEefUCbQV/zGCBjXGlYJcUj6RAzXyeNAN
# xSpKXAGd7Fh+ocGHPPphcD9LQTOJgG7Y7aYztHqBLJiQQ4eAgZNU4ac6+8LnEGAL
# go1ydC5BJEuJQjYKbNTy959HrKSu7LO3Ws0w8jw6pYdC1IMpdTkk2puTgY2PDNzB
# tLM4evG7FYer3WX+8t1UMYNTAgMBAAGjggFzMIIBbzAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQURxxxNPIEPGSO8kqz+bgCAQWGXsEw
# RQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEW
# MBQGA1UEBRMNMjMwMDEyKzUwMTgyNjAfBgNVHSMEGDAWgBRIbmTlUAXTgqoXNzci
# tW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3JsMGEG
# CCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3J0
# MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIBAISxFt/zR2frTFPB45Yd
# mhZpB2nNJoOoi+qlgcTlnO4QwlYN1w/vYwbDy/oFJolD5r6FMJd0RGcgEM8q9TgQ
# 2OC7gQEmhweVJ7yuKJlQBH7P7Pg5RiqgV3cSonJ+OM4kFHbP3gPLiyzssSQdRuPY
# 1mIWoGg9i7Y4ZC8ST7WhpSyc0pns2XsUe1XsIjaUcGu7zd7gg97eCUiLRdVklPmp
# XobH9CEAWakRUGNICYN2AgjhRTC4j3KJfqMkU04R6Toyh4/Toswm1uoDcGr5laYn
# TfcX3u5WnJqJLhuPe8Uj9kGAOcyo0O1mNwDa+LhFEzB6CB32+wfJMumfr6degvLT
# e8x55urQLeTjimBQgS49BSUkhFN7ois3cZyNpnrMca5AZaC7pLI72vuqSsSlLalG
# OcZmPHZGYJqZ0BacN274OZ80Q8B11iNokns9Od348bMb5Z4fihxaBWebl8kWEi2O
# PvQImOAeq3nt7UWJBzJYLAGEpfasaA3ZQgIcEXdD+uwo6ymMzDY6UamFOfYqYWXk
# ntxDGu7ngD2ugKUuccYKJJRiiz+LAUcj90BVcSHRLQop9N8zoALr/1sJuwPrVAtx
# HNEgSW+AKBqIxYWM4Ev32l6agSUAezLMbq5f3d8x9qzT031jMDT+sUAoCw0M5wVt
# CUQcqINPuYjbS1WgJyZIiEkBMIIHejCCBWKgAwIBAgIKYQ6Q0gAAAAAAAzANBgkq
# hkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5
# IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEwOTA5WjB+MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQg
# Q29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+laUKq4BjgaBEm6f8MMHt03
# a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc6Whe0t+bU7IKLMOv2akr
# rnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4Ddato88tt8zpcoRb0Rrrg
# OGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+lD3v++MrWhAfTVYoonpy
# 4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nkkDstrjNYxbc+/jLTswM9
# sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6A4aN91/w0FK/jJSHvMAh
# dCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmdX4jiJV3TIUs+UsS1Vz8k
# A/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL5zmhD+kjSbwYuER8ReTB
# w3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zdsGbiwZeBe+3W7UvnSSmn
# Eyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3T8HhhUSJxAlMxdSlQy90
# lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS4NaIjAsCAwEAAaOCAe0w
# ggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRIbmTlUAXTgqoXNzcitW2o
# ynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYD
# VR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBDuRQFTuHqp8cx0SOJNDBa
# BgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2Ny
# bC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3JsMF4GCCsG
# AQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3J0MIGfBgNV
# HSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEFBQcCARYzaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1hcnljcHMuaHRtMEAGCCsG
# AQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkAYwB5AF8AcwB0AGEAdABl
# AG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn8oalmOBUeRou09h0ZyKb
# C5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7v0epo/Np22O/IjWll11l
# hJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0bpdS1HXeUOeLpZMlEPXh6
# I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/KmtYSWMfCWluWpiW5IP0
# wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvyCInWH8MyGOLwxS3OW560
# STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBpmLJZiWhub6e3dMNABQam
# ASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJihsMdYzaXht/a8/jyFqGa
# J+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYbBL7fQccOKO7eZS/sl/ah
# XJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbSoqKfenoi+kiVH6v7RyOA
# 9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sLgOppO6/8MO0ETI7f33Vt
# Y5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtXcVZOSEXAQsmbdlsKgEhr
# /Xmfwb1tbWrJUnMTDXpQzTGCGgkwghoFAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAAOvMEAOTKNNBUEAAAAAA68wDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIJOOEtXRsDVUdW4N0d/IKLTY
# CSRnGPUpHyZYQd18nOnZMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAAjtOzK6doyDwhCJVJ8EN34EOS1UY927cG3QPLYu1tpoOnNlWpbwZS7hX
# pYBkMnuLAVwXxApJwYS5DggBkZdkgg6ZKpLwn7Sa/vy8CPuuGj5yEzdLeVV28CI+
# AQSyfVXufURd9mv/5Pn7vkAS4LnskcYwP9hp9KOMKDZRnfBSRbrg/ZGnxX6zYa+y
# V/zieEgPWy0jo5ZeTNAGATLP1udHNhi6poV52gLoW9Ttm4yKWwIMuaVP/wovjaWp
# k/2z5oERdW90TKbELNLIUmdxDcB+JXyFvnQ/H1+DrZcLP47QHXEaMPEiYkJdeVlj
# nrDZRvKNy8insJfr2TCsPVoauK4aW6GCF5MwghePBgorBgEEAYI3AwMBMYIXfzCC
# F3sGCSqGSIb3DQEHAqCCF2wwghdoAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFRBgsq
# hkiG9w0BCRABBKCCAUAEggE8MIIBOAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCDYxKkCoMd7/mZVergw7V0tI0wz1P197iVxQgCUX5BFBAIGZkZWuszo
# GBIyMDI0MDUyOTExNTg1MC4zMlowBIACAfSggdGkgc4wgcsxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVy
# aWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjozMzAzLTA1
# RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaCC
# EeowggcgMIIFCKADAgECAhMzAAAB5tlCnuoA+H3hAAEAAAHmMA0GCSqGSIb3DQEB
# CwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNV
# BAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4XDTIzMTIwNjE4NDUx
# NVoXDTI1MDMwNTE4NDUxNVowgcsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMx
# JzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjozMzAzLTA1RTAtRDk0NzElMCMGA1UE
# AxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCCAiIwDQYJKoZIhvcNAQEB
# BQADggIPADCCAgoCggIBAL2+mHzi2CW4TOb/Ck0qUCNwSUbN+W8oANnUP7Z3+J5h
# gS0XYcoysoYUM4uktZYbkMTKIpuVgqsTae3njQ4a7flnHSBckETTNZqdkQCMKO3h
# 4YGL65qRmyTvTMdNAcfJ8/4HebYFJI0U+GCxUg+nq+j/23o5417MjBfkTn5XAQbf
# udmAR7FAXZ9BlhvFDUBq6oO9F1exKkrV2HVQG30RoyzO65xpHmczBA3qwOMb30XN
# 0r0C3NufhKaWygtS1ECH/vrywp3RjWEyYpUfAhfz/gm5RFQFFnQla7Q1hAGnySGS
# 7XxDwIBDnTS0UHtUfekPzOgDiVwDsmTFMag8qu5+b6VFkADiIyBtwtnY//FJ2coX
# FTy8vfVGg2VkmIYvkypNe+/IEvP4xE/gSf03J7U3zH+UkPWy102jnAkb6aBewT/N
# /ODYZpWpBzMUeDQ2Xxukiqc0VRF5BGrcLWNVgwJJx6A3Md5i3Dk6Zn/t5WdGaNeU
# Kwu92zE7NzVhWfqdkuRAPnLfUdisH2Ige6zCFoy/aEk02NWd2SlbL3fg8hm5ZMyT
# frSSNc8XCXZa/VPOb206sKrz6XjTwogvon55+gY2RHxgHcz67W1h5UM79Nw5sYfF
# oYUHpBnEBSmd8Hk38yYE3Ew6rMbU3xCLBbyC2OMwmIUF/qJhisKO1HAXsg91AsW1
# AgMBAAGjggFJMIIBRTAdBgNVHQ4EFgQU5QQxee03nj7XVkz5C7tDmuDcVz0wHwYD
# VR0jBBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXwYDVR0fBFgwVjBUoFKgUIZO
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIw
# VGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3JsMGwGCCsGAQUFBwEBBGAwXjBc
# BggrBgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0
# cy9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcnQwDAYD
# VR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMC
# B4AwDQYJKoZIhvcNAQELBQADggIBAGFu6iBNqlGy7BKRoUxDp3K7xkJhSlZDyIit
# uLjS1TaErqkeC7SGPTP/3MVFHHkN+G6SO9uMD91LlVh/HPUQhs+W3z3swnawEY7Z
# gtjBh6V8mkPBsHRdL1mSuqnOrpf+WYNAOfcbm9xilhAInnksu/IWUnX3kBWjhbLx
# RfmnuD1bcyA0dAykz4RXrj5yzOPgejlpCZ4oa0rLvDvZ5Fj+9YO6m2u/Ou4U2YoI
# i3XZRwDkE6xenU+2SPHbJGwKPvsNKaXTNViOpb8hJaSsaPJ5Un6SHNy3FouSSVXA
# LGKCiQPp+RZvLSEIQpM5M8zOG6A8gBzFwexHazHTVhFr2kfbO912y4ER9IUboKPR
# BK8Rn8z2Yn6HiaJpBJHsARtUYNvJEqRifzRL7cCZGWHdk574EWonns5d14gNIdu8
# fMnuhOobz3qXd5SE+xmDr182DFPGW9E2ZET/7rViPtnW4HRdhA/rSuwwt1OVVgTJ
# lSXkwtMvku+oWjNmVLZeiOLgEQ/p11VPOYcnih05kxZNN5DQjCdYb3y9a/+ug96A
# KvUbrUVWt1csTcBch+3hk3hmQNOegCE/DsNk09GVJbhNtWP8vDRe+ctg3AxQD2i5
# j/DH215Nony9ORuBjJo5goXPqs1Fdnhp/p7chfAwJ98JqykpRcLvZgy7lbwv/PJP
# Gw1QSAFtMIIHcTCCBVmgAwIBAgITMwAAABXF52ueAptJmQAAAAAAFTANBgkqhkiG
# 9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEy
# MDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIw
# MTAwHhcNMjEwOTMwMTgyMjI1WhcNMzAwOTMwMTgzMjI1WjB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
# AOThpkzntHIhC3miy9ckeb0O1YLT/e6cBwfSqWxOdcjKNVf2AX9sSuDivbk+F2Az
# /1xPx2b3lVNxWuJ+Slr+uDZnhUYjDLWNE893MsAQGOhgfWpSg0S3po5GawcU88V2
# 9YZQ3MFEyHFcUTE3oAo4bo3t1w/YJlN8OWECesSq/XJprx2rrPY2vjUmZNqYO7oa
# ezOtgFt+jBAcnVL+tuhiJdxqD89d9P6OU8/W7IVWTe/dvI2k45GPsjksUZzpcGkN
# yjYtcI4xyDUoveO0hyTD4MmPfrVUj9z6BVWYbWg7mka97aSueik3rMvrg0XnRm7K
# MtXAhjBcTyziYrLNueKNiOSWrAFKu75xqRdbZ2De+JKRHh09/SDPc31BmkZ1zcRf
# NN0Sidb9pSB9fvzZnkXftnIv231fgLrbqn427DZM9ituqBJR6L8FA6PRc6ZNN3SU
# HDSCD/AQ8rdHGO2n6Jl8P0zbr17C89XYcz1DTsEzOUyOArxCaC4Q6oRRRuLRvWoY
# WmEBc8pnol7XKHYC4jMYctenIPDC+hIK12NvDMk2ZItboKaDIV1fMHSRlJTYuVD5
# C4lh8zYGNRiER9vcG9H9stQcxWv2XFJRXRLbJbqvUAV6bMURHXLvjflSxIUXk8A8
# FdsaN8cIFRg/eKtFtvUeh17aj54WcmnGrnu3tz5q4i6tAgMBAAGjggHdMIIB2TAS
# BgkrBgEEAYI3FQEEBQIDAQABMCMGCSsGAQQBgjcVAgQWBBQqp1L+ZMSavoKRPEY1
# Kc8Q/y8E7jAdBgNVHQ4EFgQUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXAYDVR0gBFUw
# UzBRBgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNy
# b3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBMGA1UdJQQMMAoG
# CCsGAQUFBwMIMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIB
# hjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFNX2VsuP6KJcYmjRPZSQW9fO
# mhjEMFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9w
# a2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNybDBaBggr
# BgEFBQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNv
# bS9wa2kvY2VydHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3J0MA0GCSqGSIb3
# DQEBCwUAA4ICAQCdVX38Kq3hLB9nATEkW+Geckv8qW/qXBS2Pk5HZHixBpOXPTEz
# tTnXwnE2P9pkbHzQdTltuw8x5MKP+2zRoZQYIu7pZmc6U03dmLq2HnjYNi6cqYJW
# AAOwBb6J6Gngugnue99qb74py27YP0h1AdkY3m2CDPVtI1TkeFN1JFe53Z/zjj3G
# 82jfZfakVqr3lbYoVSfQJL1AoL8ZthISEV09J+BAljis9/kpicO8F7BUhUKz/Aye
# ixmJ5/ALaoHCgRlCGVJ1ijbCHcNhcy4sa3tuPywJeBTpkbKpW99Jo3QMvOyRgNI9
# 5ko+ZjtPu4b6MhrZlvSP9pEB9s7GdP32THJvEKt1MMU0sHrYUP4KWN1APMdUbZ1j
# dEgssU5HLcEUBHG/ZPkkvnNtyo4JvbMBV0lUZNlz138eW0QBjloZkWsNn6Qo3GcZ
# KCS6OEuabvshVGtqRRFHqfG3rsjoiV5PndLQTHa1V1QJsWkBRH58oWFsc/4Ku+xB
# Zj1p/cvBQUl+fpO+y/g75LcVv7TOPqUxUYS8vwLBgqJ7Fx0ViY1w/ue10CgaiQuP
# Ntq6TPmb/wrpNPgkNWcr4A245oyZ1uEi6vAnQj0llOZ0dFtq0Z4+7X6gMTN9vMvp
# e784cETRkPHIqzqKOghif9lwY1NNje6CbaUFEMFxBmoQtB1VM1izoXBm8qGCA00w
# ggI1AgEBMIH5oYHRpIHOMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScw
# JQYDVQQLEx5uU2hpZWxkIFRTUyBFU046MzMwMy0wNUUwLUQ5NDcxJTAjBgNVBAMT
# HE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WiIwoBATAHBgUrDgMCGgMVAOJY
# 0F4Un2O9oSs3rgPUbzp4vSa7oIGDMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAg
# UENBIDIwMTAwDQYJKoZIhvcNAQELBQACBQDqAU8mMCIYDzIwMjQwNTI5MDY1MjIy
# WhgPMjAyNDA1MzAwNjUyMjJaMHQwOgYKKwYBBAGEWQoEATEsMCowCgIFAOoBTyYC
# AQAwBwIBAAICBk4wBwIBAAICE6gwCgIFAOoCoKYCAQAwNgYKKwYBBAGEWQoEAjEo
# MCYwDAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG
# 9w0BAQsFAAOCAQEAO7chV/VOV9AqUyZe0vCj7xjfjpChqb60GeCkY/M8FB3nKsRp
# kmUSC9Eq0G5Z2ofMYz1Yzu66o6stqRVhpQJKmhZnALho88GCtWoUAMfOyNClXruN
# 7UZdUUeyi4rleZIBOYgtxP8FI+hBJL0pt99WnBqnnV+2xJISSr2JYLZmcbqM4kBh
# uUHdUEAqXFA5b41l9hmNFpW5JN7aZGqqNezXCHzvm5h+OSKf5JIbfftzuLbc6L2/
# JWXVnnHLrHx2JNvhK2De0Et167Fsv2IRs6Z9g2N29fLmkJQYIrafZn4nGSZo4R8z
# A1Yp5oyj4vxuW01h77+H956yTm5ZXUA+W/zDCzGCBA0wggQJAgEBMIGTMHwxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jv
# c29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB5tlCnuoA+H3hAAEAAAHmMA0G
# CWCGSAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJ
# KoZIhvcNAQkEMSIEIAiEvrmNdWKB9GW8csSkRwSrjNTUpB0cKvjm0ayhNOsvMIH6
# BgsqhkiG9w0BCRACLzGB6jCB5zCB5DCBvQQgz7ujhqgeswlobyCcs7WrXqEhhxGe
# jLoWc4JudIPSxlkwgZgwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAx
# MAITMwAAAebZQp7qAPh94QABAAAB5jAiBCD/D1N/wXVR59kvJJ2Id/8bZa7mk7GD
# GYwoYn1w6WeY4DANBgkqhkiG9w0BAQsFAASCAgAZJf82rVie49TMYrEVxm5SR0c1
# YYEaYU6GbLnGKreHRSnGrQoqpZywoqI1Z+MLrlbSs2xhl8hp1Ey9HHsrX/AoEsPQ
# 0EyN4KAD/tImUFrZOZ0C3cVeesVkDwcmIcEgYnG5cUjakVVywGtRa3Au2Xn/LKU0
# ZRria1XmfsmtpC/qMVKZoY7gyJksb/uMHDDsftfqRFEfoErSrFz+vftYrMovUXno
# QdvYQHPpvwqT8eLeNASMoKJImbSireGnZud6ZhNgvr83n+sydc9MJuEvqshRmego
# P5ecoA2VWuEMyx9G55Yfl/cyp6o3AEUgH6oNCT1Iv2jedFAQBaQVz/ip/k55sXFs
# QNnv8H2lJOPhJtjf8cgnfpL+R8C0C2gBErwuBY5/gr4hwVRKvx25jI2LPLK0tvAT
# l4TdX4Cx6uYGyWTLTBZQsKk/J30kiD4v0h3DFZ0KWj/Xfz/wLc0hP4+X2Z/cL7F0
# HH/13Rxeyh33gEzR97Ehy4bVQ20dMaJLgA6lxVzEPSfZh+7WyXqQrjNNhxRjFYk2
# CGUzJsabzi59vuXwdP9UxBO4UMWbWdqHNp+RRC4V0SxxXfIVdXvJFkPUx1iQcJIb
# uCDxSBCo3qolGpJomAgmRj8ziTTjLqXFJ4QEIaq5mEvpkeEuqLWCyjmRPJYfSCjZ
# QtM66i/G5sb2njNHCw==
# SIG # End signature block

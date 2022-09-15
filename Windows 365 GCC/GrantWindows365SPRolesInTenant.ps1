
#---------------Login to your Azure government cloud tenant -----------------------------------------
try
{
    # If using Azure Cloud Powershell, comment out below command.
    Connect-AzAccount -Environment AzureUSGovernment -ErrorAction Stop
} 
catch [System.Management.Automation.CommandNotFoundException] 
{
    Write-Output "Please ensure az module installed first. You can run 'Install-Module -Name Az -Scope CurrentUser -AllowClobber  -Repository PSGallery -Force' to install the module"
    Write-Output "For more details, you can refer: https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-7.2.0#installation"
    return
}
catch
{
    Write-Output $PSItem.ToString()
    return
}

#--------------- Check if Windows 365 application has been provisioned into the Azure government cloud tenant, if not, consent it into the tenant.-----------------------
$Windows365AppId = "0af06dc6-e4b5-4f28-818e-e78e62d137a5"
$ServicePrincipal= Get-AzADServicePrincipal -ApplicationId $Windows365AppId -ErrorAction Stop
if([String]::IsNullOrEmpty($ServicePrincipal.Id))
{
    try
    {
        # Consent Windows 365 application into this Azure government cloud tenant.
        New-AzADServicePrincipal -ApplicationId $Windows365AppId -ErrorAction Stop
        $ServicePrincipal = Get-AzADServicePrincipal -ApplicationId $Windows365AppId -ErrorAction Stop
        Write-Output "`r`nConsent Windows 365 application into your tenant. Object Id: $($ServicePrincipal.Id)"
    }
    catch
    {
        Write-Output "Failed to consent Windows 365 application into your tenant,error: $PSItem"
        If($PSItem.ToString().contains("Insufficient privileges to complete the operation"))
        {
            Write-Output "Contact your Azure Active Directory admin to create a service principal for app id $Windows365AppId"
        }
    }
 }
 Write-Output "`r`nWindows 365 application has been provisioned into your Azure government cloud successfully. The Windows 365 service principal id:$($ServicePrincipal.Id)."


 #-------------- Select subscripion, resource group, virtual network, and add role assignments to Windows 365 service principal so that it can access your resources----------------
 # Define function to check if Role has been assigned to our service principal in the scope, if no, add the role.
function CheckAndAddRoleAssignmentToServicePrincipal() {
    param (
        [string] $RoleName,
        [string] $Scope,
        [string] $ServicePrincipalId
    )

    try
    {
       #Check RoleAssignment
       $azureRole = Get-AzRoleDefinition -Name $RoleName -ErrorAction Stop
       $restResponse = Invoke-AzRestMethod -Path "$Scope/providers/Microsoft.Authorization/roleAssignments?`$filter=atScope() and assignedTo('$ServicePrincipalId')&api-version=2020-03-01-preview" -Method GET -ErrorAction Stop
       $IsAssigned = $restResponse.Content.contains($azureRole.Id)
       if($IsAssigned -eq $true)
       {
            Write-Output "$RoleName has already been assigned to $Scope."
       }
       else
       {

           $result = New-AzRoleAssignment `
           -ObjectId $ServicePrincipalId `
            -RoleDefinitionName $RoleName `
            -Scope $Scope `
            -ErrorAction Stop
           Write-Output "$RoleName was assigned to $Scope successfully."
       }
    }
    catch
    {
        Write-Output $PSItem.ToString()
        If($PSItem.ToString().contains("Forbidden"))
        {
            Write-Output "Add role $RoleName to $Scope failed, please make sure the sign in user has owner or user access admin role in the subscription"
        }
    }
}

$optionNum = Read-Host -Prompt "`r`nSelect which scenario to proceed:: 
        1.	Enabling custom image upload
        2.	Enabling Azure Network Connections creation
        3.	Enabling both custom image upload and Azure Network Connections creation
Please enter  the number of your option"

while (($optionNum -ne 1) -and ($optionNum -ne 2) -and ($optionNum -ne 3)) 
{
    $optionNum = Read-Host -Prompt "The option is invalid, please try again" 
}

if ($optionNum -eq 1) 
{
    # List subscriptions
    Write-Output "`r`nSubscription list:" 
    Get-AzSubscription | select Name,SubscriptionId | ft -ErrorAction Stop
    # Select a subscription, and Windows 365 service principal will be granted "reader" role in this subscription
    $SubscriptionId= Read-Host -Prompt "Enter subscription Id you want to use, Windows 365 service principal will be granted 'reader' role in this subscription`
    Make sure the signed-in user has owner role in this subscription or windows 365 app already has reader role in this subscription.`
    Subscription Id"                                                                                                    
    Set-AzContext -Subscription $SubscriptionId -ErrorAction Stop

    # Check if role exists, if not exist, add the role to our service principal in the target scope
    CheckAndAddRoleAssignmentToServicePrincipal -RoleName "Reader" -Scope "/subscriptions/$SubscriptionId" -ServicePrincipalId $ServicePrincipal.Id

    #-------------- List subscription id ----------------
    Write-Output "`r`nSelected subscription Id:"
    $subscriptionId | Format-List
} 
else
{
    # List subscriptions
    Write-Output "`r`nSubscription list:" 
    Get-AzSubscription | select Name,SubscriptionId | ft -ErrorAction Stop
    # Select a subscription, and Windows 365 service principal will be granted "reader" role in this subscription
    $SubscriptionId= Read-Host -Prompt "Enter subscription Id you want to use, Windows 365 service principal will be granted 'reader' role in this subscription`
    Make sure the signed-in user has owner role in this subscription or windows 365 app already has reader role in this subscription.`
    Subscription Id"                                                                                                    
    Set-AzContext -Subscription $SubscriptionId -ErrorAction Stop

    # List resource groups under the subscription
    Write-Output "`r`nResource groups under this subscription:" 
    Get-AzResourcegroup | select ResourceGroupName | ft -ErrorAction Stop

    #Select a resource group, and Windows 365 service principal will be granted "network contributor" role in this resource group
    $rgName= Read-Host -Prompt "Enter resource group name you want to use, Windows 365 service principal will be granted 'network contributor' role in this resource group.`
    Make sure the signed in user has owner role in this resource group or subscription, or windows 365 app already has network contributor role in this resource group.`
    Resource group Name"
    $selectedRg= Get-AzResourcegroup -Name $rgName -ErrorAction Stop

    # List Vnets under the subscription and input the vnet's resource group and vnet name
    Write-Output "`r`nVirtual networks under this subscription:" 
    Get-AzResource -ResourceType Microsoft.Network/virtualNetworks|  select Name,resourceGroupName,Location | ft -ErrorAction Stop
    #Select a virtual network, and Windows 365 service principal will be granted "reader" role in this virtual network
    $vnetRgName= Read-Host -Prompt "Enter virtual network's resource group name you want to use"
    $selectedVnetName= Read-Host -Prompt "Enter virtual network's name you want to use, Windows 365 service principal will be granted 'network contributor' role in this virtual network.`
    Make sure the signed in user has owner role in this vnet or subscription, or windows 365 app already has network contributor role in this virtual network.`
    Virtual network name"
    $selectedVnet= Get-AzResource -ResourceId "/subscriptions/$SubscriptionId/resourceGroups/$vnetRgName/providers/Microsoft.Network/virtualNetworks/$selectedVnetName" -ErrorAction Stop

    # Check if role exists, if not exist, add the role to our service principal in the target scope
    CheckAndAddRoleAssignmentToServicePrincipal -RoleName "Reader" -Scope "/subscriptions/$SubscriptionId" -ServicePrincipalId $ServicePrincipal.Id
    CheckAndAddRoleAssignmentToServicePrincipal -RoleName "Network contributor" -Scope $selectedRg.ResourceId -ServicePrincipalId $ServicePrincipal.Id
    CheckAndAddRoleAssignmentToServicePrincipal -RoleName "Network contributor" -Scope $selectedVnet.ResourceId -ServicePrincipalId $ServicePrincipal.Id

    #-------------- List subscription id, resource group id, vnet id, subnet ids----------------
    Write-Output "`r`nSelected subscription Id:"
    $subscriptionId | Format-List
    Write-Output "`r`nSelected resource group Id: "
    $selectedRg |  select ResourceId | Format-List
    Write-Output "`r`nSelected virtual network Id:"
    $selectedVnet |  select ResourceId | Format-List
    Write-Output "`r`nSelected virtual network's subnet id list:"
    (Get-AzResource -ResourceId $selectedVnet.ResourceId ).Properties.subnets |  select id | Format-List
}
# SIG # Begin signature block
# MIIrZwYJKoZIhvcNAQcCoIIrWDCCK1QCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCBGhvlIBsvGsow
# WGvOzquES9CsuOHiMv5Ac+Cug5I9jaCCEXkwggiJMIIHcaADAgECAhM2AAABqdaQ
# MGZD2x+CAAIAAAGpMA0GCSqGSIb3DQEBCwUAMEExEzARBgoJkiaJk/IsZAEZFgNH
# QkwxEzARBgoJkiaJk/IsZAEZFgNBTUUxFTATBgNVBAMTDEFNRSBDUyBDQSAwMTAe
# Fw0yMjA2MTAxODI3MDRaFw0yMzA2MTAxODI3MDRaMCQxIjAgBgNVBAMTGU1pY3Jv
# c29mdCBBenVyZSBDb2RlIFNpZ24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
# AoIBAQC4u9Lcerpczo3llU92plBBtOjhYWj0CvpOrIulkipCk2hb1kbnx15rINdV
# XvAqCfQgCN7AzdV88a2JfyOM7PhW16VsJidtX3OuqpSu1OWpNsUHUv5RZA7YMuHE
# HxDJsvGLfwpqJjUMLoMvnEq4CcgZadU1LXrwWKFLEg+d4Yp8beckfUKBID+snvDu
# 2djyEeWk+kyJrqgpUBlK+iz398OkGZf5yu7exd8S/X2z7g4koug+UmI1HQ+Gypbm
# EKFOf62NU4G7xN3u1xv6N/1BCzXYc8G3Hecw2E2VhlCupckxTLrlEfbMBgB30321
# 2jpVFT/y9FjNg6tYdK6UNW0yfZyPAgMBAAGjggWVMIIFkTApBgkrBgEEAYI3FQoE
# HDAaMAwGCisGAQQBgjdbAQEwCgYIKwYBBQUHAwMwPQYJKwYBBAGCNxUHBDAwLgYm
# KwYBBAGCNxUIhpDjDYTVtHiE8Ys+hZvdFs6dEoFgg93NZoaUjDICAWQCAQwwggJ2
# BggrBgEFBQcBAQSCAmgwggJkMGIGCCsGAQUFBzAChlZodHRwOi8vY3JsLm1pY3Jv
# c29mdC5jb20vcGtpaW5mcmEvQ2VydHMvQlkyUEtJQ1NDQTAxLkFNRS5HQkxfQU1F
# JTIwQ1MlMjBDQSUyMDAxKDIpLmNydDBSBggrBgEFBQcwAoZGaHR0cDovL2NybDEu
# YW1lLmdibC9haWEvQlkyUEtJQ1NDQTAxLkFNRS5HQkxfQU1FJTIwQ1MlMjBDQSUy
# MDAxKDIpLmNydDBSBggrBgEFBQcwAoZGaHR0cDovL2NybDIuYW1lLmdibC9haWEv
# QlkyUEtJQ1NDQTAxLkFNRS5HQkxfQU1FJTIwQ1MlMjBDQSUyMDAxKDIpLmNydDBS
# BggrBgEFBQcwAoZGaHR0cDovL2NybDMuYW1lLmdibC9haWEvQlkyUEtJQ1NDQTAx
# LkFNRS5HQkxfQU1FJTIwQ1MlMjBDQSUyMDAxKDIpLmNydDBSBggrBgEFBQcwAoZG
# aHR0cDovL2NybDQuYW1lLmdibC9haWEvQlkyUEtJQ1NDQTAxLkFNRS5HQkxfQU1F
# JTIwQ1MlMjBDQSUyMDAxKDIpLmNydDCBrQYIKwYBBQUHMAKGgaBsZGFwOi8vL0NO
# PUFNRSUyMENTJTIwQ0ElMjAwMSxDTj1BSUEsQ049UHVibGljJTIwS2V5JTIwU2Vy
# dmljZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlvbixEQz1BTUUsREM9R0JM
# P2NBQ2VydGlmaWNhdGU/YmFzZT9vYmplY3RDbGFzcz1jZXJ0aWZpY2F0aW9uQXV0
# aG9yaXR5MB0GA1UdDgQWBBSPmAlYWIPObTrIuddZ/ZX08zr7VzAOBgNVHQ8BAf8E
# BAMCB4AwUAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRp
# b25zIFB1ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzYxNjcrNDcwODYxMIIB5gYDVR0f
# BIIB3TCCAdkwggHVoIIB0aCCAc2GP2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9w
# a2lpbmZyYS9DUkwvQU1FJTIwQ1MlMjBDQSUyMDAxKDIpLmNybIYxaHR0cDovL2Ny
# bDEuYW1lLmdibC9jcmwvQU1FJTIwQ1MlMjBDQSUyMDAxKDIpLmNybIYxaHR0cDov
# L2NybDIuYW1lLmdibC9jcmwvQU1FJTIwQ1MlMjBDQSUyMDAxKDIpLmNybIYxaHR0
# cDovL2NybDMuYW1lLmdibC9jcmwvQU1FJTIwQ1MlMjBDQSUyMDAxKDIpLmNybIYx
# aHR0cDovL2NybDQuYW1lLmdibC9jcmwvQU1FJTIwQ1MlMjBDQSUyMDAxKDIpLmNy
# bIaBvWxkYXA6Ly8vQ049QU1FJTIwQ1MlMjBDQSUyMDAxKDIpLENOPUJZMlBLSUNT
# Q0EwMSxDTj1DRFAsQ049UHVibGljJTIwS2V5JTIwU2VydmljZXMsQ049U2Vydmlj
# ZXMsQ049Q29uZmlndXJhdGlvbixEQz1BTUUsREM9R0JMP2NlcnRpZmljYXRlUmV2
# b2NhdGlvbkxpc3Q/YmFzZT9vYmplY3RDbGFzcz1jUkxEaXN0cmlidXRpb25Qb2lu
# dDAfBgNVHSMEGDAWgBSWUYTga297/tgGq8PyheYprmr51DAfBgNVHSUEGDAWBgor
# BgEEAYI3WwEBBggrBgEFBQcDAzANBgkqhkiG9w0BAQsFAAOCAQEAcPU4lsVn+0hr
# lmkPN5T6apYc50XaG0BkqJxF81iFpqOPJhG8JNQqf/lJkZQop1WazGIW0I6naUnb
# 4Ldvsgm6SSoL1KakiRAuEG7Pu4rg2xcHpefci/fZi4p4fiyp1GokwJ7OGxqV79KH
# p95yxVakmey99fF1cELKhVsBkJkJA3d05dTPgO0R9XZ/GFHNN9JSEqyvVVJj0cL+
# bJ52JKq+p3fN+Ar2PohHQNwvdaQqJXQH92djCe2ee2uEXEZhC489cEDvFfXRIH/w
# JUDxXU2i86S0Y7lyC+ZUx7mkDab0zuw4GAWSNeA8PuLg+gvlfSYr7pudyGIRmPUL
# mXVfovMkfjCCCOgwggbQoAMCAQICEx8AAABR6o/2nHMMqDsAAAAAAFEwDQYJKoZI
# hvcNAQELBQAwPDETMBEGCgmSJomT8ixkARkWA0dCTDETMBEGCgmSJomT8ixkARkW
# A0FNRTEQMA4GA1UEAxMHYW1lcm9vdDAeFw0yMTA1MjExODQ0MTRaFw0yNjA1MjEx
# ODU0MTRaMEExEzARBgoJkiaJk/IsZAEZFgNHQkwxEzARBgoJkiaJk/IsZAEZFgNB
# TUUxFTATBgNVBAMTDEFNRSBDUyBDQSAwMTCCASIwDQYJKoZIhvcNAQEBBQADggEP
# ADCCAQoCggEBAMmaUgl9AZ6NVtcqlzIU+gVJSWVqWuKd8RXokxzuL5tkOgv2s0ec
# cMZ8mB65Ehg7Utj/V/igxOuFdtJphEJLm8ZzzXjlZxNkb3TxsYMJavgYUtzjXVbE
# D4+/au14BzPR4cwffqpNDwvSjdc5vaf7HsokUuiRdXWzqkX9aVJexQFcZoIghYFf
# IRyG/6wz14oOxQ4t0tMhMdglA1aSKvIxIRvGp1BRNVmMTPp4tEuSh8MCjyleKshg
# 6AzvvQJg6JmtwocruVg5VuXHbal01rBjxN7prZ1+gJpZXVBS5rODlUeILin/p+Sy
# AQgum04qHH1z6JqmI2EysewBjH2lS2ml5oUCAwEAAaOCBNwwggTYMBIGCSsGAQQB
# gjcVAQQFAgMCAAIwIwYJKwYBBAGCNxUCBBYEFBJoJEIhR8vUa74xzyCkwAsjfz9H
# MB0GA1UdDgQWBBSWUYTga297/tgGq8PyheYprmr51DCCAQQGA1UdJQSB/DCB+QYH
# KwYBBQIDBQYIKwYBBQUHAwEGCCsGAQUFBwMCBgorBgEEAYI3FAIBBgkrBgEEAYI3
# FQYGCisGAQQBgjcKAwwGCSsGAQQBgjcVBgYIKwYBBQUHAwkGCCsGAQUFCAICBgor
# BgEEAYI3QAEBBgsrBgEEAYI3CgMEAQYKKwYBBAGCNwoDBAYJKwYBBAGCNxUFBgor
# BgEEAYI3FAICBgorBgEEAYI3FAIDBggrBgEFBQcDAwYKKwYBBAGCN1sBAQYKKwYB
# BAGCN1sCAQYKKwYBBAGCN1sDAQYKKwYBBAGCN1sFAQYKKwYBBAGCN1sEAQYKKwYB
# BAGCN1sEAjAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYw
# EgYDVR0TAQH/BAgwBgEB/wIBADAfBgNVHSMEGDAWgBQpXlFeZK40ueusnA2njHUB
# 0QkLKDCCAWgGA1UdHwSCAV8wggFbMIIBV6CCAVOgggFPhjFodHRwOi8vY3JsLm1p
# Y3Jvc29mdC5jb20vcGtpaW5mcmEvY3JsL2FtZXJvb3QuY3JshiNodHRwOi8vY3Js
# Mi5hbWUuZ2JsL2NybC9hbWVyb290LmNybIYjaHR0cDovL2NybDMuYW1lLmdibC9j
# cmwvYW1lcm9vdC5jcmyGI2h0dHA6Ly9jcmwxLmFtZS5nYmwvY3JsL2FtZXJvb3Qu
# Y3JshoGqbGRhcDovLy9DTj1hbWVyb290LENOPUFNRVJvb3QsQ049Q0RQLENOPVB1
# YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRp
# b24sREM9QU1FLERDPUdCTD9jZXJ0aWZpY2F0ZVJldm9jYXRpb25MaXN0P2Jhc2U/
# b2JqZWN0Q2xhc3M9Y1JMRGlzdHJpYnV0aW9uUG9pbnQwggGrBggrBgEFBQcBAQSC
# AZ0wggGZMEcGCCsGAQUFBzAChjtodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtp
# aW5mcmEvY2VydHMvQU1FUm9vdF9hbWVyb290LmNydDA3BggrBgEFBQcwAoYraHR0
# cDovL2NybDIuYW1lLmdibC9haWEvQU1FUm9vdF9hbWVyb290LmNydDA3BggrBgEF
# BQcwAoYraHR0cDovL2NybDMuYW1lLmdibC9haWEvQU1FUm9vdF9hbWVyb290LmNy
# dDA3BggrBgEFBQcwAoYraHR0cDovL2NybDEuYW1lLmdibC9haWEvQU1FUm9vdF9h
# bWVyb290LmNydDCBogYIKwYBBQUHMAKGgZVsZGFwOi8vL0NOPWFtZXJvb3QsQ049
# QUlBLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNv
# bmZpZ3VyYXRpb24sREM9QU1FLERDPUdCTD9jQUNlcnRpZmljYXRlP2Jhc2U/b2Jq
# ZWN0Q2xhc3M9Y2VydGlmaWNhdGlvbkF1dGhvcml0eTANBgkqhkiG9w0BAQsFAAOC
# AgEAUBAjt08P6N9e0a3e8mnanLMD8dS7yGMppGkzeinJrkbehymtF3u91MdvwEN9
# E34APRgSZ4MHkcpCgbrEc8jlNe4iLmyb8t4ANtXcLarQdA7KBL9VP6bVbtr/vnaE
# wif4vhm7LFV5IGl/B/uhDhhJk+Hr6eBm8EeB8FpXPg73/Bx/D3VANmdOAr3MCH3J
# EoqWzZvOI8SfF45kxU1rHJXS/XnY9jbGOohp8iRSMrq9j0u1UWMld6dVQCafdYI9
# Y0ULVhMggfD+YPZxN8/LtADWlP4Y8BEAq3Rsq2r1oJ39ibRvm09umAKJG3PJvt9s
# 1LV0TvjSt7QI4TrthXbBt6jaxeLHO8t+0fwvuz3G/3BX4bbarIq3qWYouMUrXIzD
# g2Ll8xptyCbNG9KMBxuqCne2Thrx6ZpofSvPwy64g/7KvG1EQ9dKov8LlvMzOyKS
# 4Nb3EfXSCtpnNKY+OKXOlF9F27bT/1RCYLt5U9niPVY1rWio8d/MRPcKEjMnpD0b
# c08IH7srBfQ5CYrK/sgOKaPxT8aWwcPXP4QX99gx/xhcbXktqZo4CiGzD/LA7pJh
# Kt5Vb7ljSbMm62cEL0Kb2jOPX7/iSqSyuWFmBH8JLGEUfcFPB4fyA/YUQhJG1KEN
# lu5jKbKdjW6f5HJ+Ir36JVMt0PWH9LHLEOlky2KZvgKAlCUxghlEMIIZQAIBATBY
# MEExEzARBgoJkiaJk/IsZAEZFgNHQkwxEzARBgoJkiaJk/IsZAEZFgNBTUUxFTAT
# BgNVBAMTDEFNRSBDUyBDQSAwMQITNgAAAanWkDBmQ9sfggACAAABqTANBglghkgB
# ZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3
# AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgysiXLNYslG/bncLr
# Knn8G0JbetIR8Kk5lO0Dl/SsoC8wQgYKKwYBBAGCNwIBDDE0MDKgFIASAE0AaQBj
# AHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTANBgkqhkiG
# 9w0BAQEFAASCAQCHNSsml0b9C6vpguDFi5T2PDZTknbq6g98FzmV6LdYn6yDYQSY
# uq6f61fnRBJ+v0nv1oWWbCay2S3oNpJUBajYzHl+bC1DcQcdrmffwWMzExJE/aSb
# 5PzwiZ6/mxBgxlodZ+ZAF4BfzuXxyF4LoRZZ0kM7nybV2MRZ7vO6BElUWiVarOSe
# AXOrEQWNt3bEv9lrQIcxOPX9RgKI5XkEDZihy1VFGadJ7QzndroJOwebun+mdHRb
# hjAy+l2XqZIy02pwHWk5CReHANMfIILV6G0xDViI0MoypjzBTHnGlwWrsP8OdplR
# +ji1/GI7rQzbKluoe6ZEe8R2zw3RLNSwbrevoYIXDDCCFwgGCisGAQQBgjcDAwEx
# ghb4MIIW9AYJKoZIhvcNAQcCoIIW5TCCFuECAQMxDzANBglghkgBZQMEAgEFADCC
# AVUGCyqGSIb3DQEJEAEEoIIBRASCAUAwggE8AgEBBgorBgEEAYRZCgMBMDEwDQYJ
# YIZIAWUDBAIBBQAEIEoABFcW885/JAhddaFuamnjcQQk7J/UOAxQh2S+4H/OAgZj
# EVisUugYEzIwMjIwOTE1MDYwMDIyLjYzOFowBIACAfSggdSkgdEwgc4xCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1pY3Jvc29m
# dCBPcGVyYXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVT
# TjozMkJELUUzRDUtM0IxRDElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAg
# U2VydmljZaCCEV8wggcQMIIE+KADAgECAhMzAAABrfzfTVjjXTLpAAEAAAGtMA0G
# CSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4XDTIy
# MDMwMjE4NTEzNloXDTIzMDUxMTE4NTEzNlowgc4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25z
# IFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjozMkJELUUzRDUt
# M0IxRDElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCCAiIw
# DQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOieUyqlTSrVLhvY7TO8vgC+T5N/
# y/MXeR3oNwE0rLI1Eg/gM5g9NhP+KqqJc/7uPL4TsoALb+RVf6roYNllyQrYmquU
# jwsq262MD5L9l9rU1plz2tMPehP8addVlNIjYIBh0NC4CyME6txVppQr7eFd/bW0
# X9tnZy1aDW+zoaJB2FY8haokq5cRONEW4uoVsTTXsICkbYOAYffIIGakMFXVvB30
# NcsuiDn6uDk83XXTs0tnSr8FxzPoD8SgPPIcWaWPEjCQLr5I0BxfdUliwNPHIPEg
# lqosrClRjXG7rcZWbWeODgATi0i6DUsv1Wn0LOW4svK4/Wuc/v9dlmuIramv9whb
# gCykUuYZy8MxTzsQqU2Rxcm8h89CXA5jf1k7k3ZiaLUJ003MjtTtNXzlgb+k1A5e
# L17G3C4Ejw5AoViM+UBGQvxuTxpFeaGoQFqeOGGtEK0qk0wdUX9p/4Au9Xsle5D5
# fvypBdscXBslUBcT6+CYq0kQ9smsTyhV4DK9wb9Zn7ObEOfT0AQyppI6jwzBjHhA
# GFyrKYjIbglMaEixjRv7XdNic2VuYKyS71A0hs6dbbDx/V7hDbdv2srtZ2VTO0y2
# E+4QqMRKtABv4AggjYKz5TYGuQ4VbbPY8fBO9Xqva3Gnx1ZDOQ3nGVFKHwarGDcN
# dB3qesvtJbIGJgJjAgMBAAGjggE2MIIBMjAdBgNVHQ4EFgQUfVB0HQS8qiFabmqE
# qOV9LrLGwVkwHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXwYDVR0f
# BFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwv
# TWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3JsMGwGCCsG
# AQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAx
# MCgxKS5jcnQwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcDCDANBgkq
# hkiG9w0BAQsFAAOCAgEAi9AdRbsx/gOSdBXndwRejQuutQqce3k3bgs1slPjZSx6
# FDXp1IZzjOyT1Jo/3eUWDBFJdi+Heu1NoyDdGn9vL6rxly1L68K4MnfLBm+ybyjN
# +xa1eNa4+4cOoOuxE2Kt8jtmZbIhx2jvY7F9qY/lanR5PSbUKyClhNQhxsnNUp/J
# SQ+o7nAuQJ+wsCwPCrXYE7C+TvKDja6e6WU0K4RiBXFGU1z6Mt3K9wlMD/QGU4+/
# IGZDmE+/Z/k0JfJjZyxCAlcmhe3rgdhDzAsGxJYq4PblGZTBdr8wkQwpP2jggyMM
# awMM5DggwvXaDbrqCQ8gksNhCZzTqfS2dbgLF0m7HfwlUMrcnzi/bdTSRWzIXg5Q
# sH1t5XaaIH+TZ1uZBtwXJ8EOXr6S+2A6q8RQVY10KnBH6YpGE9OhXPfuIu882muF
# Edh4EXbPdARUR1IMSIxg88khSBC/YBwQhCpjTksq5J3Z+jyHWZ4MnXX5R42mAR58
# 4iRYc7agYvuotDEqcD0U9lIjgW31PqfqZQ1tuYZTiGcKE9QcYGvZFKnVdkqK8V0M
# 9e+kF5CqDOrMMYRV2+I/FhyQsJHxK/G53D0O5bvdIh2gDnEHRAFihdZj29Z7W0pa
# GPotGX0oB5r9wqNjM3rbvuEe6FJ323MPY1x9/N1g126T/SokqADJBTKqyBYN4zMw
# ggdxMIIFWaADAgECAhMzAAAAFcXna54Cm0mZAAAAAAAVMA0GCSqGSIb3DQEBCwUA
# MIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQD
# EylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAxMDAeFw0y
# MTA5MzAxODIyMjVaFw0zMDA5MzAxODMyMjVaMHwxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFBDQSAyMDEwMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA5OGmTOe0
# ciELeaLL1yR5vQ7VgtP97pwHB9KpbE51yMo1V/YBf2xK4OK9uT4XYDP/XE/HZveV
# U3Fa4n5KWv64NmeFRiMMtY0Tz3cywBAY6GB9alKDRLemjkZrBxTzxXb1hlDcwUTI
# cVxRMTegCjhuje3XD9gmU3w5YQJ6xKr9cmmvHaus9ja+NSZk2pg7uhp7M62AW36M
# EBydUv626GIl3GoPz130/o5Tz9bshVZN7928jaTjkY+yOSxRnOlwaQ3KNi1wjjHI
# NSi947SHJMPgyY9+tVSP3PoFVZhtaDuaRr3tpK56KTesy+uDRedGbsoy1cCGMFxP
# LOJiss254o2I5JasAUq7vnGpF1tnYN74kpEeHT39IM9zfUGaRnXNxF803RKJ1v2l
# IH1+/NmeRd+2ci/bfV+AutuqfjbsNkz2K26oElHovwUDo9Fzpk03dJQcNIIP8BDy
# t0cY7afomXw/TNuvXsLz1dhzPUNOwTM5TI4CvEJoLhDqhFFG4tG9ahhaYQFzymei
# XtcodgLiMxhy16cg8ML6EgrXY28MyTZki1ugpoMhXV8wdJGUlNi5UPkLiWHzNgY1
# GIRH29wb0f2y1BzFa/ZcUlFdEtsluq9QBXpsxREdcu+N+VLEhReTwDwV2xo3xwgV
# GD94q0W29R6HXtqPnhZyacaue7e3PmriLq0CAwEAAaOCAd0wggHZMBIGCSsGAQQB
# gjcVAQQFAgMBAAEwIwYJKwYBBAGCNxUCBBYEFCqnUv5kxJq+gpE8RjUpzxD/LwTu
# MB0GA1UdDgQWBBSfpxVdAF5iXYP05dJlpxtTNRnpcjBcBgNVHSAEVTBTMFEGDCsG
# AQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0wEwYDVR0lBAwwCgYIKwYBBQUH
# AwgwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1Ud
# EwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186aGMQwVgYD
# VR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwv
# cHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsGAQUFBwEB
# BE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9j
# ZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcnQwDQYJKoZIhvcNAQELBQAD
# ggIBAJ1VffwqreEsH2cBMSRb4Z5yS/ypb+pcFLY+TkdkeLEGk5c9MTO1OdfCcTY/
# 2mRsfNB1OW27DzHkwo/7bNGhlBgi7ulmZzpTTd2YurYeeNg2LpypglYAA7AFvono
# aeC6Ce5732pvvinLbtg/SHUB2RjebYIM9W0jVOR4U3UkV7ndn/OOPcbzaN9l9qRW
# qveVtihVJ9AkvUCgvxm2EhIRXT0n4ECWOKz3+SmJw7wXsFSFQrP8DJ6LGYnn8Atq
# gcKBGUIZUnWKNsIdw2FzLixre24/LAl4FOmRsqlb30mjdAy87JGA0j3mSj5mO0+7
# hvoyGtmW9I/2kQH2zsZ0/fZMcm8Qq3UwxTSwethQ/gpY3UA8x1RtnWN0SCyxTkct
# wRQEcb9k+SS+c23Kjgm9swFXSVRk2XPXfx5bRAGOWhmRaw2fpCjcZxkoJLo4S5pu
# +yFUa2pFEUep8beuyOiJXk+d0tBMdrVXVAmxaQFEfnyhYWxz/gq77EFmPWn9y8FB
# SX5+k77L+DvktxW/tM4+pTFRhLy/AsGConsXHRWJjXD+57XQKBqJC4822rpM+Zv/
# Cuk0+CQ1ZyvgDbjmjJnW4SLq8CdCPSWU5nR0W2rRnj7tfqAxM328y+l7vzhwRNGQ
# 8cirOoo6CGJ/2XBjU02N7oJtpQUQwXEGahC0HVUzWLOhcGbyoYIC0jCCAjsCAQEw
# gfyhgdSkgdEwgc4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# KTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYD
# VQQLEx1UaGFsZXMgVFNTIEVTTjozMkJELUUzRDUtM0IxRDElMCMGA1UEAxMcTWlj
# cm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcGBSsOAwIaAxUAQJLRrUVR
# 4ZbBDgWPjuNqVctUzpCggYMwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0Eg
# MjAxMDANBgkqhkiG9w0BAQUFAAIFAObM+gMwIhgPMjAyMjA5MTUwNTEwMjdaGA8y
# MDIyMDkxNjA1MTAyN1owdzA9BgorBgEEAYRZCgQBMS8wLTAKAgUA5sz6AwIBADAK
# AgEAAgIk1wIB/zAHAgEAAgITUDAKAgUA5s5LgwIBADA2BgorBgEEAYRZCgQCMSgw
# JjAMBgorBgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3
# DQEBBQUAA4GBADbk9jcI6MRj8bNjMBb2B119qRh/F4IOF2FhgSUWQB3ul2opbFSl
# l2z8HG8KWvn8cW8w+G4bMnxYl53NNy5gi2ur3zkCl5Ek5T2suyhCopFvNx4pwnRD
# e8+c0/DZhbP6FObL8i4CreAVJIhBn2w2lhzaf9fk3TbRjnB5eeevXaO4MYIEDTCC
# BAkCAQEwgZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEm
# MCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAGt/N9N
# WONdMukAAQAAAa0wDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsq
# hkiG9w0BCRABBDAvBgkqhkiG9w0BCQQxIgQgVRvasSgOUCK1m2wsaj+gcTplG/Xh
# rHDmNmKa9a1MHR0wgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHkMIG9BCCf6nw9CR5e
# 1+Ottcn1w992Kmn8YMTY/DWPIHeMbMtQgjCBmDCBgKR+MHwxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFBDQSAyMDEwAhMzAAABrfzfTVjjXTLpAAEAAAGtMCIEILaN0PxBkav3
# bU7CUtuscVYxoCkbeXQ974K5B5qpEMKSMA0GCSqGSIb3DQEBCwUABIICANJXpAst
# ei1mMmiLULvOw/TMLFmCXeF6DMmPm+2C4AX+t9okR9mFq2XkjcgdD7Khic9fBUE2
# WtsxUeULDhhyAjCsUO16mSo+nIXhpji/Vf0lXWCqOjG1o52ryWrfTkoO+Tk1YXC8
# VX77HeyTj4NljiZcKMkOIN9HhLgmu0nhpjWE4uUUfjNumKVCh4MmOVmZgmwgJOTr
# QaXfNyQ8Q7ZUJL/oI+hSx9XKygoCUSo54Bi/skGqRu98/RN36ZJkOHbu0EWCfjzT
# dECSlYzVxSF4A4MN8wHbPLHCIa+DXS6QcuoxHdsIyD/CpaaBayqSY2ryFicgl75H
# Ws1+wh5Yx+9bSYJXRnJannuWvvtbwS7CjOgWr0jq1GRAsbfzYjosHW4zuUwSorVU
# kdnvVvcSu6c+MBm4H8Eh6KRFSSfA1+v7nn5l1i4jGLYZotVk/+mE/PFqR5t573of
# qB5UwcaT/KRiDnr7ie9nyrPLZaHcPheyOnvTEGLUYvQOj7UjhQn3EVnJZF4HRsS6
# DvFKnZS+nljDWpwlLIS2QJQh63He+owMgexEbPN3/8bg4uQR5/Emlqe4afOwx5I0
# 7mBsn8oatXz5cG3z4+K4tWhpkpE1T9hjuNd9kQYQH8gstQ+az4jxjcw5CyknHiNO
# pRTjStByPhTmiE6NIe3AAtG4+9bIjNoEQHfm
# SIG # End signature block

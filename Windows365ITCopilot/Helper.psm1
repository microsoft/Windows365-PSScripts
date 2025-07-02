<#
    .COPYRIGHT
    Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
    See LICENSE in the project root for license information.
#>

$Separator = "--------------------------------------------------------------------------------------------------------------------------------"
$script:ExternalBasedUrl = "https://graph.microsoft.com/beta"
$script:CloudPCBasedUrl = ""
$script:TenantId = ""

#####################################################################################################
# Setup-GraphConfig
#####################################################################################################

<#
    .SYNOPSIS
        Setup-GraphConfig
    .DESCRIPTION
        Setup graph configuration, import the graph module, get the required permission
    .PARAMETER GraphScopes
        The required permission scopes for the Microsoft Graph API
#>
function Setup-GraphConfig {
    param (
        [Parameter(Mandatory = $True)]
        [string[]] $GraphScopes
    )

    #Commands to load MS.Graph modules
    if (invoke-graphmodule -eq 1) {
        throw "Failed to load Microsoft.Graph module. Exiting..."
    }

    #Command to connect to MS.Graph PowerShell app
    if ((connect-msgraph -Scopes $GraphScopes) -eq 1) {
        throw "Failed to connect to Microsoft Graph. Exiting..."
    }
}

#####################################################################################################
# Invoke-GraphModule
#####################################################################################################

<#
    .SYNOPSIS
        Invoke-GraphModule
    .DESCRIPTION
        Import the graph module, if the graph is not installed, then install the latest the graph module
        
#>
function Invoke-GraphModule {
    Write-Host $Separator

    $graphavailable = (find-module -name Microsoft.Graph)
    $vertemp = $graphavailable.version.ToString()
    Write-host "Latest version of Microsoft.Graph module is $vertemp" | out-host
    $graphcurrent = (get-installedmodule -name Microsoft.Graph -ErrorAction SilentlyContinue) 

    if ($graphcurrent -eq $null) {
        write-host "Microsoft.Graph module is not installed. Installing..." | out-host
        try {
            Install-Module -Name Microsoft.Graph -Force -ErrorAction Stop
        }
        catch {
            write-host $_.Exception.Message | out-host
            Return 1
        }
    }
    $graphcurrent = (get-installedmodule -name Microsoft.Graph)
    $vertemp = $graphcurrent.Version.ToString() 
    write-host "Current installed version of Microsoft.Graph module is $vertemp" | out-host

    if ($graphavailable.Version -gt $graphcurrent.Version) { 
        write-host "There is an update to this module available." 
    }
    else { 
        write-host "The installed Microsoft.Graph module is up to date." | out-host 
    }
}

#####################################################################################################
# Connect-Msgraph
#####################################################################################################

<#
    .SYNOPSIS
        Connect-Msgraph
    .DESCRIPTION
        Get the required permission
    .PARAMETER Scopes
        The required permission scopes for the Microsoft Graph API
#>
function Connect-Msgraph {
    param (
        [Parameter(Mandatory = $True)]
        [string[]] $Scopes
    )

    Write-Host $Separator

    $tenant = get-mgcontext
    if ($tenant.TenantId -eq $null) {
        write-host "Not connected to MS Graph. Connecting..." | out-host
        try {
            Connect-MgGraph -Scopes $Scopes -TenantId $script:TenantId -ErrorAction Stop | Out-Null
        }
        catch {
            write-host $_.Exception.Message | out-host
            Return 1
        }   
    }
    $tenant = get-mgcontext
    $text = "Tenant ID is " + $tenant.TenantId
    Write-host "Connected to Microsoft Graph" | out-host
    Write-host $text | out-host
}

#####################################################################################################
# Setup-EnvironmentConfig
#####################################################################################################

<#
    .SYNOPSIS
        Setup-EnvironmentConfig
    .DESCRIPTION
        Setup CloudPCBasedUrl and TenantId
    .PARAMETER CloudPC
        The CloudPC Graph API Based Url
    .PARAMETER TenantId
        The TenantId of this account
#>
function Setup-EnvironmentConfig {
    param (
        [Parameter(Mandatory = $True)]
        [string] $CloudPCBasedUrl,
        [string] $TenantId
    )

    Write-Host $Separator

    $script:CloudPCBasedUrl = $CloudPCBasedUrl
    Write-Host "Setup CloudPCBasedUr: $CloudPCBasedUrl"

    $script:TenantId = $TenantId
    Write-Host "Setup TenantId: $TenantId"
}

#####################################################################################################
# Remove-CloudPCLicense
#####################################################################################################

<#
    .SYNOPSIS
        Remove-CloudPCLicense
    .DESCRIPTION
        Remove the license from the Cloud PC owner if it is directly assigned, or remove the owner from the group that provides the group-based license.
    .PARAMETER CloudPC
        The reclaimed CloudPC
#>
function Remove-CloudPCLicense{
    param (
        [Parameter(Mandatory = $True)]
        [PSCustomObject] $CloudPC
    )

    Write-Host $Separator

    $deviceName = $CloudPC.ManagedDeviceName
    $skuId = $CloudPC.CurrentSkuId
    $userId = $CloudPC.UserId
    $userPrincipalName = $CloudPC.UserPrincipalName
    $groupId = $CloudPC.LicenseAssignedGroupId
    $groupName = $CloudPC.LicenseAssignedGroupName

    if (-not $groupId){
        # Reclaim direct assigned license
        $unAssignLicenseUrl = $script:ExternalBasedUrl + "/users/${userId}/assignLicense"
        $body = @{
            addLicenses = @()
            removeLicenses = @($skuId)
        } | ConvertTo-Json

        $response = Invoke-MgGraphRequest -Method POST -Uri $unAssignLicenseUrl -Body $body

        Write-Host "✅ Successfully remove the license from the user $userPrincipalName"
    } else{
        # Reclaim group based license
        $removeUserUrl = $script:ExternalBasedUrl + "/groups/${groupId}/members/${userId}/`$ref"

        Invoke-MgGraphRequest -Method DELETE -Uri $removeUserUrl -OutputType PSObject   
        
        Write-Host "✅ Successfully remove the user $userPrincipalName from the source group $groupName"
    }
}

#####################################################################################################
# Deprovision-GracePeriodCloudPC
#####################################################################################################

<#
    .SYNOPSIS
        Deprovision-GracePeriodCloudPC
    .DESCRIPTION
        End the grace period status if the CloudPC is under inGracePeriod status
    .PARAMETER DeviceName
        The name of the Cloud PC
#>
function Deprovision-GracePeriodCloudPC {
    param (
        [Parameter(Mandatory = $True)]
        [string] $DeviceName
    )
    Write-Host $Separator

    $cloudPCStatusUrl = $script:CloudPCBasedUrl + "/deviceManagement/virtualEndpoint/cloudPCs?`$filter=(contains(tolower(managedDeviceName),'$DeviceName')) and servicePlanType eq 'enterprise'&`$top=200&`$count=true&`$select=id,displayName,status,managedDeviceName,userPrincipalName,servicePlanId"
    $response = Invoke-MgGraphRequest -Method GET $cloudPCStatusUrl -OutputType PSObject
    $status = $response.value[0].status
    $cloudPCId = $response.value[0].id

    if ($status -eq "inGracePeriod") {
        $deprovisionCloudPCUrl = $script:CloudPCBasedUrl + "/deviceManagement/virtualEndpoint/cloudPCs/${cloudPCId}/endGracePeriod"
        Invoke-MgGraphRequest -Method POST $deprovisionCloudPCUrl -OutputType PSObject
        Write-Output "✅ Successfully deprovisioned device: $DeviceName"
    } else {
        Write-Output "❌ Device $DeviceName is not in grace period"
    }
}

#####################################################################################################
# Check-CloudPCByStatus
#####################################################################################################

<#
    .SYNOPSIS
        Check-CloudPCByStatus
    .DESCRIPTION
        Check-CloudPCByStatus
    .PARAMETER DeviceName
        The name of the Cloud PC
    .PARAMETER Status
        The status of the Cloud PC
#>
function Check-CloudPCByStatus {
    param (
        [Parameter(Mandatory = $True)]
        [string] $DeviceName,
        [string] $Status
    )

    $cloudPCStatusUrl = $script:CloudPCBasedUrl + "/deviceManagement/virtualEndpoint/cloudPCs?`$filter=(contains(tolower(managedDeviceName),'$DeviceName')) and servicePlanType eq 'enterprise'&`$top=200&`$count=true&`$select=id,displayName,status,managedDeviceName,userPrincipalName,servicePlanId"
    $response = Invoke-MgGraphRequest -Method GET $cloudPCStatusUrl -OutputType PSObject
    $actualStatus = $response.value[0].status

    if ($actualStatus -ne $Status){
        return 1
    }
}

#####################################################################################################
# Start-BulkResize
#####################################################################################################

<#
    .SYNOPSIS
        Start-BulkResize
    .DESCRIPTION
        Trigger the Cloud PC bulk resize API    
    .PARAMETER CloudPCIds
        The name of the CloudPC Ids
    .PARAMETER TargetServicePlanId
        The name of the target service PlanId
#>
function Start-BulkResize{
    param (
        [Parameter(Mandatory = $True)]
        [string[]] $CloudPCIds,
        [string] $TargetServicePlanId
    )
    Write-Host $Separator

    $bulkResizeUrl = $script:CloudPCBasedUrl + "/deviceManagement/virtualEndpoint/bulkActions"
    $bulkActionName = "BulkResize_" + [guid]::NewGuid() + "_" + (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    $body = @{
        "@odata.type" = "#microsoft.graph.CloudPcBulkResize"
        cloudPcIds = @($CloudPCIds)
        displayName = $bulkActionName
        scheduledDuringMaintenanceWindow = $true
        targetServicePlanId = $TargetServicePlanId
    } | ConvertTo-Json

    $response = Invoke-MgGraphRequest -Method POST -Uri $bulkResizeUrl -Body $body

    Write-Host "Successfully triggered resize flow, the bulk action batch name is: $bulkActionName"
}

#####################################################################################################
# Validate-CloudPCStatus
#####################################################################################################

<#
    .SYNOPSIS
        Validate-CloudPCStatus
    .DESCRIPTION
        Validate if the CloudPC is able to be resized to the target servicePlan
    .PARAMETER CloudPCIds
        The id list of the Cloud PC
    .PARAMETER TargetServicePlanId
        The target ServicePlanId of the Cloud PC        
#>
function Validate-CloudPCStatus{
    param (
        [Parameter(Mandatory = $True)]
        [string[]] $CloudPCIds,
        [string] $TargetServicePlanId
    )
    Write-Host $Separator

    $validateBulkResizeUrl = $script:CloudPCBasedUrl + "/deviceManagement/virtualEndpoint/cloudPCs/validateBulkResize"
    $body = @{
        cloudPcIds = @($CloudPCIds)
        targetServicePlanId = $TargetServicePlanId
    } | ConvertTo-Json

    $response = Invoke-MgGraphRequest -Method POST -Uri $validateBulkResizeUrl -Body $body

    foreach ($validateStatus in $response.value){
        if ($validateStatus.validationResult -ne "success"){
            $reason = $validateStatus.validationResult
            Write-Error "Unable to resize CloudPC, reason: $reason. Please make sure you input the valid CloudPCs."
            return 1
        }
    }
}

#####################################################################################################
# Create-EntraGroup
#####################################################################################################

<#
    .SYNOPSIS
        Create-EntraGroup
    .DESCRIPTION
        Create a new entra group
#>
function Create-EntraGroup{
    param (
        [Parameter(Mandatory = $True)]
        [string] $GroupName
    )

    Write-Host $Separator

    $createGroupUrl = $script:ExternalBasedUrl + "/groups"
    $body = @{
        displayName = $GroupName
        mailEnabled = $false
        securityEnabled = $true
        mailNickname = ([guid]::NewGuid().ToString()).Substring(0,10)
    } | ConvertTo-Json
                
    $response = Invoke-MgGraphRequest -Method POST -Uri $createGroupUrl -Body $body

    Write-Host $Separator
    Write-Host "Successfully create a new group: $GroupName"

    return $response.id
}

#####################################################################################################
# Add-MembersToEntraGroup
#####################################################################################################

<#
    .SYNOPSIS
        Add-MembersToEntraGroup
    .DESCRIPTION
        Add the users to an entra group
    .PARAMETER GroupId
        The group id for the new entra group   
    .PARAMETER UserIds
        The users' ids that need to be added in the entra group   
#>
function Add-MembersToEntraGroup{
    param (
        [Parameter(Mandatory = $True)]
        [string] $GroupId,
        [string[]] $UserIds
    )
    Write-Host $Separator

    # if user is already added, return
    $groupMemberInfoUrl = $script:ExternalBasedUrl + "/groups/${GroupId}/members"
    $response = Invoke-MgGraphRequest -Method GET -Uri $groupMemberInfoUrl
    $addedUserIds = $response.value | ForEach-Object { $_.id }
    $newUserIds = $UserIds | Where-Object { $_ -notin $addedUserIds }

    if ($newUserIds.Count -eq 0){
        Write-Host "Users have already been added"
        return
    }

     # Add user to the new group
    $addUserToGroupUrl = $script:ExternalBasedUrl + "/groups/${GroupId}"
    $directoryObjectUrls = $newUserIds | ForEach-Object {
        $script:ExternalBasedUrl + "/directoryObjects/$_"
    }  
    $body = @{
        "members@odata.bind" = @($directoryObjectUrls)
    } | ConvertTo-Json

    $response = Invoke-MgGraphRequest -Method PATCH -Uri $addUserToGroupUrl -Body $body
}

#####################################################################################################
# Remove-MembersFromEntraGroup
#####################################################################################################

<#
    .SYNOPSIS
        Remove-MembersFromEntraGroup
    .DESCRIPTION
        Remove the users from the entra group
    .PARAMETER GroupId
        The group id for the entra group
    .PARAMETER UserId
        The user id that need to be remvoed from the entra group
#>
function Remove-MembersFromEntraGroup{
    param (
        [Parameter(Mandatory = $True)]
        [string] $GroupId,
        [string] $UserId
    )
    Write-Host $Separator

    # if user is already removed, return
    $groupMemberInfoUrl = $script:ExternalBasedUrl + "/groups/${GroupId}/members"

    $response = Invoke-MgGraphRequest -Method GET -Uri $groupMemberInfoUrl
    $existedUserIds = $response.value | ForEach-Object { $_.id }

    if ($existedUserIds -notcontains $UserId){
        Write-Host "User has already been removed"
        return
    }

    $removeUserUrl = $script:ExternalBasedUrl + "/groups/${GroupId}/members/${UserId}/`$ref"
    Invoke-MgGraphRequest -Method DELETE -Uri $removeUserUrl
}

#####################################################################################################
# Assign-LicenseToEntraGroup
#####################################################################################################

<#
    .SYNOPSIS
        Get CloudPC basic information
    .DESCRIPTION
        Assign a license to an entra group
    .PARAMETER GroupId
        The group id for the entra group
    .PARAMETER SkuId
        The Sku id for the assigned license
#>
function Assign-LicenseToEntraGroup{
    param (
        [Parameter(Mandatory = $True)]
        [string] $GroupId,
        [string] $SkuId
    )
    Write-Host $Separator

    $assignLicenseUrl = $script:ExternalBasedUrl + "/groups/${GroupId}/assignLicense"
    $body = @{
        addLicenses = @(
            @{
                disabledPlans = @()
                skuId = $SkuId
            }
        )
        removeLicenses = @()
    } | ConvertTo-Json -Depth 3

    $response = Invoke-MgGraphRequest -Method POST -Uri $assignLicenseUrl -Body $body
}

#####################################################################################################
# Bind-EntraGroupToProvisioningPolicy
#####################################################################################################

<#
    .SYNOPSIS
        Bind-EntraGroupToProvisioningPolicy
    .DESCRIPTION
        Bind the entra group to an provisioning policy
    .PARAMETER GroupId
        The group id for the entra group
    .PARAMETER PolicyId
        The policy id of the an provisioning policy
#>
function Bind-EntraGroupToProvisioningPolicy{
    param (
        [Parameter(Mandatory = $True)]
        [string] $GroupId,
        [string] $PolicyId
    )
    Write-Host $Separator

    $getPolicyInfoUrl = $script:CloudPCBasedUrl + "/deviceManagement/virtualEndpoint/provisioningPolicies/${PolicyId}?`$expand=assignments&`$select=id"
    $response = Invoke-MgGraphRequest -Method GET -Uri $getPolicyInfoUrl
    $sourceGroupIds = @($response.assignments | ForEach-Object { $_.id })

    if ($sourceGroupIds -notcontains $GroupId){
        $assignPolicyToGroupUrl = $script:CloudPCBasedUrl + "/deviceManagement/virtualEndpoint/provisioningPolicies/${PolicyId}/assign"
        $sourceGroupIds += $GroupId
        $assignments = $sourceGroupIds | ForEach-Object {
            @{
                target = @{
                    groupId = $_
                }
            }
        }
        $body = @{
            assignments = $assignments
        } | ConvertTo-Json -Depth 5

        $response = Invoke-MgGraphRequest -Method POST -Uri $assignPolicyToGroupUrl -Body $body
    }
}

#####################################################################################################
# Show-SleepProgress
#####################################################################################################

<#
    .SYNOPSIS
        Show-SleepProgress
    .DESCRIPTION
        Show the progress of the sleep process
    .PARAMETER Duration
        The sleep duration
#>
function Show-SleepProgress {
    param (
        [int]$Duration
    )

    for ($i = 1; $i -le $Duration; $i++) {
        $percentComplete = ($i / $Duration) * 100
        Write-Progress -Activity "Waitting..." -Status "$i s / $Duration s" -PercentComplete $percentComplete
        Start-Sleep -Seconds 1
    }

    Write-Progress -Activity "Complete" -Completed
}

#####################################################################################################
# Summarize-ReclaimSteps
#####################################################################################################

<#
    .SYNOPSIS
        Summarize-ReclaimSteps
    .DESCRIPTION
        Summarize the detailed reclaim steps
    .PARAMETER CloudPCList
        The list of CloudPCs
#>
function Summarize-ReclaimSteps {
    param (
        [Parameter(Mandatory = $True)]
        [PSCustomObject[]] $CloudPCList
    )

    Write-Host "To complete the reclaim flow, we need to take the following steps: "
    Write-Host "`n1. For the CloudPCs with direct assigned licenses, we will remove the licenses from the following users."
    $directAssignedLicense = $CloudPCList | Where-Object { [string]::IsNullOrEmpty($_.LicenseAssignedGroupId) }
    $directAssignedLicense | ForEach-Object { "`n" + $_.UserPrincipalName }

    Write-Host "`n2. For the Cloud PCs with group based licenses, we will remove the following users from the source group, this may cause the users to lose existing permissions."
    $groupBasedLicenseDeivceList = $CloudPCList | Where-Object { $_.LicenseAssignedGroupId }
    $groupBasedLicenseDeivceList | Select-Object @{Name='Group name'; Expression={ $_.LicenseAssignedGroupName }}, @{Name='User name'; Expression={ $_.UserPrincipalName }} | Format-Table -AutoSize
}


#####################################################################################################
# Summarize-ResizeSteps
#####################################################################################################

<#
    .SYNOPSIS
        Summarize-ResizeSteps
    .DESCRIPTION
        Summarize the detailed resize steps
    .PARAMETER CloudPCList
        The list of CloudPCs
    .PARAMETER UseDefaultName
        Indicate whether to use the default naming convention
#>
function Summarize-ResizeSteps {
    param (
        [PSCustomObject[]] $CloudPCList
    )

    $groupBasedLicenseDeivceList = $CloudPCList | Where-Object { $_.LicenseAssignedGroupId }

    Write-Host "To complete the resize flow, we need to take the following steps: "
    Write-Host "`n1. Remove the following users from the source group. This may cause the users to lose existing permissions."
    $sheet = $groupBasedLicenseDeivceList | Select-Object @{Name='Group name'; Expression={ $_.LicenseAssignedGroupName }}, @{Name='User name'; Expression={ $_.UserPrincipalName }} | Format-Table -AutoSize | Out-String        
    Write-Host $sheet

    Write-Host "`n2. Create new entra groups, this step requires you to name the new groups."
    $UseDefaultName = Read-Host "Would you like to use the default name for the new groups (The example name looks like: Resize_2vCPU/8GB/256GB_2025-06-24T21)? [Y] Yes [N] No (default is "N"): "

    if ($UseDefaultName -eq "Y") {
        $groupInfoList = @()
        $groupedByRecommendedServicePlanList = $groupBasedLicenseDeivceList | Group-Object -Property RecommendedSize
        foreach ($group in $groupedByRecommendedServicePlanList) {
            $recommendedSize = $group.Group[0].RecommendedSize
            $groupName = "Resize_${recommendedSize}_$((Get-Date).ToString("yyyy-MM-ddTHHyyyy-MM-ddTHH:mm"))"
            $userNamesString = ($group.Group | ForEach-Object { $_.UserPrincipalName }) -join ","

            $groupInfo = [PSCustomObject]@{
                GroupName = $groupName
                UserNames = $userNamesString
                RecommendedSize = $recommendedSize
            }

            $groupInfoList += $groupInfo
        }
                
        Write-Host "`n3. Move the target users to the new created entra groups as following."
        $sheet = $groupInfoList | Select-Object @{Name='New Group name'; Expression={ $_.GroupName }}, @{Name='User names'; Expression={ $_.UserNames }} | Format-Table -AutoSize | Out-String  
        Write-Host $sheet

        Write-Host "`n4. Assign the target licenses to the new created entra groups as following."
        $sheet = $groupInfoList | Select-Object @{Name='New Group name'; Expression={ $_.GroupName }}, @{Name='Target license'; Expression={ $_.RecommendedSize }} | Format-Table -AutoSize | Out-String
        Write-Host $sheet

        $groupedByPolicyIdList = $groupBasedLicenseDeivceList | Group-Object -Property RecommendedServicePlanId, ProvisioningPolicyId
        $groupPolicyList = @()
        foreach ($group in $groupedByPolicyIdList) {
            $recommendedSize = $group.Group[0].RecommendedSize
            $provisioningPolicyName = $group.Group[0].ProvisioningPolicyName
            $groupName = $groupInfoList | Where-Object { $_.RecommendedSize -eq $recommendedSize } | Select-Object -First 1 -ExpandProperty GroupName

            $groupInfo = [PSCustomObject]@{
                GroupName = $groupName
                ProvisioningPolicyName = $provisioningPolicyName
            }

            $groupPolicyList += $groupInfo
        }

        Write-Host "`n5. Assign the origin provisioning policy to the new created entra groups as following."
        $sheet = $groupPolicyList | Select-Object @{Name='New Group name'; Expression={ $_.GroupName }}, @{Name='Provisioning Policy Name'; Expression={ $_.ProvisioningPolicyName }} | Format-Table -AutoSize | Out-String
        Write-Host $sheet
    } else {
        Write-Host "`n3. Move the target users to the new created entra groups."
        Write-Host "`n4. Assign the target licenses to the new created entra groups."
        Write-Host "`n5. Assign the origin provisioning policy to the new created entra groups."
    }

    return $UseDefaultName
}
# SIG # Begin signature block
# MIIsAAYJKoZIhvcNAQcCoIIr8TCCK+0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAzkBHdxiFivBcH
# eO8xt4cXenx2K5N75UDcS6wZ6bEtZKCCEW4wggh+MIIHZqADAgECAhM2AAACAO38
# jbec3qFIAAIAAAIAMA0GCSqGSIb3DQEBCwUAMEExEzARBgoJkiaJk/IsZAEZFgNH
# QkwxEzARBgoJkiaJk/IsZAEZFgNBTUUxFTATBgNVBAMTDEFNRSBDUyBDQSAwMTAe
# Fw0yNDExMDgxMjQzMjhaFw0yNTExMDgxMjQzMjhaMCQxIjAgBgNVBAMTGU1pY3Jv
# c29mdCBBenVyZSBDb2RlIFNpZ24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
# AoIBAQC5L/UPrOpwYjxcoZC0TqqvMF1WUELvwXN+k27SrA5rohJknn7Cgbxg4hGT
# XKqpcdbtsVTN3ZY896SJ20uQ+INL5OVLzpW408nCNTPYg2LtGJbqHUjpNm0hLCJ+
# gO5Jn2T8DDzIJoUijGXj1m+hRLKb2nOIicCED2GuYBmuWXnaY7INmVEaU3peryty
# ZjDuxdyGDuiPURz8lW1SUiDzoszNp1oswVr+WjDvLDUx4HlxPsG8zUjIst0NnJ6o
# z4tNFKaUBDCetcMjQxpCETn29a1CuRddxZLjPHZHfcotr5sh1S6bNQdzVaMNsxV8
# L3wjHb7XJ6ZVm662mHEiPgpyNcLhAgMBAAGjggWKMIIFhjApBgkrBgEEAYI3FQoE
# HDAaMAwGCisGAQQBgjdbAQEwCgYIKwYBBQUHAwMwPQYJKwYBBAGCNxUHBDAwLgYm
# KwYBBAGCNxUIhpDjDYTVtHiE8Ys+hZvdFs6dEoFgg93NZoaUjDICAWQCAQ4wggJ2
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
# aG9yaXR5MB0GA1UdDgQWBBST/HE52ZUlmsYqZcZBdrXZ5u4ZnzAOBgNVHQ8BAf8E
# BAMCB4AwRQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEWMBQGA1UEBRMNMjM2MTY3KzUwMzE1NTCCAeYGA1UdHwSCAd0wggHZMIIB
# 1aCCAdGgggHNhj9odHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpaW5mcmEvQ1JM
# L0FNRSUyMENTJTIwQ0ElMjAwMSgyKS5jcmyGMWh0dHA6Ly9jcmwxLmFtZS5nYmwv
# Y3JsL0FNRSUyMENTJTIwQ0ElMjAwMSgyKS5jcmyGMWh0dHA6Ly9jcmwyLmFtZS5n
# YmwvY3JsL0FNRSUyMENTJTIwQ0ElMjAwMSgyKS5jcmyGMWh0dHA6Ly9jcmwzLmFt
# ZS5nYmwvY3JsL0FNRSUyMENTJTIwQ0ElMjAwMSgyKS5jcmyGMWh0dHA6Ly9jcmw0
# LmFtZS5nYmwvY3JsL0FNRSUyMENTJTIwQ0ElMjAwMSgyKS5jcmyGgb1sZGFwOi8v
# L0NOPUFNRSUyMENTJTIwQ0ElMjAwMSgyKSxDTj1CWTJQS0lDU0NBMDEsQ049Q0RQ
# LENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNvbmZp
# Z3VyYXRpb24sREM9QU1FLERDPUdCTD9jZXJ0aWZpY2F0ZVJldm9jYXRpb25MaXN0
# P2Jhc2U/b2JqZWN0Q2xhc3M9Y1JMRGlzdHJpYnV0aW9uUG9pbnQwHwYDVR0jBBgw
# FoAUllGE4Gtve/7YBqvD8oXmKa5q+dQwHwYDVR0lBBgwFgYKKwYBBAGCN1sBAQYI
# KwYBBQUHAwMwDQYJKoZIhvcNAQELBQADggEBAEDd8Wf5RkHsB64vgn2slxDtHzSo
# It9xN/Dm3RdFjNZ0diTUPMgSPYQlSk8nIAfudnB9FLavGlvZLlyUpfrPSuikepj3
# i3pqNEFn6fNdNFv/wHMxv7hQTIDCmuoR1v1rX+w3oeleBPMnN3QmH4ff1NsynyV4
# dZdYgN9Cw9sC/S3pWZpJrbOs7YOM3vqyU6DciHhC4D9i2zByHCF2pu9nYfiQf5A2
# iUZenRvyo1E5rC+UP2VZXa4k7g66W20+zAajIKKIqEmRtWahekMkCcOIHFBY4RDA
# ybgPRSGur4VDAiZPjTXS90wQXrX9CwU20cfiCC6e76F4H95KtQjKYpzuNVAwggjo
# MIIG0KADAgECAhMfAAAAUeqP9pxzDKg7AAAAAABRMA0GCSqGSIb3DQEBCwUAMDwx
# EzARBgoJkiaJk/IsZAEZFgNHQkwxEzARBgoJkiaJk/IsZAEZFgNBTUUxEDAOBgNV
# BAMTB2FtZXJvb3QwHhcNMjEwNTIxMTg0NDE0WhcNMjYwNTIxMTg1NDE0WjBBMRMw
# EQYKCZImiZPyLGQBGRYDR0JMMRMwEQYKCZImiZPyLGQBGRYDQU1FMRUwEwYDVQQD
# EwxBTUUgQ1MgQ0EgMDEwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDJ
# mlIJfQGejVbXKpcyFPoFSUllalrinfEV6JMc7i+bZDoL9rNHnHDGfJgeuRIYO1LY
# /1f4oMTrhXbSaYRCS5vGc8145WcTZG908bGDCWr4GFLc411WxA+Pv2rteAcz0eHM
# H36qTQ8L0o3XOb2n+x7KJFLokXV1s6pF/WlSXsUBXGaCIIWBXyEchv+sM9eKDsUO
# LdLTITHYJQNWkiryMSEbxqdQUTVZjEz6eLRLkofDAo8pXirIYOgM770CYOiZrcKH
# K7lYOVblx22pdNawY8Te6a2dfoCaWV1QUuazg5VHiC4p/6fksgEILptOKhx9c+ia
# piNhMrHsAYx9pUtppeaFAgMBAAGjggTcMIIE2DASBgkrBgEEAYI3FQEEBQIDAgAC
# MCMGCSsGAQQBgjcVAgQWBBQSaCRCIUfL1Gu+Mc8gpMALI38/RzAdBgNVHQ4EFgQU
# llGE4Gtve/7YBqvD8oXmKa5q+dQwggEEBgNVHSUEgfwwgfkGBysGAQUCAwUGCCsG
# AQUFBwMBBggrBgEFBQcDAgYKKwYBBAGCNxQCAQYJKwYBBAGCNxUGBgorBgEEAYI3
# CgMMBgkrBgEEAYI3FQYGCCsGAQUFBwMJBggrBgEFBQgCAgYKKwYBBAGCN0ABAQYL
# KwYBBAGCNwoDBAEGCisGAQQBgjcKAwQGCSsGAQQBgjcVBQYKKwYBBAGCNxQCAgYK
# KwYBBAGCNxQCAwYIKwYBBQUHAwMGCisGAQQBgjdbAQEGCisGAQQBgjdbAgEGCisG
# AQQBgjdbAwEGCisGAQQBgjdbBQEGCisGAQQBgjdbBAEGCisGAQQBgjdbBAIwGQYJ
# KwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMBIGA1UdEwEB/wQI
# MAYBAf8CAQAwHwYDVR0jBBgwFoAUKV5RXmSuNLnrrJwNp4x1AdEJCygwggFoBgNV
# HR8EggFfMIIBWzCCAVegggFToIIBT4YxaHR0cDovL2NybC5taWNyb3NvZnQuY29t
# L3BraWluZnJhL2NybC9hbWVyb290LmNybIYjaHR0cDovL2NybDIuYW1lLmdibC9j
# cmwvYW1lcm9vdC5jcmyGI2h0dHA6Ly9jcmwzLmFtZS5nYmwvY3JsL2FtZXJvb3Qu
# Y3JshiNodHRwOi8vY3JsMS5hbWUuZ2JsL2NybC9hbWVyb290LmNybIaBqmxkYXA6
# Ly8vQ049YW1lcm9vdCxDTj1BTUVSb290LENOPUNEUCxDTj1QdWJsaWMlMjBLZXkl
# MjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9uLERDPUFNRSxE
# Qz1HQkw/Y2VydGlmaWNhdGVSZXZvY2F0aW9uTGlzdD9iYXNlP29iamVjdENsYXNz
# PWNSTERpc3RyaWJ1dGlvblBvaW50MIIBqwYIKwYBBQUHAQEEggGdMIIBmTBHBggr
# BgEFBQcwAoY7aHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraWluZnJhL2NlcnRz
# L0FNRVJvb3RfYW1lcm9vdC5jcnQwNwYIKwYBBQUHMAKGK2h0dHA6Ly9jcmwyLmFt
# ZS5nYmwvYWlhL0FNRVJvb3RfYW1lcm9vdC5jcnQwNwYIKwYBBQUHMAKGK2h0dHA6
# Ly9jcmwzLmFtZS5nYmwvYWlhL0FNRVJvb3RfYW1lcm9vdC5jcnQwNwYIKwYBBQUH
# MAKGK2h0dHA6Ly9jcmwxLmFtZS5nYmwvYWlhL0FNRVJvb3RfYW1lcm9vdC5jcnQw
# gaIGCCsGAQUFBzAChoGVbGRhcDovLy9DTj1hbWVyb290LENOPUFJQSxDTj1QdWJs
# aWMlMjBLZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9u
# LERDPUFNRSxEQz1HQkw/Y0FDZXJ0aWZpY2F0ZT9iYXNlP29iamVjdENsYXNzPWNl
# cnRpZmljYXRpb25BdXRob3JpdHkwDQYJKoZIhvcNAQELBQADggIBAFAQI7dPD+jf
# XtGt3vJp2pyzA/HUu8hjKaRpM3opya5G3ocprRd7vdTHb8BDfRN+AD0YEmeDB5HK
# QoG6xHPI5TXuIi5sm/LeADbV3C2q0HQOygS/VT+m1W7a/752hMIn+L4ZuyxVeSBp
# fwf7oQ4YSZPh6+ngZvBHgfBaVz4O9/wcfw91QDZnTgK9zAh9yRKKls2bziPEnxeO
# ZMVNaxyV0v152PY2xjqIafIkUjK6vY9LtVFjJXenVUAmn3WCPWNFC1YTIIHw/mD2
# cTfPy7QA1pT+GPARAKt0bKtq9aCd/Ym0b5tPbpgCiRtzyb7fbNS1dE740re0COE6
# 7YV2wbeo2sXixzvLftH8L7s9xv9wV+G22qyKt6lmKLjFK1yMw4Ni5fMabcgmzRvS
# jAcbqgp3tk4a8emaaH0rz8MuuIP+yrxtREPXSqL/C5bzMzsikuDW9xH10graZzSm
# PjilzpRfRdu20/9UQmC7eVPZ4j1WNa1oqPHfzET3ChIzJ6Q9G3NPCB+7KwX0OQmK
# yv7IDimj8U/GlsHD1z+EF/fYMf8YXG15LamaOAohsw/ywO6SYSreVW+5Y0mzJutn
# BC9Cm9ozj1+/4kqksrlhZgR/CSxhFH3BTweH8gP2FEISRtShDZbuYymynY1un+Ry
# fiK9+iVTLdD1h/SxyxDpZMtimb4CgJQlMYIZ6DCCGeQCAQEwWDBBMRMwEQYKCZIm
# iZPyLGQBGRYDR0JMMRMwEQYKCZImiZPyLGQBGRYDQU1FMRUwEwYDVQQDEwxBTUUg
# Q1MgQ0EgMDECEzYAAAIA7fyNt5zeoUgAAgAAAgAwDQYJYIZIAWUDBAIBBQCgga4w
# GQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisG
# AQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEINfYUhcWmk6Hs8OlT8XiQrEryXntq/Nj
# MiuwMqYlht2zMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBvAGYA
# dKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEA
# Amsu4oaS8NgH81oOu3/0/cdE/t0Zc+yLnwpfctE3VP9UZek/M8ePRRaPMpbVOus2
# ooaygFFA6CHkyULInJXAvVG09jvsdIy7HiX7sQtyJY6JrZU49UOCIa83VrmbDw+d
# 83GsLeTFoRQ8Tm9qX3p4lLQ2bVOQVwGto3NZ6sjPeqCcO8vMODxoLRZD1tkm0lWU
# CTy+4zpyPubqDUgzNEkSkb2SzeYwrP536WrAV2solHlyG8RTDU+t8VqufChm07d7
# zVVgdDVUR1LSE8oL+3BOIumCaS0amRXgKzlnMZTgmRqzQdTYpI8szuiLtFIZwGgi
# pWwARB6BeBYQK74yyPXJRKGCF7AwghesBgorBgEEAYI3AwMBMYIXnDCCF5gGCSqG
# SIb3DQEHAqCCF4kwgheFAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFaBgsqhkiG9w0B
# CRABBKCCAUkEggFFMIIBQQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUA
# BCCrCcJqAxL6NX0+uQg5T698rfrA4FFuSBL6vaCtaJ3erwIGaFLm4XZWGBMyMDI1
# MDcwMjA3MDgzNS4xMTFaMASAAgH0oIHZpIHWMIHTMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFuZCBP
# cGVyYXRpb25zIExpbWl0ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo0MzFB
# LTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vydmlj
# ZaCCEf4wggcoMIIFEKADAgECAhMzAAAB+vs7RNN3M8bTAAEAAAH6MA0GCSqGSIb3
# DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAk
# BgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4XDTI0MDcyNTE4
# MzExMVoXDTI1MTAyMjE4MzExMVowgdMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpX
# YXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQg
# Q29ycG9yYXRpb24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlv
# bnMgTGltaXRlZDEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjQzMUEtMDVFMC1E
# OTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAyhZVBM3PZcBfEpAf7fIIhygwYVVP
# 64USeZbSlRR3pvJebva0LQCDW45yOrtpwIpGyDGX+EbCbHhS5Td4J0Ylc83ztLEb
# bQD7M6kqR0Xj+n82cGse/QnMH0WRZLnwggJdenpQ6UciM4nMYZvdQjybA4qejOe9
# Y073JlXv3VIbdkQH2JGyT8oB/LsvPL/kAnJ45oQIp7Sx57RPQ/0O6qayJ2SJrwcj
# A8auMdAnZKOixFlzoooh7SyycI7BENHTpkVKrRV5YelRvWNTg1pH4EC2KO2bxsBN
# 23btMeTvZFieGIr+D8mf1lQQs0Ht/tMOVdah14t7Yk+xl5P4Tw3xfAGgHsvsa6ug
# rxwmKTTX1kqXH5XCdw3TVeKCax6JV+ygM5i1NroJKwBCW11Pwi0z/ki90ZeO6XfE
# E9mCnJm76Qcxi3tnW/Y/3ZumKQ6X/iVIJo7Lk0Z/pATRwAINqwdvzpdtX2hOJib4
# GR8is2bpKks04GurfweWPn9z6jY7GBC+js8pSwGewrffwgAbNKm82ZDFvqBGQQVJ
# wIHSXpjkS+G39eyYOG2rcILBIDlzUzMFFJbNh5tDv3GeJ3EKvC4vNSAxtGfaG/mQ
# hK43YjevsB72LouU78rxtNhuMXSzaHq5fFiG3zcsYHaa4+w+YmMrhTEzD4SAish3
# 5BjoXP1P1Ct4Va0CAwEAAaOCAUkwggFFMB0GA1UdDgQWBBRjjHKbL5WV6kd06Koc
# QHphK9U/vzAfBgNVHSMEGDAWgBSfpxVdAF5iXYP05dJlpxtTNRnpcjBfBgNVHR8E
# WDBWMFSgUqBQhk5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9N
# aWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcmwwbAYIKwYB
# BQUHAQEEYDBeMFwGCCsGAQUFBzAChlBodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20v
# cGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEw
# KDEpLmNydDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4G
# A1UdDwEB/wQEAwIHgDANBgkqhkiG9w0BAQsFAAOCAgEAuFbCorFrvodG+ZNJH3Y+
# Nz5QpUytQVObOyYFrgcGrxq6MUa4yLmxN4xWdL1kygaW5BOZ3xBlPY7Vpuf5b5ea
# XP7qRq61xeOrX3f64kGiSWoRi9EJawJWCzJfUQRThDL4zxI2pYc1wnPp7Q695bHq
# wZ02eaOBudh/IfEkGe0Ofj6IS3oyZsJP1yatcm4kBqIH6db1+weM4q46NhAfAf07
# 0zF6F+IpUHyhtMbQg5+QHfOuyBzrt67CiMJSKcJ3nMVyfNlnv6yvttYzLK3wS+0Q
# wJUibLYJMI6FGcSuRxKlq6RjOhK9L3QOjh0VCM11rHM11ZmN0euJbbBCVfQEufOL
# NkG88MFCUNE10SSbM/Og/CbTko0M5wbVvQJ6CqLKjtHSoeoAGPeeX24f5cPYyTcK
# lbM6LoUdO2P5JSdI5s1JF/On6LiUT50adpRstZajbYEeX/N7RvSbkn0djD3BvT2O
# f3Wf9gIeaQIHbv1J2O/P5QOPQiVo8+0AKm6M0TKOduihhKxAt/6Yyk17Fv3RIdjT
# 6wiL2qRIEsgOJp3fILw4mQRPu3spRfakSoQe5N0e4HWFf8WW2ZL0+c83Qzh3VtEP
# I6Y2e2BO/eWhTYbIbHpqYDfAtAYtaYIde87ZymXG3MO2wUjhL9HvSQzjoquq+OoU
# mvfBUcB2e5L6QCHO6qTO7WowggdxMIIFWaADAgECAhMzAAAAFcXna54Cm0mZAAAA
# AAAVMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBB
# dXRob3JpdHkgMjAxMDAeFw0yMTA5MzAxODIyMjVaFw0zMDA5MzAxODMyMjVaMHwx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1p
# Y3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMIICIjANBgkqhkiG9w0BAQEFAAOC
# Ag8AMIICCgKCAgEA5OGmTOe0ciELeaLL1yR5vQ7VgtP97pwHB9KpbE51yMo1V/YB
# f2xK4OK9uT4XYDP/XE/HZveVU3Fa4n5KWv64NmeFRiMMtY0Tz3cywBAY6GB9alKD
# RLemjkZrBxTzxXb1hlDcwUTIcVxRMTegCjhuje3XD9gmU3w5YQJ6xKr9cmmvHaus
# 9ja+NSZk2pg7uhp7M62AW36MEBydUv626GIl3GoPz130/o5Tz9bshVZN7928jaTj
# kY+yOSxRnOlwaQ3KNi1wjjHINSi947SHJMPgyY9+tVSP3PoFVZhtaDuaRr3tpK56
# KTesy+uDRedGbsoy1cCGMFxPLOJiss254o2I5JasAUq7vnGpF1tnYN74kpEeHT39
# IM9zfUGaRnXNxF803RKJ1v2lIH1+/NmeRd+2ci/bfV+AutuqfjbsNkz2K26oElHo
# vwUDo9Fzpk03dJQcNIIP8BDyt0cY7afomXw/TNuvXsLz1dhzPUNOwTM5TI4CvEJo
# LhDqhFFG4tG9ahhaYQFzymeiXtcodgLiMxhy16cg8ML6EgrXY28MyTZki1ugpoMh
# XV8wdJGUlNi5UPkLiWHzNgY1GIRH29wb0f2y1BzFa/ZcUlFdEtsluq9QBXpsxREd
# cu+N+VLEhReTwDwV2xo3xwgVGD94q0W29R6HXtqPnhZyacaue7e3PmriLq0CAwEA
# AaOCAd0wggHZMBIGCSsGAQQBgjcVAQQFAgMBAAEwIwYJKwYBBAGCNxUCBBYEFCqn
# Uv5kxJq+gpE8RjUpzxD/LwTuMB0GA1UdDgQWBBSfpxVdAF5iXYP05dJlpxtTNRnp
# cjBcBgNVHSAEVTBTMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNodHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0w
# EwYDVR0lBAwwCgYIKwYBBQUHAwgwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEw
# CwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU1fZWy4/o
# olxiaNE9lJBb186aGMQwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNy
# b3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYt
# MjMuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5j
# cnQwDQYJKoZIhvcNAQELBQADggIBAJ1VffwqreEsH2cBMSRb4Z5yS/ypb+pcFLY+
# TkdkeLEGk5c9MTO1OdfCcTY/2mRsfNB1OW27DzHkwo/7bNGhlBgi7ulmZzpTTd2Y
# urYeeNg2LpypglYAA7AFvonoaeC6Ce5732pvvinLbtg/SHUB2RjebYIM9W0jVOR4
# U3UkV7ndn/OOPcbzaN9l9qRWqveVtihVJ9AkvUCgvxm2EhIRXT0n4ECWOKz3+SmJ
# w7wXsFSFQrP8DJ6LGYnn8AtqgcKBGUIZUnWKNsIdw2FzLixre24/LAl4FOmRsqlb
# 30mjdAy87JGA0j3mSj5mO0+7hvoyGtmW9I/2kQH2zsZ0/fZMcm8Qq3UwxTSwethQ
# /gpY3UA8x1RtnWN0SCyxTkctwRQEcb9k+SS+c23Kjgm9swFXSVRk2XPXfx5bRAGO
# WhmRaw2fpCjcZxkoJLo4S5pu+yFUa2pFEUep8beuyOiJXk+d0tBMdrVXVAmxaQFE
# fnyhYWxz/gq77EFmPWn9y8FBSX5+k77L+DvktxW/tM4+pTFRhLy/AsGConsXHRWJ
# jXD+57XQKBqJC4822rpM+Zv/Cuk0+CQ1ZyvgDbjmjJnW4SLq8CdCPSWU5nR0W2rR
# nj7tfqAxM328y+l7vzhwRNGQ8cirOoo6CGJ/2XBjU02N7oJtpQUQwXEGahC0HVUz
# WLOhcGbyoYIDWTCCAkECAQEwggEBoYHZpIHWMIHTMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFuZCBP
# cGVyYXRpb25zIExpbWl0ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo0MzFB
# LTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vydmlj
# ZaIjCgEBMAcGBSsOAwIaAxUA94Z+bUJn+nKwBvII6sg0Ny7aPDaggYMwgYCkfjB8
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1N
# aWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQsFAAIFAOwP
# MK4wIhgPMjAyNTA3MDIwNDE0MzhaGA8yMDI1MDcwMzA0MTQzOFowdzA9BgorBgEE
# AYRZCgQBMS8wLTAKAgUA7A8wrgIBADAKAgEAAgIYXQIB/zAHAgEAAgIUAjAKAgUA
# 7BCCLgIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAID
# B6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBCwUAA4IBAQAuIoGoFFwcoUdVdcak
# cb6DpTB5Me23S8lJ/PlzpoCTfDartjbySVI3AJxFXM0PxllJvy92fhf1wIZgeQS+
# D+YG5wUHNagad5XPhZ88T7+mNwXMWDRAQVkin73Y/ZYnhkZ1wdMdOX74rDVCvrrW
# VMPKcDagVR7xlXSuWAWbcr+YOmtC3VPYdA2K5lTY5GUZYzjPw6OowZe8AWAd8qJY
# 7LM0GTicUkcaP1uvFhI4bZxKh8zbSgAs2/nHyR1CapK1ycwuNol3s/yRMCJBDWc4
# sHvu2kHE+Mv1fmzjYjKg75+lVWkeXFskt/WVx2Mj7tl2mMZYCyccaVtdjM1OLH1q
# fl7bMYIEDTCCBAkCAQEwgZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAC
# EzMAAAH6+ztE03czxtMAAQAAAfowDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqGSIb3
# DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0BCQQxIgQgwKtOg+YmeK1nK/4v
# rgQ5ymZ+aWTf4uoH9mAFO2XknJcwgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHkMIG9
# BCB98n8tya8+B2jjU/dpJRIwHwHHpco5ogNStYocbkOeVjCBmDCBgKR+MHwxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jv
# c29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB+vs7RNN3M8bTAAEAAAH6MCIE
# INgnm6CBSupi4GyFPcgDMXFJQdvNcsEYz8Sl6EOE4rOGMA0GCSqGSIb3DQEBCwUA
# BIICACFFjg2VaGa0Sxtdt0IXmmTQE/zj4zsKWWrTBC89ZsGubsMo7DlDAKtYu1BB
# tEz6PHzi60Wf7ZQeN65/SMCyMBWme4l4+nNT4pxu3Rb6nV8W2mfSz+31JZSQCfYe
# ojdoU4aXHAULQYoXiu1pSBbWYBxuDr2aZk3O4kMWXBlnYHqIfeTz4y6r+ZjhJly9
# OSpruA0BxgtP81JJ+1Tg3r9+fdCxdNOJLRSLENFqAQ+wnlJ55avT60ZREvyolHS7
# +aQUvR12KolBV1KqSQA+Szg1FGAGDf7+PeFQ7oeR1lxg/XU3s99UlKzVenblQCDd
# xTcKow7EP6rMdPiWYX4q2QHyJSzV1Eb0nUCq7c6uOkQHWZUqJJZnPUn7wF8O1Yv5
# FlRHgnKMYTDpcbocZqYQbVmKaqo+OqYbBez8fEzIUrOQAkQpXMWvB7WSZPLz3Wz9
# Grhs7ph6DYKmj8e3vwU2CKFUUkyMIEuqxbD+f1G/v2l//AKfcfTOYy2HT0z2nAfe
# wv6t6mOv4ua3lReIXcIYgl1rtPy/3cZxXnS8jAt+4IhhebTwYaH/7xxbMtj0XvJY
# DvkeKev1RLTlPLJWVGjD4ooUwGsHn4oTby6O15oeQ8KrRLki/PdLqXkZNHcoHxXC
# 0fYZ5W4a6MugqPuYoCYrbgSCqhoKCaZGkWp3LSWNx1Sh5Gee
# SIG # End signature block

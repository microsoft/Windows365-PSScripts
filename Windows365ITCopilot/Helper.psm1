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
#>
function Setup-GraphConfig {
    param (
        [Parameter(Mandatory = $True)]
        [string[]] $GraphScopes
    )

    #Commands to load MS.Graph modules
    if (invoke-graphmodule -eq 1) {
        write-host "Invoking Graph failed. Exiting..." | out-host
        Return 1
    }

    #Command to connect to MS.Graph PowerShell app
    if ((connect-msgraph -Scopes $GraphScopes) -eq 1) {
        write-host "Connecting to Graph failed. Exiting..." | out-host
        Return 1
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
            write-host "Failed to install Microsoft.Graph Module" | out-host
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
            write-host "Failed to connect to MS Graph" | out-host
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
        Remove the license for the direct assigned Cloud PC and remove the user for the group based the Cloud PC
    .PARAMETER CloudPC
        The reclaimed CloudPC
#>
function Remove-CloudPCLicense{
    param (
        [Parameter(Mandatory = $True)]
        [PSCustomObject] $CloudPC
    )

    Write-Host $Separator

    $deviceName = $CloudPC.DeviceName
    $skuId = $CloudPC.SourceSkuId
    $userId = $CloudPC.UserId
    $groupId = $CloudPC.LisenceAssignedGroupId

    if (-not $groupId){
        # Reclaim direct assigned license
        $unAssignLicenseUrl = $script:ExternalBasedUrl + "/users/${userId}/assignLicense"
        $body = @{
            addLicenses = @()
            removeLicenses = @($skuId)
        } | ConvertTo-Json

        $response = Invoke-MgGraphRequest -Method POST -Uri $unAssignLicenseUrl -Body $body
    } else{
        # Reclaim group based license
        $removeUserUrl = $script:ExternalBasedUrl + "/groups/${groupId}/members/${userId}/`$ref"

        Invoke-MgGraphRequest -Method DELETE -Uri $removeUserUrl -OutputType PSObject
    }

    Write-Host "✅ Successfully recliam license for device: $deviceName"
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
        $deprovisionCloudPCUrl = $script:CloudPCBasedUrl + "deviceManagement/virtualEndpoint/cloudPCs/${cloudPCId}/endGracePeriod"
        Invoke-MgGraphRequest -Method POST $deprovisionCloudPCUrl -OutputType PSObject
        Write-Output "✅ Successfully deprovisioned device: $DeviceName"
    } else {
        Write-Output "❌ Device did not enter 'inGracePeriod' status: $DeviceName"
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

    Invoke-MgGraphRequest -Method POST -Uri $bulkResizeUrl -Body $body

    Write-Host "Successfully to trigger resize flow, the bulk action name is: $bulkActionName"
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
            Write-Error "Unable to resize CloudPC, Reason: $reason, please make sure you input the valid CloudPCs."
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

    Write-Host $Separator

    $GroupName = Read-Host "Please input the new Group name"
   
    $createGroupUrl = $script:ExternalBasedUrl + "/groups"
    $body = @{
        displayName = $GroupName
        mailEnabled = $false
        securityEnabled = $true
        mailNickname = "mailNickname"
    } | ConvertTo-Json
                
    $response = Invoke-MgGraphRequest -Method POST -Uri $createGroupUrl -Body $body

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

    # Todo: if user is already add, return

     # Add user to the new group
    $addUserToGroupUrl = $script:ExternalBasedUrl + "/groups/${GroupId}"
    $directoryObjectUrls = $UserIds | ForEach-Object {
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

    # Todo: if user is already removed, return

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
    $sourceGroupIds = $response.assignments | ForEach-Object { $_.id }

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
        } | ConvertTo-Json -Depth 3

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


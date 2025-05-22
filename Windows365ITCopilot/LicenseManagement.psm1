<#
    .COPYRIGHT
    Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
    See LICENSE in the project root for license information.
#>
using module ".\Model\CloudPcModel.psm1"
$Separator = "--------------------------------------------------------------------------------------------------------------------------------"

#####################################################################################################
# Reclaim-CloudPCs
#####################################################################################################

<#
    .SYNOPSIS
        Reclaim-CloudPCs
    .DESCRIPTION
        Reclaim CloudPCs, include direct assigned and group based license
    .PARAMETER CloudPCBasedUrl
        The CloudPC graph based url
    .PARAMETER TenantId
        The TenantId
    .PARAMETER CloudPCListPath
        The path of the source data, it should be a csv file
#>
function Reclaim-CloudPCs {
    param (
        [string]$CloudPCBasedUrl = "https://graph.microsoft.com/beta",
        [string]$TenantId,
        [string]$CloudPCListPath
    )

    try {
        # Import Helper Module
        if (Test-Path "$PSScriptRoot\Helper.psm1")
        {
            Import-Module "$PSScriptRoot\Helper.psm1" -DisableNameChecking -Force
        } else {
            throw "Can not find module"
        } 

        # Setup Environment Config
        Setup-EnvironmentConfig -CloudPCBasedUrl $CloudPCBasedUrl -TenantId $TenantId

        # Setup Graph Config and Get Required Permission
        if ((Setup-GraphConfig -GraphScopes "CloudPC.ReadWrite.All", "Group.ReadWrite.All", "User.ReadWrite.All") -eq 1){
            throw "Failed to setup Graph Config"
        }

        # Import source data
        Write-Host $Separator
        Write-Host "Import reclaimed Cloud PCs from $CloudPCListPath"
     
        if (-Not (Test-Path $CloudPCListPath)) {
            throw "File is not exist：$CloudPCListPath"
        }

        $cloudPCInfoList = @()
        Import-Csv -Path $CloudPCListPath | ForEach-Object {
            $cloudPCModel = [CloudPcModel]::new(
            $_.CloudPcId,
            $_.DeviceName,
            $_.UserPrincipalName,
            $_.UserId,
            $_.SourceServicePlanId,
            $_.TargetServicePlanId,
            $_.ProvisionPolicyId,
            $_.SourceSkuId,
            $_.TargetSkuId,
            $_.GroupId,
            $_.LisenceAssignedGroupId)
            $cloudPCInfoList += $cloudPCModel
        }

        # Revoke the license from the user
        Write-Output $Separator
        Write-Output "Start to reclaim licenses from the users, for the group based license, we will remove the users from the source group, this may cause the user to lose existing permissions. Are you sure you want to continue?"
        $IsUserConsent = Read-Host "[Y] Yes [N] No (default is "N")"
        if ($IsUserConsent -ne "Y"){
            return
        }
    
        $cloudPCInfoList | ForEach-Object { Remove-CloudPCLicense -CloudPC $_ }

        # Deprovision Cloud PC
        Write-Output $Separator
        Write-Output "Start to end the grace period CloudPCs, we will derpovision these Cloud PCs. Are you sure you want to continue?"
        $IsUserConsent = Read-Host "[Y] Yes [N] No (default is "N")"
        if ($IsUserConsent -ne "Y"){
            return
        }

        # Wait all Cloud PCs enter grace period status
        Write-Output $Separator
        Write-Output "Wait all Cloud PCs enter grace period status"
        Show-SleepProgress -Duration 120

        $cloudPCInfoList | ForEach-Object { Deprovision-GracePeriodCloudPC -DeviceName $_.DeviceName }

        Write-Output $Separator
        Write-Output "✅ Successfully recliam license for all the CloudPCs"

    } catch {
        write-output "Failed to reclaim CloudPCs" | out-host
        write-output $_
    }
}

#####################################################################################################
# Resize-CloudPCs
#####################################################################################################

<#
    .SYNOPSIS
        Resize-CloudPCs
    .DESCRIPTION
        Resize CloudPCs, include direct assigned and group based license
    .PARAMETER CloudPCBasedUrl
        The CloudPC graph based url
    .PARAMETER TenantId
        The TenantId
    .PARAMETER CloudPCListPath
        The path of the source data, it should be a csv file
#>
function Resize-CloudPCs {
    param (
        [string]$CloudPCBasedUrl = "https://graph.microsoft.com/beta",
        [string]$TenantId,
        [string]$CloudPCListPath
    )

    try {   
        # Import Helper Module
        if (Test-Path "$PSScriptRoot\Helper.psm1")
        {
            Import-Module "$PSScriptRoot\Helper.psm1" -DisableNameChecking -Force
        } else {
            throw "Can not find module"
        }

        # Setup Environment Config
        Setup-EnvironmentConfig -CloudPCBasedUrl $CloudPCBasedUrl -TenantId $TenantId

        # Setup Graph Config and Get Required Permission
        if ((Setup-GraphConfig -GraphScopes "CloudPC.ReadWrite.All", "Group.ReadWrite.All", "User.ReadWrite.All") -eq 1){
            throw "Failed to setup Graph Config"
        }

        # Import source data
        if (-Not (Test-Path $CloudPCListPath)) {
            throw "File is not exist：$CloudPCListPath"
        }

        $cloudPCInfoList = @()
        Import-Csv -Path $CloudPCListPath | ForEach-Object {
            $cloudPCModel = [CloudPcModel]::new(
            $_.CloudPcId,
            $_.DeviceName,
            $_.UserPrincipalName,
            $_.UserId,
            $_.SourceServicePlanId,
            $_.TargetServicePlanId,
            $_.ProvisionPolicyId,
            $_.SourceSkuId,
            $_.TargetSkuId,
            $_.GroupId,
            $_.LisenceAssignedGroupId)
            $cloudPCInfoList += $cloudPCModel
        }
  
        $invalidCloudPCs = $cloudPCInfoList | Where-Object { [string]::IsNullOrWhiteSpace($_.TargetServicePlanId) }
        if ($invalidCloudPCs.Count -gt 0) {
            throw "invalid devices are founde, please check your source data"
        }

        $groupedDeviceList = $cloudPCInfoList | Group-Object -Property TargetServicePlanId
        # Validate CloudPCs status
        foreach($groupedDevice in $groupedDeviceList){
            $targetServicePlanId = $groupedDevice.Name.Split(',')[0].Trim()
            $cloudPCIds = $groupedDevice.Group | Select-Object -ExpandProperty CloudPCId

            $result = Validate-CloudPCStatus -CloudPCIds $cloudPCIds -TargetServicePlanId $targetServicePlanId
            if($result -eq 1){
                throw "There are CloudPCs that are not ready to be resized."
            }
        }
        Write-Host "✅ All the CloudPCs are ready to be resized."
        Write-Host $Separator

        # Trigger bulk resize api
        Write-Host "Start to trigger the bulk resize action. Are you sure you want to continue?"
        $IsUserConsent = Read-Host "[Y] Yes [N] No (default is "N")"
        if ($IsUserConsent -ne "Y"){
            return
        }
        foreach($groupedDevice in $groupedDeviceList) {
            $targetServicePlanId = $groupedDevice.Name.Split(',')[0].Trim()
            $cloudPCIds = $groupedDevice.Group | Select-Object -ExpandProperty CloudPCId

            Start-BulkResize -CloudPCIds $cloudPCIds -TargetServicePlanId $targetServicePlanId
        }

        # Wait for group based CloudPC enter into license pending status
        Write-Host $Separator
        Write-Host "Wait all group based license Cloud PCs enter license pending status"
        Show-SleepProgress -Duration 240

        $groupBasedLicenseDeivceList = $cloudPCInfoList | Where-Object { $_.LisenceAssignedGroupId }
        # Check the CloudPCs status
        foreach($device in $groupBasedLicenseDeivceList){
            $deviceName = $device.DeviceName
            $result = Check-CloudPCByStatus -DeviceName $device.DeviceName -Status "resizePendingLicense"
            if ($result -eq 1) {
                throw "❌ Device did not enter 'resizePendingLicense' status: $deviceName"
            }
        }

        # Remove the users from the source group
        Write-Host "Start to remove the users from the source group this may cause the user to lose existing permissions. Are you sure you want to continue?"
        $IsUserConsent = Read-Host "[Y] Yes [N] No (default is "N")"
        if ($IsUserConsent -ne "Y"){
            return
        }

        $groupedDeviceList = $groupBasedLicenseDeivceList | Group-Object -Property UserId, LisenceAssignedGroupId
        foreach($groudedDevice in $groupedDeviceList){
            $useId = $groudedDevice.Name.Split(',')[0].Trim()
            $lisenceAssignedGroupId = $groudedDevice.Name.Split(',')[1].Trim()

            Remove-MembersFromEntraGroup -GroupId $lisenceAssignedGroupId -UserId $useId
        }

        $groupedDeviceList = $groupBasedLicenseDeivceList | Group-Object -Property TargetServicePlanId
        foreach ($group in $groupedDeviceList){
            $targetServicePlan = $group.Name.Split(',')[0].Trim()
            $userIds = $group.Group | Select-Object -ExpandProperty UserId
            $skuIds = ,@($group.Group | Select-Object -ExpandProperty TargetSkuId)
            $cloudPCIds = $group.Group | Select-Object -ExpandProperty CloudPCId

            # Create new entra groups for group base license Cloud PCs
            Write-Host $Separator
            Write-Host "Start to create new entra groups for the group base license Cloud PCs. Are you sure you want to continue?"
            $IsUserConsent = Read-Host "[Y] Yes [N] No (default is "N")"
            if ($IsUserConsent -ne "Y"){
                return
            }

            $createdGroupId = Create-EntraGroup

            # Add user to the new group
            Write-Host "Start to add the users to the new group. Are you sure you want to continue?"
            $IsUserConsent = Read-Host "[Y] Yes [N] No (default is "N")"
            if ($IsUserConsent -ne "Y"){
                return
            }
            Add-MembersToEntraGroup -GroupId $createdGroupId -UserIds $userIds

            # Assign target license to the new group
            Write-Host "Start to assign the target licenses to the new group. Are you sure you want to continue?"
            $IsUserConsent = Read-Host "[Y] Yes [N] No (default is "N")"
            if ($IsUserConsent -ne "Y"){
                return
            }

            $targetSkuId = [string]$skuIds[0]
            Assign-LicenseToEntraGroup -GroupId $createdGroupId -SkuId $targetSkuId

            # Bind the new group to the source provisioning policy
            foreach($id in $cloudPCIds) {
                $deviceItem = $cloudPCInfoList | Where-Object { $_.CloudPCId -eq $id } | Select-Object -First 1
                $policyId = $deviceItem.ProvisionPolicyId

                Bind-EntraGroupToProvisioningPolicy -GroupId $createdGroupId -PolicyId $policyId
            }
        }

        Write-Host "✅ Successfully resize for all the CloudPCs"
    } catch {
        Write-Host "Failed to resize CloudPCs" | out-host
        Write-Host $_
    }
}
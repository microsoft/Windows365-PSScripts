<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>
using module ".\Model\CloudPcModel.psm1"

try {   
    # Import Helper Module
    if (Test-Path "$PSScriptRoot\Helper.psm1")
    {
        Import-Module "$PSScriptRoot\Helper.psm1" -DisableNameChecking
    } else {
        throw "Can not find module"
    }

    # Setup Environment Config
    Setup-EnvironmentConfig -CloudPCBasedUrl "https://canary.graph.microsoft.com/testprodbeta_cpc_int" -TenantId "633fc03f-56d0-459c-a1b5-ab5083fc35d4"

    # Setup Graph Config and Get Required Permission
    if (Setup-GraphConfig -eq 1){
        throw "Failed to setup Graph Config"
    }

    # Import source data
    $csvPath = "C:\repos\Windows365-PSScripts\Windows365ITCopilot\SampleData.CSV"

    if (-Not (Test-Path $csvPath)) {
        throw "File is not exist：$csvPath"
    }

    $cloudPCInfoList = @()
    Import-Csv -Path $csvPath | ForEach-Object {
        $cloudPCModel = [CloudPcModel]::new(
        $_.CloudPcId,
        $_.DeviceName,
        $_.UserPrincipalName,
        $_.UserId,
        $_.SourceServicePlanId,
        $_.TargetServicePlanId,
        ionPolicyId,
        $_.SkuId,
        $_.AssignedGroupId
        )
        $cloudPCInfoList += $cloudPCModel
    }

    # Revoke the license from the user
    Write-Output "Start to reclaim licenses from the users, for the group based license, we will remove the users from the source group, this may cause the user to lose existing permissions. Are you sure you want to continue?"
    $IsUserConsent = Read-Host "[Y] Yes [N] No (default is "N")"
    if ($IsUserConsent -ne "Y"){
        return
    }
    
    $cloudPCInfoList | ForEach-Object { Remove-CloudPCLicense -CloudPC $_ }

    # Wait all Cloud PCs enter grace period status
    Start-Sleep -Seconds 120

    # Deprovision Cloud PC
    Write-Output "Start to reclaim licenses from the users, for the group based license, we will remove the users from the source group, this may cause the user to lose existing permissions. Are you sure you want to continue?"
    $IsUserConsent = Read-Host "[Y] Yes [N] No (default is "N")"
    if ($IsUserConsent -ne "Y"){
        return
    }

    $cloudPCInfoList | ForEach-Object { Deprovision-GracePeriodCloudPC -DeviceName $_.CloudPCName }

    Write-Output "✅ Successfully recliam license for all the CloudPCs"

} catch {
    write-output "Failed to reclaim CloudPCs" | out-host
    write-output $_.Exception | Format-List * -Force
}


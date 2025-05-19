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

    # Setup Graph Config and Get Required Permission
    if (Setup-GraphConfig -eq 1) {
        throw "Failed to setup Graph Config"
    }

    # Setup Environment Config
    Setup-EnvironmentConfig -CloudPCBasedUrl "https://canary.graph.microsoft.com/testprodbeta_cpc_int" -TenantId "633fc03f-56d0-459c-a1b5-ab5083fc35d4"

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
        $_.AssignedGroupId)
        $cloudPCInfoList += $cloudPCModel
    }

    # Validate required properties

    # Validate CloudPCs status

    # Trigger bulk resize api

    # Wait for group based CloudPC enter into license pending status

    # create new entra groups

    # Add user to the new group

    # Assign target license to the new group

    # Bind the new group to the source provisioning policy

    # Remove the users from the source group

} catch {
    write-output "Failed to resize CloudPCs" | out-host
    write-output $_.Exception | Format-List * -Force
}


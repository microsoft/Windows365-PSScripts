<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

try {   
    # Import Helper Module
    if (Test-Path "$PSScriptRoot\Helper.psm1")
    {
        Import-Module "$PSScriptRoot\Helper.psm1" -DisableNameChecking
    } else {
        throw "Can not find module"
    }

    # Setup Graph Config and Get Required Permission
    if (Setup-GraphConfig -eq 1){
        throw "Failed to setup Graph Config"
    }

    # Import source data
    $csvPath = "C:\repos\Windows365-PSScripts\Windows365ITCopilot\SampleData.CSV"

    if (-Not (Test-Path $csvPath)) {
        throw "File is not exist：$csvPath"
    }

    $data = Import-Csv -Path $csvPath
    $cloudPCInfoList = @($data)

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


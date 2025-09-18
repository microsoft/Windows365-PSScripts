function invoke-foldercheck($path){
# Output directory for JSON files with timestamp
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $outputDir = $path + "W365-Configs-$timestamp"
    if (-not (Test-Path $outputDir)) {
        New-Item -Path $outputDir -ItemType Directory | Out-Null
        New-Item -Path $outputDir\provisioningpolicies -ItemType Directory | Out-Null
        New-Item -Path $outputDir\customimages -ItemType Directory | Out-Null
        New-Item -Path $outputDir\UserSettings -ItemType Directory | Out-Null
        New-Item -Path $outputDir\ANCs -ItemType Directory | Out-Null
    }
    return $outputDir
}

# Helper function to export objects as JSON
function Export-Json {
    param (
        [Parameter(Mandatory)]
        [string]$FileName,
        [Parameter(Mandatory)]
        $Object
    )
    $json = $Object | ConvertTo-Json -Depth 100 
    $json | Out-File -FilePath $FileName -Encoding utf8 
}

function get-GroupNames($CPCPPID) {
    $assignments = Get-MgBetaDeviceManagementVirtualEndpointProvisioningPolicy -CloudPcProvisioningPolicyId $CPCPPID -ExpandProperty assignments
    $groupIds = $assignments.assignments.target.AdditionalProperties.groupId

    # Get users in each group
    foreach ($groupId in $groupIds) {
        Get-MgGroup -GroupId $groupId | fl
    }
}

function invoke-bkpp($outputdir){
    
    
    # 1. Cloud PC Provisioning Policies
    $provisioningPolicies = Get-MgDeviceManagementVirtualEndpointProvisioningPolicy -ExpandProperty assignments
    foreach ($PP in $provisioningPolicies){
        $String = $outputdir + "\ProvisioningPolicies\" + $pp.DisplayName + ".json"
        $Group = Get-MgGroup -GroupId $PP.Assignments.target.AdditionalProperties.groupId
        $pp | Add-Member -MemberType NoteProperty -Name AssignedGroupNames -Value $Group.DisplayName
    
        if ($pp.ProvisioningType -eq "sharedByUser"){
        #$PP | Add-Member -MemberType NoteProperty -Name servicePlanId -Value $pp.Assignments.target.AdditionalProperties.servicePlanId
            $PP | Add-Member -MemberType NoteProperty -Name allotmentLicensesName -Value $pp.Assignments.target.AdditionalProperties.allotmentLicensesName
            $PP | Add-Member -MemberType NoteProperty -Name allotmentLicensesCount -Value $pp.Assignments.target.AdditionalProperties.allotmentLicensesCount

            $FLSP = Get-MgBetaDeviceManagementVirtualEndpointFrontLineServicePlan -CloudPcFrontLineServicePlanId $pp.Assignments.target.AdditionalProperties.servicePlanId
            $PP | Add-Member -MemberType NoteProperty -Name ServiceLicense -Value $FLSP.DisplayName
        }
        Export-Json -FileName $string -Object $pp
    }
}

function invoke-bkimages($outputdir){
    # 2. Cloud PC Images
    $images = Get-MgDeviceManagementVirtualEndpointDeviceImage
    foreach ($image in $images){
        $String = $outputdir + "\customimages\" + $image.DisplayName + ".json"
        Export-Json -FileName $String -Object $image
        }
}

function invoke-bkanc($outputdir){
# 3. Cloud PC On-Premises Connections
    $onPremConnections = Get-MgDeviceManagementVirtualEndpointOnPremiseConnection
    foreach ($ANC in $onPremConnections){
        $String = $outputdir + "\ANCs\" + $ANC.DisplayName + ".json"
        Export-Json -FileName $String -Object $ANC
    }
}

function invoke-bkusersets($outputdir){
    # 4. Cloud PC User Settings
    $userSettings = Get-MgDeviceManagementVirtualEndpointUserSetting -ExpandProperty assignments
    foreach ($setting in $usersettings){
        $String = $outputdir + "\UserSettings\" + $setting.DisplayName + ".json"
        $Group = Get-MgGroup -GroupId $userSettings.Assignments.target.AdditionalProperties.groupId
        $userSettings | Add-Member -MemberType NoteProperty -Name AssignedGroupNames -Value $Group.DisplayName
        Export-Json -FileName $String -Object $setting
    }

}


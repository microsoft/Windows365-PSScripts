function Invoke-BkPP {
    <#
    .SYNOPSIS
        Helper function to backup Cloud PC Provisioning Policies.
    #>

    param($outputdir)
    
    # 1. Cloud PC Provisioning Policies
    try {
        $provisioningPolicies = Get-MgDeviceManagementVirtualEndpointProvisioningPolicy -ExpandProperty assignments
    }
    catch {
        Write-Error "Failed to retrieve provisioning policies: $_"
        return
    }

    foreach ($PP in $provisioningPolicies) {
        try {
            $String = Join-Path $outputdir "ProvisioningPolicies\$($pp.DisplayName).json"
            $Group = Get-MgGroup -GroupId $PP.Assignments.target.AdditionalProperties.groupId
            $pp | Add-Member -MemberType NoteProperty -Name AssignedGroupNames -Value $Group.DisplayName

            if ($pp.ProvisioningType -eq "sharedByUser") {
                try {
                    $PP | Add-Member -MemberType NoteProperty -Name allotmentLicensesName -Value $pp.Assignments.target.AdditionalProperties.allotmentLicensesName
                    $PP | Add-Member -MemberType NoteProperty -Name allotmentLicensesCount -Value $pp.Assignments.target.AdditionalProperties.allotmentLicensesCount

                    $FLSP = Get-MgBetaDeviceManagementVirtualEndpointFrontLineServicePlan -CloudPcFrontLineServicePlanId $pp.Assignments.target.AdditionalProperties.servicePlanId
                    $PP | Add-Member -MemberType NoteProperty -Name ServiceLicense -Value $FLSP.DisplayName
                }
                catch {
                    Write-Warning "Failed to retrieve FrontLineServicePlan or assign properties for policy '$($pp.DisplayName)': $_"
                }
            }
            Export-Json -FileName $string -Object $pp
        }
        catch {
            Write-Warning "Error processing provisioning policy '$($pp.DisplayName)': $_"
        }
    }
}
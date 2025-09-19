function Invoke-PPRestore {
    param($JSON)
    
    try {
        $values = Get-Content -Path $JSON | ConvertFrom-Json
    } catch {
        Write-Error "Failed to read or parse JSON file: $_"
        return
    }

    try {
        $AssignmentInfo = Get-MgGroup | Where-Object { $_.DisplayName -eq $values.AssignedGroupNames }
        if (-not $AssignmentInfo) {
            Write-Error "Assigned group '$($values.AssignedGroupNames)' not found."
            return
        }
    } catch {
        Write-Error "Failed to retrieve group information: $_"
        return
    }

    $windowsSettings = $values.WindowsSetting.Locale

    $domaingjoinconfigurations = @{
        DomainJoinType          = $values.DomainJoinConfigurations.domainjointype
        OnPremsisesConnectionID = $values.DomainJoinConfigurations.OnPremisesConnectionID
        RegionGroup             = $values.DomainJoinConfigurations.RegionGroup
        RegionName              = $values.DomainJoinConfigurations.RegionName
    }

    $params = @{
        DisplayName              = $values.DisplayName
        Description              = $values.Description
        DomainJoinConfigurations = $domaingjoinconfigurations
        ImageId                  = $values.ImageId
        ProvisioningType         = $values.ProvisioningType
        WindowsSetting           = @{Locale = $windowsSettings }
        enableSingleSignOn       = $values.EnableSingleSignOn
        ImageType                = $values.ImageType
    }

    try {
        $NewPP = New-MgDeviceManagementVirtualEndpointProvisioningPolicy @params
        Write-Host "Provisioning policy created."
    } catch {
        Write-Error "Failed to create provisioning policy: $_"
        return
    }

    if ($values.ProvisioningType -eq "sharedByUser") {
        try {
            $serviceplan = Get-MgBetaDeviceManagementVirtualEndpointFrontLineServicePlan | Where-Object { $_.DisplayName -eq $values.ServiceLicense }
            if (-not $serviceplan) {
                Write-Error "Service plan '$($values.ServiceLicense)' not found."
                return
            }
        } catch {
            Write-Error "Failed to retrieve service plan: $_"
            return
        }

        $params = @{
            assignments = @(
                @{
                    target = @{
                        "@odata.type"          = "microsoft.graph.cloudPcManagementGroupAssignmentTarget"
                        groupId                = $AssignmentInfo.Id
                        allotmentLicensesName  = $values.allotmentLicensesName
                        allotmentLicensesCount = $values.allotmentLicensesName
                        servicePlanID          = $serviceplan.Id
                    }
                }
            )
        }
    }

    if ($values.ProvisioningType -eq "dedicated") {
        $params = @{
            assignments = @(
                @{
                    target = @{
                        "@odata.type" = "microsoft.graph.cloudPcManagementGroupAssignmentTarget"
                        groupId       = $AssignmentInfo.Id
                    }
                }
            )
        }
    }

    try {
        Set-MgDeviceManagementVirtualEndpointProvisioningPolicy -CloudPcProvisioningPolicyId $NewPP.id -BodyParameter $params
    } catch {
        Write-Error "Failed to set provisioning policy assignments: $_"
        return
    }
}
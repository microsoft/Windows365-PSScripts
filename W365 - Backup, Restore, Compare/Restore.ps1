# Connect to Microsoft Graph

#$JSON = "C:\temp\CC\W365-Configs-20250825_233813\provisioningpolicies\FLD.json"

function invoke-PPrestore($JSON){
    $values = get-content -path $JSON | ConvertFrom-Json
    $AssignmentInfo = get-mggroup | Where-Object {$_.DisplayName -eq $values.AssignedGroupNames}

    $windowsSettings = $values.WindowsSetting.Locale #This is sus

    $domaingjoinconfigurations = @{
        DomainJoinType = $values.DomainJoinConfigurations.domainjointype
        OnPremsisesConnectionID = $values.DomainJoinConfigurations.OnPremisesConnectionID
        RegionGroup = $values.DomainJoinConfigurations.RegionGroup
        RegionName = $values.DomainJoinConfigurations.RegionName
    }

# Create the provisioning policy
    $params = @{
        DisplayName = $values.DisplayName
        Description = $values.Description
        DomainJoinConfigurations = $domaingjoinconfigurations
        ImageId = $values.ImageId
        ProvisioningType = $values.ProvisioningType
        WindowsSetting = @{Locale = $windowsSettings} #This is sus
        enableSingleSignOn = $values.EnableSingleSignOn
        ImageType = $values.ImageType
    }

# If you need to specify on-premises connection, add it to params
#if ($onPremisesConnectionId -ne "") {
#    $params["OnPremisesConnectionId"] = $onPremisesConnectionId
#}

    $NewPP = New-MgDeviceManagementVirtualEndpointProvisioningPolicy @params

    Write-Host "Provisioning policy created."

    if ($values.ProvisioningType -eq "sharedByUser"){
        $serviceplan = Get-MgBetaDeviceManagementVirtualEndpointFrontLineServicePlan | Where-Object {$_.DisplayName -eq $values.ServiceLicense}

        $params = @{
    	    assignments = @(
    		@{
    			target = @{
    				"@odata.type" = "microsoft.graph.cloudPcManagementGroupAssignmentTarget"
    				groupId = $AssignmentInfo.Id
                    allotmentLicensesName = $values.allotmentLicensesName
                    allotmentLicensesCount = $values.allotmentLicensesName
                    servicePlanID = $serviceplan.Id
    			}
    		}
    	)
        }
    }

    if ($values.ProvisioningType -eq "dedicated"){

    
        $params = @{
    	    assignments = @(
    		@{
    			target = @{
    				"@odata.type" = "microsoft.graph.cloudPcManagementGroupAssignmentTarget"
    				groupId = $AssignmentInfo.Id
                    
                    
    			}
    		}
    	)
        }
    }

    Set-MgDeviceManagementVirtualEndpointProvisioningPolicy -CloudPcProvisioningPolicyId $NewPP.id -BodyParameter $Params
}

function invoke-USrestore($JSON){

    $values = get-content -path $JSON | ConvertFrom-Json
    $AssignmentInfo = get-mggroup | Where-Object {$_.DisplayName -eq $values.AssignedGroupNames}

    $params = @{
    	"@odata.type" = "#microsoft.graph.cloudPcUserSetting"
    	displayName = $values.DisplayName
    	localAdminEnabled = $values.LocalAdminEnabled
        ResetEnabled = $values.ResetEnabled
    	restorePointSetting = @{
    		frequencyType = $values.RestorePointSetting.FrequencyType
    		userRestoreEnabled = $values.RestorePointSetting.UserRestoreEnabled
    	}
    }

    $setting = New-MgDeviceManagementVirtualEndpointUserSetting -BodyParameter $params

    $string = $setting.id + "_" + $assignmentinfo.Id

    $params = @{
    	assignments = @(
    		@{
    			id = $string
    			target = @{
    				"@odata.type" = "microsoft.graph.cloudPcManagementGroupAssignmentTarget"
    				groupId = $AssignmentInfo.Id
    			}
    		}
    	)
    }

    Set-MgDeviceManagementVirtualEndpointUserSetting -CloudPcUserSettingId $setting.Id -BodyParameter $params

}


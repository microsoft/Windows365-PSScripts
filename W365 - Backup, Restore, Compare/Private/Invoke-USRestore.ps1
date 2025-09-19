function Invoke-USRestore {
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

	$params = @{
		"@odata.type"       = "#microsoft.graph.cloudPcUserSetting"
		displayName         = $values.DisplayName
		localAdminEnabled   = $values.LocalAdminEnabled
		ResetEnabled        = $values.ResetEnabled
		restorePointSetting = @{
			frequencyType      = $values.RestorePointSetting.FrequencyType
			userRestoreEnabled = $values.RestorePointSetting.UserRestoreEnabled
		}
	}

	try {
		$setting = New-MgDeviceManagementVirtualEndpointUserSetting -BodyParameter $params
	} catch {
		Write-Error "Failed to create user setting: $_"
		return
	}

	$string = $setting.id + "_" + $AssignmentInfo.Id

	$params = @{
		assignments = @(
			@{
				id     = $string
				target = @{
					"@odata.type" = "microsoft.graph.cloudPcManagementGroupAssignmentTarget"
					groupId       = $AssignmentInfo.Id
				}
			}
		)
	}

	try {
		Set-MgDeviceManagementVirtualEndpointUserSetting -CloudPcUserSettingId $setting.Id -BodyParameter $params
	} catch {
		Write-Error "Failed to assign user setting: $_"
		return
	}
}
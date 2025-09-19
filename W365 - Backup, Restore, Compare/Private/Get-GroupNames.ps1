function Get-GroupNames {
    param($CPCPPID)
    
    try {
        $assignments = Get-MgBetaDeviceManagementVirtualEndpointProvisioningPolicy -CloudPcProvisioningPolicyId $CPCPPID -ExpandProperty assignments
        if (-not $assignments) {
            Write-Warning "No assignments found for policy ID $CPCPPID."
            return
        }

        $groupIds = $assignments.assignments.target.AdditionalProperties.groupId
        if (-not $groupIds) {
            Write-Warning "No group IDs found in assignments."
            return
        }

        foreach ($groupId in $groupIds) {
            try {
                $group = Get-MgGroup -GroupId $groupId
                if ($group) {
                    $group | Format-List
                } else {
                    Write-Warning "Group with ID $groupId not found."
                }
            } catch {
                Write-Warning "Error retrieving group with ID $groupId : $_"
            }
        }
    } catch {
        Write-Error "Failed to get assignments for policy ID $CPCPPID : $_"
    }
}
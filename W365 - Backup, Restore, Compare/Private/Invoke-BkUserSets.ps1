function Invoke-BkUserSets {
    <#
    .SYNOPSIS
        Helper function to backup Cloud PC User Settings.
    #>

    param($outputdir)
    
    # 4. Cloud PC User Settings
    try {
        $userSettings = Get-MgDeviceManagementVirtualEndpointUserSetting -ExpandProperty assignments
    }
    catch {
        Write-Error "Failed to retrieve user settings: $_"
        return
    }

    foreach ($setting in $userSettings) {
        try {
            $String = Join-Path -Path $outputdir -ChildPath ("UserSettings\" + $setting.DisplayName + ".json")
            $groupId = $setting.Assignments.target.AdditionalProperties.groupId
            try {
                $Group = Get-MgGroup -GroupId $groupId
                $setting | Add-Member -MemberType NoteProperty -Name AssignedGroupNames -Value $Group.DisplayName -Force
            }
            catch {
                Write-Warning "Failed to retrieve group for GroupId '$groupId': $_"
                $setting | Add-Member -MemberType NoteProperty -Name AssignedGroupNames -Value $null -Force
            }
            Export-Json -FileName $String -Object $setting
        }
        catch {
            Write-Warning "Failed to process setting '$($setting.DisplayName)': $_"
        }
    }
}
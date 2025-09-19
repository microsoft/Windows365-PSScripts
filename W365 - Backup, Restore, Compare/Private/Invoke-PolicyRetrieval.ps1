function Invoke-PolicyRetrieval {
    $options = @(
        [PSCustomObject]@{ Option = "Provisioning Policy" }
        [PSCustomObject]@{ Option = "User Setting" }
        [PSCustomObject]@{ Option = "Azure Network Connection" }
        [PSCustomObject]@{ Option = "Custom Image" }
    )

    try {
        $selected = $options | Out-GridView -Title "Select an Option" -PassThru
        if ($null -eq $selected) {
            Write-Host "No option selected. Exiting."
            return
        }
        Write-Host $selected

        switch ($selected.Option) {
            "Provisioning Policy" {
                try {
                    $Policy = Get-MgDeviceManagementVirtualEndpointProvisioningPolicy | Select-Object DisplayName, Id | Out-GridView -Title "Select Provisioning Policy from Intune" -PassThru
                    if ($null -eq $Policy) {
                        Write-Host "No provisioning policy selected. Exiting."
                        return
                    }
                    Write-Host "You selected: $($selected.Option)"
                    Write-Host $Policy | Format-List

                    $string = "C:\Windows\temp\provisioningpolicies\" + $Policy.DisplayName + ".json"
                    Write-Host $string

                    if (-not (Test-Path -Path 'c:\windows\temp\provisioningpolicies')) {
                        New-Item -Path 'C:\windows\temp\provisioningpolicies' -ItemType Directory -Force | Out-Null
                    }
                    Invoke-BkPP -outputdir C:\windows\Temp
                    Write-Host

                    $backup = Select-FileDialog
                    if ($null -eq $backup) {
                        Write-Host "A backup policy was not selected. Please try again."
                        return
                    }
                    Write-Host $backup

                    Invoke-Compare -JSON1 $string -JSON2 $backup
                } catch {
                    Write-Host "Error during Provisioning Policy selection or backup: $_"
                }
            }
            "User Setting" {
                try {
                    $Policy = Get-MgDeviceManagementVirtualEndpointUserSetting | Select-Object DisplayName, Id | Out-GridView -Title "Select Provisioning Policy" -PassThru
                    if ($null -eq $Policy) {
                        Write-Host "No user setting selected. Exiting."
                        return
                    }
                    Write-Host "You selected: $($selected.Option)"
                    Write-Host $Policy | Format-List
                } catch {
                    Write-Host "Error during User Setting selection: $_"
                }
            }
            "Azure Network Connection" {
                try {
                    $Policy = Get-MgDeviceManagementVirtualEndpointOnPremiseConnection | Select-Object DisplayName, Id | Out-GridView -Title "Select Provisioning Policy" -PassThru
                    if ($null -eq $Policy) {
                        Write-Host "No Azure Network Connection selected. Exiting."
                        return
                    }
                    Write-Host "You selected: $($selected.Option)"
                    Write-Host $Policy | Format-List
                } catch {
                    Write-Host "Error during Azure Network Connection selection: $_"
                }
            }
            "Custom Image" {
                try {
                    $Policy = Get-MgDeviceManagementVirtualEndpointDeviceImage | Select-Object DisplayName, Id | Out-GridView -Title "Select Provisioning Policy" -PassThru
                    if ($null -eq $Policy) {
                        Write-Host "No custom image selected. Exiting."
                        return
                    }
                    Write-Host "You selected: $($selected.Option)"
                    Write-Host $Policy | Format-List
                } catch {
                    Write-Host "Error during Custom Image selection: $_"
                }
            }
            default {
                Write-Host "Unknown option selected."
            }
        }
    } catch {
        Write-Host "An unexpected error occurred: $_"
    }
}
function invoke-compare ($JSON1,$JSON2) {# Specify the paths to your JSON files
    #$jsonPath1 = "C:\temp\CC\W365-Configs-20250820_142405\provisioningpolicies\test.json"
    #$jsonPath2 = "C:\temp\CC\W365-Configs-20250820_142631\provisioningpolicies\TestTestTest.json"

    # Read and convert both JSON files to PowerShell objects
    $obj1 = Get-Content -Path $json1 | ConvertFrom-Json
    $obj2 = Get-Content -Path $json2 | ConvertFrom-Json

    # Get all property names from both objects
    $allProps = ($obj1.PSObject.Properties.Name + $obj2.PSObject.Properties.Name) | Sort-Object -Unique

    foreach ($prop in $allProps) {
        $val1 = $obj1.$prop
        $val2 = $obj2.$prop

        # Check if both values are arrays
        #if ($val1 -is [System.Collections.IEnumerable] -and $val1 -isnot [string] -and
        #    $val2 -is [System.Collections.IEnumerable] -and $val2 -isnot [string]) {
            if (($val1 -ne $null) -and ($val2 -ne $null)){
            #write-host "Not Null"
                $diff = Compare-Object -ReferenceObject $val1 -DifferenceObject $val2
                if ($diff) {
                    Write-Host "Property '$prop' (array) differs:"
                    $diff | ForEach-Object {
                        Write-Host "  $($_.SideIndicator) $($_.InputObject)"
                    }
            
                }
    
    # If not arrays, compare directly
    #elseif ($val1 -ne $val2) {
        #Write-Host "Property '$prop' differs:`n  File1: $val1`n  File2: $val2`n"
        }
    
    }
}

function invoke-policyretrieval{
    $options = @(
    [PSCustomObject]@{ Option = "Provisioning Policy" }
    [PSCustomObject]@{ Option = "User Setting" }
    [PSCustomObject]@{ Option = "Azure Network Connection" }
    [PSCustomObject]@{ Option = "Custom Image" }
    )

    $selected = $options | Out-GridView -Title "Select an Option" -PassThru
    write-host $selected

    if ($selected.option -eq "Provisioning Policy") {
        $Policy = Get-MgDeviceManagementVirtualEndpointProvisioningPolicy | Select-Object DisplayName, Id | Out-GridView -Title "Select Provisioning Policy from Intune" -PassThru
        Write-Host "You selected: $($selected.Option)"
        write-host $Policy | fl
        
        $string = "C:\Windows\temp\provisioningpolicies\" + $policy.displayname + ".json"
        write-host $string

        if ((test-path -Path 'c:\windows\temp\provisioningpolicies') -eq $false ){New-Item -Path 'C:\windows\temp\provisioningpolicies' -ItemType Directory -Force Out-Null}
        invoke-bkpp -outputdir C:\windows\Temp
        Write-Host


        $backup = Select-FileDialog
        if ($backup -eq $null){write-host "A backup policy was not selected. Please try again"
            exit 1
            }
        write-host $backup
    
    invoke-compare -JSON1 $string -JSON2 $backup
    
    
    }

    if ($selected.option -eq "User Setting") {
        $Policy = Get-MgDeviceManagementVirtualEndpointUserSetting | Select-Object DisplayName, Id | Out-GridView -Title "Select Provisioning Policy" -PassThru
        Write-Host "You selected: $($selected.Option)"
        write-host $Policy | fl
    }

    if ($selected.option -eq "Azure Network Connection") {
        $Policy = Get-MgDeviceManagementVirtualEndpointOnPremiseConnection | Select-Object DisplayName, Id | Out-GridView -Title "Select Provisioning Policy" -PassThru
        Write-Host "You selected: $($selected.Option)"
        write-host $Policy | fl
    }

    if ($selected.option -eq "Custom Image") {
        $Policy = Get-MgDeviceManagementVirtualEndpointDeviceImage | Select-Object DisplayName, Id | Out-GridView -Title "Select Provisioning Policy" -PassThru
        Write-Host "You selected: $($selected.Option)"
        write-host $Policy | fl
    }

}

function Select-FileDialog {
    param(
        [string]$Title = 'Select a file',
        [string]$InitialDirectory = [Environment]::GetFolderPath('Desktop'),
        [string]$Filter = 'JSON Files (*.json)|*.json',
        [switch]$MultiSelect
    )

    Add-Type -AssemblyName System.Windows.Forms

    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = $Title
    $dlg.InitialDirectory = $InitialDirectory
    $dlg.Filter = $Filter
    $dlg.Multiselect = $MultiSelect.IsPresent

    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        if ($dlg.Multiselect) { return $dlg.FileNames } else { return $dlg.FileName }
    }

    return $null
}


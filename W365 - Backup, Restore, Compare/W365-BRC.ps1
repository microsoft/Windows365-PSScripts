
function invoke-W365Restore{
        param(
        [ValidateSet("ProvisioningPolicy","UserSetting","AzureNetworkConnection")]
        [string]$Object,
        [String]$JSON
    )
    $graph = Connect-MgGraph -Scopes "CloudPC.ReadWrite.All"
    
    If ($JSON -eq $null){
        
        Add-Type -AssemblyName System.Windows.Forms
        $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $OpenFileDialog.ShowDialog() | Out-Null
        $JSON = $OpenFileDialog.FileName
        Write-Host "Selected file: $JSON"

    }

    If ($Object -eq "ProvisioningPolicy"){invoke-PPrestore -JSON $JSON}
    If ($Object -eq "UserSetting"){invoke-USrestore -JSON $JSON }
    If ($Object -eq "AzureNetworkConnection"){write-host "Feature coming soon!"}
}

function invoke-W365Backup{
        param(
        [ValidateSet("ProvisioningPolicy","CustomImages","UserSetting","AzureNetworkConnection","All")]
        [string]$Object,
        [String]$Path = "c:\W365-Policy-Backup\"
    )
    $GraphInfo = Connect-MgGraph -Scopes "CloudPC.Read.All","DeviceManagementConfiguration.Read.All"
    $outputdir = invoke-foldercheck -Path $Path

    If ($Object -eq "ProvisioningPolicy"){invoke-bkpp -outputdir $outputdir}
    if ($Object -eq "CustomImages"){invoke-bkimages -outputdir $outputdir}
    If ($Object -eq "UserSetting"){invoke-bkusersets -outputdir $outputdir}
    If ($Object -eq "AzureNetworkConnection"){invoke-bkanc -outputdir $outputdir}
    If ($Object -eq "All"){
        invoke-bkpp -outputdir $outputdir
        invoke-bkimages -outputdir $outputdir
        invoke-bkusersets -outputdir $outputdir
        invoke-bkanc -outputdir $outputdir
    }
}

function invoke-W365Compare {
    $GraphInfo = Connect-MgGraph -Scopes "CloudPC.Read.All","DeviceManagementConfiguration.Read.All"
    invoke-policyretrieval
    }

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

function invoke-compare ($JSON1,$JSON2) {# Specify the paths to your JSON files

    # Read and convert both JSON files to PowerShell objects
    $obj1 = Get-Content -Path $json1 | ConvertFrom-Json
    $obj2 = Get-Content -Path $json2 | ConvertFrom-Json

    # Get all property names from both objects
    $allProps = ($obj1.PSObject.Properties.Name + $obj2.PSObject.Properties.Name) | Sort-Object -Unique

    foreach ($prop in $allProps) {
        $val1 = $obj1.$prop
        $val2 = $obj2.$prop

        # Check if both values are arrays
            if (($val1 -ne $null) -and ($val2 -ne $null)){
                $diff = Compare-Object -ReferenceObject $val1 -DifferenceObject $val2
                if ($diff) {
                    Write-Host "Property '$prop' (array) differs:"
                    $diff | ForEach-Object {
                        Write-Host "  $($_.SideIndicator) $($_.InputObject)"
                    }
            
                }
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

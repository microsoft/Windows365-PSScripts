function Invoke-W365Backup {
    <#
    .SYNOPSIS
        Backup Windows 365 configuration objects to JSON files.
    
    .DESCRIPTION
        Creates timestamped backup of Windows 365 objects including provisioning policies,
        custom images, user settings, and Azure network connections.
    
    .PARAMETER Object
        Specifies which object type to backup.
    
    .PARAMETER Path
        Specifies the backup directory path. Default is "c:\W365-Policy-Backup\".
    
    .EXAMPLE
        Invoke-W365Backup -Object "All"
        
    .EXAMPLE
        Invoke-W365Backup -Object "ProvisioningPolicy" -Path "C:\Backup\"
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("ProvisioningPolicy","CustomImages","UserSetting","AzureNetworkConnection","All")]
        [string]$Object,
        [String]$Path = "c:\W365-Policy-Backup\"
    )
    
    Connect-MgGraph -Scopes "CloudPC.Read.All","DeviceManagementConfiguration.Read.All" | Out-Null
    $outputdir = Invoke-FolderCheck -Path $Path

    If ($Object -eq "ProvisioningPolicy"){Invoke-BkPP -outputdir $outputdir}
    if ($Object -eq "CustomImages"){Invoke-BkImages -outputdir $outputdir}
    If ($Object -eq "UserSetting"){Invoke-BkUserSets -outputdir $outputdir}
    If ($Object -eq "AzureNetworkConnection"){Invoke-BkANC -outputdir $outputdir}
    If ($Object -eq "All"){
        Invoke-BkPP -outputdir $outputdir
        Invoke-BkImages -outputdir $outputdir
        Invoke-BkUserSets -outputdir $outputdir
        Invoke-BkANC -outputdir $outputdir
    }
}
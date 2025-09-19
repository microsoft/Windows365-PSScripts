function Invoke-W365Restore {
    <#
    .SYNOPSIS
        Restore Windows 365 configuration objects from JSON backup files.
    
    .DESCRIPTION
        Restores Windows 365 objects from JSON backup files created with Invoke-W365Backup.
    
    .PARAMETER Object
        Specifies which object type to restore.
    
    .PARAMETER JSON
        Path to the JSON backup file. If not specified, a file dialog will open.
    
    .EXAMPLE
        Invoke-W365Restore -Object "ProvisioningPolicy" -JSON "C:\Backup\policy.json"
        
    .EXAMPLE
        Invoke-W365Restore -Object "UserSetting"
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("ProvisioningPolicy","UserSetting","AzureNetworkConnection")]
        [string]$Object,
        [String]$JSON
    )
    
    Connect-MgGraph -Scopes "CloudPC.ReadWrite.All" | Out-Null
    
    If ($JSON -eq $null){
        Add-Type -AssemblyName System.Windows.Forms
        $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $OpenFileDialog.ShowDialog() | Out-Null
        $JSON = $OpenFileDialog.FileName
        Write-Host "Selected file: $JSON"
    }

    If ($Object -eq "ProvisioningPolicy"){Invoke-PPRestore -JSON $JSON}
    If ($Object -eq "UserSetting"){Invoke-USRestore -JSON $JSON }
    If ($Object -eq "AzureNetworkConnection"){write-host "Feature coming soon!"}
}
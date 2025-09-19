function Invoke-W365Compare {
    <#
    .SYNOPSIS
        Compare current Windows 365 configuration with backup files.
    
    .DESCRIPTION
        Compares current Windows 365 configuration objects with backup JSON files
        to identify differences and changes.
    
    .EXAMPLE
        Invoke-W365Compare
    #>
    [CmdletBinding()]
    param()
    
    Connect-MgGraph -Scopes "CloudPC.Read.All","DeviceManagementConfiguration.Read.All" | Out-Null
    Invoke-PolicyRetrieval
}
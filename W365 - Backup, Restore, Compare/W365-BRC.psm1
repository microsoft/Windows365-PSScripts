<#	
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2025 v5.9.259
	 Created on:   	18-09-2025 20:02
	 Created by:   	Michael Morten Sonne
	 Organization: 	Sonne´s Cloud - blog.sonnes.cloud
	 Filename:     	W365-BRC.psm1
	-------------------------------------------------------------------------
	 Module Name: W365-BRC
	===========================================================================
#>

# Get public and private function definition files
$Public = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue)

# Dot source the files
foreach ($import in @($Public + $Private)) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error -Message "Failed to import function $($import.FullName): $_"
    }
}

# Export only public functions
Export-ModuleMember -Function Invoke-W365Backup, Invoke-W365Restore, Invoke-W365Compare
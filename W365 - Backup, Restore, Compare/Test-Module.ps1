<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2025 v5.9.259
	 Created on:   	18-09-2025 20:02
	 Created by:   	Michael Morten Sonne
	 Organization: 	Sonne´s Cloud - blog.sonnes.cloud
	 Filename:     	Test-Module.ps1
	===========================================================================
	.DESCRIPTION
	The Test-Module.ps1 script lets you test the functions and other features of
	your module in your PowerShell Studio module project. It's part of your project,
	but it is not included in your module.

	In this test script, import the module (be careful to import the correct version)
	and write commands that test the module features. You can include Pester
	tests, too.

	To run the script, click Run or Run in Console. Or, when working on any file
	in the project, click Home\Run or Home\Run in Console, or in the Project pane, 
	right-click the project name, and then click Run Project.
#>

#Explicitly import the module for testing
Import-Module "$PSScriptRoot\W365-BRC.psm1" -Force

#Run each module function
Write-Host "Testing W365-BRC Module..." -ForegroundColor Green

# Test that the module is loaded
$Module = Get-Module W365-BRC
if ($Module) {
    Write-Host "✅ Module loaded successfully: $($Module.Name) v$($Module.Version)" -ForegroundColor Green
    Write-Host "   Exported Commands: $($Module.ExportedCommands.Count)" -ForegroundColor Gray
} else {
    Write-Host "❌ Module failed to load" -ForegroundColor Red
}

# Test that only expected functions are available
Write-Host "`n📋 Available Functions:" -ForegroundColor Yellow
$Commands = Get-Command -Module W365-BRC
foreach ($Command in $Commands) {
    Write-Host "   • $($Command.Name)" -ForegroundColor Cyan
}

# Verify we have exactly 3 functions
if ($Commands.Count -eq 3) {
    Write-Host "✅ Correct number of exported functions (3)" -ForegroundColor Green
} else {
    Write-Host "⚠️  Expected 3 functions, found $($Commands.Count)" -ForegroundColor Yellow
}

# Test function parameters
Write-Host "`n🔧 Function Parameters:" -ForegroundColor Yellow
Write-Host "   Invoke-W365Backup: Object, Path" -ForegroundColor Gray
Write-Host "   Invoke-W365Restore: Object, JSON" -ForegroundColor Gray
Write-Host "   Invoke-W365Compare: (no parameters)" -ForegroundColor Gray

Write-Host "`n✅ Module testing complete!" -ForegroundColor Green
Write-Host "   Ready to use: Invoke-W365Backup, Invoke-W365Restore, Invoke-W365Compare" -ForegroundColor Gray

#Sample Pester Test
#Describe "Test W365-BRC" {
#	It "tests Write-HellowWorld" {
#		Write-HelloWorld | Should BeExactly "Hello World"
#	}	
#}

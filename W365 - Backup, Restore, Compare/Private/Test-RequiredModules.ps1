<#	
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2025 v5.9.259
	 Created on:   	02-10-2025
	 Created by:   	Michael Morten Sonne
	 Organization: 	Sonne´s Cloud - blog.sonnes.cloud
	 Filename:     	Test-RequiredModules.ps1
	-------------------------------------------------------------------------
	 Function Name: Test-RequiredModules
	===========================================================================
#>

<#
.SYNOPSIS
    Tests for and installs required PowerShell modules for Windows 365 operations.

.DESCRIPTION
    This function checks if the required PowerShell modules are installed and optionally installs them if missing.
    It supports both interactive and automated installation scenarios for Windows 365 backup, restore, and compare operations.

.PARAMETER InstallMissing
    If specified, automatically installs any missing modules without prompting.

.PARAMETER Force
    Forces reinstallation of modules even if they're already present.

.PARAMETER Scope
    Specifies the installation scope. Valid values are 'CurrentUser' (default) or 'AllUsers'.

.EXAMPLE
    Test-RequiredModules
    Checks for required modules and prompts to install missing ones.

.EXAMPLE
    Test-RequiredModules -InstallMissing
    Automatically installs any missing required modules.

.EXAMPLE
    Test-RequiredModules -Force -Scope AllUsers
    Forces reinstallation of all modules for all users.

.NOTES
    This function is part of the W365-BRC module for Windows 365 operations.
    It ensures that all required Microsoft Graph modules are available for Cloud PC management.
#>
function Test-RequiredModules {
    [CmdletBinding()]
    param(
        [switch]$InstallMissing,
        [switch]$Force,
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$Scope = 'CurrentUser'
    )

    # Define required modules for Windows 365 operations
    $RequiredModules = @(
        @{
            Name = 'Microsoft.Graph.Authentication'
            MinimumVersion = '2.28.0'
            Description = 'Microsoft Graph Authentication module for connecting to Graph API'
        },
        @{
            Name = 'Microsoft.Graph.DeviceManagement'
            MinimumVersion = '2.28.0'
            Description = 'Microsoft Graph Device Management module for managing Cloud PCs'
        },
        @{
            Name = 'Microsoft.Graph.Identity.DirectoryManagement'
            MinimumVersion = '2.28.0'
            Description = 'Microsoft Graph Directory Management module for Azure AD operations'
        },
        @{
            Name = 'Microsoft.Graph.Groups'
            MinimumVersion = '2.28.0'
            Description = 'Microsoft Graph Groups module for managing Azure AD groups'
        },
        @{
            Name = 'Microsoft.Graph.Applications'
            MinimumVersion = '2.28.0'
            Description = 'Microsoft Graph Applications module for app registrations'
        }
    )

    $MissingModules = @()
    $OutdatedModules = @()

    Write-Verbose "Checking required PowerShell modules for W365-BRC operations..."

    foreach ($Module in $RequiredModules) {
        try {
            $InstalledModule = Get-Module -Name $Module.Name -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
            
            if (-not $InstalledModule) {
                Write-Warning "Module '$($Module.Name)' is not installed."
                $MissingModules += $Module
            }
            elseif ($InstalledModule.Version -lt [Version]$Module.MinimumVersion) {
                Write-Warning "Module '$($Module.Name)' version $($InstalledModule.Version) is outdated. Minimum required: $($Module.MinimumVersion)"
                $OutdatedModules += $Module
            }
            else {
                Write-Verbose "Module '$($Module.Name)' version $($InstalledModule.Version) is installed and up to date."
            }
        }
        catch {
            Write-Error "Error checking module '$($Module.Name)': $($_.Exception.Message)"
            $MissingModules += $Module
        }
    }

    # Handle missing or outdated modules
    $ModulesToInstall = $MissingModules + $OutdatedModules

    if ($ModulesToInstall.Count -eq 0 -and -not $Force) {
        Write-Host "✓ All required modules are installed and up to date." -ForegroundColor Green
        return $true
    }

    if ($Force) {
        $ModulesToInstall = $RequiredModules
        Write-Host "Force installation requested. Will reinstall all required modules." -ForegroundColor Yellow
    }

    if ($InstallMissing -or $Force) {
        Write-Host "Installing/updating required modules..." -ForegroundColor Yellow
        
        # Check if running as administrator for AllUsers scope
        if ($Scope -eq 'AllUsers') {
            $CurrentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
            if (-not $CurrentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                Write-Warning "Installing modules for 'AllUsers' requires administrator privileges. Switching to 'CurrentUser' scope."
                $Scope = 'CurrentUser'
            }
        }
        
        foreach ($Module in $ModulesToInstall) {
            try {
                Write-Host "Installing module: $($Module.Name)" -ForegroundColor Cyan
                
                $InstallParams = @{
                    Name = $Module.Name
                    MinimumVersion = $Module.MinimumVersion
                    Force = $Force
                    AllowClobber = $true
                    Scope = $Scope
                    Repository = 'PSGallery'
                }
                
                # Ensure PSGallery is trusted for automated installation
                if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne 'Trusted') {
                    Write-Verbose "Setting PSGallery as trusted repository"
                    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
                }
                
                Install-Module @InstallParams -ErrorAction Stop
                Write-Host "✓ Successfully installed: $($Module.Name)" -ForegroundColor Green
            }
            catch {
                Write-Error "✗ Failed to install module '$($Module.Name)': $($_.Exception.Message)"
                return $false
            }
        }
        
        Write-Host "✓ All required modules have been installed successfully." -ForegroundColor Green
    }
    else {
        Write-Host "`nThe following modules need to be installed for W365-BRC operations:" -ForegroundColor Yellow
        foreach ($Module in $ModulesToInstall) {
            Write-Host "  • $($Module.Name) (v$($Module.MinimumVersion)+): $($Module.Description)" -ForegroundColor White
        }
        
        $Response = Read-Host "`nWould you like to install the missing modules now? (Y/N)"
        if ($Response -match '^[Yy]') {
            return Test-RequiredModules -InstallMissing -Scope $Scope
        }
        else {
            Write-Warning "Required modules are not installed. Some W365-BRC functions may not work properly."
            return $false
        }
    }

    return $true
}
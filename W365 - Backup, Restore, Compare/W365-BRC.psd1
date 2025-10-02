﻿<#	
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2025 v5.9.259
	 Created on:   	18-09-2025 20:02
	 Created by:   	Michael Morten Sonne
	 Organization: 	Sonne´s Cloud - blog.sonnes.cloud
	 Filename:     	W365-BRC.psd1
	 -------------------------------------------------------------------------
	 Module Manifest
	-------------------------------------------------------------------------
	 Module Name: W365-BRC
	===========================================================================
#>

@{
	
	# Script module or binary module file associated with this manifest
	RootModule = 'W365-BRC.psm1'
	
	# Version number of this module.
	ModuleVersion = '1.0.0.0'
	
	# ID used to uniquely identify this module
	GUID = '855edbf4-2b44-4565-aa4f-2152ac351164'
	
	# Author of this module
	Author = 'Donna Ryan and Michael Morten Sonne'
	
	# Company or vendor of this module
	CompanyName = 'Microsoft Corporation'
	
	# Copyright statement for this module
	Copyright = '(c) 2025. All rights reserved.'
	
	# Description of the functionality provided by this module
	Description = 'Module to Backup, Restore and Compare Windows 365 configurations.'
	
	# Supported PSEditions
	# CompatiblePSEditions = @('Core', 'Desktop')
	
	# Minimum version of the Windows PowerShell engine required by this module
	PowerShellVersion = '5.1'
	
	# Name of the Windows PowerShell host required by this module
	PowerShellHostName = ''
	
	# Minimum version of the Windows PowerShell host required by this module
	PowerShellHostVersion = ''
	
	# Minimum version of the .NET Framework required by this module
	DotNetFrameworkVersion = '4.5.2'
	
	# Minimum version of the common language runtime (CLR) required by this module
	# CLRVersion = ''
	
	# Processor architecture (None, X86, Amd64, IA64) required by this module
	ProcessorArchitecture = 'None'
	
	# Modules that must be imported into the global environment prior to importing
	# this module
	RequiredModules = @(
		@{ ModuleName = 'Microsoft.Graph.Authentication'; ModuleVersion = '2.0.0' },
		@{ ModuleName = 'Microsoft.Graph.DeviceManagement'; ModuleVersion = '2.0.0' },
		@{ ModuleName = 'Microsoft.Graph.Identity.DirectoryManagement'; ModuleVersion = '2.0.0' },
		@{ ModuleName = 'Microsoft.Graph.Groups'; ModuleVersion = '2.0.0' },
		@{ ModuleName = 'Microsoft.Graph.Applications'; ModuleVersion = '2.0.0' }
	)
	
	# Assemblies that must be loaded prior to importing this module
	RequiredAssemblies = @()
	
	# Script files (.ps1) that are run in the caller's environment prior to
	# importing this module
	ScriptsToProcess = @()
	
	# Type files (.ps1xml) to be loaded when importing this module
	TypesToProcess = @()
	
	# Format files (.ps1xml) to be loaded when importing this module
	FormatsToProcess = @()
	
	# Modules to import as nested modules of the module specified in
	# ModuleToProcess
	NestedModules = @()
	
	# Functions to export from this module
	FunctionsToExport = @('Invoke-W365Backup', 'Invoke-W365Restore', 'Invoke-W365Compare', 'Test-RequiredModules')
	
	# Cmdlets to export from this module
	CmdletsToExport = '*' 
	
	# Variables to export from this module
	VariablesToExport = '*'
	
	# Aliases to export from this module
	AliasesToExport = '*' #For performance, list alias explicitly
	
	# DSC class resources to export from this module.
	#DSCResourcesToExport = ''
	
	# List of all modules packaged with this module
	ModuleList = @()
	
	# List of all files packaged with this module
	FileList = @()
	
	# Private data to pass to the module specified in ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
	PrivateData = @{
		
		#Support for PowerShellGet galleries.
		PSData = @{
			
			# Tags applied to this module. These help with module discovery in online galleries.
			# Tags = @()
			
			# A URL to the license for this module.
			# LicenseUri = ''
			
			# A URL to the main website for this project.
			# ProjectUri = ''
			
			# A URL to an icon representing this module.
			# IconUri = ''
			
			# ReleaseNotes of this module
			# ReleaseNotes = ''
			
		} # End of PSData hashtable
		
	} # End of PrivateData hashtable
}
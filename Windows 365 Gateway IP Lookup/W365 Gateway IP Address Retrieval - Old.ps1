<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

#v2.0

#output CSV file
$CSVFile = "$PSSCriptRoot\W365-Gateways.CSV"

#To check if PowerShell modules are out of date, set to $true
$CheckUpdates = $false

#modules required for this script
$modules = @("az.accounts",
    "az.network"
)

#function to ensure modules are installed and current
function invoke-modulecheck {
    foreach ($module in $modules) {

        write-host "Checking module - " $module
        $graphcurrent = (get-installedmodule -name $module -ErrorAction SilentlyContinue)
        if ($graphcurrent -eq $null) {
            write-output "Module is not installed. Installing..." | out-host
            try {
                Install-Module -name $module -Force -ErrorAction Stop 
                Import-Module -name $module -Force -ErrorAction Stop 
            }
            catch {
                write-output "Failed to install " $module | out-host
                write-output $_.Exception.Message | out-host
                Exit
            }
        }

        if ($CheckUpdates -eq $true) {
            $currentver = (find-module -name $module).version.ToString()
            $installedver = (get-installedmodule -name $module).version.tostring()

            if ($currentver -gt $installedver) { 
                write-host "There is an update to this module."
                write-host "The module will not be upgraded automatically"
                write-host "Consider upgrading the module using the Update-Module commandlet" 
            }
            else {   
                write-host "This module is up to date" 
            }
        }
    }
}

#prompt user to connect to Azure
function connect-azure {
    $tenant = get-aztenant -ErrorAction SilentlyContinue
    if ($tenant.TenantId -eq $null) {
        write-output "Not connected to Azure. Connecting..." | out-host
        try {
            Connect-AzAccount -ErrorAction Stop | Out-Null
        }
        catch {
            write-output "Failed to connect to Azure" | out-host
            write-output $_.Exception.Message | out-host
            Exit
        }   
    }
    Write-Output "Connected to Azure" | out-host
}

#function to download current Gateway IP list from Azure
function invoke-download {
    try {
        write-host "retrieving service tags from Azure..."
        $tags = Get-AzNetworkServiceTag -Location eastus2 -ErrorAction Stop 
    }
    catch {
        write-host "failed to retrieve service tags."
        write-host $_.Exception.Message
        exit
    }

    #retrive subnets from Azure data
    write-host "Parsing data..."
    $addresses = $tags.Values | Where-Object { $_.name -eq "WindowsVirtualDesktop" }
    $subnets = $addresses.Properties.AddressPrefixes

    #remove temp.csv if found
    if ((Test-Path -Path $PSScriptRoot\test.csv) -eq $true) {
        write-host "removing temp CSV file"
        Remove-Item -Path $PSSCriptRoot\test.csv -Force
    }

    #remove subnet masks to create gateways - output to temp.csv
    $count = 0
    foreach ($subnet in $subnets) {
        $count = $count + 1
        $index = $subnet.IndexOf('/')
        if ($count -ne $subnets.count) {
        ($subnet.Substring(0, $index)) + ',' | out-file $PSSCriptRoot\temp.csv -Append
        }
        else {
        ($subnet.Substring(0, $index)) | out-file $PSSCriptRoot\temp.csv -Append 
        }
    }    
    write-host "$count gateways found"
}

#Removes left over temp.csv file if found
if ((Test-Path -Path $PSSCriptRoot\temp.csv) -eq $true) {
    write-host "Removing stale temp file"
    remove-item -Path $PSSCriptRoot\temp.csv -Force
}

invoke-modulecheck

connect-azure

invoke-download

if ((test-path $CSVFile) -eq $true) {
    write-host "Existing CSV Found"
    write-host "Importing Gateway IPs from existing CSV"
    $CSVData1 = (Get-Content -Path $CSVfile) -replace ",", ""
    $CSVData2 = (Get-Content -Path $PSScriptRoot\temp.csv) -replace ",", ""
    $diff = Compare-Object -ReferenceObject $CSVData1 -DifferenceObject $CSVData2

    if ($diff -eq $null) {
        write-host "No changes to Gateway IP list detected."
        remove-item -Path $PSSCriptRoot\temp.csv -Force
        exit
    }
    write-host "There is an update to the list"
    write-host "Updating CSV File $CSVFile"
    Remove-Item -Path $CSVFile -Force
}
else {
    write-host "Outputting to CSV file $CSVFile"
}

Rename-Item -Path "$PSSCriptRoot\temp.csv" -NewName $CSVFile -Force
    
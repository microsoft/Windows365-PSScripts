<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

#v1.0

#output CSV file
$CSVFile = "c:\temp\W365-Gateways.CSV"

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
                Import-Module -name $module -force -ErrorAction Stop 

            }
            catch {
                write-output "Failed to install " $module | out-host
                write-output $_.Exception.Message | out-host
                Exit
            }
        }

        $currentver = (find-module -name $module).version.ToString()
        $installedver = (get-installedmodule -name $module).version.tostring()

        if ($currentver -gt $installedver) { write-host "There is an update to this module." }
        else
        { write-host "This module is up to date" }

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
    $tenant = get-aztenant
    $text = "Tenant ID is " + $tenant.TenantId
    Write-Output "Connected to Azure" | out-host
    Write-Output $text | out-host
}

#function to check for existing CSV file
function invoke-filecheck {
    if ((test-path -path (Split-Path $CSVFile -Parent)) -eq $false) {
        write-host "Creating folder..."
        new-item -Path (Split-Path $CSVFile -Parent) -ItemType Directory | Out-Null
    } 

    if ((test-path $CSVFile) -eq $true) {
        write-host "Existing CSV Found"
        write-host "Press O to Overwrite"
        write-host "Press A to Archive"
        write-host "Press C to Cancel"
        $input = Read-host -Prompt "Press O, A, or C"


        if ($input -eq "C") {
            write-host "Cancelling"
            exit
        }


        if ($input -eq "O") {
            write-host "Overwriting"
            Remove-Item -Path $CSVFile -Force
            Return
        } 

        if ($input -eq "A") {
            write-host "Archiving"
            $newname = $CSVFile + ".old"
            if ((test-path -Path $newname) -eq $true) {
                write-host "removing old archive"
                Remove-Item -Path $newname -Force

            }
            Rename-Item -Path $CSVFile -NewName $newname
            return
    
        }
        write-host "Input not understood. Exiting"
        exit
    }

}

invoke-modulecheck

connect-azure

invoke-filecheck

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

#remove subnet masks to create gateways
write-host "Writing gateways to CSV..."
$count = 0
foreach ($subnet in $subnets) {
    $count = $count + 1
    $index = $subnet.IndexOf('/')
    
    if ($count -ne $subnets.count) {
        ($subnet.Substring(0, $index)) + ',' | out-file $CSVFile -Append
          
    }
    else {
        ($subnet.Substring(0, $index)) | out-file $CSVFile -Append 
    }
    
}    

write-host "$count gateways recorded to $CSVFile"
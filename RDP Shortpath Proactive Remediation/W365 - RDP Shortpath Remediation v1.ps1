<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

# Version 1.0
#
# This script is the remediation script for a Proactive Remediation solution to enable RDP
# Shortpath for Windows 365 Cloud PCs. 
#
#####################################

#sets variable used to determine registry key state
$state = 0

#Determine if the key needs to be updated or created
try {
    if (((Get-ItemProperty -ErrorAction Stop -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations" -name ICEControl).ICEControl) -ne 2) {
        write-host "Registry key present - needs updating"
        $state = 1
    }
}
catch {
    write-host "Registry key is not present - needs creating"
    $state = 2
}

#Set the registry key, fail on error
if ($state -eq 1) {
    try {
        write-host "Updating the registry key..."
        Set-ItemProperty -Path  "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations" -Name ICEControl -Value 2 -ErrorAction stop
    }
    catch {
        Exit 1
    }
}

#Create the key, fail on error
if ($state -eq 2) {
    try {
        write-host "Creating the registry key..."
        New-ItemProperty -Path  "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations" -Name ICEControl -PropertyType DWORD -Value 2 -ErrorAction stop
    }
    catch {
        Exit 1
    }
}

#check if update/create was succesful
try {
    if (((Get-ItemProperty -ErrorAction Stop -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations" -name ICEControl).ICEControl) -eq 2) {
        write-host "Key updated successfully"
        Exit 0
    }
    else {
        write-host "Failed to update registry key"
        Exit 1
    }

}
catch {
    write-host "An error occured in validating the registry key remediation. Failing."
    Exit 1
}


<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

# Version 1.0
#
# This script is the detection script for a Proactive Remediation solution to enable RDP
# Shortpath for Windows 365 Cloud PCs. 
#
#####################################

#Ensure the computer is a Cloud PC. Exit if not
if ($env:COMPUTERNAME -notlike "CPC-*") {
    write-host "This is not a cloud pc. No remdiation required."
    Exit 0
}

#Check the value of the regisry key. Return non-compliant if not equal to 2 or on failure (key not present)
try {
    if (((Get-ItemProperty -ErrorAction Stop -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations" -name ICEControl).ICEControl) -eq 2) {
        write-host "Registry key is properly configured for RDP Shortpath."
        Exit 0
    }
    else {
        write-host "Registry key is not set correctly RDP Shortpath."
        Exit 1
    }
}
catch {
    write-host "Registry key likely not present."
    Exit 1
}
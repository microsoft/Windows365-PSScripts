﻿<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

#This script is provided without support from Microsoft.

#version v1.0

#The number of lines the script will read
$NumOfLines = 26

#Finds the health check log in the user path
$users = Get-ChildItem -Path c:\users -Directory 
foreach ($user in $users) {
       
    if ($user.name -ne "Public") {
        $logpath = "c:\users\" + $user + "\AppData\Local\Temp\DiagOutputDir\Windows365\Logs\health_checks.log"
            
        if ((test-path -Path $logpath) -eq $true)  {
            write-host "$logpath is the log location." 
        }
        else
        { 
            write-host "Could not find the health check log. Quitting"
            Exit 1
        }
    }
}

#reads the health check log for the last performed health check
$content = Get-Content -Path $logpath -Tail $NumOfLines

#Detects if a Fail or Warning has occured
if (((select-string -InputObject $content -Pattern "Warning") -eq $null) -and ((select-string -InputObject $content -Pattern "Fail") -eq $null)){
    write-host "No Warnings or Failures detected"
    Exit 0
}
else
{
    write-host "Warnings or Failures detected"
    Exit 1
}


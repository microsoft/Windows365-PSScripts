<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

#This script is provided without support from Microsoft.

#version v1.0

#The number of lines the script will read
$NumOfLines = 26

#Variable to track how many logs have an error or warning
$global:NumOfErrors = 0

function invoke-WinAppVersion{

     $version = (Get-AppxPackage -Name "*Windows365*").version
     if ($version -eq $null){
        write-host "Windows App not installed"
        Return 0
     }
     if ($version -ne $null){write-host "Windows App Version - $version"}
     if ($version -ge 2.0.705.0){Write-host "Acceptable Version for Health Check"}
        else{
        write-host "Version is out of date. Please update"
        Return 1
        }
 }

function invoke-HCLogRead($path){

    #reads the health check log for the last performed health check
    $content = Get-Content -Path $path -Tail $NumOfLines

    #Detects if a Fail or Warning has occured
    if (((select-string -InputObject $content -Pattern "Warning") -eq $null) -and ((select-string -InputObject $content -Pattern "Fail") -eq $null)){
        write-host "No Warnings or Failures detected"
        }
        else
        {
        write-host "Warnings or Failures detected"
        $global:NumOfErrors = $global:NumOfErrors + 1     
         
        }    
}

$WinAppVer = invoke-WinAppVersion
if (($WinAppVer) -eq 0){Exit 0} #Returns compliant if Windows App is not installed
if (($WinAppVer) -eq 1){Exit 1} #Returns non-compliant if Windows App is out of date



#Finds the health check log in the user path
$userpaths = $env:PUBLIC.TrimEnd('Public')
$users = Get-ChildItem -Path $userpaths -Directory 


foreach ($user in $users) {
       
    if ($user.name -ne "Public") {
        $logpath = $userpaths + $user + "\AppData\Local\Temp\DiagOutputDir\Windows365\Logs\health_checks.log"
            
        if ((test-path -Path $logpath) -eq $true)  {
            write-host "$logpath is the log location."
            invoke-HCLogRead $logpath 
        }
        else
        { 
            write-host "Could not find the health check log for $user"
            
        }
    }
}


if ($global:NumOfErrors -eq 0){
    write-host "No errors found. Complaint"
    Exit 0
    }
    else{
    Write-Host "Errors or warnings found. Non-Compliant"
    Exit 1
    }


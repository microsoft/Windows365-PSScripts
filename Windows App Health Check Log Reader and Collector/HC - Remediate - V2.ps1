<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

#This script is provided without support from Microsoft

#version v2.0

#The number of lines for the script to read. Currently 26 lines covers the entirety of a single health check. Adjust as needed.
$NumOfLines = 26

function invoke-HCLogRead($path,$UsersName){
    $output = @()
    $count = 0
    $content = Get-Content -Path $path -Tail $NumOfLines
    Foreach ($i in 0..$NumOfLines){

        $logline = $content[$count]
        if (((select-string -InputObject $logline -Pattern "Warning") -ne $null) -or ((select-string -InputObject $logline -Pattern "Fail") -ne $null)){$output += $logline} 
        $count = $count +1
    }
    write-host $output
    
    #Copies the log to the IME log folder so it can be retrieved by Intune
    $name = $env:COMPUTERNAME + "_" + $UsersName + "_" + "health_checks.log"
    Copy-Item -Path $logpath -Destination C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\$name -Force
}

#Finds the health check log in the user path
$userpaths = $env:PUBLIC.TrimEnd('Public')
$users = Get-ChildItem -Path $userpaths -Directory 

#parses through each user profile for a health check log
foreach ($user in $users) {
       
    if ($user.name -ne "Public") {
        $logpath = $userpaths + $user + "\AppData\Local\Temp\DiagOutputDir\Windows365\Logs\health_checks.log"
            
        if ((test-path -Path $logpath) -eq $true)  {
            write-host "$logpath is the log location."
            invoke-HCLogRead $logpath $user.Name
        }
        else
        { 
            write-host "Could not find the health check log for $user"
            
        }
    }
}

































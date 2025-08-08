<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

#This script is provided without support from Microsoft

#version v1.0

#The number of lines for the script to read. Currently 26 lines covers the entirety of a single health check. Adjust as needed.
$NumOfLines = 26

#Finds the health check log in the user path
$users = Get-ChildItem -Path c:\users -Directory 
foreach ($user in $users) {
       
    if ($user.name -ne "Public") {
        $logpath = "c:\users\" + $user + "\AppData\Local\Temp\DiagOutputDir\Windows365\Logs\health_checks.log"
            
        if ((test-path -Path $logpath) -eq $true)  {
            write-host "$logpath is the log location." 
            write-host " "
        }
        else
        { 
            write-host "Could not find the health check log. Quitting"
            Exit 1
        }
    }
}

#Read the log file
$content = Get-Content -Path $logpath -Tail $NumOfLines

$count = 0
$output = @()

write-host "Failures/Warnings:"
write-host " "

#Read each line of the log segment to look for "Fail" or "Warning"
Foreach ($i in 0..$NumOfLines){

    $logline = $content[$count]
    if (((select-string -InputObject $logline -Pattern "Warning") -ne $null) -or ((select-string -InputObject $logline -Pattern "Fail") -ne $null)){$output += $logline} 
    $count = $count +1
}

#Send the fail/warning lines to the console
write-host $output

#Copies the log to the IME log folder so it can be retrieved by Intune
Copy-Item -Path $logpath -Destination C:\ProgramData\Microsoft\IntuneManagementExtension\Logs -Force



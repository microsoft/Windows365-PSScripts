<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

#version v1.0

Param(
    [parameter(mandatory = $false, HelpMessage = "Log path and file name")] 
    [string]$logpath = "$env:windir\temp\Teams-MWI-detect.log"
)

function update-log {
    Param(
        [Parameter(
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [string]$Data,
        [validateset('Information', 'Warning', 'Error', 'Comment')]
        [string]$Class = "Information",
        [validateset('Console', 'File', 'Both')]
        [string]$Output 
    )

    $date = get-date -UFormat "%m/%d/%y %r"
    $String = $Class + " " + $date + " " + $data
    if ($Output -eq "Console") { Write-Output $string | out-host }
    if ($Output -eq "file") { Write-Output $String | out-file -FilePath $logpath -Append }
    if ($Output -eq "Both") {
        Write-Output $string | out-host
        Write-Output $String | out-file -FilePath $logpath -Append
    }
}

#Determine if Teams is installed in Program Files x86
$path = "C:\Program Files (x86)\Microsoft\Teams"
$exepath = "C:\Program Files (x86)\Microsoft\Teams\update.exe"
$deadpath = "C:\Program Files (x86)\Microsoft\Teams\.dead"
$currentpath = "C:\Program Files (x86)\Microsoft\Teams\current"     
if ((Test-Path -path $path) -eq $true) {
    if (((test-path -Path $exepath) -eq $true) -and ((test-path -Path $currentpath) -eq $true) -and ((test-path -Path $deadpath) -eq $false)) {
        update-log -Data "Program Files x86 is the install location. Not Compliant" -Class Information -Output Both
        Exit 1
    }
    else
    { update-log -data "Progran Files x86 is not the install location" -Class Information -Output Both }
}
else {
    update-log -data "Program Files x86 does not contain a Teams installation" -Class Information -Output Both
}

#Determine if Teams is installed in Program Files
$path = "C:\Program Files\Microsoft\Teams"
$exepath = "C:\Program Files\Microsoft\Teams\update.exe"
$deadpath = "C:\Program Files\Microsoft\Teams\.dead"
$currentpath = "C:\Program Files\Microsoft\Teams\current"     
if ((Test-Path -path $path) -eq $true) {
    if (((test-path -Path $exepath) -eq $true) -and ((test-path -Path $currentpath) -eq $true) -and ((test-path -Path $deadpath) -eq $false)) {
        update-log -data "Program Files is the install location. Not Compliant" -Class Information -Output Both
        Exit 1
    }
    else
    { update-log -data "Progran Files is not the install location" -Class Information -Output Both }
}
else {
    update-log -data "Program Files does not contain a Teams installation" -Class Information -Output Both
}

#Determine if Teams is installed in Appdata
$users = Get-ChildItem -Path c:\users -Directory 
foreach ($user in $users) {
       
    if ($user.name -ne "Public") {
        $exepath = "c:\users\" + $user + "\AppData\Local\Microsoft\Teams\update.exe"
        $deadpath = "c:\users\" + $user + "\AppData\Local\Microsoft\Teams\.dead"
        $currentpath = "c:\users\" + $user + "\AppData\Local\Microsoft\Teams\current"      
            
        if (((test-path -Path $exepath) -eq $true) -and ((test-path -Path $currentpath) -eq $true) -and ((test-path -Path $deadpath) -eq $false)) {
            update-log -data "$exepath is the install location. Compliant" -Class Information -Output Both
            Exit 0
        }
        else
        { update-log -Data "Appdata is not the install location" -Class Information -Output Both }
    }
}

update-log -Data "A User installation of Teams was not found in any path." -Class Information -Output Both
exit 1


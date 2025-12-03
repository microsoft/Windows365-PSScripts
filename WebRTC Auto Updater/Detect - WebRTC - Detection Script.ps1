<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

# Version 0.3.2
#
#####################################

Param(
    [parameter(mandatory = $false, HelpMessage = "Log path and file name")] 
    [string]$logpath = "$env:windir\temp\TeamsWebRTC-detect.log"
)

#Retrives the version number of the current Web RTC client
function get-CurrentRTCver {
    
    $response = (Invoke-WebRequest -Uri "https://aka.ms/msrdcwebrtcsvc/msi" -UseBasicParsing)
    $versionC = $response.BaseResponse.ResponseUri.AbsolutePath -replace ".*HostSetup_", "" -replace ".x64.msi*", "" 
    $string = "The latest available version of the WebRTC client is " + $versionC
    update-log -Data $string -Class Information -output both
    $global:currentversion = $versionC
    return $versionC
}

#Retrieves the installed version of the Web RTC client
function get-installedRTCver {
    if ((test-path -Path 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\AddIns\WebRTC Redirector\') -eq $true) {

        $version = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\AddIns\WebRTC Redirector\')
        if ($version.CurrentVersion -eq "1.53.2408.19001"){$version.CurrentVersion = "1.54.2408.19001"}
        $string = "The currently installed version of the WebRTC client is " + $version.currentversion
        update-log -Data $string -Class Information -output both
        return $version.currentversion
    }
    else {
        update-log -data "It doesn't appear that the WebRTC client is installed" -Class Warning -output both
        return "0"

    }
}
#Logging function
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

#function to detect if Teams is installed
function get-teamsinstall {
    $rootpath = "c:\users\"

    $userfolders = (get-childitem $rootpath -Attributes directory).Name

    $count = 0
    foreach ($userfolder in $userfolders) {
        if ($userfolder -ne "Public") {
            
            if ((test-path -Path "c:\users\$userfolder\Appdata\Local\Microsoft\Teams\current\teams.exe") -eq $true) {
                $count = $count + 1
            }
        }
    }

    if ($count -eq '0') {
        update-log -data "Classic Teams install not found. Checking for New Teams." -Class Information -Output Both
        ###  Old method of finding New Teams. It was not reliable. Keeping until new process validated and pushing to Main
        #Exit 0
        #$appxpacks = Get-ChildItem 'C:\Program Files\WindowsApps'

        #foreach ($appxpack in $appxpacks){
        #    if ($appxpack -match "MSTeams"){$count = $count + 1}
        #}
        #if ($count -eq 0){
        #    update-log -data "New Teams not found. Teams is not installed. Returning compliant." -Class Information -Output Both
        #    Exit 0
        #}
        #else{
        #    update-log -data "New Teams installation has been found" -Class Information -Output Both
        #}
        $NewTeams = (get-appxpackage -Name MSteams)
        if ((get-appxpackage -Name MSteams) -eq $null){
            update-log -data "New Teams not found. Teams is not installed. Returning compliant." -Class Information -Output Both
            Exit 0
            }
        else{
           update-log -data "New Teams installation has been found" -Class Information -Output Both
        }
    }
    else {
        update-log -data "Old Teams install found." -Class Information -Output Both
    }
}

#Writes the header of the log
update-log -Data " " -Class Information -output both
update-log -Data "*** Starting WebRTC agent detection ***" -Class Information -output both
update-log -Data " " -Class Information -output both

#Calls the function to check if Teams is installed. WebRTC client cannot upgrade if teams isn't detected in a user profile.
get-teamsinstall

#Calls the function to get the current available version number
$Global:currentversion = $null
$RTCCurrent = get-currentRTCver 
$RTCCurrent = $Global:currentversion 

#Calls the function to get the installed version number
$RTCInstalled = get-installedRTCver -Erroraction SilentlyContinue

#Handles the error code if Web RTC client is not installed.
if ($RTCInstalled -eq $null) {
 
    update-log -Data "WebRTC client was not detected. Returning Non-compliant" -Class Warning -output both
    Exit 1
}

#Handles the error code if the Web RTC client is out of date.
if ($RTCInstalled -lt $RTCCurrent) {

    update-log -Data "WebRTC was detected to be out of date. Returning Non-compliant" -Class Warning -output both
    Exit 1
}

#Handles the error code if the installed agent is newer than the latest available client. (shouldn't happen)
if ($RTCInstalled -gt $RTCCurrent) {
    
    update-log -data "The installed version is newer than what is available." -Class Warning -output both
    exit 1
}

#Handles the error code if the agent is current.
if ($RTCInstalled -eq $RTCCurrent) {
   
    update-log -Data "The WebRTC client is current. Returning Compliant" -Class Information -output both
    Exit 0
}


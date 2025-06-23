<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

# Remote Desktop Multimedia Redirection updater - Detection Script
# Version 0.0.1

#####################################

Param(
    [parameter(mandatory = $false, HelpMessage = "Log path and file name")] 
    [string]$logpath = "$env:windir\temp\RDMMR-detect.log"
)

#Retrieves the version number of the current MMR client
function get-CurrentMMRver {

    $response = (Invoke-WebRequest -Uri "https://aka.ms/avdmmr/msi" -UseBasicParsing)
    $versionC = $response.BaseResponse.ResponseUri.AbsolutePath -replace ".*HostInstaller_", "" -replace ".x64.msi*", "" 
    $string = "The latest available version of the RD MMR client is " + $versionC
    update-log -Data $string -Class Information -output both
    return $versionC
}

#Retrieves the version of MMR installed on the Cloud PC
function get-installedMMRver{
    if ((Test-Path -Path 'C:\Program Files\MsRDCMMRHost\MsMmrHost.exe') -eq $true){
        $version = (Get-ItemProperty -Path 'C:\Program Files\MsRDCMMRHost\MsMmrHost.exe')
        $string = "The currently installed version of the RD MMR client is " + $version.VersionInfo.ProductVersion
        update-log -Data $string -Class Information -output both
        return $version.VersionInfo.ProductVersion
    }
    else
    {
        update-log -data "It doesn't appear that the MMR client is installed" -Class Warning -output both
        return "0"}
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

#Writes the header of the log
update-log -Data " " -Class Information -output both
update-log -Data "*** Starting RD MMR agent detection ***" -Class Information -output both
update-log -Data " " -Class Information -output both


$MMRCurrent = get-CurrentMMRver 

#Calls the function to get the installed version number
$MMRInstalled = get-installedMMRver -Erroraction SilentlyContinue

#Handles the error code if Web RTC client is not installed.
if ($MMRInstalled -eq $null) {
 
    update-log -Data "RD MMR client was not detected. Returning Non-compliant" -Class Warning -output both
    Exit 1
}

#Handles the error code if the Web RTC client is out of date.
if ($MMRInstalled -lt $MMRCurrent) {

    update-log -Data "RD MMR was detected to be out of date. Returning Non-compliant" -Class Warning -output both
    Exit 1
}

#Handles the error code if the installed agent is newer than the latest available client. (shouldn't happen)
if ($MMRInstalled -gt $MMRCurrent) {
    
    update-log -data "The installed version is newer than what is available." -Class Warning -output both
    exit 1
}

#Handles the error code if the agent is current.
if ($MMRInstalled -eq $MMRCurrent) {
   
    update-log -Data "The RD MMR client is current. Returning Compliant" -Class Information -output both
    Exit 0
}
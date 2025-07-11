﻿<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

# Remote Desktop Multimedia Redirection updater - Remediation Script
# Version 0.0.1

#####################################

Param(
    [parameter(mandatory = $false, HelpMessage = "Log path and file name")] 
    [string]$logpath = "$env:windir\temp\TeamsWebRTC-remediate.log",
    [parameter(mandatory = $false, HelpMessage = "time to wait past disconnect")]
    [string]$DCNTwait = 600,
    [parameter(mandatory = $false, HelpMessage = "time to wait to re-check user state")]
    [string]$StateDetWait = 300,
    [parameter(mandatory = $false, HelpMessage = "evaluate user state only once")] 
    [switch]$retry,
    [parameter(mandatory = $false, HelpMessage = "time in minutes to timeout")]
    [int]$TimeOut = 60
)

#function to handle logging
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

#function to query the user state and convert to variable
function get-userstate {
    (((quser) -replace '^>', '') -replace '\s{2,}', ',').Trim() | ForEach-Object {
        if ($_.Split(',').Count -eq 5) {
            Write-Output ($_ -replace '(^[^,]+)', '$1,')
        }
        else {
            Write-Output $_
        }
    } | ConvertFrom-Csv
}

#function to perform the upgrading
function invoke-remediation {

    $MMRCurrent = get-CurrentMMRver

    $MMRInstalled = get-installedMMRver
    $string = "Installed MMR agent version is " + $MMRInstalled
    update-log -Data $string  -Class Information -Output Both
    $string = "Latest version of MMR agent is " + $MMRCurrent
    update-log -Data $string -Class Information -Output Both
 
    try {

        #Create a directory to save download files
        $tempCreated = $false
        if (!(Test-Path C:\RDMMRtemp)) {
            New-Item -Path C:\ -ItemType Directory -Name RDMMRtemp | Out-Null
            update-log -data "Temp path created" -output both -Class Information
            $tempCreated = $true
        }

        #Download MMR
        update-log -Data "Downloading RD MMR client" -Class Information -output both
        invoke-WebRequest -Uri "https://aka.ms/avdmmr/msi" -OutFile "C:\RDMMRtemp\MMR_Installer.msi" -UseBasicParsing -PassThru 
 
        #Install MMR
        update-log -Data "Installing RD MMR client" -Class Information -output both
        $msireturn = Start-Process msiexec.exe -ArgumentList '/i C:\RDMMRtemp\MMR_Installer.msi /q /n /l*voicewarmup c:\windows\temp\RDMMRmsi.log' -Wait -PassThru
        if ($msireturn.ExitCode -eq '0') {
            update-log -data "MSIEXEC returned 0" -Class Information -Output Both
        }
        else {
            $string = "MSIEXEC returned exit code " + $msireturn.ExitCode
            update-log -data $string -Class Information -Output Both
            exit 1
        }

        if ($tempCreated -eq $true) {
            #Remove temp folder
            update-log -Data "Removing temp directory" -Class Information -output both
            Remove-Item -Path C:\RDMMRtemp\ -Recurse | out-null
        }
        else {
            #Remove downloaded WebRTC file
            update-log -Data "Removing RD MMR client installer file" -Class Information -output both
            Remove-Item -Path C:\RDMMRtemp\MsRdcWebRTCSvc_HostSetup.msi
        }
        #Return Success
        update-log -Data "Media Optimization Installed" -Class Information -output both
        $MMRCurrent = get-CurrentMMRver
        $string = "Current installed version is now " + $MMRCurrent
        update-log -Data $string -Class Information -Output Both
        return "Success"
    }
    catch {
        Write-Error -ErrorRecord $_
        return /b "Fail"
    }
}

#function to handle user state detection logic
function invoke-userdetect {
    update-log -data "Detecting user state." -Class Information -output both 
    $explorerprocesses = @(Get-WmiObject -Query "Select * FROM Win32_Process WHERE Name='explorer.exe'" -ErrorAction SilentlyContinue)
    if ($explorerprocesses.Count -eq 0) {
        update-log -data "There is not a user logged in. Skipping user state detection." -Class Information -Output both
        Return 
    }
    else {
        foreach ($i in $explorerprocesses) {    
            $Username = $i.GetOwner().User
            $Domain = $i.GetOwner().Domain
            $string = $Domain + "\" + $Username + " logged on since: " + ($i.ConvertToDateTime($i.CreationDate))
            update-log -data $string -Class Information -Output Both
        }
        update-log -data "There is a logged on user" -Class Information -Output Both
    }

    if ($retry -eq $true) {
        do {
            $session = get-userstate
            $text = "Waiting for non-active user state."
            update-log -data $text -Class Information -output both
            $String = "Session State is " + $session.STATE
            update-log -data $String -output both -Class Information
            $string = "Idle Time is " + $session.'IDLE TIME'
            update-log -data $String -output both -Class Information

            if ($TimeOut -gt 0) {
                sleep -Seconds $StateDetWait
                $TimeOut = ($TimeOut - $StateDetWait)
            }
            else {
                update-log -Data "Timed out. Returning fail" -Class Error -output both
                return 3
            }        
        } while ($session.state -eq "Active")
    
        update-log -data "User state is not active." -output both -Class Information
        invoke-disctimer
    }
    
    if ($retry -eq $false) {
        update-log -Data "Attempting to detect only once." -Class Information -output both
        $session = get-userstate
        if ($session.state -eq "disc") {
            $text = "User state is disconnected"
            update-log -data $text -Class Information -output both
        }
        else {
            update-log -Data "User state is not disconnected" -Class Warning -output both
            return 2
        }   
    }    
}

#function to handle wait time between first non-active discovery and upgrade
function invoke-disctimer {
    $string = "Waiting " + $DCNTwait + " seconds..."
    update-log -Data $string -Class Information -output both
    sleep -Seconds $DCNTwait
    $Timeout = ($Timeout - $DCNTwait)

    $session = get-userstate
    if ($session.STATE -eq "Active") {
        update-log -Data "User state has become active again. Waiting for non-active state..." -Class Warning -output both
        invoke-userdetect
    }
    else {
        update-log -data "Session state is still non-active. Continuing with remediation..." -Class Information -output both
    }
}

#function to query the latest available version number of RD MMR client
function get-CurrentMMRver {
    $response = (Invoke-WebRequest -Uri "https://aka.ms/avdmmr/msi" -UseBasicParsing)
    $versionC = $response.BaseResponse.ResponseUri.AbsolutePath -replace ".*HostInstaller_", "" -replace ".x64.msi*", "" 
    $string = "The latest available version of the RD MMR client is " + $versionC
    update-log -Data $string -Class Information -output both
    return $versionC
}

#function to determine what version of RDMMR is installed
function get-installedMMRver{
    if ((Test-Path -Path 'C:\Program Files\MsRDCMMRHost\MsMmrHost.exe') -eq $true){
        $version = (Get-ItemProperty -Path 'C:\Program Files\MsRDCMMRHost\MsMmrHost.exe')
        $string = "The currently installed version of the RD MMR client is " + $version.VersionInfo.ProductVersion
        update-log -Data $string -Class Information -output both
        return $version.VersionInfo.ProductVersion
    }
    else
    {
        update-log -data "It doesn't appear that the RD MMR client is installed" -Class Warning -output both
        return "0"}
}

#Opening text of log. 
update-log -Data " " -Class Information -output both
update-log -Data "*** Starting RD MMR agent remediation ***" -Class Information -output both
update-log -Data " " -Class Information -output both

#Display timeout amount in the log - if using retry function
if ($retry -eq $true) {
    $String = "Time out set for " + $Timeout + " minutes"
    update-log -Data $String -output both -Class Information
}

#Converts Timeout minutes to seconds
$TimeOut = $TimeOut * 60

#Starts the user state detection and handling
$var1 = invoke-userdetect

# Exit if user is active (default). 
#Return code for no retry - user is active
if ($var1 -eq 2) {
    update-log -Data "User State is active. Returning fail. Try again" -Class Warning -output both
    exit 1
}

#Exit if process times out. Used with "-retry" parameter. 
#Return code for time out
if ($var1 -eq 3) {
    update-log -Data "Timed out. Returning fail. Try again" -Class Warning -output both
    exit 1
}

#Starts the remediaiton function
$result = $null
$result = invoke-remediation

#Exit if the remediation was successful
if ($result -eq "Success") {
    update-log -Data "Remediation Complete" -Class Information -output both
    exit 0
}

#Exit if remediation failed
if ($result -ne "Success") {
    update-log -Data "An error occured." -Class Error -output both
    exit 1
}
    
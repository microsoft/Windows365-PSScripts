<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

#version v1.0

Param(
    [parameter(mandatory = $false, HelpMessage = "Log path and file name")] 
    [string]$logpath = "$env:windir\temp\Teams-MWI-remediate.log",
    [parameter(mandatory = $false, HelpMessage = "time to wait past disconnect")]
    [string]$DCNTwait = 600,
    [parameter(mandatory = $false, HelpMessage = "time to wait to re-check user state")]
    [string]$StateDetWait = 300,
    [parameter(mandatory = $false, HelpMessage = "evaluate user state only once")] 
    [switch]$retry,
    [parameter(mandatory = $false, HelpMessage = "time in minutes to timeout")]
    [int]$TimeOut = 60
)

#How many days to keep scheduled task active before it expires
$DateOffset = 3

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

#function to handle user state detection logic
function invoke-userdetect {
    update-log -data "Detecting user state." -Class Information -output both 
    $explorerprocesses = @(Get-WmiObject -Query "Select * FROM Win32_Process WHERE Name='explorer.exe'" -ErrorAction SilentlyContinue)
    if ($explorerprocesses.Count -eq 0) {
        update-log -data "There is not a user logged in. Skipping user state detection." -Class Information -Output both
        Return 3
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

#function to download Teams Machine Wide Installer
function download-teams {
    update-log -Data "Downloading latest Teams client for VDI..." -Class Information -Output Both
    try {
        invoke-webrequest -Uri https://statics.teams.cdn.office.net/production-windows-x64/1.5.00.11865/Teams_windows_x64.msi -OutFile c:\windows\temp\TeamsMWInstaller.msi -ErrorAction Stop
    }
    catch {
        update-log -Data "An error occured while downloading Teams Machine Wide Installer" -Class Error -Output Both
        Update-Log -data $_.Exception.Message -Class Error -Output Both
        exit 1
    }
}

#function to uninstall Teams Machine Wide Installer
function uninstall-machinewide {  
    update-log -Data "Checking registry for Machine Wide Installer GUID" -Class Information -Output Both
    $keys = Get-ChildItem -path HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\ -ErrorAction Stop
    $Uninstall = $null
    foreach ($key in $keys) {
        if ($key.name -like '*{*}') {
            $name = $key.Name
            $temp = $name.replace("HKEY_LOCAL_MACHINE", "HKLM:")
            $values = Get-ItemProperty -Path $temp
            if ($values.DisplayName -eq "Teams Machine-Wide Installer") { $Uninstall = $values.UninstallString }
        }
    }

    If ($Uninstall -eq $null) {
        update-log -Data "Teams Machine Wide Installer not installed. Skipping uninstallation" -Class Warning -Output Both
        return
    }

    $guid = $Uninstall.replace("MsiExec.exe /I", "")
    update-log -Data "Uninstalling existing Teams Machine Wide Installer..." -Class Information -Output Both
    $process = start-process -FilePath C:\windows\System32\msiexec.exe -Args @('/X', "`"$guid`"", '/qb-') -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        update-log -Data "Machine Wide Installer failed to uninstall." -Class Error -Output Both
        $string = "Installer returned exit code " + $process.ExitCode
        update-log -Data $string -Class Error -Output Both
        exit 1
    }
}

#function to install Teams Machine Wide Installer
function install-machinewide {
    update-log -Data "Installing Teams Machine Wide Installer..." -Class Information -Output Both
    $process = start-process -FilePath c:\windows\system32\msiexec.exe -Args @('/I', 'c:\windows\temp\TeamsMWInstaller.msi', 'ALLUSERS=1') -wait -PassThru
    if ($process.ExitCode -ne 0) {
        update-log -Data "Machine Wide Installer failed to install." -Class Error -Output Both
        $string = "Installer returned exit code " + $process.ExitCode
        update-log -Data $string -Class Error -Output Both
        exit 1
    }
}

#Function no longer used.
function install-teamsuser {
    update-log -Data "Starting Teams Client installer..." -Class Information -Output Both
    Start-Process -FilePath 'C:\Program Files (x86)\Teams Installer\Teams.exe' -wait
}

#Function to kill all running Teams processes
function kill-teams {
    update-log "Killing active Teams processes..." -Class Information -Output Both
    if ((get-process | where ProcessName -eq "Teams").Count -gt 0) { kill -name teams -force }
}

#Function to find Teams client installations and uninstall them
function invoke-teamslocation {

    $count = 0
    #Determine if Teams is installed in Appdata
    $users = Get-ChildItem -Path c:\users -Directory 
    foreach ($user in $users) {
       
        if ($user.name -ne "Public") {
            $exepath = "c:\users\" + $user + "\AppData\Local\Microsoft\Teams\update.exe"
            $deadpath = "c:\users\" + $user + "\AppData\Local\Microsoft\Teams\.dead"
            $currentpath = "c:\users\" + $user + "\AppData\Local\Microsoft\Teams\current"      
            
            if (((test-path -Path $exepath) -eq $true) -and ((test-path -Path $currentpath) -eq $true) -and ((test-path -Path $deadpath) -eq $false)) {
                update-log -data "$exepath is the install location. Uninstalling..." -Class Information -Output Both
                
                $process = Start-Process -FilePath $exepath -Args @('--uninstall', '/s') -Wait -PassThru
                if ($process.ExitCode -ne 0) {
                    update-log -Data "Teams client failed to uninstall. Exiting" -Class Error -Output Both
                    $string = "The exit code returned is " + $process.ExitCode
                    update-log -data $string -Class Error -Output Both
                    exit 1
                }
                remove-item -Path "c:\users\$user\AppData\Local\Microsoft\Teams" -Recurse -Force
                $Count = $Count + 1
            }
            else
            { update-log -Data "Appdata is not the install location" -Class Information -Output Both }
        }
    }

    #Determine if Teams is installed in Program Files x86
    $path = "C:\Program Files (x86)\Microsoft\Teams"
    $exepath = "C:\Program Files (x86)\Microsoft\Teams\update.exe"
    $deadpath = "C:\Program Files (x86)\Microsoft\Teams\.dead"
    $currentpath = "C:\Program Files (x86)\Microsoft\Teams\current"     
    if ((Test-Path -path $path) -eq $true) {
        if (((test-path -Path $exepath) -eq $true) -and ((test-path -Path $currentpath) -eq $true) -and ((test-path -Path $deadpath) -eq $false)) {
            update-log -Data "Program Files x86 is the install location. Uninstalling..." -Class Information -Output Both
            $process = Start-Process -FilePath $exepath -Args @('--uninstall', '/s') -Wait -PassThru
            if ($process.ExitCode -ne 0) {
                update-log -Data "Teams client failed to uninstall. Exiting" -Class Error -Output Both
                $string = "The exit code returned is " + $process.ExitCode
                update-log -data $string -Class Error -Output Both
                exit 1
            }    
            remove-item -Path "C:\Program Files (x86)\Microsoft\Teams" -Recurse -Force
            $Count = $Count + 1
        }
        else
        { update-log -data "Progran Files x86 is not the install location" -Class Information -Output Both }
    }
    else {
        update-log -Data "Program Files x86 does not contain a Teams installation" -Class Information -Output Both
    }

    #Determine if Teams is installed in Program Files
    $path = "C:\Program Files\Microsoft\Teams"
    $exepath = "C:\Program Files\Microsoft\Teams\update.exe"
    $deadpath = "C:\Program Files\Microsoft\Teams\.dead"
    $currentpath = "C:\Program Files\Microsoft\Teams\current"     
    if ((Test-Path -path $path) -eq $true) {
        if (((test-path -Path $exepath) -eq $true) -and ((test-path -Path $currentpath) -eq $true) -and ((test-path -Path $deadpath) -eq $false)) {
            update-log -Data "Program Files is the install location. Uninstalling..." -Class Information -Output Both
            $process = Start-Process -FilePath $exepath -Args @('--uninstall', '/s') -Wait -PassThru
            if ($process.ExitCode -ne 0) {
                update-log -Data "Teams client failed to uninstall. Exiting" -Class Error -Output Both
                $string = "The exit code returned is " + $process.ExitCode
                update-log -data $string -Class Error -Output Both
                exit 1
            }
            remove-item -Path "C:\Program Files\Microsoft\Teams" -Recurse -Force
            $Count = $Count + 1
        }
        else
        { update-log -Data "Program Files is not the install location" -Class Information -Output Both }
    }
    else {
        update-log -Data "Program Files does not contain a Teams installation" -Class Information -Output Both
    }
    return $count
}

#Function to remove reg key that can block Teams client from installing
function delete-regkey {
    try {
        update-log -Data "Looking up Registry Key value..." -Class Information -Output Both
        $value = Get-Item -Path HKCU:\Software\Microsoft\Office\Teams -ErrorAction Stop
    }
    catch {
        update-log -Data "Could not find Registry Key. This is not fatal." -Class Information -Output Both
    }
    
    if ($value.Property -eq "PreventInstallationFromMsi") {
        update-log -Data "Removing PreventInstallationFromMsi Reg Key" -Class Information -Output Both
        try {
            Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Office\Teams" -Name "PreventInstallationFromMsi" -ErrorAction Stop
        }
        catch {
            update-log -Data "Failed to remove the registry key. This will prevent Teams client from installing at logon" -Class Error -Output Both
            Update-Log -data $_.Exception.Message -Class Error -Output Both
            exit 1
        }
    }
}

#function to create scheduled task to launch Teams client installer for end user
function create-SchedXML($SID) {
    update-log -Data "Creating temp XML for Scheduled Tasks in c:\windows\temp" -Class Information -Output Both

    #create Schedule Task expiration date using offset variable - sets correct format
    $adjdate = (get-date).AddDays($DateOffset)
    $thedate = $adjdate | get-date -format s #| Out-Null

    $TaskXML = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Author>Microsoft\DonnaRyan</Author>
    <URI>\InstallTeams-Remediation</URI>
  </RegistrationInfo>
  <Triggers>
    <SessionStateChangeTrigger>
      <EndBoundary>$thedate</EndBoundary>
      <Enabled>true</Enabled>
      <StateChange>RemoteConnect</StateChange>
    </SessionStateChangeTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$SID</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT72H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>Powershell.exe</Command>
      <Arguments>-executionpolicy Bypass -windowstyle Hidden c:\windows\temp\teamsinstall.ps1</Arguments>
    </Exec>
  </Actions>
</Task>
"@

    try {

        $TaskXML | Out-File C:\windows\temp\InstallTeams-Remediation.xml -ErrorAction Stop
    }
    catch {
        update-log -Data "Failed to create XML. Exiting" -Class Error -Output Both
        Update-Log -data $_.Exception.Message -Class Error -Output Both
        Exit 1 
    }

}

#function to create script that scheduled task will run (script starts teams client installer and cleans up files)
function create-SchedPS1 {

    $scriptblock = {
        $logpath = "$env:windir\temp\Teams-MWI-remediate-child.log"

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

        function delete-schedtask {
            try {
                update-log -Data "Deleting temp scheudled task..." -Class Information -Output Both
                Unregister-ScheduledTask -TaskPath '\' -TaskName "InstallTeams-Remediation" -Confirm:$false -ErrorAction Stop
            }
            catch {
                update-log -Data "Failed to delete scheduled task." -Class Error -Output Both
                update-log -Data Update-Log -data $_.Exception.Message -Class Error -Output Both
                exit 1
            }
        }


        update-log -Data "***Starting child script to reinstall Teams client without reboot***" -Class Information -Output Both
        update-log -Data "If the Teams client fails to install automatically, reboot the PC." -Class Information -Output Both

        if (((test-path -Path c:\windows\temp\InstallTeams-Remediation.xml) -eq $False) -and ((Test-Path -Path C:\windows\Temp\TeamsMWInstaller.msi) -eq $false)) {
            update-log -Data "Teams installer already staged. Exiting" -Class Warning -Output Both
            exit 0
        }

        try {
            update-log -Data "Starting Teams client installer..." -Class Information -Output Both
            $process = Start-Process -FilePath 'C:\Program Files (x86)\Teams Installer\Teams.exe' -wait -PassThru -ErrorAction Stop
            if ($process.ExitCode -ne 0) {
                update-log -Data "Teams client installer reported an error installing." -Class Error -Output Both
                update-log -data "Rebooting the Cloud PC should launch Teams client installer automatically" -Class Error -Output Both
                $string = "The exit code returned is " + $process.ExitCode
                update-log -data $string -Class Error -Output Both
                exit 1
            }
        }

        catch {
            update-log -Data "Failed to start Teams.exe. Instruct user to reboot their Cloud PC" -Class Error -Output Both
            update-log -Data Update-Log -data $_.Exception.Message -Class Error -Output Both
            exit 1
        }


        delete-schedtask

        update-log -Data "Cleaning up files..." -Class Information -Output Both

        Remove-Item -Path c:\windows\temp\InstallTeams-Remediation.xml -Force -ErrorAction Continue
        Remove-Item -Path C:\windows\Temp\TeamsMWInstaller.msi -Force -ErrorAction Continue
        remove-item -path c:\windows\temp\teamsinstall.ps1 -force -ErrorAction Continue

    }
    try{
        update-log -data "Creating child script for scheduled task..." -Class Information -Output Both
        $scriptblock | Out-String -Width 4096 | Out-File -FilePath c:\windows\temp\teamsinstall.ps1 -Force -ErrorAction Stop
    }
    catch
    {
        update-log -data "Failed to create the child script. Reboot PC and Teams client should install" -Class Error -Output Both
        Update-Log -data $_.Exception.Message -Class Error -Output Both
        exit 1
    }
}

#function to retrieve users' SID for use in scheduled task
function get-sid {
    $CurrentUser = (get-userstate).username
    $userkeys = Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
    update-log -Data "Searching through registry to find current user SID..." -Class Information -Output Both
    foreach ($userkey in $userkeys) {
        $tempreg = $userkey.name.Replace('HKEY_LOCAL_MACHINE', 'HKLM:')
        $tempresult = get-itemproperty -Path $tempreg
        if ($tempresult.profileimagepath -like "*$CurrentUser*") {
            $string = $CurrentUser + " SID is " + $userkey.PSChildName
            return $userkey.PSChildName
        }

    }
    update-log -Data "Could not determine SID. Cannot auto install Teams client. It should install after a reboot. Exiting" -Class Error -Output Both
    Exit 1
}

#function to check if child script has already run.
function invoke-preruncheck{
    $fail = 0
    $TaskTemp = Get-ScheduledTask | where{$_.TaskName -eq 'InstallTeams-Remediation'}

    if ($TaskTemp.state -eq "Ready"){update-log -data "Scheduled Task state is Ready" -Class Comment -Output Both}
        else{
        update-log -Data "Scheduled Tak not ready" -Class Information -Output Both
        $fail = $fail + 1
        }

    if ((test-path -Path c:\windows\temp\teamsinstall.ps1) -eq $true){
        update-log -Data "PS1 file for scheduled task exists" -Class Information -Output Both }
        else{
        update-log -data "PS1 does not exist" -Class Information -Output Both
        $fail = $fail + 1
        }


    if ((test-path -path c:\windows\temp\TeamsMWInstaller.msi) -eq $true){
        update-log -Data "Teams Machine Wide Installer MSI file exists" -Class Information -Output Both}
        else{
        update-log -data "MSI doesn't exist" -Class Information -Output Both
        $fail = $fail + 1}

    if ((test-path -Path C:\windows\temp\InstallTeams-Remediation.xml) -eq $true){update-log -data "Scheduled Task XML exists" -Class Information -Output Both
        update-log -data "All files and conditions indicate user hasn't logged in yet" -Class Information -Output Both }
        else{
        update-log -data "XML doesn't exist" -Class Information -Output Both
        $fail = $fail + 1
        }
                

    if ($fail -eq 0){
        update-log -Data "Remediation complete, user hasn't logged in yet" -Class Information -Output Both
        exit 1
        }
    if ($fail -gt 0){update-log -Data "$fail conditions are missing. Triggering install" -Class Information -Output both}
}

$userstate = invoke-userdetect
if ($userstate -eq 2) {
    update-log -data "The user session is active. Exiting" -Class Information -output both
    Return 1
    #Exit 1
}

invoke-preruncheck

download-teams

kill-teams

uninstall-machinewide

#checks to see if Teams is installed, and remove wherever found
$Installed = invoke-teamslocation 
if ($installed -eq 0) { update-log -data "Teams is not installed" -Class Warning -Output Both }

install-machinewide

delete-regkey

#Runs if user has logged into the machine before and user state is inactive. This sets the scheduled task
if ($userstate -ne 3) {
    $sid = get-sid
    create-SchedXML -SID $sid
    create-SchedPS1
    update-log -Data "Creating temporary scheduled task..." -Class Information -Output Both
    
    try {
        Start-Process schtasks.exe -Args @('/create', '/xml', 'C:\Windows\temp\InstallTeams-Remediation.xml', '/tn', 'InstallTeams-Remediation') -wait -ErrorAction Stop
    }
    catch {
        update-log -Data "Couldn't create the scheduled task. Team client should reinstall after CPC is rebooted." -Class Error -Output Both
        exit 1
    }
}

Exit 0
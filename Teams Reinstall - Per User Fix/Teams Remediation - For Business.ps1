<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

#version v1.0

Param(
    [parameter(mandatory = $false, HelpMessage = "Log path and file name")] 
    [string]$logpath = "$env:SystemDrive\CPCRemediation\Teams-Remediation.log",
    [parameter(mandatory = $false, HelpMessage = "destination of files")]
    [string]$dest = "$env:SystemDrive\CPCRemediation",
    [parameter(mandatory = $false, HelpMessage = "destination of machine-wide msi")]
    [string]$filePath = "$env:SystemDrive\CPCRemediation\Teams_windows_x64.msi",
    [parameter(mandatory = $false, HelpMessage = "machine-wide installer version")]
    [string]$targetVersion = "1.5.00.19563",
    [parameter(mandatory = $false, HelpMessage = "expiration for schedtask")]
    [int]$DateOffset = 60
)
#function to handle logging
function UpdateLog {
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
        [string]$Output = "File"
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
# Function to query the user state and convert to variable
function GetUserstate {
    try {
        (((quser) -replace '^>', '') -replace '\s{2,}', ',').Trim() | ForEach-Object {
            if ($_.Split(',').Count -eq 5) {
                Write-Output ($_ -replace '(^[^,]+)', '$1,')
            }
            else {
                Write-Output $_
            }
        } | ConvertFrom-Csv
    }
    catch {
        UpdateLog -Data "quser not works." -Class Warning -Output Both
    }
}
# No active user return 0, user disc return 1, else return 2.
function InvokeUserdetect {
    UpdateLog -data "Detecting user state." -Output Console
    # explorer process can be considered as user logs on or not.
    $explorerprocesses = @(Get-WmiObject -Query "Select * FROM Win32_Process WHERE Name='explorer.exe'" -ErrorAction SilentlyContinue)
    if ($explorerprocesses.Count -eq 0) {
        UpdateLog -data "No user logs on yet." -Output Console
        return 0
    }
    else {
        # if there is explorer process, user can be active or disc.
        # quser result can be used to distinguish the exact value. 
        $session = GetUserstate
        # if quser doesn't work on the target CPC, we will consider as user active.
        if ($session.state -eq "disc") {
            UpdateLog -data "User disconnected." -Output Console
            return 1
        }
    }
    return 2
}
# Function to dowanload machine-wide installer.
function DownloadMsi {
    UpdateLog -data "Starting machine-wide installer downloading." -Output Both
    if ((test-path -Path $filePath) -eq $false) {
        $url = "https://statics.teams.cdn.office.net/production-windows-x64/$targetVersion/Teams_windows_x64.msi"
        $bits = Get-Service -Name "BITS"
        # try to download via BITS. otherwise use Invoke-WebRequest instead.
        if (($bits.StartType -ne 'Disabled') -or ($bits.Status -eq 'Running'))
        {
            try {
                Start-BitsTransfer -TransferType Download -Source $url -Destination $filePath
                UpdateLog -data "machine-wide installer downloaded." -Output Both
            }
            catch {
                UpdateLog -data "Failed to download machine-wide installer." -Class Error -Output Both
            }
        }
        else {
            $ProgressPreference = 'SilentlyContinue'
            try {
                Invoke-WebRequest -Uri $url -OutFile $filePath
                UpdateLog -data "machine-wide installer downloaded." -Output Both
            }
            catch {
                UpdateLog -data "Failed to download machine-wide installer." -Class Error -Output Both
            }
        }
    }
}
# Return true when need update.
function MachineWideNeedUpdate {
    # there's broken property ALLUSER undr HKLM:\SOFTWARE\WOW6432Node\Microsoft\Teams.
    if (Test-Path HKLM:\SOFTWARE\WOW6432Node\Microsoft\Teams) {
        # try to find the registry key's property all not equal to ALLUSER.
        $programValue = Get-ItemProperty HKLM:\SOFTWARE\WOW6432Node\Microsoft\Teams |  Where-Object {-not($_.ALLUSER)}
        # if found ALLUSER, the value is empty.
        if ($programValue.Count -eq 0) {
            return $true
        }
    }
    return $false
}
# Function to uninstall current version of machine-wide installer.
function UninstallMachinewide {
    UpdateLog -data "Starting machine-wide installer uninstallation." -Output Both
    # try to find Teams machine-wide installer's guid.
    $programValue = Get-ItemProperty HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |  Where-Object {$_.DisplayName -like "*Teams Machine-Wide Installer*"}
    $Uninstall = $programValue.UninstallString
    If ($null -eq $Uninstall) {
        UpdateLog -data "machine-wide installer not found." -Class Warning -Output Both
        return
    }
    $guid = $Uninstall.replace("MsiExec.exe /I", "")
    UpdateLog -data "Uninstalling machine-wide installer." -Output Both
    # uninstall the installer via guid.
    $process = start-process -FilePath C:\windows\System32\msiexec.exe -Args @('/X', "`"$guid`"", '/qb-') -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        UpdateLog -data "Failed to uninstall machine-wide installer." -Class Error -Output Both
        exit 1
    }
    else {
        UpdateLog -data "Uninstalled machine-wide installer." -Output Both
    }
}
# Function to get SID of VM user.
function GetSid([string] $CurrentUser) {
    UpdateLog -data "Searching user SID." -Output Both
    # get all user keys
    $userkeys = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
    foreach ($userkey in $userkeys) {
        $tempreg = $userkey.name.Replace("HKEY_LOCAL_MACHINE", "HKLM:")
        $tempresult = get-itemproperty -Path $tempreg
        # compare with the CPC user's profile name.
        # we got the profile name from directory SystemDrive\Users.
        if ($tempresult.profileimagepath -like "*$CurrentUser*") {
            UpdateLog -data "Found user SID." -Output Both
            return $userkey.PSChildName
        }
        else {
            UpdateLog -data "User SID not found." -Class Error -Output Both
            return $null
        }
    }
}
# Function to create xml of schedtask.
# Schedtask will be trigger when user from disconnected to active,
# or be triggered when user logs on after the CPC rebooted.
function CreateSchedXML([string] $SID) {
    $adjdate = (get-date).AddDays($DateOffset)
    $thedate = $adjdate | get-date -format s
    $TaskXML = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Author>Windows365</Author>
    <URI>\Teams-Remediation</URI>
  </RegistrationInfo>
  <Triggers>
    <SessionStateChangeTrigger>
      <EndBoundary>$thedate</EndBoundary>
      <Enabled>true</Enabled>
      <StateChange>RemoteConnect</StateChange>
    </SessionStateChangeTrigger>
    <LogonTrigger>
      <EndBoundary>$thedate</EndBoundary>
      <Enabled>true</Enabled>
    </LogonTrigger>
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
      <Arguments>-executionpolicy Bypass -windowstyle Hidden $dest\Teams-Remediation.ps1</Arguments>
    </Exec>
  </Actions>
</Task>
"@
    try {
        $TaskXML | Out-File "$dest\Teams-Remediation.xml" -ErrorAction Stop
    }
    catch {
        UpdateLog -data $_.Exception.Message -Class Error -Output Both
        Exit 1
    }
}
# Function to uninstall teams client and remove all related files.
function RemoveTeams([string] $path) {
    $process = Start-Process -FilePath "$path\update.exe" -Args @('--uninstall', '/s') -Wait -PassThru
    if ($process.ExitCode -eq 0)
    {
        UpdateLog -data "Uninstalled Teams." -Output Both
        remove-item -Path $path -Recurse -Force
    }
    else {
        UpdateLog -data "Failed to uninstall Teams." -Class Error -Output Both
    }
}
# Function to trigger teams uninstallation.
# Teams client could be installed under 4 possible paths.
function InvokeTeamslocation {
    $Users = Get-ChildItem -Path "$ENV:SystemDrive\Users" -Directory
    $Users | ForEach-Object {
        If ($_.Name -ne "Public") {
            $localAppData = "$($ENV:SystemDrive)\Users\$($_.Name)\AppData\Local\Microsoft\Teams"
            If (((Test-Path "$localAppData\update.exe") -eq $true) -and ((Test-Path "$localAppData\Current") -eq $true) -and ((Test-Path "$localAppData\.dead") -eq $false)) {
                RemoveTeams -path $localAppData
            }
            $programData = "$($env:ProgramData)\$($_.Name)\Microsoft\Teams"
            If (((Test-Path "$programData\update.exe") -eq $true) -and ((Test-Path "$programData\Current") -eq $true) -and ((Test-Path "$programData\.dead") -eq $false)) {
                RemoveTeams -path $programData
            }
        }
    }
    $x86AppPath = "$($ENV:SystemDrive)\Program Files (x86)\Microsoft\Teams"
    If (((Test-Path "$x86AppPath\update.exe") -eq $true) -and ((Test-Path "$x86AppPath\Current") -eq $true) -and ((Test-Path "$x86AppPath\.dead") -eq $false)) {
        RemoveTeams -path $x86AppPath
    }
    $x64AppPath = "$($ENV:SystemDrive)\Program Files\Microsoft\Teams"
    If (((Test-Path "$x64AppPath\update.exe") -eq $true) -and ((Test-Path "$x64AppPath\Current") -eq $true) -and ((Test-Path "$x64AppPath\.dead") -eq $false)) {
        RemoveTeams -path $x64AppPath
    }
}
# Function to create ps1 script used by schedtask.
# Phase 2 methods.
function CreateSchedPS1([int] $userState) {
    # script block for function methods.
    $scriptblockFunc = {
        $dest = "$env:SystemDrive\CPCRemediation"
        # Check whether the remediation related files still exist.
        # If not, exit the script execution.
        # We keep this because user might not be able to DeleteSchedtask due to user's permission.
        # So we add the pre-check method here to avoid Teams client being installed again.
        if (((test-path -Path "$dest\Teams-Remediation.xml") -eq $false) -and ((Test-Path -Path "$dest\Teams_windows_x64.msi") -eq $false)) {
            exit 0
        }
        # This method works only when the user has local admin permission.
        function DeleteSchedtask {
            try {
                Unregister-ScheduledTask -TaskPath '\' -TaskName "Teams-Remediation" -Confirm:$false -ErrorAction Stop
            }
            catch {
                exit 1
            }
        }
        # There's a property PreventInstallationFromMsi which will block teams client installation.
        # Teams machine-wide Installer will only works after reboot.
        # If the CPC state was no user logs on yet, which means the CPC has been rebooted.
        # In this case, this method will be invoked to check if we need to manually trigger installation.
        function BrokenRegistryProperty {
            $value = Get-Item -Path HKCU:\Software\Microsoft\Office\Teams -ErrorAction SilentlyContinue
            if ($value.Count -ne 0) {
                if ($value.Property -eq "PreventInstallationFromMsi") {
                    return $true
                }
            }
            return $false
        }
    }
    # This script block is only for CPC state was no user logs on yet (rebooted).
    $scriptblockInstall0 = {
        if (BrokenRegistryProperty -eq $true) {
            Start-Process -FilePath "C:\Program Files (x86)\Teams Installer\Teams.exe" -PassThru -ErrorAction Stop > $null
        }
    }
    # This script block is only for CPC state was disconnected.
    # Because if CPC was not rebooted, machine-wide installer won't work.
    # We need to trigger Teams client installation manually.
    $scriptblockInstall1 = {
        Start-Process -FilePath "C:\Program Files (x86)\Teams Installer\Teams.exe" -PassThru -ErrorAction Stop > $null
    }
    # We check user's state to select which script block above.
    if ($userState -eq 0) {
        $scriptblockInstall = $scriptblockInstall0
    } else {
        $scriptblockInstall = $scriptblockInstall1
    }
    # Script block to clean up related files.
    $scriptblockCleanup = {
        Remove-Item -Path $dest -Recurse -Force -ErrorAction Stop
        DeleteSchedtask
    }
    # Try to remove schedTask. It won't work if user has no local admin permission.
    try{
        $scriptblockFunc.ToString() + $scriptblockInstall.ToString() + $scriptblockCleanup.ToString() | Out-String -Width 4096 | Out-File -FilePath "$dest\Teams-Remediation.ps1" -Force -ErrorAction Stop
        UpdateLog -data "Created script executed by schedtask." -Output Both
    }
    catch
    {
        UpdateLog -data $_.Exception.Message -Class Error -Output Both
        exit 1
    }
}
$userState = InvokeUserdetect
$teamsNeedUpdate = MachineWideNeedUpdate
# Check if Teams is broken.
if ($teamsNeedUpdate -eq $false) {
    UpdateLog -data "Teams is fine." -Output Console
}
else {
    # If user is active, won't do anything.
    if ($userState -eq 2) {
        UpdateLog -data "User is active, exiting." -Output Console
    }
    else {
        # Phase 1.
        if ((test-path -Path $dest) -eq $false) {
            New-Item $dest -ItemType Directory > $null
        }
        # Download teams machine-wide installer.
        DownloadMsi
        # Uninstall teams machine-wide installer.
        UninstallMachinewide
        # Uninstall teams client from every possible path.
        InvokeTeamslocation
        # Install teams machine-wide installer.
        msiexec.exe /I $filePath ALLUSERS=1
        # Create PS1 file which will be triggered be schedTask in Phase 2.
        CreateSchedPS1 -userState $userState
        # List profile user name under SystemDrive\Users directory.
        $Users = Get-ChildItem -Path "$ENV:SystemDrive\Users" -Directory
        $Users | ForEach-Object {
            # CPC will only contain Public folder and profile user name's folder.
            # User name's folder will be the name we wanna to get.
            If ($_.Name -ne "Public") {
                # Once we have the user name, we can get it's SID from registry table.
                $sid = GetSid -CurrentUser $_.Name
                if ($sid -ne $null) {
                    # Create schedTask XML which will be used to setup schedTask.
                    CreateSchedXML -SID $sid
                    try {
                        # Setup schedTask.
                        Start-Process schtasks.exe -Args @("/create", "/xml", "$dest\Teams-Remediation.xml", "/tn", "Teams-Remediation") -wait -ErrorAction Stop
                        UpdateLog -Data "schedtask has been set." -Output Both
                    }
                    catch {
                        UpdateLog -Data "Couldn't create the scheduled task. Team client should reinstall after CPC is rebooted." -Class Error -Output Both
                    }
                }
            }
        }
    }
}
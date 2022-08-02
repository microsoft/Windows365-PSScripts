# Teams Remediation script. Aims to reinstall Teams client.
Param(
    [parameter(mandatory = $false, HelpMessage = "Incoming user SID")] 
    [string]$UserSid
)
# Initial constants.
$remediationFilesPath = "$env:SystemDrive\CPCRemediation"
$msiFilePath = "$remediationFilesPath\Teams_windows_x64.msi"
$installerVersion = "1.5.00.19563"
$schedTaskRetiredDay = 60
# Define output class.
Add-Type @"
    using System;
    public class CustomLog{
        public bool Succceded;
        public string UserStatus;
        public string ErrorCode;
        public string Output;
        public string Error;
    }
"@
# Define user states.
enum UserStates {
    NoUserLogged
    UserActive
    UserDisc
}
[UserStates]$noUserLogged = [UserStates]::NoUserLogged
[UserStates]$userActive = [UserStates]::UserActive
[UserStates]$userDisc = [UserStates]::UserDisc
#function to handle logging.
$log = New-Object CustomLog
$outputValues = $null
$errorValues = $null
function Log {
    Param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [string]$Data,
        [validateset('Succeeded', 'Error')]
        [string]$Class = "Succeeded",
        [validateset('QuserNotWork', 'DownloadMsiFailed', 'UninstallMachinewideFailed', 'UninstallTeamsFailed', 'InstallMachinewideFailed', 'SetupSchedTaskFailed')]
        [string]$ErrCode
    )
    if ($Class -eq "Succeeded") {
        $log.Output = $Data
        $log.Succceded = $true
        $jsonString = ConvertTo-Json -InputObject $log
        return $jsonString
    }
    if ($Class -eq "Error") {
        $errorValues += $Data
        $log.Error = $errorValues
        $log.ErrorCode = $ErrCode
        $log.Succceded = $false
        $jsonString = ConvertTo-Json -InputObject $log
        return $jsonString
    }
}
# Method to detect whether schedTask exists.
function DetectSchedTask {
    $value = Get-ScheduledTask -TaskName Teams-Remediation -ErrorAction SilentlyContinue
    if ($null -eq $value.TaskName) {
        return $false
    }
    else {
        return $true
    }
}
# Function to query the user state and convert to variable.
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
        Log -Data "quser not works." -Class Error -ErrCode QuserNotWork
        exit 1
    }
}
# Return enum according to user state.
function InvokeUserdetect {
    # explorer process can be considered as user logs on or not.
    $explorerprocesses = @(Get-WmiObject -Query "Select * FROM Win32_Process WHERE Name='explorer.exe'" -ErrorAction SilentlyContinue)
    if ($explorerprocesses.Count -eq 0) {
        return $noUserLogged
    }
    else {
        # if there is explorer process, user can be active or disc.
        # quser result can be used to distinguish the exact value. 
        $session = GetUserstate
        # if quser doesn't work on the target CPC, we will consider as user active.
        if ($session.state -eq "disc") {
            return $userDisc
        }
    }
    return $userActive
}
# Function to dowanload machine-wide installer.
function DownloadMsi {
    if ((test-path -Path $msiFilePath) -eq $false) {
        $url = "https://statics.teams.cdn.office.net/production-windows-x64/$installerVersion/Teams_windows_x64.msi"
        $bits = Get-Service -Name "BITS"
        # try to download via BITS. otherwise use Invoke-WebRequest instead.
        if (($bits.StartType -ne 'Disabled') -or ($bits.Status -eq 'Running'))
        {
            try {
                Start-BitsTransfer -TransferType Download -Source $url -Destination $msiFilePath
            }
            catch {
                Log -Data "Failed to download machine-wide installer." -Class Error -ErrCode DownloadMsiFailed
                exit 1
            }
        }
        else {
            $ProgressPreference = 'SilentlyContinue'
            try {
                Invoke-WebRequest -Uri $url -OutFile $msiFilePath
            }
            catch {
                Log -Data "Failed to download machine-wide installer." -Class Error -ErrCode DownloadMsiFailed
                exit 1
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
    # try to find Teams machine-wide installer's guid.
    $programValue = Get-ItemProperty HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |  Where-Object {$_.DisplayName -like "*Teams Machine-Wide Installer*"}
    $Uninstall = $programValue.UninstallString
    If ($null -eq $Uninstall) {
        exit 0
    }
    $guid = $Uninstall.replace("MsiExec.exe /I", "")
    # uninstall the installer via guid.
    $process = start-process -FilePath C:\windows\System32\msiexec.exe -Args @('/X', "`"$guid`"", '/qb-') -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Log -Data "Failed to uninstall machine-wide installer." -Class Error -ErrCode UninstallMachinewideFailed
        exit 1
    }
}
# Function to get SID of VM user.
function GetSid([string] $CurrentUser) {
    # get all user keys.
    $userkeys = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
    foreach ($userkey in $userkeys) {
        $tempreg = $userkey.name.Replace("HKEY_LOCAL_MACHINE", "HKLM:")
        $tempresult = get-itemproperty -Path $tempreg
        # compare with the CPC user's profile name.
        # we got the profile name from directory SystemDrive\Users.
        if ($tempresult.profileimagepath -like "*$CurrentUser*") {
            return $userkey.PSChildName
        }
        else {
            return $null
        }
    }
}
# Function to create xml of schedtask.
# Schedtask will be trigger when user from disconnected to active,
# or be triggered when user logs on after the CPC rebooted.
function CreateSchedXML([string] $SID) {
    $adjdate = (get-date).AddDays($schedTaskRetiredDay)
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
      <Arguments>-executionpolicy Bypass -windowstyle Hidden $remediationFilesPath\Teams-Remediation.ps1</Arguments>
    </Exec>
  </Actions>
</Task>
"@
    try {
        $TaskXML | Out-File "$remediationFilesPath\Teams-Remediation.xml" -ErrorAction Stop
    }
    catch {
        Log -Data $_.Exception.Message -Class Error -ErrCode SetupSchedTaskFailed
        Exit 1
    }
}
# Function to uninstall teams client and remove all related files.
function RemoveTeams([string] $path) {
    If (((Test-Path "$path\update.exe") -eq $true) -and ((Test-Path "$path\Current") -eq $true) -and ((Test-Path "$path\.dead") -eq $false)) {
        $process = Start-Process -FilePath "$path\update.exe" -Args @('--uninstall', '/s') -Wait -PassThru
        if ($process.ExitCode -eq 0)
        {
            remove-item -Path $path -Recurse -Force
        }
        else {
            Log -Data "Failed to uninstall Teams." -Class Error -ErrCode UninstallTeamsFailed
            exit 1
        }
    }
}
# Function to trigger teams uninstallation.
# Teams client could be installed under 4 possible paths.
function UninstallTeamsFromAllPaths {
    $Users = Get-ChildItem -Path "$ENV:SystemDrive\Users" -Directory
    $Users | ForEach-Object {
        If ($_.Name -ne "Public") {
            $localAppData = "$($ENV:SystemDrive)\Users\$($_.Name)\AppData\Local\Microsoft\Teams"
            RemoveTeams -path $localAppData
            $programData = "$($env:ProgramData)\$($_.Name)\Microsoft\Teams"
            RemoveTeams -path $programData
        }
    }
    $x86AppPath = "$($ENV:SystemDrive)\Program Files (x86)\Microsoft\Teams"
    RemoveTeams -path $x86AppPath
    $x64AppPath = "$($ENV:SystemDrive)\Program Files\Microsoft\Teams"
    RemoveTeams -path $x64AppPath
}
# Function to install machine-wide installer.
function InstallMachinewide {
    try {
        msiexec.exe /I $msiFilePath ALLUSERS=1
    }
    catch {
        Log -Data "Failed to install machine-wide." -Class Error -ErrCode InstallMachinewideFailed
        exit 1
    }
}
# Function to create ps1 script used by schedtask.
# Phase 2 methods.
function CreateSchedPS1([int] $userState) {
    # script block for function methods.
    $scriptblockFunc = {
        $remediationFilesPath = "$env:SystemDrive\CPCRemediation"
        # Check whether the remediation related files still exist.
        # If not, exit the script execution.
        # We keep this because user might not be able to DeleteSchedtask due to user's permission.
        # So we add the pre-check method here to avoid Teams client being installed again.
        if (((test-path -Path "$remediationFilesPath\Teams-Remediation.xml") -eq $false) -and ((Test-Path -Path "$remediationFilesPath\Teams_windows_x64.msi") -eq $false)) {
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
    $scriptblockInstallForUserNotLogged = {
        if (BrokenRegistryProperty -eq $true) {
            Start-Process -FilePath "C:\Program Files (x86)\Teams Installer\Teams.exe" -PassThru -ErrorAction Stop > $null
        }
    }
    # This script block is only for CPC state was disconnected.
    # Because if CPC was not rebooted, machine-wide installer won't work.
    # We need to trigger Teams client installation manually.
    $scriptblockInstallForDiscUser = {
        Start-Process -FilePath "C:\Program Files (x86)\Teams Installer\Teams.exe" -PassThru -ErrorAction Stop > $null
    }
    # We check user's state to select which script block above.
    if ($userState -eq $noUserLogged) {
        $scriptblockInstall = $scriptblockInstallForUserNotLogged
    } else {
        $scriptblockInstall = $scriptblockInstallForDiscUser
    }
    # Script block to clean up related files.
    $scriptblockCleanup = {
        Remove-Item -Path $remediationFilesPath -Recurse -Force -ErrorAction Stop
        DeleteSchedtask
    }
    # Try to remove schedTask. It won't work if user has no local admin permission.
    try{
        $scriptblockFunc.ToString() + $scriptblockInstall.ToString() + $scriptblockCleanup.ToString() | Out-String -Width 4096 | Out-File -FilePath "$remediationFilesPath\Teams-Remediation.ps1" -Force -ErrorAction Stop
    }
    catch
    {
        Log -Data $_.Exception.Message -Class Error -ErrCode SetupSchedTaskFailed
        exit 1
    }
}
# Check if schedTask exists.
$schedTaskExists = DetectSchedTask
if ($schedTaskExists -eq $true) {
    $outputValues += "Remediation has been applied."
    Log -Data $outputValues -Class Succeeded
    exit 0
}
# Check if Teams is broken.
$teamsNeedUpdate = MachineWideNeedUpdate
if ($teamsNeedUpdate -eq $false) {
    $outputValues += "Teams is fine."
    Log -Data $outputValues -Class Succeeded
    exit 0
}
# If user is active, won't do anything.
$userState = InvokeUserdetect
if ($userState -eq $userActive) {
    $log.UserStatus = $userState
    $outputValues += "User is active."
    Log -Data $outputValues -Class Succeeded
    exit 0
}
$log.UserStatus = $userState
# Start Phase 1.
if ((test-path -Path $remediationFilesPath) -eq $false) {
    New-Item $remediationFilesPath -ItemType Directory > $null
}
DownloadMsi
UninstallMachinewide
UninstallTeamsFromAllPaths
InstallMachinewide
# Create PS1 file which will be triggered be schedTask in Phase 2.
CreateSchedPS1 -userState $userState
# List profile user name under SystemDrive\Users directory.
$Users = Get-ChildItem -Path "$ENV:SystemDrive\Users" -Directory
$userName = ($Users | ForEach-Object {
    # CPC will only contain Public folder and profile user name's folder.
    # User name's folder will be the name we wanna to get.
    If ($_.Name -ne "Public") {
        return $_.Name
    }
})
# Once we have the user name, we can get it's SID from registry table.
# In case the CPC is never logged by user, we pass sid from service.
if ($null -eq $userName) {
    $sid = $UserSid
}
else {
    $sid = GetSid -CurrentUser $userName
}
if ($null -ne $sid) {
    # Create schedTask XML which will be used to setup schedTask.
    CreateSchedXML -SID $sid
    try {
        # Setup schedTask.
        Start-Process schtasks.exe -Args @("/create", "/xml", "$remediationFilesPath\Teams-Remediation.xml", "/tn", "Teams-Remediation") -wait -ErrorAction Stop
        $outputValues += "schedtask has been set."
    }
    catch {
        Log -Data "Couldn't create the scheduled task. Team client should reinstall after CPC is rebooted." -Class Error -ErrCode SetupSchedTaskFailed
        exit 1
    }
}
# Finalize without any issue will return a structured json.
$outputValues += "Phase 1 finished."
Log -Data $outputValues -Class Succeeded

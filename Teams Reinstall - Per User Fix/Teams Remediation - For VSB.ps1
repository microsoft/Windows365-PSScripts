# Teams Remediation script.
Param(
    [parameter(mandatory = $false, HelpMessage = "destination of files")]
    [string]$dest = "$env:SystemDrive\CPCRemediation",
    [parameter(mandatory = $false, HelpMessage = "destination of machine-wide msi")]
    [string]$filePath = "$env:SystemDrive\CPCRemediation\Teams_windows_x64.msi",
    [parameter(mandatory = $false, HelpMessage = "machine-wide installer version")]
    [string]$targetVersion = "1.5.00.11865",
    [parameter(mandatory = $false, HelpMessage = "expiration for schedtask")]
    [string]$DateOffset = 60
)
# Function to dowanload machine-wide installer.
function DownloadMsi {
    if ((test-path -Path $filePath) -eq $false) {
        $url = "https://statics.teams.cdn.office.net/production-windows-x64/$targetVersion/Teams_windows_x64.msi"
        $bits = Get-Service -Name "BITS"
        if (($bits.StartType -ne 'Disabled') -or ($bits.Status -eq 'Running'))
        {
            Start-BitsTransfer -TransferType Download -Source $url -Destination $filePath
        }
        else 
        {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $url -OutFile $filePath
        }
    }
}
# Function to check machine-wide version, return true if need to update.
function MachineWideNeedUpdate {
    $programValue = Get-ItemProperty HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |  Where-Object {$_.DisplayName -like "*Teams Machine-Wide Installer*"}
    return [System.Version]$programValue.DisplayVersion -lt [System.Version]$targetVersion
}
# Function to uninstall current version of machine-wide installer.
function UninstallMachinewide {  
    $programValue = Get-ItemProperty HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |  Where-Object {$_.DisplayName -like "*Teams Machine-Wide Installer*"}
    $Uninstall = $programValue.UninstallString
    If ($null -eq $Uninstall) {
        return
    }
    $guid = $Uninstall.replace("MsiExec.exe /I", "")
    $process = start-process -FilePath C:\windows\System32\msiexec.exe -Args @('/X', "`"$guid`"", '/qb-') -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        exit 1
    }
}
# Function to get SID of VM user.
function GetSid([string] $CurrentUser) {
    $userkeys = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
    foreach ($userkey in $userkeys) {
        $tempreg = $userkey.name.Replace("HKEY_LOCAL_MACHINE", "HKLM:")
        $tempresult = get-itemproperty -Path $tempreg
        if ($tempresult.profileimagepath -like "*$CurrentUser*") {
            return $userkey.PSChildName
        }
        else {
            return ""
        }
    }
}
# Function to create xml of schedtask.
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
        Write-Host $_.Exception.Message
    }
}
# Function to create ps1 script used by schedtask.
function CreateSchedPS1 {
    $scriptblock = {
        $dest = "$env:SystemDrive\CPCRemediation"
        function RemoveTeams([string] $path) {
            $process = Start-Process -FilePath "$path\update.exe" -Args @('--uninstall', '/s') -Wait -PassThru
            if ($process.ExitCode -eq 0)
            {
                remove-item -Path $path -Recurse -Force
            }
        }
        function DeleteSchedtask {
            try {
                Unregister-ScheduledTask -TaskPath '\' -TaskName "Teams-Remediation" -Confirm:$false -ErrorAction Stop
            }
            catch {
                exit 1
            }
        }
        if (((test-path -Path "$dest\Teams-Remediation.xml") -eq $False) -and ((Test-Path -Path "$dest\Teams_windows_x64.msi") -eq $false)) {
            exit 0
        }
        $Users = Get-ChildItem -Path "$ENV:SystemDrive\Users" -Directory
        $Users | ForEach-Object {
            If ($_.Name -ne "Public") {
                $localAppData = "$($ENV:SystemDrive)\Users\$($_.Name)\AppData\Local\Microsoft\Teams"
                If (((Test-Path "$localAppData\update.exe") -eq $true) -and ((Test-Path "$localAppData\Current") -eq $true) -and ((Test-Path "$localAppData\.dead") -eq $false)) {
                    RemoveTeams -path $localAppData
                }
                # check
                $programData = "$($env:ProgramData)\$($_.Name)\Microsoft\Teams"
                If (((Test-Path "$programData\update.exe") -eq $true) -and ((Test-Path "$programData\Current") -eq $true) -and ((Test-Path "$programData\.dead") -eq $false)) {
                    RemoveTeams -path $programData
                }
            }
        }
        # check
        $x86AppPath = "$($ENV:SystemDrive)\Program Files (x86)\Microsoft\Teams"
        If (((Test-Path "$x86AppPath\update.exe") -eq $true) -and ((Test-Path "$x86AppPath\Current") -eq $true) -and ((Test-Path "$x86AppPath\.dead") -eq $false)) {
            RemoveTeams -path $x86AppPath
        }
        # check
        $x64AppPath = "$($ENV:SystemDrive)\Program Files\Microsoft\Teams"
        If (((Test-Path "$x64AppPath\update.exe") -eq $true) -and ((Test-Path "$x64AppPath\Current") -eq $true) -and ((Test-Path "$x64AppPath\.dead") -eq $false)) {
            RemoveTeams -path $x64AppPath
        }
        try {
            $value = Start-Process -FilePath "C:\Program Files (x86)\Teams Installer\Teams.exe" -PassThru -ErrorAction Stop
        }
        catch {
            exit 1
        }
        Remove-Item -Path $dest -Recurse -Force -ErrorAction Stop
        DeleteSchedtask
    }
    try{
        $scriptblock | Out-String -Width 4096 | Out-File -FilePath "$dest\Teams-Remediation.ps1" -Force -ErrorAction Stop
    }
    catch
    {
        exit 1
    }
}
# Only apply remediation if machine-wide version is lower than target one.
if ((MachineWideNeedUpdate) -eq $true) {
	# Create CPCRemediation folder under system drive if not exists.
	if ((test-path -Path $dest) -eq $false) {
		$createFolder = New-Item $dest -ItemType Directory
	}
    DownloadMsi
    UninstallMachinewide
    msiexec.exe /I $filePath ALLUSERS=1
    CreateSchedPS1
    $Users = Get-ChildItem -Path "$ENV:SystemDrive\Users" -Directory
    $Users | ForEach-Object {
        If ($_.Name -ne "Public") {
            $sid = GetSid -CurrentUser $_.Name
            if ($sid -ne "") {
                CreateSchedXML -SID $sid
                try {
                    Start-Process schtasks.exe -Args @("/create", "/xml", "$dest\Teams-Remediation.xml", "/tn", "Teams-Remediation") -wait -ErrorAction Stop
                }
                catch {
                    exit 1
                }
            }
        }
    }
    Write-Host "CloudPC is applied teams remediation."
}
else {
    Write-Host "CloudPC uses latest machine-wide installer."
}
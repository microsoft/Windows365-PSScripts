<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

#version v1.0

# Teams Remediation script for user. Aims to reinstall Teams client.
# This script is required to be executed via Powershell Run as Administrator.
# Initial constants.
$remediationFilesPath = "$env:SystemDrive\CPCRemediation"
$msiFilePath = "$remediationFilesPath\Teams_windows_x64.msi"
$installerVersion = "1.5.00.19563"
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
                Write-Host "Failed to download machine-wide installer."
                exit 1
            }
        }
        else {
            $ProgressPreference = 'SilentlyContinue'
            try {
                Invoke-WebRequest -Uri $url -OutFile $msiFilePath
            }
            catch {
                Write-Host "Failed to download machine-wide installer."
                exit 1
            }
        }
    }
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
        Write-Host "Failed to uninstall machine-wide installer."
        exit 1
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
            Write-Host "Failed to uninstall Teams."
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
        Write-Host "Failed to install machine-wide."
        exit 1
    }
}
# Start Remediation.
if ((test-path -Path $remediationFilesPath) -eq $false) {
    New-Item $remediationFilesPath -ItemType Directory > $null
}
DownloadMsi
UninstallMachinewide
UninstallTeamsFromAllPaths
InstallMachinewide
while((Test-Path "C:\Program Files (x86)\Teams Installer\Teams.exe") -eq $false) {
    Write-Host "Wait for teams machine-wide installer installing..."
    Start-Sleep -Seconds 5
}
Start-Process -FilePath "C:\Program Files (x86)\Teams Installer\Teams.exe" -PassThru -ErrorAction Stop > $null
Remove-Item -Path $remediationFilesPath -Recurse -Force -ErrorAction Stop
# Finalize without any issue will return a structured json.
Write-Host "Remediation finished."

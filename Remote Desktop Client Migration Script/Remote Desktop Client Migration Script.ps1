<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

#Microsoft Remote Desktop Client Migration Script
#Version 1.2
#For more info, visit: https://github.com/microsoft/Windows365-PSScripts

Param(
    [parameter(mandatory = $false, HelpMessage = "Value to set auto update reg key")]
    [ValidateSet(0,1,2,3)]
    [int]$DisableAutoUpdate = 0,
    [parameter(mandatory = $false, HelpMessage = "Do not uninstall Remote Desktop if found")]
    [switch]$SkipRemoteDesktopUninstall ,
    [parameter(mandatory = $false, HelpMessage = "Log path and file name")] 
    [string]$logpath = "$env:windir\temp\RDC-Migration.log"
)

#$DisableAutoUpdate values:
#0: Enables updates (default value)
#1: Disable updates from all locations
#2: Disable updates from the Microsoft Store
#3: Disable updates from the CDN location

#logging function
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

#function to uninstall MSRDC by pulling MSIEXEC.EXE GUID from the registy - primary method
function uninstall-MSRDCreg{
    
    $MSRCDreg = Get-ItemProperty hklm:\software\microsoft\windows\currentversion\uninstall\* | Where-Object {$_.Displayname -eq "Remote Desktop"} | Select-Object DisplayName,DisplayVersion,UninstallString,QuietUninstallString
    if ($MSRCDreg.DisplayName -eq "Remote Desktop"){
        update-log -Data "Remote Desktop Installation Found" -Class Information -Output Both
        $uninstall = $MSRCDreg.uninstallstring -replace "MsiExec.exe /X",""
        update-log -Data "Uninstalling Remote Desktop"  -Class Information -Output Both
        
        try{
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $($uninstall) /q /norestart" -Wait -ErrorAction Stop
        }
        catch
        {
            update-log -Data "Something went wrong uninstalling Remote Desktop" -Class Error -Output Both 
            Update-Log -data $_.Exception.Message -Class Error -Output Both
        }
    }
    else
    {
    update-log -Data "Remote Desktop not detected via registry. Trying as package" -Class Information -Output Both
    uninstall-MSRDC
    }
}

#Function to uninstall MSRDC via uninstall-package as a secondary method
function uninstall-MSRDC{
    try{
        update-log -Data "Looking to see if Remote Desktop is an installed package" -Class Information -Output Both
        try{
            $MSRDC = Get-Package -Name "Remote Desktop" -ErrorAction Stop
        }
        catch
        {
            Update-Log -data $_.Exception.Message -Class Error -Output Both
        }

        if ($MSRDC.name -eq "Remote Desktop"){
           update-log -Data "Remote Desktop Install Found" -Class Information -Output Both
           #update-log -Data "Version: " $MSRDC.Version
           update-log -Data "Uninstalling Remote Desktop" -Class Information -Output Both
           try{
                Uninstall-Package -Name "Remote Desktop" -force -ErrorAction Stop| Out-Null
           }
           catch
           {
                Update-Log -data $_.Exception.Message -Class Error -Output Both
           }
         
           update-log -Data "Remote Desktop uninstalled" -Class Information -Output Both
       }
    }
    catch
    {
        update-log -Data "Remote Desktop not found as package." -Class Information -Output Both
    }
}

#Function to install Windows App from MSIX direct download
function install-windowsappMSIX{
    $guid = New-Guid
    try{
        update-log -data "Downloading payload" -Class Information -Output Both
        #if ((test-path -Path $env:windir\Temp\WindowsApp.msix) -eq $true){Remove-Item -Path $env:windir\Temp\WindowsApp.msix -Force -ErrorAction Stop}        
        
        new-item -Path $env:windir\temp -Name $guid.guid -ItemType Directory -Force -ErrorAction Stop | Out-Null
        $path = $env:windir + "\temp\" + $guid.guid

        $Payload = Invoke-WebRequest -uri "https://go.microsoft.com/fwlink/?linkid=2262633" -UseBasicParsing -OutFile $path\WindowsApp.msix -PassThru -ErrorAction Stop
        $filename = ($Payload.BaseResponse.ResponseUri.AbsolutePath -replace ".*/")
    
        #if ((test-path -Path $env:windir\Temp\$filename) -eq $true){Remove-Item -Path $env:windir\Temp\$filename -Force -ErrorAction Stop}    
    
        Rename-Item -Path $path\WindowsApp.msix -NewName $filename -Force -ErrorAction Stop
        update-log -Data "Downloaded $filename to $path" -Class Information -Output Both
        
        }
    catch{
        Update-Log -data $_.Exception.Message -Class Error -Output Both
    }
    try{
        #Add-AppxPackage -Path $env:windir\temp\$filename -ErrorAction Stop
        update-log -data "Installing Windows App MSIX package..." -Class Information -Output Both
        add-appxprovisionedpackage -PackagePath $path\$filename -online -SkipLicense -ErrorAction Stop | Out-Null
    }
    catch{
        Update-Log -data $_.Exception.Message -Class Error -Output Both
    }

    try{
        update-log -data "Cleaning up temp folder and files..." -Class Information -Output Both
        remove-item -Path $path -Recurse -Force -ErrorAction Stop | Out-Null
    
    }
    catch{
        Update-Log -data $_.Exception.Message -Class Error -Output Both
    }
}

#Function to check if Windows App is installed
function invoke-WAInstallCheck{
    
    $WAappx = (Get-AppxProvisionedPackage -online | Where-Object {$_.DisplayName -eq "MicrosoftCorporationII.Windows365"})
    
    if  ($WAappx.DisplayName -eq "MicrosoftCorporationII.Windows365"){
        update-log -Data "Windows App Provisioning Package installation found." -Class Information -Output Both
        update-log -data $WAappx.displayname -Class Information -Output Both
        update-log -data $WAappx.version -Class Information -Output Both
        Return 0
    }
    else
    {
        update-log -Data "Windows App Provisioning Package installation not found." -Class Information -Output Both
        Return 1
    }
}

#function to set the registry key to control auto updates
function invoke-disableautoupdate($num){
    update-log -Data "Setting disableautoupdate reg key" -Class Information -Output Both
    $path = "HKLM:\SOFTWARE\Microsoft\WindowsApp"
    If (!(Test-Path $path)) {
        New-Item -Path $path -Force
    }
    try{
        New-ItemProperty -Path $path -Name DisableAutomaticUpdates -PropertyType DWORD -Value $num -Force -ErrorAction Stop| Out-Null    
    }
    catch{
        Update-Log -data $_.Exception.Message -Class Error -Output Both
    }
}



#check if Windows App is installed. If so, skip installation. Else, install
if ((invoke-WAInstallCheck) -eq 0){
    update-log -Data "Skipping Windows App Installation" -Class Information -Output Both
    }
else
    {

    #if ($source -eq "MSIX"){
        update-log -Data "Starting Windows App installation from MSIX download" -Class Information -Output Both
        install-windowsappMSIX
    #    }
}

#verify if Windows App has now been installed. If so, move to uninstalling MSRDC. Else, fail.
if ((invoke-WAInstallCheck) -eq 0){
    update-log -Data "Validated Windows App Installed" -Class Information -Output Both
    if ($SkipRemoteDesktopUninstall -eq $False){uninstall-MSRDCreg}
    }
    else
    {
    update-log -Data "Windows App does not appear to be installed. Something went wrong" -Class Error -Output Both
    exit 1
    }

#Apply auto update registry key if option selected
if ($DisableAutoUpdate -ne 0){
    if ($DisableAutoUpdate -eq 1){invoke-disableautoupdate -num 1}
    if ($DisableAutoUpdate -eq 2){invoke-disableautoupdate -num 2}
    if ($DisableAutoUpdate -eq 3){invoke-disableautoupdate -num 3}
}

update-log -Data "Installation Complete" -Class Information -Output Both
update-log -data "************" -Class Information -Output File

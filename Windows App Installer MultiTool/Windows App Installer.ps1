﻿#cls
#Needs:
#try/catch in main functions
#complete #change update-log -Data to proper logging
#complete #Test Param Block
#test with store disabled from policy
#test on Windows 10
#test on LTSC greater than 1809
#test when Windows App doesn't install (use pause and delete)

Param(
    [parameter(mandatory = $false, HelpMessage = "Where to source installer payload")] 
    [ValidateSet('Store','WinGet','MSIX')]
    [string]$source = "Store",
    [parameter(mandatory = $false, HelpMessage = "Value to set auto update reg key")]
    [ValidateSet(0,1,2,3)]
    [int]$DisableAutoUpdate = 0,
    #[parameter(mandatory = $false, HelpMessage = "Uninstall Remote Desktop if found")]
    #[ValidateSet($true,$false)]
    #[string]$UninstallMSRDC = $true,
    [parameter(mandatory = $false, HelpMessage = "Do not uninstall Remote Desktop if found")]
    [switch]$SkipRemoteDesktopUninstall ,
    [parameter(mandatory = $false, HelpMessage = "Log path and file name")] 
    [string]$logpath = "$env:windir\temp\MultiTool.log"
)

#$DisableAutoUpdate = 0 
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
    
    $MSRCDreg = Get-ItemProperty hklm:\software\microsoft\windows\currentversion\uninstall\* | Where-Object {$_.Displayname -like "*Remote Desktop*"} | Select-Object DisplayName,DisplayVersion,UninstallString,QuietUninstallString
    if ($MSRCDreg.DisplayName -eq "Remote Desktop"){
        update-log -Data "Remote Desktop Installation Found" -Class Information -Output Both
        $uninstall = $MSRCDreg.uninstallstring -replace "MsiExec.exe /X",""
        update-log -Data "Uninstalling Remote Desktop"  -Class Information -Output Both
        
        try{
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $($uninstall) /q /norestart" -ErrorAction Stop
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

#function to install Windows App from MS Store - write install process log to $env:windir\temp\WindowsAppStoreInstall.log
function install-windowsappstore{
   update-log -Data "Writing install process log to $env:windir\temp\WindowsAppStoreInstall.log" -Class Information -Output Both
   try{
        invoke-command -ScriptBlock { winget install 9N1F85V9T8BN --accept-package-agreements --accept-source-agreements} | Out-File -FilePath $env:windir\temp\WindowsAppStoreInstall.log -Append #MS Store Install 
   }
   catch
   {
        Update-Log -data $_.Exception.Message -Class Error -Output Both
        Exit 1
   }

}

#Function to install Windows App from Winget CDN - write install process log to $env:windir\temp\WindowsAppWinGetInstall.log
function install-windowsappwinget{
    update-log -Data "Writing install process log to $env:windir\temp\WindowsAppWinGetInstall.log" -Class Information -Output Both
    try{
        invoke-command -ScriptBlock {winget install Microsoft.WindowsApp --accept-package-agreements --accept-source-agreements} | Out-File -FilePath $env:windir\temp\WindowsAppWinGetInstall.log -Append #Winget Install
    }
    catch
    {
        Update-Log -data $_.Exception.Message -Class Error -Output Both
        Exit 1
    }

}

#Function to install Windows App from MSIX direct download
function install-windowsappMSIX{

    try{
        if ((test-path -Path $env:windir\Temp\WindowsApp.msix) -eq $true){Remove-Item -Path $env:windir\Temp\WindowsApp.msix -Force -ErrorAction Stop}        
        
        $Payload = Invoke-WebRequest -uri "https://go.microsoft.com/fwlink/?linkid=2262633" -UseBasicParsing -OutFile $env:windir\Temp\WindowsApp.msix -PassThru -ErrorAction Stop
        $filename = ($Payload.BaseResponse.ResponseUri.AbsolutePath -replace ".*/")
    
        if ((test-path -Path $env:windir\Temp\$filename) -eq $true){Remove-Item -Path $env:windir\Temp\$filename -Force -ErrorAction Stop}    
    
        Rename-Item -Path $env:windir\Temp\WindowsApp.msix -NewName $filename -Force -ErrorAction Stop
        update-log -Data "Downloaded $filename to $env:windir\temp" -Class Information -Output Both
        }
    catch{
        Update-Log -data $_.Exception.Message -Class Error -Output Both
    }

    try{
        Add-AppxPackage -Path $env:windir\temp\$filename -ErrorAction Stop
    }
    catch{
        Update-Log -data $_.Exception.Message -Class Error -Output Both
    }
    
    
    }

#Function to check if Windows App is installed
function invoke-WAInstallCheck{
    if ((($testWA = get-appxpackage -name MicrosoftCorporationII.Windows365).name) -eq "MicrosoftCorporationII.Windows365"  ){
        update-log -Data "Windows App Installation found." -Class Information -Output Both
        Return 0
    }
    else
    {
        update-log -Data "Windows App installation not found." -Class Information -Output Both
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
    if ($source -eq "Store"){
        update-log -Data "Starting Windows App installation from Microsoft Store" -Class Information -Output Both
        install-windowsappstore
        }
    if ($source -eq "WinGet"){
        update-log -Data "Starting Windows App installation from WinGet" -Class Information -Output Both
        install-windowsappwinget
        }
    if ($source -eq "MSIX"){
        update-log -Data "Starting Windows App installation from MSIX download" -Class Information -Output Both
        install-windowsappMSIX
        }
}

#verify if Windows App has now been installed. If so, move to uninstalling MSRDC. Else, fail.
if ((invoke-WAInstallCheck) -eq 0){
    update-log -Data "Validated Windows App Installed" -Class Information -Output Both
    if ($SkipRemoteDesktopUninstall -eq $False){uninstall-MSRDCreg}
    #$SkipRemoteDesktopUninstall
    #update-log -Data "Installation Complete"
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

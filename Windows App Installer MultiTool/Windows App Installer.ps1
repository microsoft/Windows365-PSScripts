#cls
#Needs:
#try/catch in main functions
#change write-host to proper logging
#Test Param Block
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
    [parameter(mandatory = $false, HelpMessage = "Value to set auto update reg key")]
    [ValidateSet($true,$false)]
    [string]$UninstallMSRDC = $true
)


#$source = "Store" #Store,WinGet,MSIX,All
#$UninstallMSRDC = $true #$true,$false

#$DisableAutoUpdate = 0 
#0: Enables updates (default value)
#1: Disable updates from all locations
#2: Disable updates from the Microsoft Store
#3: Disable updates from the CDN location

#function to uninstall MSRDC by pulling MSIEXEC.EXE GUID from the registy - primary method
function uninstall-MSRDCreg{
    
    $MSRCDreg = Get-ItemProperty hklm:\software\microsoft\windows\currentversion\uninstall\* | Where-Object {$_.Displayname -like "*Remote Desktop*"} | Select-Object DisplayName,DisplayVersion,UninstallString,QuietUninstallString
    if ($MSRCDreg.DisplayName -eq "Remote Desktop"){
        write-host "Remote Desktop Installation Found"
        #write-host "Version " $MSRCDreg.DisplayVersion
        $uninstall = $MSRCDreg.uninstallstring -replace "MsiExec.exe /X",""
        write-host "Uninstalling Remote Desktop"
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $($uninstall) /q /norestart"
    }
    else
    {
    write-host "Remote Desktop not detected via registry. Trying as package"
    uninstall-MSRDC
    
    }
}

#Function to uninstall MSRDC via uninstall-package as a secondary method
function uninstall-MSRDC{
    try{
        write-host "Looking to see if Remote Desktop is an installed package"
        $MSRDC = Get-Package -Name "Remote Desktop" -ErrorAction Stop

        if ($MSRDC.name -eq "Remote Desktop"){
           write-host "Remote Desktop Install Found"
           #write-host "Version: " $MSRDC.Version
           write-host "Uninstalling Remote Desktop"
           Uninstall-Package -Name "Remote Desktop" -force | Out-Null
           write-host "Remote Desktop uninstalled"
       }
    }
    catch
    {
        Write-Host "Remote Desktop not found as package."
    }
}

#function to install Windows App from MS Store - write install process log to $env:windir\temp\WindowsAppStoreInstall.log
function install-windowsappstore{
   invoke-command -ScriptBlock { winget install 9N1F85V9T8BN --accept-package-agreements --accept-source-agreements} | Out-File -FilePath c:\windows\temp\WindowsAppStoreInstall.log -Append #MS Store Install 
}

#Function to install Windows App from Winget CDN - write install process log to $env:windir\temp\WindowsAppWinGetInstall.log
function install-windowsappwinget{
    invoke-command -ScriptBlock {winget install Microsoft.WindowsApp --accept-package-agreements --accept-source-agreements} | Out-File -FilePath c:\windows\temp\WindowsAppWinGetInstall.log -Append #Winget Install
}

#Function to install Windows App from MSIX direct download
function install-windowsappMSIX{
    Invoke-WebRequest -uri "https://go.microsoft.com/fwlink/?linkid=2262633" -outfile "c:\windows\temp\WindowsApp.MSIX" -UseBasicParsing -PassThru #windowsapp download
    Add-AppxPackage -Path C:\windows\temp\WindowsApp.MSIX
    }

#Function to check if Windows App is installed
function invoke-WAInstallCheck{
    if ((($testWA = get-appxpackage -name MicrosoftCorporationII.Windows365).name) -eq "MicrosoftCorporationII.Windows365"  ){
        Write-Host "Windows App Installation found."
        Return 0
    }
    else
    {
        write-host "Windows App installation not found."
        Return 1
    }
}

#function to set the registry key to control auto updates
function invoke-disableautoupdate($num){
    write-host "Setting disableautoupdate reg key"
    $path = "HKLM:\SOFTWARE\Microsoft\WindowsApp"
    If (!(Test-Path $path)) {
        New-Item -Path $path -Force
}

    New-ItemProperty -Path $path -Name DisableAutomaticUpdates -PropertyType DWORD -Value $num -Force    

}

#check if Windows App is installed. If so, skip installation. Else, install
if ((invoke-WAInstallCheck) -eq 0){
    write-host "Skipping Windows App Installation"
    }
else
    {
    if ($source -eq "Store"){
        write-host "Starting Windows App installation from Microsoft Store"
        install-windowsappstore
        }
    if ($source -eq "WinGet"){
        write-host "Starting Windows App installation from WinGet"
        install-windowsappwinget
        }
    if ($source -eq "MSIX"){
        write-host "Starting Windows App installation from MSIX download"
        install-windowsappMSIX
        }
}

#verify if Windows App has now been installed. If so, move to uninstalling MSRDC. Else, fail.
if ((invoke-WAInstallCheck) -eq 0){
    write-host "Validated Windows App Installed"
    if ($UninstallMSRDC -eq $true){uninstall-MSRDCreg}
    #write-host "Installation Complete"
    }
    else
    {
    write-host "Windows App does not appear to be installed. Something went wrong"
    }

#Apply auto update registry key if option selected
if ($DisableAutoUpdate -ne 0){
    if ($DisableAutoUpdate -eq 1){invoke-disableautoupdate -num 1}
    if ($DisableAutoUpdate -eq 2){invoke-disableautoupdate -num 2}
    if ($DisableAutoUpdate -eq 3){invoke-disableautoupdate -num 3}

}
write-host "Installation Complete"

cls

$source = "Store" #Store,WinGet,MSIX,All
$UninstallMSRDC = $true #$true,$false

function uninstall-MSRDC{
    try{
        write-host "Looking to see if Remote Desktop is an installed package"
        $MSRDC = Get-Package -Name "Remote Desktop" -ErrorAction Stop

        if ($MSRDC.name -eq "Remote Desktop"){
           write-host "Remote Desktop Install Found"
           write-host "Version: " $MSRDC.Version
           write-host "Uninstalling Remote Desktop"
           Uninstall-Package -Name "Remote Desktop" -force | Out-Null
       }
    }
    catch
    {
        Write-Host "Remote Desktop not found as package."
    }
}

function uninstall-MSRDCreg{
    
    $MSRCDreg = Get-ItemProperty hklm:\software\microsoft\windows\currentversion\uninstall\* | Where-Object {$_.Displayname -like "*Remote Desktop*"} | Select-Object DisplayName,DisplayVersion,UninstallString,QuietUninstallString
    if ($MSRCDreg.DisplayName -eq "Remote Desktop"){
        write-host "MSRDC Installation Found"
        write-host "Version " $MSRCDreg.DisplayVersion
        $uninstall = $MSRCDreg.uninstallstring -replace "MsiExec.exe /X",""
        write-host "uninstalling"
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $($uninstall) /q /norestart"
    }
    else
    {
    write-host "MSRDC not detected via registry. Trying as package"
    uninstall-MSRDC
    
    }
}

#function to install Windows App from MS Store
function install-windowsappstore{
   invoke-command -ScriptBlock { winget install 9N1F85V9T8BN --accept-package-agreements --accept-source-agreements} #MS Store Install
}

#Function to install Windows App from Winget CDN
function install-windowsappwinget{
    invoke-command -ScriptBlock {winget install Microsoft.WindowsApp --accept-package-agreements --accept-source-agreements} #Winget Install
}

#Function to install Windows App from MSIX direct download
function install-windowsappMSIX{
    Invoke-WebRequest -uri "https://go.microsoft.com/fwlink/?linkid=2262633" -outfile "c:\windows\temp\WindowsApp.MSIX" -UseBasicParsing -PassThru #windowsapp download
    Add-AppxPackage -Path C:\windows\temp\WindowsApp.MSIX
    }

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

#check if Windows App is installed. If so, skip installation. Else, install
if ((invoke-WAInstallCheck) -eq 0){
    write-host "Skipping Windows App Installation"
    }
else
    {
    if ($source -eq "Store"){install-windowsappstore}
    if ($source -eq "WinGet"){install-windowsappwinget}
    if ($source -eq "MSIX"){install-windowsappMSIX}
}

#verify if Windows App has now been installed. If so, move to uninstalling MSRDC. Else, fail.
if ((invoke-WAInstallCheck) -eq 0){
    if ($UninstallMSRDC -eq $true){uninstall-MSRDCreg}
    write-host "Installation Complete"
    }
    else
    {
    write-host "Windows App does not appear to be installed. Something went wrong"
    }
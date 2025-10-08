cls

$source = "Store" #Store,WinGet,MSIX,All
$UninstallMSRDC = $true #$true,$false

function uninstall-MSRDC{
    try{

        $MSRDC = Get-Package -Name "Remote Desktop" -ErrorAction Stop

        if ($MSRDC.name -eq "Remote Desktop"){
           write-host "Remote Desktop Install Found"
           write-host "Version: " $MSRDC.Version
           Uninstall-Package -Name "Remote Desktop" -force | Out-Null
       }
    }
    catch
    {
        Write-Host "Remote Desktop not found as package."
        write-host "Trying reg key detection."
        uninstall-MSRDCreg

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
    {write-host "MSRDC not installed"}
}

function install-windowsappstore{
   invoke-command -ScriptBlock { winget install 9N1F85V9T8BN --accept-package-agreements --accept-source-agreements} #MS Store Install
     
}

function install-windowsappwinget{
    invoke-command -ScriptBlock {winget install Microsoft.WindowsApp --accept-package-agreements --accept-source-agreements} #Winget Install


}

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


if ((invoke-WAInstallCheck) -eq 0){
    write-host "Skipping Windows App Installation"
    }
else
    {
    if ($source -eq "Store"){install-windowsappstore}
    if ($source -eq "WinGet"){install-windowsappwinget}
    if ($source -eq "MSIX"){install-windowsappMSIX}
}

if ((invoke-WAInstallCheck) -eq 0){
    if ($UninstallMSRDC -eq $true){uninstall-msrdc}
    write-host "Installation Complete"
    }
    else
    {
    write-host "Windows App does not appear to be installed. Something went wrong"
    }
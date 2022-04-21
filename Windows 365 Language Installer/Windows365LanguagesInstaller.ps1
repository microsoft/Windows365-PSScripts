
<#PSScriptInfo

.VERSION 1.0.0.2

.GUID afa48b3c-60c5-42a6-9ae7-a8b8b59a3000

.AUTHOR Microsoft Corporation

.COMPANYNAME Microsoft Corporation

.COPYRIGHT (c) 2021 Microsoft Corporation. All rights reserved.

.TAGS 

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES


#> 





<# 

.DESCRIPTION 
A PowerShell script to install additional languages machine-wide on Windows 10. After installing the desired languages through the script, you can capture this Windows 10 instance as a generalized image, use it as the base image for users' Cloud PCs, and have the languages readily available when they log in. 

To use this script for a Windows 365 custom device image, see the documentation site(https://go.microsoft.com/fwlink/?linkid=2172610).  

This PowerShell script is provided as-is. For any questions on using the script, see the Windows 365 Tech Community(https://aka.ms/w365tc). For any feedback to improve the script, see the Windows 365 Feedback page(https://aka.ms/w365feedback).  

This script supports the following versions of Windows 10: 
    • Windows 10, version 1903 
    • Windows 10, version 1909 
    • Windows 10, version 2004 
    • Windows 10, version 20H2
    • Windows 10, version 21H1

The script supports installing the following 38 languages: 
    • Arabic (Saudia Arabia) 
    • Bulgarian (Bulgaria) 
    • Czech (Czech Republic) 
    • Danish (Denmark) 
    • German (Germany) 
    • Greek (Greece) 
    • English (United Kingdom) 
    • English (United States) 
    • Spanish (Spain) 
    • Spanish (Mexico) 
    • Estonian (Estonia) 
    • Finnish (Finland) 
    • French (Canada) 
    • French (France) 
    • Hebrew (Israel) 
    • Croatian (Croatia) 
    • Hungarian (Hungary) 
    • Italian (Italy) 
    • Japanese (Japan) 
    • Korean (Korea) 
    • Lithuanian (Lithuania) 
    • Latvian (Latvia) 
    • Norwegian (Bokmål) (Norway) 
    • Dutch (Netherlands) 
    • Polish (Poland) 
    • Portuguese (Brazil) 
    • Portuguese (Portugal) 
    • Romanian (Romania) 
    • Russian (Russia) 
    • Slovak (Slovakia) 
    • Slovenian (Slovenia) 
    • Serbian (Latin, Serbia) 
    • Swedish (Sweden) 
    • Thai (Thailand) 
    • Turkish (Turkey) 
    • Ukrainian (Ukraine) 
    • Chinese (Simplified) 
    • Chinese (Traditional) 

#> 

Param()

$downloadPath = "$env:SystemDrive\Users\$env:UserName\Downloads\"

$languages = @("ar-SA", "bg-BG", "cs-CZ", "da-DK","de-DE", "el-GR", "en-GB","en-US","es-ES",
"es-MX","et-EE","fi-FI","fr-CA","fr-FR","he-IL","hr-HR","hu-HU","it-IT","ja-JP","ko-KR","lt-LT",
"lv-LV","nb-NO","nl-NL","pl-PL","pt-BR","pt-PT","ro-RO","ru-RU","sk-SK","sl-SI","sr-Cyrl-CS",
"sv-SE","th-TH","tr-TR","uk-UA","zh-CN","zh-TW")

$languagesDescription = @("Arabic (Saudi Arabia)","Bulgarian (Bulgaria)","Czech (Czech Republic)","Danish (Denmark)","German (Germany)","Greek (Greece)","English (United Kingdom)","English (United States)","Spanish (Spain)",
"Spanish (Mexico)","Estonian (Estonia)","Finnish (Finland)","French (Canada)","French (France)","Hebrew (Israel)","Croatian (Croatia)","Hungarian (Hungary)","Italian (Italy)","Japanese (Japan)","Korean (Korea)","Lithuanian (Lithuania)",
"Latvian (Latvia)","Norwegian (Bokmål) (Norway)","Dutch (Netherlands)","Polish (Poland)","Portuguese (Brazil)","Portuguese (Portugal)","Romanian (Romania)","Russian (Russia)","Slovak (Slovakia)","Slovenian (Slovenia)","Serbian (Latin, Serbia)",
"Swedish (Sweden)","Thai (Thailand)","Turkish (Turkey)","Ukrainian (Ukraine)","Chinese (Simplified)","Chinese (Traditional)")

function ListSupportedLanguages(){
    foreach($num in 1..$languages.Count){
        Write-Host "`n[$num] $($languagesDescription[$num-1])"
    }
}

$1903Files = @{
    'LanguagePack' = "https://software-download.microsoft.com/download/pr/18362.1.190318-1202.19h1_release_CLIENTLANGPACKDVD_OEM_MULTI.iso"
    'FOD'          = "https://software-download.microsoft.com/download/pr/18362.1.190318-1202.19h1_release_amd64fre_FOD-PACKAGES_OEM_PT1_amd64fre_MULTI.iso"
    'InboxApps'    = "https://software-download.microsoft.com/download/pr/18362.1.190318-1202.19h1_release_amd64fre_InboxApps.iso"
}

$1909Files = @{
    'LanguagePack' = 'https://software-download.microsoft.com/download/pr/18362.1.190318-1202.19h1_release_CLIENTLANGPACKDVD_OEM_MULTI.iso'
    'FOD'          = 'https://software-download.microsoft.com/download/pr/18362.1.190318-1202.19h1_release_amd64fre_FOD-PACKAGES_OEM_PT1_amd64fre_MULTI.iso'
    'InboxApps'    = 'https://software-download.microsoft.com/download/pr/18362.1.190318-1202.19h1_release_amd64fre_InboxApps.iso'
}

$2004Files = @{
    'LanguagePack' = 'https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_CLIENTLANGPACKDVD_OEM_MULTI.iso'
    'FOD'          = 'https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_amd64fre_FOD-PACKAGES_OEM_PT1_amd64fre_MULTI.iso'
    'InboxApps'    = 'https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_amd64fre_InboxApps.iso'
}

$20H2Files = @{
    'LanguagePack' = 'https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_CLIENTLANGPACKDVD_OEM_MULTI.iso'
    'FOD'          = 'https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_amd64fre_FOD-PACKAGES_OEM_PT1_amd64fre_MULTI.iso'
    'InboxApps'    = 'https://software-download.microsoft.com/download/pr/19041.508.200905-1327.vb_release_svc_prod1_amd64fre_InboxApps.iso'
}

$21H1Files = @{
    'LanguagePack' = 'https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_CLIENTLANGPACKDVD_OEM_MULTI.iso'
    'FOD'          = 'https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_amd64fre_FOD-PACKAGES_OEM_PT1_amd64fre_MULTI.iso'
    'InboxApps'    = 'https://software-download.microsoft.com/download/sg/19041.928.210407-2138.vb_release_svc_prod1_amd64fre_InboxApps.iso'
}

$languageFiles = @{
    '1903' = $1903Files
    '1909' = $1909Files
    '2004' = $2004Files
    '20H2' = $20H2Files
    '21H1' = $21H1Files
}

function DownloadFile($fileName, $url, $outFile) {
    Write-Output "Downloading $fileName file..." 
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $url -OutFile $outFile
}

function DownloadLanguageFiles() {
    $files = $languageFiles[$winver]

    $space = 20
    foreach ($fileName in $files.Keys) {
        $fileUrl = $files[$fileName]
        $outFile = $downloadPath + $fileUrl.Split("/")[-1]
        if (Test-Path $outFile) {
            $space -= 5
        }
    }
    
    $CDrive = GWMI Win32_LogicalDisk -Filter "DeviceID='C:'"
    if ([Math]::Round($CDrive.FreeSpace / 1GB) -lt $space) {
        Write-Output "Not enough space. Install additional languages require $space GB free space, please try again after cleaning the disk."
        Break Script
    }

    foreach ($fileName in $files.Keys) {
        $fileUrl = $files[$fileName]
        $outFile = $downloadPath + $fileUrl.Split("/")[-1]

        if (!(Test-Path $outFile)) {
            DownloadFile $fileName $fileUrl $outFile
        }
    }
}

function GetOutputFilePath($fileName) {
    return $downloadPath + $languageFiles[$winver][$fileName].Split("/")[-1]
}

function MountFile($filePath) {
    $result = Mount-DiskImage -ImagePath $filePath -PassThru
    return ($result | Get-Volume).Driveletter
}

function DismountFile($filePath) {
    Dismount-DiskImage -ImagePath $filePath | Out-Null
}

function CleanupLanguageFiles() {
    Remove-Item (GetOutputFilePath 'LanguagePack')
    Remove-Item (GetOutputFilePath 'FOD')
    Remove-Item (GetOutputFilePath 'InboxApps')
}

function InstallLanguagePackage($languageCode, $driveletter) {
    Write-Output "Installing $languageCode language pack"

    $LIPContent = $driveLetter + ":"

    $lowerLanguageCode = $languageCode.ToLower()
    $packagePath = "$LIPContent\LocalExperiencePack\$lowerLanguageCode\LanguageExperiencePack.$languageCode.Neutral.appx"
    $licensePath = "$LIPContent\LocalExperiencePack\$lowerLanguageCode\License.xml"

    Add-AppProvisionedPackage -Online -PackagePath $packagePath -LicensePath $licensePath
    Add-WindowsPackage -Online -PackagePath $LIPContent\x64\langpacks\Microsoft-Windows-Client-Language-Pack_x64_$lowerLanguageCode.cab
}

function AddWindowsPackageIfExists ($filePath) {
    if (Test-Path $filePath) {
        Write-Output "Installing $filePath"
        Add-WindowsPackage -Online -PackagePath $filePath
    }
}

function InstallFOD($languageCode, $driveLetter) {
    Write-Output "Installing $languageCode FOD"

    $LIPContent = $driveLetter + ":"

    if ($languageCode -eq "zh-CN") {
        AddWindowsPackageIfExists $LIPContent\Microsoft-Windows-LanguageFeatures-Fonts-Hans-Package~31bf3856ad364e35~amd64~~.cab
    }

    AddWindowsPackageIfExists $LIPContent\Microsoft-Windows-LanguageFeatures-Basic-$languagecode-Package~31bf3856ad364e35~amd64~~.cab
    AddWindowsPackageIfExists $LIPContent\Microsoft-Windows-LanguageFeatures-Handwriting-$languagecode-Package~31bf3856ad364e35~amd64~~.cab
    AddWindowsPackageIfExists $LIPContent\Microsoft-Windows-LanguageFeatures-OCR-$languagecode-Package~31bf3856ad364e35~amd64~~.cab
    AddWindowsPackageIfExists $LIPContent\Microsoft-Windows-LanguageFeatures-Speech-$languagecode-Package~31bf3856ad364e35~amd64~~.cab
    AddWindowsPackageIfExists $LIPContent\Microsoft-Windows-LanguageFeatures-TextToSpeech-$languagecode-Package~31bf3856ad364e35~amd64~~.cab
    AddWindowsPackageIfExists $LIPContent\Microsoft-Windows-NetFx3-OnDemand-Package~31bf3856ad364e35~amd64~$languagecode~.cab
    AddWindowsPackageIfExists $LIPContent\Microsoft-Windows-InternetExplorer-Optional-Package~31bf3856ad364e35~amd64~$languagecode~.cab
    AddWindowsPackageIfExists $LIPContent\Microsoft-Windows-MSPaint-FoD-Package~31bf3856ad364e35~amd64~$languagecode~.cab
    AddWindowsPackageIfExists $LIPContent\Microsoft-Windows-Notepad-FoD-Package~31bf3856ad364e35~amd64~$languagecode~.cab
    AddWindowsPackageIfExists $LIPContent\Microsoft-Windows-PowerShell-ISE-FOD-Package~31bf3856ad364e35~amd64~$languagecode~.cab
    AddWindowsPackageIfExists $LIPContent\Microsoft-Windows-Printing-WFS-FoD-Package~31bf3856ad364e35~amd64~$languagecode~.cab
    AddWindowsPackageIfExists $LIPContent\Microsoft-Windows-StepsRecorder-Package~31bf3856ad364e35~amd64~$languagecode~.cab
    AddWindowsPackageIfExists $LIPContent\Microsoft-Windows-WordPad-FoD-Package~31bf3856ad364e35~amd64~$languagecode~.cab
}

function UpdateLanguageList($languageCode) {
    Write-Output "Adding $languageCode to LanguageList"

    $LanguageList = Get-WinUserLanguageList
    $LanguageList.Add($languageCode)
    Set-WinUserLanguageList $LanguageList -force
}

###################################
## Update inbox apps for language##
###################################
function InstallInboxApps() {
    Write-Output "Installing InboxApps"

    $file = GetOutputFilePath 'InboxApps'
    $driveletter = MountFile $file

    $AppsContent = $driveletter + ":\amd64fre"
    foreach ($App in (Get-AppxProvisionedPackage -Online)) {
        $AppPath = $AppsContent + $App.DisplayName + '_' + $App.PublisherId
        Write-Output "Handling $AppPath"
        $licFile = Get-Item $AppPath*.xml
        if ($licFile.Count) {
            $lic = $true
            $licFilePath = $licFile.FullName
        }
        else {
            $lic = $false
        }
        $appxFile = Get-Item $AppPath*.appx*
        if ($appxFile.Count) {
            $appxFilePath = $appxFile.FullName
            if ($lic) {
                Add-AppxProvisionedPackage -Online -PackagePath $appxFilePath -LicensePath $licFilePath 
            }
            else {
                Add-AppxProvisionedPackage -Online -PackagePath $appxFilePath -skiplicense
            }
        }
    }

    DismountFile $file
}

function InstallLanguageFiles($languageCode) { 
    $languagePackDriveLetter = MountFile (GetOutputFilePath 'LanguagePack')
    $fodDriveLetter = MountFile (GetOutputFilePath 'FOD')

    InstallLanguagePackage $languageCode $languagePackDriveLetter
    InstallFOD $languageCode $fodDriveLetter
    UpdateLanguageList $languageCode

    DismountFile (GetOutputFilePath 'LanguagePack')
    DismountFile (GetOutputFilePath 'FOD')

    InstallInboxApps
}

function Install() {

    ListSupportedLanguages
    $languageNumber = Read-Host "Select number to install language"

    if (!($languageNumber -in 1..$languages.Count))
    {
        Write-Host "Invalid language number." -ForegroundColor red
        break
    }

    $languageCode = $languages[$languageNumber - 1]

    DownloadLanguageFiles 
    InstallLanguageFiles $languageCode
    CleanupLanguageFiles
}

If (!(test-path $downloadPath)) {
    New-Item -ItemType Directory -Force -Path $downloadPath
}

$currentWindowsIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$currentWindowsPrincipal = [Security.Principal.WindowsPrincipal]$currentWindowsIdentity
 
if( -not $currentWindowsPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
    Write-Host "Script needs to be run as Administrator." -ForegroundColor red
    Break Script
}

$winver = (Get-Item "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion").GetValue('DisplayVersion')
if (!$winver) {
    $winver = (Get-Item "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion").GetValue('ReleaseId')
}

if (!$languageFiles[$winver]){
    Write-Host "Languages installer is not supportd Windows $winver." -ForegroundColor red
    Break Script
}

##Disable language pack cleanup##
Disable-ScheduledTask -TaskPath "\Microsoft\Windows\AppxDeploymentClient\" -TaskName "Pre-staged app cleanup"

Write-Output "Install Windows $winver languages:" 
Install
# SIG # Begin signature block
# MIInOAYJKoZIhvcNAQcCoIInKTCCJyUCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDB9vAEFUYUirz5
# wmuc+s3etbPtRFYujJJGISZ8NuG7L6CCEWUwggh3MIIHX6ADAgECAhM2AAABOXjG
# OfXldyfqAAEAAAE5MA0GCSqGSIb3DQEBCwUAMEExEzARBgoJkiaJk/IsZAEZFgNH
# QkwxEzARBgoJkiaJk/IsZAEZFgNBTUUxFTATBgNVBAMTDEFNRSBDUyBDQSAwMTAe
# Fw0yMDEwMjEyMDM5MDZaFw0yMTA5MTUyMTQzMDNaMCQxIjAgBgNVBAMTGU1pY3Jv
# c29mdCBBenVyZSBDb2RlIFNpZ24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
# AoIBAQCvtf6RG9X1bFXLQOzLuA06k5gBhizLWQ3/m6nIKOwoNsu9N+s9yt+ZGRpb
# ZbDtBmtAeoi3c2XK9vf0x3sq32GWPPv+px6a7u55tQ9lq4evX6QNxPhrH++ltlUt
# siiVmV934/+F5B/71sJ1Nxr89OsExV1b5Ey7LiKkEwxpTRxlOyUXf4OiQvTDzG0I
# 7AseJ4RxOy23tLnh8268pkucY2PbSLFYoRIG1ZGNgchcprL+uiRLuCz4vZXfidQo
# Wus3ThY8+mYulD8AaQ5ZtnuwzSHtzxYm/g6OeSDsf4xFep0DYLA3zNiKO4CvmzNR
# jJbcg1Bm7OpDe/CSLSWG5aoqW+X5AgMBAAGjggWDMIIFfzApBgkrBgEEAYI3FQoE
# HDAaMAwGCisGAQQBgjdbAQEwCgYIKwYBBQUHAwMwPQYJKwYBBAGCNxUHBDAwLgYm
# KwYBBAGCNxUIhpDjDYTVtHiE8Ys+hZvdFs6dEoFgg93NZoaUjDICAWQCAQwwggJ2
# BggrBgEFBQcBAQSCAmgwggJkMGIGCCsGAQUFBzAChlZodHRwOi8vY3JsLm1pY3Jv
# c29mdC5jb20vcGtpaW5mcmEvQ2VydHMvQlkyUEtJQ1NDQTAxLkFNRS5HQkxfQU1F
# JTIwQ1MlMjBDQSUyMDAxKDEpLmNydDBSBggrBgEFBQcwAoZGaHR0cDovL2NybDEu
# YW1lLmdibC9haWEvQlkyUEtJQ1NDQTAxLkFNRS5HQkxfQU1FJTIwQ1MlMjBDQSUy
# MDAxKDEpLmNydDBSBggrBgEFBQcwAoZGaHR0cDovL2NybDIuYW1lLmdibC9haWEv
# QlkyUEtJQ1NDQTAxLkFNRS5HQkxfQU1FJTIwQ1MlMjBDQSUyMDAxKDEpLmNydDBS
# BggrBgEFBQcwAoZGaHR0cDovL2NybDMuYW1lLmdibC9haWEvQlkyUEtJQ1NDQTAx
# LkFNRS5HQkxfQU1FJTIwQ1MlMjBDQSUyMDAxKDEpLmNydDBSBggrBgEFBQcwAoZG
# aHR0cDovL2NybDQuYW1lLmdibC9haWEvQlkyUEtJQ1NDQTAxLkFNRS5HQkxfQU1F
# JTIwQ1MlMjBDQSUyMDAxKDEpLmNydDCBrQYIKwYBBQUHMAKGgaBsZGFwOi8vL0NO
# PUFNRSUyMENTJTIwQ0ElMjAwMSxDTj1BSUEsQ049UHVibGljJTIwS2V5JTIwU2Vy
# dmljZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlvbixEQz1BTUUsREM9R0JM
# P2NBQ2VydGlmaWNhdGU/YmFzZT9vYmplY3RDbGFzcz1jZXJ0aWZpY2F0aW9uQXV0
# aG9yaXR5MB0GA1UdDgQWBBRQasfWFuGWZ4TjHj7E0G+JYLldgzAOBgNVHQ8BAf8E
# BAMCB4AwUAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRp
# b25zIFB1ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzYxNjcrNDYyNTE2MIIB1AYDVR0f
# BIIByzCCAccwggHDoIIBv6CCAbuGPGh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9w
# a2lpbmZyYS9DUkwvQU1FJTIwQ1MlMjBDQSUyMDAxLmNybIYuaHR0cDovL2NybDEu
# YW1lLmdibC9jcmwvQU1FJTIwQ1MlMjBDQSUyMDAxLmNybIYuaHR0cDovL2NybDIu
# YW1lLmdibC9jcmwvQU1FJTIwQ1MlMjBDQSUyMDAxLmNybIYuaHR0cDovL2NybDMu
# YW1lLmdibC9jcmwvQU1FJTIwQ1MlMjBDQSUyMDAxLmNybIYuaHR0cDovL2NybDQu
# YW1lLmdibC9jcmwvQU1FJTIwQ1MlMjBDQSUyMDAxLmNybIaBumxkYXA6Ly8vQ049
# QU1FJTIwQ1MlMjBDQSUyMDAxLENOPUJZMlBLSUNTQ0EwMSxDTj1DRFAsQ049UHVi
# bGljJTIwS2V5JTIwU2VydmljZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlv
# bixEQz1BTUUsREM9R0JMP2NlcnRpZmljYXRlUmV2b2NhdGlvbkxpc3Q/YmFzZT9v
# YmplY3RDbGFzcz1jUkxEaXN0cmlidXRpb25Qb2ludDAfBgNVHSMEGDAWgBQbZqIZ
# /JvrpdqEjxiY6RCkw3uSvTAfBgNVHSUEGDAWBgorBgEEAYI3WwEBBggrBgEFBQcD
# AzANBgkqhkiG9w0BAQsFAAOCAQEArFNMfAJStrd/3V4hInTdjEo/CLYAY8YX/foG
# Amyk6NrjEx3uFN0sJmR3qR0iBggS3SBiUi4oZ+Xk8+DjVnnJFn9Fhmu/kB2wT4ZK
# jjjZeWROPcTsUnRgs1+OhKTWbX2Eng8oH3Cq0qR9LaOT/ES5Ejd98S1jq6WZ8B8K
# dNHg0d+VGAtwts+E3uu8MkUM5rUukmPHW7BC8ttmgKeXZiIiLV4T1KzxBMMNg0lY
# 7iFbQ5fkj5hLa1E0WvsGMcMGOMwRUVwVwl6F8OL8aUY5i7tpAuz54XVS4W1grPyT
# JDae1qB19H5JvqTwPPNm30JrFGpR/X/SGQhROsoD4V1tvCJ8tDCCCOYwggbOoAMC
# AQICEx8AAAAUtMUfxvKAvnEAAAAAABQwDQYJKoZIhvcNAQELBQAwPDETMBEGCgmS
# JomT8ixkARkWA0dCTDETMBEGCgmSJomT8ixkARkWA0FNRTEQMA4GA1UEAxMHYW1l
# cm9vdDAeFw0xNjA5MTUyMTMzMDNaFw0yMTA5MTUyMTQzMDNaMEExEzARBgoJkiaJ
# k/IsZAEZFgNHQkwxEzARBgoJkiaJk/IsZAEZFgNBTUUxFTATBgNVBAMTDEFNRSBD
# UyBDQSAwMTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANVXgQLW+frQ
# 9xuAud03zSTcZmH84YlyrSkM0hsbmr+utG00tVRHgw40pxYbJp5W+hpDwnmJgicF
# oGRrPt6FifMmnd//1aD/fW1xvGs80yZk9jxTNcisVF1CYIuyPctwuJZfwE3wcGxh
# kVw/tj3ZHZVacSls3jRD1cGwrcVo1IR6+hHMvUejtt4/tv0UmUoH82HLQ8w1oTX9
# D7xj35Zt9T0pOPqM3Gt9+/zs7tPp2gyoOYv8xR4X0iWZKuXTzxugvMA63YsB4ehu
# SBqzHdkF55rxH47aT6hPhvDHlm7M2lsZcRI0CUAujwcJ/vELeFapXNGpt2d3wcPJ
# M0bpzrPDJ/8CAwEAAaOCBNowggTWMBAGCSsGAQQBgjcVAQQDAgEBMCMGCSsGAQQB
# gjcVAgQWBBSR/DPOQp72k+bifVTXCBi7uNdxZTAdBgNVHQ4EFgQUG2aiGfyb66Xa
# hI8YmOkQpMN7kr0wggEEBgNVHSUEgfwwgfkGBysGAQUCAwUGCCsGAQUFBwMBBggr
# BgEFBQcDAgYKKwYBBAGCNxQCAQYJKwYBBAGCNxUGBgorBgEEAYI3CgMMBgkrBgEE
# AYI3FQYGCCsGAQUFBwMJBggrBgEFBQgCAgYKKwYBBAGCN0ABAQYLKwYBBAGCNwoD
# BAEGCisGAQQBgjcKAwQGCSsGAQQBgjcVBQYKKwYBBAGCNxQCAgYKKwYBBAGCNxQC
# AwYIKwYBBQUHAwMGCisGAQQBgjdbAQEGCisGAQQBgjdbAgEGCisGAQQBgjdbAwEG
# CisGAQQBgjdbBQEGCisGAQQBgjdbBAEGCisGAQQBgjdbBAIwGQYJKwYBBAGCNxQC
# BAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAw
# HwYDVR0jBBgwFoAUKV5RXmSuNLnrrJwNp4x1AdEJCygwggFoBgNVHR8EggFfMIIB
# WzCCAVegggFToIIBT4YjaHR0cDovL2NybDEuYW1lLmdibC9jcmwvYW1lcm9vdC5j
# cmyGMWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2lpbmZyYS9jcmwvYW1lcm9v
# dC5jcmyGI2h0dHA6Ly9jcmwyLmFtZS5nYmwvY3JsL2FtZXJvb3QuY3JshiNodHRw
# Oi8vY3JsMy5hbWUuZ2JsL2NybC9hbWVyb290LmNybIaBqmxkYXA6Ly8vQ049YW1l
# cm9vdCxDTj1BTUVST09ULENOPUNEUCxDTj1QdWJsaWMlMjBLZXklMjBTZXJ2aWNl
# cyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9uLERDPUFNRSxEQz1HQkw/Y2Vy
# dGlmaWNhdGVSZXZvY2F0aW9uTGlzdD9iYXNlP29iamVjdENsYXNzPWNSTERpc3Ry
# aWJ1dGlvblBvaW50MIIBqwYIKwYBBQUHAQEEggGdMIIBmTA3BggrBgEFBQcwAoYr
# aHR0cDovL2NybDEuYW1lLmdibC9haWEvQU1FUk9PVF9hbWVyb290LmNydDBHBggr
# BgEFBQcwAoY7aHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraWluZnJhL2NlcnRz
# L0FNRVJPT1RfYW1lcm9vdC5jcnQwNwYIKwYBBQUHMAKGK2h0dHA6Ly9jcmwyLmFt
# ZS5nYmwvYWlhL0FNRVJPT1RfYW1lcm9vdC5jcnQwNwYIKwYBBQUHMAKGK2h0dHA6
# Ly9jcmwzLmFtZS5nYmwvYWlhL0FNRVJPT1RfYW1lcm9vdC5jcnQwgaIGCCsGAQUF
# BzAChoGVbGRhcDovLy9DTj1hbWVyb290LENOPUFJQSxDTj1QdWJsaWMlMjBLZXkl
# MjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9uLERDPUFNRSxE
# Qz1HQkw/Y0FDZXJ0aWZpY2F0ZT9iYXNlP29iamVjdENsYXNzPWNlcnRpZmljYXRp
# b25BdXRob3JpdHkwDQYJKoZIhvcNAQELBQADggIBACi3Soaajx+kAWjNwgDqkIvK
# AOFkHmS1t0DlzZlpu1ANNfA0BGtck6hEG7g+TpUdVrvxdvPQ5lzU3bGTOBkyhGmX
# oSIlWjKC7xCbbuYegk8n1qj3rTcjiakdbBqqHdF8J+fxv83E2EsZ+StzfCnZXA62
# QCMn6t8mhCWBxpwPXif39Ua32yYHqP0QISAnLTjjcH6bAV3IIk7k5pQ/5NA6qIL8
# yYD6vRjpCMl/3cZOyJD81/5+POLNMx0eCClOfFNxtaD0kJmeThwL4B2hAEpHTeRN
# tB8ib+cze3bvkGNPHyPlSHIuqWoC31x2Gk192SfzFDPV1PqFOcuKjC8049SSBtC1
# X7hyvMqAe4dop8k3u25+odhvDcWdNmimdMWvp/yZ6FyjbGlTxtUqE7iLTLF1eaUL
# SEobAap16hY2N2yTJTISKHzHI4rjsEQlvqa2fj6GLxNj/jC+4LNy+uRmfQXShd30
# lt075qTroz0Nt680pXvVhsRSdNnzW2hfQu2xuOLg8zKGVOD/rr0GgeyhODjKgL2G
# Hxctbb9XaVSDf6ocdB//aDYjiabmWd/WYmy7fQ127KuasMh5nSV2orMcAed8CbIV
# I3NYu+sahT1DRm/BGUN2hSpdsPQeO73wYvp1N7DdLaZyz7XsOCx1quCwQ+bojWVQ
# TmKLGegSoUpZNfmP9MtSMYIVKTCCFSUCAQEwWDBBMRMwEQYKCZImiZPyLGQBGRYD
# R0JMMRMwEQYKCZImiZPyLGQBGRYDQU1FMRUwEwYDVQQDEwxBTUUgQ1MgQ0EgMDEC
# EzYAAAE5eMY59eV3J+oAAQAAATkwDQYJYIZIAWUDBAIBBQCgga4wGQYJKoZIhvcN
# AQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUw
# LwYJKoZIhvcNAQkEMSIEILEmuFvL/+HPxMIHfB3Q0qxpYwE8+gGHegpIn+m59ggq
# MEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEAfYXc+277HGQf
# Uk7hQujZfUpcujz4GN5W5t+LilyfvWqG2S7wPm9I9mzP8s5rJiPPxEde18VrtVOR
# lYO3pYqbTebA4wToVphmGA8qskzGlvr8jFgSxT5HwPJ1MIR7C7CwYz7emC/eXAQ2
# qpfLN2U6x0Hb7Bo7sDbuaofagTp7Aw6m+IyAIlZb5PZ09N+OO6VYnXJCJZOv/ZGJ
# iKTUT91wvuazZAxslkYQctYN+UBQ4HF7vjboKA4jnjcAeYw/lS7YzAoSY75WZNtZ
# wZJ+QNj5g+XYcxA5arl69rVX6FdMhKhStvFppO032B53M7dLb92djInIUkDwdLdv
# YoKcKGKcy6GCEvEwghLtBgorBgEEAYI3AwMBMYIS3TCCEtkGCSqGSIb3DQEHAqCC
# EsowghLGAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFVBgsqhkiG9w0BCRABBKCCAUQE
# ggFAMIIBPAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCDZmK7jAsO8
# ArG+wcBflCeGG7e18gc8Ki/n4KUuC/Wo7QIGYR69zXzkGBMyMDIxMDkxNDA5MjY0
# MS45OTJaMASAAgH0oIHUpIHRMIHOMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSkwJwYDVQQLEyBNaWNyb3NvZnQgT3BlcmF0aW9ucyBQdWVydG8g
# UmljbzEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046MEE1Ni1FMzI5LTRENEQxJTAj
# BgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Wggg5EMIIE9TCCA92g
# AwIBAgITMwAAAVt8sLo0ZzfBpwAAAAABWzANBgkqhkiG9w0BAQsFADB8MQswCQYD
# VQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3Nv
# ZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yMTAxMTQxOTAyMTZaFw0yMjA0MTEx
# OTAyMTZaMIHOMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSkw
# JwYDVQQLEyBNaWNyb3NvZnQgT3BlcmF0aW9ucyBQdWVydG8gUmljbzEmMCQGA1UE
# CxMdVGhhbGVzIFRTUyBFU046MEE1Ni1FMzI5LTRENEQxJTAjBgNVBAMTHE1pY3Jv
# c29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAw
# ggEKAoIBAQDIJH+l7PXaoXrLpi5bZ5epcI4g9Y4fiKc/+o+auQkM0p22lbqOCogo
# kqa+VraqlZQ+50/91l+ler3KTUFeXHbVVcGnzaS598hfn0TaFFodUPbvFxokl/GM
# 1UvKuvCTxYkTuBzMzKSwmko3H0GSHegorpMi0K7ip0hcHRoTMROxgmsmkPGQ8hDx
# 7PwtseAAGDBbFTrLEnUfI2/H8wHpN0jZWbVSndCm/IqPt15EOeDL1F1fXFS9f3g3
# V1VQQajoR86CbMvnNsv7N1voBF/EG/Tv24wZEeoSGjsBAMOzbuNP0zFX8Fye4OUf
# xzVwre3OCGozTeFvgroHsrC52G6kZlvpAgMBAAGjggEbMIIBFzAdBgNVHQ4EFgQU
# ZectNYhtt1MgXUx/9eU5yZi6qy4wHwYDVR0jBBgwFoAU1WM6XIoxkPNDe3xGG8Uz
# aFqFbVUwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29t
# L3BraS9jcmwvcHJvZHVjdHMvTWljVGltU3RhUENBXzIwMTAtMDctMDEuY3JsMFoG
# CCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraS9jZXJ0cy9NaWNUaW1TdGFQQ0FfMjAxMC0wNy0wMS5jcnQwDAYDVR0T
# AQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcDCDANBgkqhkiG9w0BAQsFAAOCAQEA
# pzNrO6YTGpnOEHVaJaztWV0YgzFFXYLvf8qvIO5CFZfn5JVFdlZaLrevn6TqgBp3
# sDLcHpxbWoFYVSfB2rvDcJPiAIQdAdOA6GzQ8O7+ChEwEX/CjfIEx+ge0Yx4a3jA
# 1oO4nFdA7KI/DCAPAIq1pcH+J6/KSh9J9qxE7HgSQ1nN3W1NCEyRB9UcxYRpFuyM
# zT0AjteuU6ezS516eJmmc6FcfD8ojjTun8g2a9MqlbofTqlh/nz2WEP2GBcoccvo
# R1jrqmKXPNz4Z9bwNAHtflp+G53umRoz8USOrMbDCJHQVw9ByS8je2H0q2zlQGMI
# 2Fjh63rBmbr6BGhIA0VlKzCCBnEwggRZoAMCAQICCmEJgSoAAAAAAAIwDQYJKoZI
# hvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# MjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAy
# MDEwMB4XDTEwMDcwMTIxMzY1NVoXDTI1MDcwMTIxNDY1NVowfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTAwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQCpHQ28dxGKOiDs/BOX9fp/aZRrdFQQ1aUKAIKF++18aEssX8XD5WHCdrc+Zitb
# 8BVTJwQxH0EbGpUdzgkTjnxhMFmxMEQP8WCIhFRDDNdNuDgIs0Ldk6zWczBXJoKj
# RQ3Q6vVHgc2/JGAyWGBG8lhHhjKEHnRhZ5FfgVSxz5NMksHEpl3RYRNuKMYa+YaA
# u99h/EbBJx0kZxJyGiGKr0tkiVBisV39dx898Fd1rL2KQk1AUdEPnAY+Z3/1ZsAD
# lkR+79BL/W7lmsqxqPJ6Kgox8NpOBpG2iAg16HgcsOmZzTznL0S6p/TcZL2kAcEg
# CZN4zfy8wMlEXV4WnAEFTyJNAgMBAAGjggHmMIIB4jAQBgkrBgEEAYI3FQEEAwIB
# ADAdBgNVHQ4EFgQU1WM6XIoxkPNDe3xGG8UzaFqFbVUwGQYJKwYBBAGCNxQCBAwe
# CgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0j
# BBgwFoAU1fZWy4/oolxiaNE9lJBb186aGMQwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0
# cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljUm9vQ2Vy
# QXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXRf
# MjAxMC0wNi0yMy5jcnQwgaAGA1UdIAEB/wSBlTCBkjCBjwYJKwYBBAGCNy4DMIGB
# MD0GCCsGAQUFBwIBFjFodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vUEtJL2RvY3Mv
# Q1BTL2RlZmF1bHQuaHRtMEAGCCsGAQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAFAA
# bwBsAGkAYwB5AF8AUwB0AGEAdABlAG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUA
# A4ICAQAH5ohRDeLG4Jg/gXEDPZ2joSFvs+umzPUxvs8F4qn++ldtGTCzwsVmyWrf
# 9efweL3HqJ4l4/m87WtUVwgrUYJEEvu5U4zM9GASinbMQEBBm9xcF/9c+V4XNZgk
# Vkt070IQyK+/f8Z/8jd9Wj8c8pl5SpFSAK84Dxf1L3mBZdmptWvkx872ynoAb0sw
# RCQiPM/tA6WWj1kpvLb9BOFwnzJKJ/1Vry/+tuWOM7tiX5rbV0Dp8c6ZZpCM/2pi
# f93FSguRJuI57BlKcWOdeyFtw5yjojz6f32WapB4pm3S4Zz5Hfw42JT0xqUKloak
# vZ4argRCg7i1gJsiOCC1JeVk7Pf0v35jWSUPei45V3aicaoGig+JFrphpxHLmtgO
# R5qAxdDNp9DvfYPw4TtxCd9ddJgiCGHasFAeb73x4QDf5zEHpJM692VHeOj4qEir
# 995yfmFrb3epgcunCaw5u+zGy9iCtHLNHfS4hQEegPsbiSpUObJb2sgNVZl6h3M7
# COaYLeqN4DMuEin1wC9UJyH3yKxO2ii4sanblrKnQqLJzxlBTeCG+SqaoxFmMNO7
# dDJL32N79ZmKLxvHIa9Zta7cRDyXUHHXodLFVeNp3lfB0d4wwP3M5k37Db9dT+md
# Hhk4L7zPWAUu7w2gUDXa7wknHNWzfjUeCLraNtvTX4/edIhJEqGCAtIwggI7AgEB
# MIH8oYHUpIHRMIHOMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MSkwJwYDVQQLEyBNaWNyb3NvZnQgT3BlcmF0aW9ucyBQdWVydG8gUmljbzEmMCQG
# A1UECxMdVGhhbGVzIFRTUyBFU046MEE1Ni1FMzI5LTRENEQxJTAjBgNVBAMTHE1p
# Y3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WiIwoBATAHBgUrDgMCGgMVAAq7QW6m
# MtK/mBi7VGhVUVv2Ie6moIGDMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
# IDIwMTAwDQYJKoZIhvcNAQEFBQACBQDk6tntMCIYDzIwMjEwOTE0MTIyMTAxWhgP
# MjAyMTA5MTUxMjIxMDFaMHcwPQYKKwYBBAGEWQoEATEvMC0wCgIFAOTq2e0CAQAw
# CgIBAAICK5sCAf8wBwIBAAICEWIwCgIFAOTsK20CAQAwNgYKKwYBBAGEWQoEAjEo
# MCYwDAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG
# 9w0BAQUFAAOBgQBH59OewnZ0+Cok8bUwZxZJiUHxAH/efrmpeInIZRhwAaiso2m7
# QO727X16Mjtv4IRta9l8C6uFrLWnw+iiy+azJcTz5S3AY7vHHmErcGsVxOsDb4qZ
# /OxiqFglZVg9NP5eT5c2xBGXrrZKEyjgTnVsUoeaAFB0oEXgzgFo5/AKrzGCAw0w
# ggMJAgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAABW3yw
# ujRnN8GnAAAAAAFbMA0GCWCGSAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYL
# KoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEIO/gWzkJ4ZNi7oBJb+xvvz4moBMz
# DgTjeMo30TnM9ZbmMIH6BgsqhkiG9w0BCRACLzGB6jCB5zCB5DCBvQQgySLgqShj
# EYeJQhrnBjxwjSe46vTE23t5kNhbUmSwhRkwgZgwgYCkfjB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMAITMwAAAVt8sLo0ZzfBpwAAAAABWzAiBCBqusDlFAEH
# H3NjsfGhEczV9ATG5H700s+YIPVOVGeHhTANBgkqhkiG9w0BAQsFAASCAQCAfisA
# QXbPBEAVOGAGEG2Gdj6UJQ4EZ4jx4OVhlBAfcfg+0YwHxoWYf2wacyGYF2n10OUS
# fJoqL9enc4oFfKpiMiDDZEPKrdU9uv/Vb9ju/sXp8L4csH9/dIPe2N/UX+i7li1S
# pAXV8mQoxWuDbIiULVMqsG4VJ7yV1tOtSZGSyTpmlD4uHbTvlyMIEiXaOtdFXaUI
# FdK1F7RikDbGOROuN3JpEtn3hTaitV/tjOIw69Ijg1x7ZYmF2VJy3L6IdqErK/0Q
# KJLaIUq/0KfB4NiI7XIXODMlRqdl3tDM/Xr/TosEKhofBbO7MBr5LEwjLLic+IOu
# j4hk1Qg4gvxa6JZt
# SIG # End signature block

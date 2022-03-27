<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

#Function to check if MS.Graph module is installed and is current version
function invoke-graphmodule {
    $graphavailable = (find-module -name microsoft.graph)
    $vertemp = $graphavailable.version.ToString()
    Write-Output "Latest version of Microsoft.Graph module is $vertemp" | out-host
    $graphcurrent = (get-installedmodule -name Microsoft.Graph -ErrorAction SilentlyContinue) 

    if ($graphcurrent -eq $null) {
        write-output "Microsoft.Graph module is not installed. Installing..." | out-host
        try {
            Install-Module Microsoft.Graph -Force -ErrorAction Stop
        }
        catch {
            write-output "Failed to install Microsoft.Graph Module" | out-host
            write-output $_.Exception.Message | out-host
            Return 1
        }
    }
    $graphcurrent = (get-installedmodule -name Microsoft.Graph)
    $vertemp = $graphcurrent.Version.ToString() 
    write-output "Current installed version of Microsoft.Graph module is $vertemp" | out-host

    if ($graphavailable.Version -gt $graphcurrent.Version) { write-host "There is an update to this module available." }
    else
    { write-output "The installed Microsoft.Graph module is up to date." | out-host }
}

#Function to connect to the MS.Graph PowerShell Enterprise App
function connect-msgraph {

    $tenant = get-mgcontext
    if ($tenant.TenantId -eq $null) {
        write-output "Not connected to MS Graph. Connecting..." | out-host
        try {
            Connect-MgGraph -Scopes "CloudPC.Read.All" -ErrorAction Stop | Out-Null
        }
        catch {
            write-output "Failed to connect to MS Graph" | out-host
            write-output $_.Exception.Message | out-host
            Return 1
        }   
    }
    $tenant = get-mgcontext
    $text = "Tenant ID is " + $tenant.TenantId
    Write-Output "Connected to Microsoft Graph" | out-host
    Write-Output $text | out-host
}
#Function to set the profile to beta
function set-profile {
    Write-Output "Setting profile as beta..." | Out-Host
    Select-MgProfile -Name beta
}

#Commands to load MS.Graph modules
if (invoke-graphmodule -eq 1) {
    write-output "Invoking Graph failed. Exiting..." | out-host
    Return 1
}

#Command to connect to MS.Graph PowerShell app
if (connect-msgraph -eq 1) {
    write-output "Connecting to Graph failed. Exiting..." | out-host
    Return 1
}

set-profile

$Galimages = Get-MgDeviceManagementVirtualEndpointGalleryImage
$Customimages = Get-MgDeviceManagementVirtualEndpointDeviceImage
$CloudPCs = Get-MgDeviceManagementVirtualEndpointCloudPC

write-host ""
write-host "Gallery Images"
foreach ($Galimage in $Galimages) {
    write-host ""
    Write-Host $Galimage.displayname

    foreach ($CloudPC in $CloudPCs) {
        if ($CloudPC.ImageDisplayName -eq $Galimage.displayname) {
            Write-Host $CloudPC.ManagedDeviceName
        }
    }
}
write-host ""
write-host "Custom Images"
foreach ($Customimage in $Customimages) {
    write-host ""
    Write-Host $Customimage.displayname

    foreach ($CloudPC in $CloudPCs) {
        if ($CloudPC.ImageDisplayName -eq $Customimage.displayname) {
            Write-Host $CloudPC.ManagedDeviceName
        }
    }
}

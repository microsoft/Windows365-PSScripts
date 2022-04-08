<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

#This script requires the AzureADPreview module be installed. During testing, I found that if the
#AzureAD module is installed, it will conflict with the Preview module and fail to install. The AzureAD
#module may have to be uninstalled before isntalling the Preview module.

Param(
    [parameter(mandatory = $false, HelpMessage = "over how many days")] 
    [int]$offset = 30,

    [parameter(mandatory = $false, HelpMessage = "logpath")] 
    [string]$logpath = "C:\CPC_Logon_Count.csv"

)

#Function to check if MS.Graph module is installed and up-to-date
function invoke-graphmodule {
    $graphavailable = (find-module -name microsoft.graph)
    $vertemp = $graphavailable.version.ToString()
    Write-Output "Latest version of Microsoft.Graph module is $vertemp" | out-host

    foreach ($module in $modules){
        write-host "Checking module - " $module
        $graphcurrent = (get-installedmodule -name $module -ErrorAction SilentlyContinue)

        if ($graphcurrent -eq $null) {
            write-output "Module is not installed. Installing..." | out-host
            try {
                Install-Module -name $module -Force -ErrorAction Stop 
                Import-Module -name $module -force -ErrorAction Stop 

                }
            catch {
                write-output "Failed to install " $module | out-host
                write-output $_.Exception.Message | out-host
                Return 1
                }
        }
    }


    $graphcurrent = (get-installedmodule -name Microsoft.Graph.DeviceManagement.Functions)
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

#Function to connect to the MS.Graph PowerShell Enterprise App
function connect-aad {
    
    try{
        $AADtenant = Get-AzureADTenantDetail -ErrorAction Stop | Out-Null
    }
    catch{
        write-output "Not connected to Azure AD. Connecting..." | out-host
        try {
            Connect-AzureAD -ErrorAction Stop | Out-Null
        }
        catch {
            write-output "Failed to connect to Azure AD" | out-host
            write-output $_.Exception.Message | out-host
            Return 1
        }
    }
   
    $AADtenant = Get-AzureADTenantDetail
    $text = "Tenant ID is " + $AADtenant.ObjectId
    Write-Output "Connected to Azure AD" | out-host
    Write-Output $text | out-host

    }
  
#Function to check if AzureADPreview module is installed and up-to-date
function invoke-AzureADPreview {
    $AADPavailable = (find-module -name AzureADPreview)
    $vertemp = $AADPavailable.version.ToString()
    Write-Output "Latest version of AzureADPreview module is $vertemp" | out-host
    $AADPcurrent = (get-installedmodule -name AzureADPreview -ErrorAction SilentlyContinue) 

    if ($AADPcurrent -eq $null) {
        write-output "AzureADPreview module is not installed. Installing..." | out-host
        try {
            Install-Module AzureADPreview -Force -ErrorAction Stop
        }
        catch {
            write-output "Failed to install AzureADPreview Module" | out-host
            write-output $_.Exception.Message | out-host
            Return 1
        }
    }
    $AADPcurrent = (get-installedmodule -name AzureADPreview)
    $vertemp = $AADPcurrent.Version.ToString() 
    write-output "Current installed version of AzureADPreview module is $vertemp" | out-host


    if ($AADPavailable.Version -gt $AADPcurrent.Version) { write-host "There is an update to this module available." }
    else
    { write-output "The installed AzureADPreview module is up to date." | out-host }
}

#Function to set the profile to beta
function set-profile {
    Write-Output "Setting profile as beta..." | Out-Host
    Select-MgProfile -Name beta
}

$modules = @("Microsoft.Graph.DeviceManagement.Functions",
                "Microsoft.Graph.DeviceManagement.Administration",
                "Microsoft.Graph.DeviceManagement.Enrolment",
                "Microsoft.Graph.Users.Functions",
                "Microsoft.Graph.DeviceManagement.Actions",
                "Microsoft.Graph.Users.Actions"
            )

$WarningPreference = 'SilentlyContinue'

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

#Commands to load AzureADPreview modules
if (invoke-AzureADPreview -eq 1) {
    write-output "Invoking AzureADPreview failed. Exiting..." | out-host
    Return 1
}

#Command to connect to AzureAD PowerShell app
if (connect-aad -eq 1) {
    write-output "Connecting to AzureAD failed. Exiting..." | out-host
    Return 1
}

#gets date, applies offset, and formats date so query can use it
$adjdate = (get-date).AddDays( - $($offset)) 
$string = "$($adjdate.Year)" + "-" + "$($adjdate.Month)" + "-" + "$($adjdate.Day)"

#gets all cloudpcs
$cloudPCs = Get-MgDeviceManagementVirtualEndpointCloudPC

#gets all AAD Windows logons over time period 
$String = "appdisplayname eq 'Windows Sign In' and createdDateTime gt $string"
$Logons = get-AzureADAuditSignInLogs -Filter $String

write-host ""
write-host "Count of user logons to Cloud PCs over last $offset days"
write-host ""

#gets all users assigned to a cloud pc
$users = @()
foreach ($CloudPC in $CloudPCs) {
    $users += $CloudPC.UserPrincipalName
}

#output user name, their assigned cloud PC name, and usage data
foreach ($user in $users) {

    #declare array for CSV output
    $output = [PSCustomObject]@{
        "CPCUserPrincipalName" = ""
        "CPCManagedDeviceName" = ""
        "LastLogon"            = ""
        "Logons"               = ""
        "TotalDays"            = "$offset"
    }
    
    #sets count variables to null so each user logon count is accurate
    $count = $null
    $LastLogon = $null

    #outputs user UPN
    Write-Host $user
    $output.CPCUserPrincipalName = $user
    
    #Finds the name of the cloudPC the user has
    foreach ($CloudPC in $cloudPCs) {
        if ($CloudPC.UserPrincipalName -eq $user) {
            write-host $CloudPC.ManagedDeviceName
            $output.CPCManagedDeviceName = $CloudPC.ManagedDeviceName
        }
    }
    

    #Counts each web logon
    foreach ($Logon in $Logons) {

        if (($Logon.UserPrincipalName -eq $user) -and ($Logon.DeviceDetail.Displayname -like "CPC-*")) {
            $count = $count + 1

            if ($logon.CreatedDateTime -gt $LastLogon) { $LastLogon = $Logon.CreatedDateTime }    
        }
    }
    if ($count -eq $null) { $count = 0 }
    
    #outputs local client logon count
    write-host "Logon count is $count"
    $output.Logons = $count

    #outputs the last logon time
    write-host "User's last logon time is"$LastLogon
    $output.LastLogon = $LastLogon
    
    #outputs notification if no logon activity has been recorded
    if ($total -eq 0) { write-host "User has not logged in." -ForegroundColor Red }

    write-host ""

    #sends data to CSV file
    $output | export-csv -Path $logpath -NoTypeInformation -append
}


<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

#WARNING - This script has not fully been tested, use at your own risk

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

#Function to check if AzureADPreview module is installed and up-to-date
function invoke-AzureADPreview {
    $AADPavailable = (find-module -name microsoft.graph)
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
    $AADPcurrent = (get-installedmodule -name Microsoft.Graph)
    $vertemp = $AADPcurrent.Version.ToString() 
    write-output "Current installed version of AzureADPreview module is $vertemp" | out-host

    if ($AADPavailable.Version -gt $gAADPcurrent.Version) { write-host "There is an update to this module available." }
    else
    { write-output "The installed AzureADPreview module is up to date." | out-host }
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

#Commands to load AzureADPreview modules
if (invoke-AzureADPreview -eq 1) {
    write-output "Invoking AzureADPreview failed. Exiting..." | out-host
    Return 1
}


set-profile

Connect-AzureAD

#gets date, applies offset, and formats date so query can use it
$adjdate = (get-date).AddDays(-$($offset)) 
$string = "$($adjdate.Year)" + "-" + "$($adjdate.Month)" + "-" + "$($adjdate.Day)"

#gets all cloudpcs
#Graph API equivalent is GET /deviceManagement/virtualEndpoint/cloudPCs
$cloudPCs = Get-MgDeviceManagementVirtualEndpointCloudPC

#gets all AAD logons over time period for Web Portal
#Graph API call equivalent should be GET https://graph.microsoft.com/v1.0/auditLogs/signIns?&$filter=startsWith(appDisplayName,'Graph')&top=1
#That example has not been formatted to get the correct data, but that should be the call to work with
$WebString = "appdisplayname eq 'Windows 365 Portal' and createdDateTime gt $string"
$WebLogons = Get-AzureADAuditSignInLogs -Filter $WebString

#gets all AAD logons over time period for Local Clients
#Graph API call equivalent should be GET https://graph.microsoft.com/v1.0/auditLogs/signIns?&$filter=startsWith(appDisplayName,'Graph')&top=1
#That example has not been formatted to get the correct data, but that should be the call to work with
$ClientString = "appdisplayname eq 'Azure Virtual Desktop Client' and createdDateTime gt $string"
$ClientLogons = get-AzureADAuditSignInLogs -Filter $ClientString

write-host ""
write-host "Count of user logons to Cloud PCs over last $offset days"
write-host ""

#gets all users assigned to a cloud pc
$users = @()
foreach ($CloudPC in $CloudPCs){

    $users += $CloudPC.UserPrincipalName
}

#output user name and their assigned cloud PC name
foreach ($user in $users){

        #declare array for CSV output
        $output = [PSCustomObject]@{
        "CPCUserPrincipalName" = ""
        "CPCManagedDeviceName" = ""
        "LastLogon" = ""
        "TotalLogons" = ""
        "WebLogons" = ""
        "ClientLogons" = ""
        "TotalDays" = "$offset"
        }
    
    #sets count variables to null so each user logon count is accurate
    $countweb = $null
    $countclient = $null

    #outputs user UPN
    Write-Host $user
    $output.CPCUserPrincipalName = $user
    
    #Finds the name of the cloudPC the user has
    foreach ($CloudPC in $cloudPCs){
        if ($CloudPC.UserPrincipalName -eq $user){
            write-host $CloudPC.ManagedDeviceName
            $output.CPCManagedDeviceName = $CloudPC.ManagedDeviceName
            }
    }

    #Resets LastLogon variable
    $LastLogon = $null
    
    #Counts each web logon
    foreach ($WebLogon in $WebLogons){
        if ($WebLogon.UserPrincipalName -eq $user){
            $countweb = $countweb +1
            if ($Weblogon.CreatedDateTime -gt $LastLogon){$LastLogon = $WebLogon.CreatedDateTime}    
            
        }

    }
    if ($countweb -eq $null){$countweb = 0}
    
    #Counts each local client logon
    foreach ($ClientLogon in $ClientLogons){
        if ($ClientLogon.UserPrincipalName -eq $user){
            $countclient = $countclient +1
            if ($Clientlogon.CreatedDateTime -gt $LastLogon){$LastLogon = $LastLogon.CreatedDateTime}
        }
    }
    if ($countclient -eq $null){$countclient = 0}
    
    #adds both logon counts for a total
    $total = $countweb + $countclient
    write-host "Total CloudPC logons is $total"
    $output.TotalLogons = $total

    #outputs web client logon count
    write-host "Web Client Logon count is $countweb"
    $output.WebLogons = $countweb
    
    #outputs local client logon count
    write-host "Local client count is $countclient"
    $output.ClientLogons = $countclient

    #outputs the last logon time
    write-host "User's last logon time is"$LastLogon
    $output.LastLogon = $LastLogon
    
    #outputs notification if no logon activity has been recorded
    if ($total -eq 0){write-host "User has not logged in." -ForegroundColor Red}

    write-host ""

    #sends data to CSV file
    $output | export-csv -Path $logpath -NoTypeInformation -append
}



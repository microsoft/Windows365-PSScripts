<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

Param(
    [parameter(mandatory = $true, HelpMessage = "Subscription ID")] 
    [string]$SubscriptionID,
    [parameter(mandatory = $true, HelpMessage = "The name of a resource group in the subscription you just entered")] 
    [string]$ResourceGroupName,
    [parameter(mandatory = $true, HelpMessage = "The id of a VNet in the subscription you just entered. e.g. /subscriptions/{SubscriptionID}/resourceGroups/{ResourceGroupName}/providers/Microsoft.Network/virtualNetworks/{VNetName}")] 
    [string]$VnetResourceID
)
$SubscriptionID = "/subscriptions/" + $SubscriptionID.Trim()
$ResourceGroupID = $SubscriptionID + "/resourceGroups/" + $ResourceGroupName.Trim()


#modules required for this script
$modules = @("az.accounts",
    "az.resources",
    "AzureAD"
)

#paths used for role creation
$paths = @("$env:windir\temp\Sub.json",
    "$env:windir\temp\RG.json",
    "$env:windir\temp\VNet.json"
)

$RoleNameForSubscription = "Windows365RequiredRoleForSubscription"
$RoleNameForResourceGroup = "Windows365RequiredRoleForResourceGroup"
$RoleNameForVNet = "Windows365RequiredRoleForVNet"

#Role names to be created
$Roles = @($Windows365RequiredRoleForSubscription,
    $RoleNameForResourceGroup,
    $RoleNameForVNet
)

#JSON formatted variables used to create role permissions
$CustomRoleSubJSON = @"
{
    "Name": "Windows365RequiredRoleForSubscription",
    "Id": null,
    "IsCustom": true,
    "Description": "Windows365RequiredRoleForSubscription",
    "Actions": [
        "Microsoft.Resources/subscriptions/read",
        "Microsoft.Resources/subscriptions/operationresults/read",
        "Microsoft.Compute/images/read"
    ],
    "NotActions": [],
    "AssignableScopes": [
        "$SubscriptionID"
    ]
}
"@
$CustomRoleRGJSON = @"
{
    "Name": "Windows365RequiredRoleForResourceGroup",
    "Id": null,
    "IsCustom": true,
    "Description": "Windows365RequiredRoleForResourceGroup",
    "Actions": [
        "Microsoft.Resources/subscriptions/resourcegroups/read",
        "Microsoft.Resources/deployments/read",
        "Microsoft.Resources/deployments/write",
        "Microsoft.Resources/deployments/delete",
        "Microsoft.Resources/deployments/operations/read",
        "Microsoft.Resources/deployments/operationstatuses/read",
        "Microsoft.Network/locations/operations/read",
        "Microsoft.Network/locations/operationResults/read",
        "Microsoft.Network/locations/usages/read",
        "Microsoft.Network/networkInterfaces/write",
        "Microsoft.Network/networkInterfaces/read",
        "Microsoft.Network/networkInterfaces/delete",
        "Microsoft.Network/networkInterfaces/join/action"
    ],
    "NotActions": [],
    "AssignableScopes": [
        "$SubscriptionID"
    ]
}
"@
$CustomRoleVNetJSON = @"
{
    "Name": "Windows365RequiredRoleForVNet",
    "Id": null,
    "IsCustom": true,
    "Description": "Windows365RequiredRoleForVNet",
    "Actions": [
        "Microsoft.Network/virtualNetworks/read",
        "Microsoft.Network/virtualNetworks/subnets/read",
        "Microsoft.Network/virtualNetworks/usages/read",
        "Microsoft.Network/virtualNetworks/subnets/join/action"
    ],
    "NotActions": [],
    "AssignableScopes": [
        "$SubscriptionID"
    ]
}
"@

#function to check if modules are installed and to import them
function invoke-modulecheck {
    foreach ($module in $modules) {
        write-output "Checking module - " $module | Out-Host
        $graphcurrent = (get-installedmodule -name $module -ErrorAction SilentlyContinue)
        if ($graphcurrent -eq $null) {
            write-output "This module is not installed. Please install it and try again" | out-host
            exit
        }
        else {
            write-output "Module is installed." | Out-Host
        }
    }
}

function invoke-assignRole {
    param (
        [string] $Scope,
        [string] $ApplicationId,
        [string] $RoleDefinitionName
    )
    try {
        Write-Output "Try to assign role $RoleDefinitionName on $Scope..." | out-host
        New-AzRoleAssignment -Scope $Scope -ApplicationId $ApplicationId -RoleDefinitionName $RoleDefinitionName -ErrorAction Stop | Out-Null
        Write-Output "Succeeded" | out-host
    }
    catch {
        if ($_.Exception.Message -eq "Operation returned an invalid status code 'Conflict'") {
            Write-Output "Skip assign role $RoleDefinitionName on $Scope because it already exists." | Out-Host -Verbose
            return
        }

        Write-Output "Failed to create role assignment for $RoleDefinitionName on $Scope" | out-host
        throw
    }
}


#Calls the function to see if required modules are installed
invoke-modulecheck

#Connect to Azure
Connect-AzAccount | Out-Null

#Connect to AzureAD
Connect-AzureAD | Out-Null

#Create the JSON files in windows\temp folder
Write-Output "Creating JSON templates..." | Out-Host
$CustomRoleSubJSON | Out-File -FilePath $env:windir\temp\Sub.json
$CustomRoleRGJSON | Out-File -FilePath $env:windir\temp\RG.json
$CustomRoleVNetJSON | Out-File -FilePath $env:windir\temp\VNet.json

#Create the role definitions in Azure
write-output "Creating the new role definitions in Azure..." | out-host
foreach ($path in $paths) {
    try {
        New-AzRoleDefinition -InputFile $path -ErrorAction Stop | Out-Null
    }
    catch {
        if ($_.Exception.Message -eq "Operation returned an invalid status code 'Conflict'") {
            Write-Output "Skip create role definition from $path because it already exists." | Out-Host -Verbose
            continue;
        }
        Write-Output "Failed to create role definition from $path" | Out-Host -Verbose
        write-output $_.Exception.Message | out-host
        exit
    }
}

#Retrieves the AppID for the Windows 365 App
Write-Output "Retriving the App ID of the W365 App..." | Out-Host
try{
    $AppID = (Get-AzureADServicePrincipal -SearchString "Windows 365" | Where-Object { $_.DisplayName -eq "Windows 365" } -ErrorAction Stop).appid
}
catch{
    write-output "Failed to retrive the App ID for W365" | Out-Host
    write-output $_.Exception.Message | out-host
    exit
}

#Assings the new roles to the Win365 APP
Write-Output "Assigning the new roles to the Windows 365 app..." | out-host
try {
    invoke-assignRole -Scope $SubscriptionID  -ApplicationId $AppID -RoleDefinitionName $RoleNameForSubscription -ErrorAction Stop | Out-Null
    invoke-assignRole -Scope $ResourceGroupID -ApplicationId $AppID -RoleDefinitionName $RoleNameForResourceGroup -ErrorAction Stop | Out-Null
    invoke-assignRole -Scope $VnetResourceID -ApplicationId $AppID -RoleDefinitionName $RoleNameForVnet -ErrorAction Stop | Out-Null
}
catch {
    write-output $_.Exception.Message | out-host
}

#Clean Up
Write-Output "Cleaning up..." | out-host
foreach ($path in $paths) {
    Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
}

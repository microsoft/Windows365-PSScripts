<#
    .COPYRIGHT
    Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
    See LICENSE in the project root for license information.
#>
using module ".\Model\CloudPcModel.psm1"
$Separator = "--------------------------------------------------------------------------------------------------------------------------------"

#####################################################################################################
# Reclaim-CloudPCs
#####################################################################################################

<#
    .SYNOPSIS
        Reclaim-CloudPCs
    .DESCRIPTION
        Reclaim CloudPCs, include direct assigned and group based license
    .PARAMETER CloudPCBasedUrl
        The CloudPC graph based url
    .PARAMETER TenantId
        The TenantId
    .PARAMETER CloudPCListPath
        The path of a csv file which contains a list of Cloud PCs to be reclaimed
#>
function Reclaim-CloudPCs {
    param (
        [string]$CloudPCBasedUrl = "https://graph.microsoft.com/beta",
        [string]$TenantId,
        [string]$CloudPCListPath
    )

    try {
        # Import Helper Module
        if (Test-Path "$PSScriptRoot\Helper.psm1")
        {
            Import-Module "$PSScriptRoot\Helper.psm1" -DisableNameChecking -Force
        } else {
            throw "Can not find module Helper.psm1 from $PSScriptRoot"
        } 

        # Setup Environment Config
        Setup-EnvironmentConfig -CloudPCBasedUrl $CloudPCBasedUrl -TenantId $TenantId

        # Setup Graph Config and Get Required Permission
        if ((Setup-GraphConfig -GraphScopes "Group.ReadWrite.All", "User.ReadWrite.All") -eq 1){
            throw $_
        }

        # Import source data
        Write-Host $Separator
        Write-Host "Import reclaimed Cloud PCs from $CloudPCListPath"
     
        if (-Not (Test-Path $CloudPCListPath)) {
            throw "File does not exist in: $CloudPCListPath"
        }

        $cloudPCInfoList = @()
        Import-Csv -Path $CloudPCListPath | ForEach-Object {
            $cloudPCModel = [CloudPcModel]::new(
            $_.ManagedDeviceName,
            $_.UserPrincipalName,
            $_.UserId,
            $_.ProvisioningPolicyId,
            $_.ProvisioningPolicyName,
            $_.CurrentSkuId,
            $_.RecommendedSize,
            $_.RecommendedSkuId,
            $_.LicenseAssignedGroupId,
            $_.LicenseAssignedGroupName)
            $cloudPCInfoList += $cloudPCModel
        }

        # Revoke the license from the user
        Write-Host $Separator        
        Summarize-ReclaimSteps -CloudPCList $cloudPCInfoList

        $IsUserConsent = Read-Host "`nAre you sure you want to continue? [Y] Yes [N] No (default is "N")"
        if ($IsUserConsent -ne "Y"){
            return
        }
    
        try {
            $cloudPCInfoList | ForEach-Object { Remove-CloudPCLicense -CloudPC $_ }
        } catch {
            if ($_.Exception.Response.StatusCode -eq 403) {
                throw "Access forbidden: You do not have permission to remove the license from the current user. It requires the admin with 'Group.ReadWrite.All' or 'User.ReadWrite.All' (like a Global Administrator or Tenant Administrator) permission to reclaim licenses."
            } else{
                throw $_
            }
        }

        Write-Host $Separator
        Write-Host "✅ Successfully reclaimed license for all the CloudPCs"
    } catch {
        Write-Host $_ -ForegroundColor Red
    } finally {
        Write-Host "Disconnecting from Microsoft Graph"
        $result = Disconnect-MgGraph
    }
}

#####################################################################################################
# Manage-EntraGroupForResize
#####################################################################################################

<#
    .SYNOPSIS
        Manage-EntraGroupForResize
    .DESCRIPTION
        Group membership changes and manage licenses for group based Cloud PCs
    .PARAMETER CloudPCBasedUrl
        The CloudPC graph based url
    .PARAMETER TenantId
        The TenantId
    .PARAMETER CloudPCListPath
        The path of a csv file which contains a list of Cloud PCs to be resized
#>
function Manage-EntraGroupForResize() {
    param (
        [string]$CloudPCBasedUrl = "https://graph.microsoft.com/beta",
        [string]$TenantId,
        [string]$CloudPCListPath
    )

    try {
        # Import Helper Module
        if (Test-Path "$PSScriptRoot\Helper.psm1")
        {
            Import-Module "$PSScriptRoot\Helper.psm1" -DisableNameChecking -Force
        } else {
            throw "Can not find module Helper.psm1 from $PSScriptRoot"
        }

        # Setup Environment Config
        Setup-EnvironmentConfig -CloudPCBasedUrl $CloudPCBasedUrl -TenantId $TenantId

        # Setup Graph Config and Get Required Permission
        if ((Setup-GraphConfig -GraphScopes "CloudPC.ReadWrite.All", "Group.ReadWrite.All") -eq 1){
            throw "Failed to setup Graph Config"
        }

        # Import source data
        if (-Not (Test-Path $CloudPCListPath)) {
            throw "CSV File does not exist in：$CloudPCListPath"
        }

        $cloudPCInfoList = @()
        Import-Csv -Path $CloudPCListPath | ForEach-Object {
            $cloudPCModel = [CloudPcModel]::new(
            $_.ManagedDeviceName,
            $_.UserPrincipalName,
            $_.UserId,
            $_.ProvisioningPolicyId,
            $_.ProvisioningPolicyName,
            $_.CurrentSkuId,
            $_.RecommendedSize,
            $_.RecommendedSkuId,
            $_.LicenseAssignedGroupId,
            $_.LicenseAssignedGroupName)
            $cloudPCInfoList += $cloudPCModel
        }

        $groupBasedLicenseDeivceList = $cloudPCInfoList | Where-Object { $_.LicenseAssignedGroupId }

        # Check the CloudPCs status
        foreach($device in $groupBasedLicenseDeivceList){
            $deviceName = $device.ManagedDeviceName
            $result = Check-CloudPCByStatus -DeviceName $deviceName -Status "resizePendingLicense"
            if ($result -eq 1) {
                throw "❌ Device $deviceName did not enter 'Resize pending license' status"
            }
        }

        Write-Host $Separator
        $UseDefaultName = Summarize-ResizeSteps -CloudPCList $cloudPCInfoList

        $IsUserConsent = Read-Host "`nAre you sure you want to continue? [Y] Yes [N] No (default is "N"): "
        if ($IsUserConsent -ne "Y"){
            return
        }


        try {
            # Remove user from the group
            $groupedDeviceList = $groupBasedLicenseDeivceList | Group-Object -Property UserId, LicenseAssignedGroupId
            foreach($groupedDevice in $groupedDeviceList){
                $useId = $groupedDevice.Name.Split(',')[0].Trim()
                $licenseAssignedGroupId = $groupedDevice.Name.Split(',')[1].Trim()
                Remove-MembersFromEntraGroup -GroupId $licenseAssignedGroupId -UserId $useId

                $deviceItem = $cloudPCInfoList | Where-Object { $_.UserId -eq $useId } | Select-Object -First 1
                $userName = $deviceItem.UserPrincipalName
                $deviceItem = $cloudPCInfoList | Where-Object { $_.LicenseAssignedGroupId -eq $licenseAssignedGroupId } | Select-Object -First 1
                $groupName = $deviceItem.LicenseAssignedGroupName

                Write-Host $Separator
                Write-Host "✅ Successfully remove the user: $userName from the group: $groupName ...."
            }

            $groupedDeviceList = $groupBasedLicenseDeivceList | Group-Object -Property RecommendedSize
            $groupToPolicyList = @()
            foreach ($group in $groupedDeviceList){
                $targetServicePlan = $group.Name.Split(',')[0].Trim()
                $userIds = $group.Group | Select-Object -ExpandProperty UserId
                $targetSkuId = $group.Group[0].RecommendedSkuId
                $deviceNames = $group.Group | Select-Object -ExpandProperty ManagedDeviceName
                $recommendedSize = $group.Group | Select-Object -ExpandProperty RecommendedSize | Select-Object -First 1

                Write-Host $Separator
                Write-Host "Start to move the following users to a new group ...."
                $cloudPCInfoList | Where-Object { $userIds -contains $_.UserId } | ForEach-Object { $_.UserPrincipalName }

                # Create new entra groups for group base license Cloud PCs
                $groupName = ""
                if ($UseDefaultName -eq "Y")
                {
                    $groupName = "Resize_" + $recommendedSize + "_"+ (Get-Date).ToString("yyyy-MM-ddTHH:mm")
                } else {
                    $groupName = Read-Host "Please input the new Group name: "
                }

                $createdGroupId = Create-EntraGroup -GroupName $groupName
                Write-Host $Separator
                Write-Host "✅ Successfully create a new group: $groupName ...."

                # Add user to the new group
                Add-MembersToEntraGroup -GroupId $createdGroupId -UserIds $userIds

                Write-Host $Separator
                Write-Host "✅ Successfully move the following users to the new group: $groupName ...."
                $cloudPCInfoList | Where-Object { $userIds -contains $_.UserId } | ForEach-Object { $_.UserPrincipalName }

                # Assign target license to the new group                
                Assign-LicenseToEntraGroup -GroupId $createdGroupId -SkuId $targetSkuId

                Write-Host $Separator
                Write-Host "✅ Successfully assign the $recommendedSize license to the new group: $groupName ...."

                foreach($name in $deviceNames) {
                    $deviceItem = $cloudPCInfoList | Where-Object { $_.ManagedDeviceName -eq $name } | Select-Object -First 1
                    $policyId = $deviceItem.ProvisioningPolicyId
                    $policyName = $deviceItem.ProvisioningPolicyName

                    $groupToPolicyList += [PSCustomObject]@{ 
                        GroupId = $createdGroupId
                        GroupName = $groupName
                        PolicyId = $policyId
                        PolicyName = $policyName
                    }
                } 
            }         
        } catch {
            if ($_.Exception.Response.StatusCode -eq 403) {
                throw "Access forbidden: You do not have permission to create an entra group. It requires the admin with 'Group.ReadWrite.All' permission."
            } else{
                throw $_
            }
        }

        Write-Host $Separator
        Write-Host "Wait for Group changes take effective"
        Show-SleepProgress -Duration 30

        # Bind the new group to the source provisioning policy
        try {
            foreach ($group in $groupToPolicyList) {
                $groupId = $group.GroupId
                $policyId = $group.PolicyId
                $groupName = $group.GroupName
                $policyName = $group.PolicyName

                Bind-EntraGroupToProvisioningPolicy -GroupId $groupId -PolicyId $policyId

                Write-Host "Successfully bind the group: $groupName to the provisioning policy: $policyName ...."
            }
        } catch {
            if ($_.Exception.Response.StatusCode -eq 403) {
                throw "Access forbidden: You do not have permission to assign provisioning policy to the entra group. It requires the admin with 'CloudPC.ReadWrite.All' permission."
            } else{
                throw $_
            }
        }       

        Write-Host $Separator
        Write-Host "✅ Successfully manage all the Entra Groups"
    }catch {
        Write-Host $_ -ForegroundColor Red
    } finally {
        $response = Disconnect-MgGraph
    }
}
# SIG # Begin signature block
# MIIr5wYJKoZIhvcNAQcCoIIr2DCCK9QCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCqytfPkDZwydkr
# DYwGLWCn4OcTW/+zDGJaB10g67GhTaCCEW4wggh+MIIHZqADAgECAhM2AAACAO38
# jbec3qFIAAIAAAIAMA0GCSqGSIb3DQEBCwUAMEExEzARBgoJkiaJk/IsZAEZFgNH
# QkwxEzARBgoJkiaJk/IsZAEZFgNBTUUxFTATBgNVBAMTDEFNRSBDUyBDQSAwMTAe
# Fw0yNDExMDgxMjQzMjhaFw0yNTExMDgxMjQzMjhaMCQxIjAgBgNVBAMTGU1pY3Jv
# c29mdCBBenVyZSBDb2RlIFNpZ24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
# AoIBAQC5L/UPrOpwYjxcoZC0TqqvMF1WUELvwXN+k27SrA5rohJknn7Cgbxg4hGT
# XKqpcdbtsVTN3ZY896SJ20uQ+INL5OVLzpW408nCNTPYg2LtGJbqHUjpNm0hLCJ+
# gO5Jn2T8DDzIJoUijGXj1m+hRLKb2nOIicCED2GuYBmuWXnaY7INmVEaU3peryty
# ZjDuxdyGDuiPURz8lW1SUiDzoszNp1oswVr+WjDvLDUx4HlxPsG8zUjIst0NnJ6o
# z4tNFKaUBDCetcMjQxpCETn29a1CuRddxZLjPHZHfcotr5sh1S6bNQdzVaMNsxV8
# L3wjHb7XJ6ZVm662mHEiPgpyNcLhAgMBAAGjggWKMIIFhjApBgkrBgEEAYI3FQoE
# HDAaMAwGCisGAQQBgjdbAQEwCgYIKwYBBQUHAwMwPQYJKwYBBAGCNxUHBDAwLgYm
# KwYBBAGCNxUIhpDjDYTVtHiE8Ys+hZvdFs6dEoFgg93NZoaUjDICAWQCAQ4wggJ2
# BggrBgEFBQcBAQSCAmgwggJkMGIGCCsGAQUFBzAChlZodHRwOi8vY3JsLm1pY3Jv
# c29mdC5jb20vcGtpaW5mcmEvQ2VydHMvQlkyUEtJQ1NDQTAxLkFNRS5HQkxfQU1F
# JTIwQ1MlMjBDQSUyMDAxKDIpLmNydDBSBggrBgEFBQcwAoZGaHR0cDovL2NybDEu
# YW1lLmdibC9haWEvQlkyUEtJQ1NDQTAxLkFNRS5HQkxfQU1FJTIwQ1MlMjBDQSUy
# MDAxKDIpLmNydDBSBggrBgEFBQcwAoZGaHR0cDovL2NybDIuYW1lLmdibC9haWEv
# QlkyUEtJQ1NDQTAxLkFNRS5HQkxfQU1FJTIwQ1MlMjBDQSUyMDAxKDIpLmNydDBS
# BggrBgEFBQcwAoZGaHR0cDovL2NybDMuYW1lLmdibC9haWEvQlkyUEtJQ1NDQTAx
# LkFNRS5HQkxfQU1FJTIwQ1MlMjBDQSUyMDAxKDIpLmNydDBSBggrBgEFBQcwAoZG
# aHR0cDovL2NybDQuYW1lLmdibC9haWEvQlkyUEtJQ1NDQTAxLkFNRS5HQkxfQU1F
# JTIwQ1MlMjBDQSUyMDAxKDIpLmNydDCBrQYIKwYBBQUHMAKGgaBsZGFwOi8vL0NO
# PUFNRSUyMENTJTIwQ0ElMjAwMSxDTj1BSUEsQ049UHVibGljJTIwS2V5JTIwU2Vy
# dmljZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlvbixEQz1BTUUsREM9R0JM
# P2NBQ2VydGlmaWNhdGU/YmFzZT9vYmplY3RDbGFzcz1jZXJ0aWZpY2F0aW9uQXV0
# aG9yaXR5MB0GA1UdDgQWBBST/HE52ZUlmsYqZcZBdrXZ5u4ZnzAOBgNVHQ8BAf8E
# BAMCB4AwRQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEWMBQGA1UEBRMNMjM2MTY3KzUwMzE1NTCCAeYGA1UdHwSCAd0wggHZMIIB
# 1aCCAdGgggHNhj9odHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpaW5mcmEvQ1JM
# L0FNRSUyMENTJTIwQ0ElMjAwMSgyKS5jcmyGMWh0dHA6Ly9jcmwxLmFtZS5nYmwv
# Y3JsL0FNRSUyMENTJTIwQ0ElMjAwMSgyKS5jcmyGMWh0dHA6Ly9jcmwyLmFtZS5n
# YmwvY3JsL0FNRSUyMENTJTIwQ0ElMjAwMSgyKS5jcmyGMWh0dHA6Ly9jcmwzLmFt
# ZS5nYmwvY3JsL0FNRSUyMENTJTIwQ0ElMjAwMSgyKS5jcmyGMWh0dHA6Ly9jcmw0
# LmFtZS5nYmwvY3JsL0FNRSUyMENTJTIwQ0ElMjAwMSgyKS5jcmyGgb1sZGFwOi8v
# L0NOPUFNRSUyMENTJTIwQ0ElMjAwMSgyKSxDTj1CWTJQS0lDU0NBMDEsQ049Q0RQ
# LENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNvbmZp
# Z3VyYXRpb24sREM9QU1FLERDPUdCTD9jZXJ0aWZpY2F0ZVJldm9jYXRpb25MaXN0
# P2Jhc2U/b2JqZWN0Q2xhc3M9Y1JMRGlzdHJpYnV0aW9uUG9pbnQwHwYDVR0jBBgw
# FoAUllGE4Gtve/7YBqvD8oXmKa5q+dQwHwYDVR0lBBgwFgYKKwYBBAGCN1sBAQYI
# KwYBBQUHAwMwDQYJKoZIhvcNAQELBQADggEBAEDd8Wf5RkHsB64vgn2slxDtHzSo
# It9xN/Dm3RdFjNZ0diTUPMgSPYQlSk8nIAfudnB9FLavGlvZLlyUpfrPSuikepj3
# i3pqNEFn6fNdNFv/wHMxv7hQTIDCmuoR1v1rX+w3oeleBPMnN3QmH4ff1NsynyV4
# dZdYgN9Cw9sC/S3pWZpJrbOs7YOM3vqyU6DciHhC4D9i2zByHCF2pu9nYfiQf5A2
# iUZenRvyo1E5rC+UP2VZXa4k7g66W20+zAajIKKIqEmRtWahekMkCcOIHFBY4RDA
# ybgPRSGur4VDAiZPjTXS90wQXrX9CwU20cfiCC6e76F4H95KtQjKYpzuNVAwggjo
# MIIG0KADAgECAhMfAAAAUeqP9pxzDKg7AAAAAABRMA0GCSqGSIb3DQEBCwUAMDwx
# EzARBgoJkiaJk/IsZAEZFgNHQkwxEzARBgoJkiaJk/IsZAEZFgNBTUUxEDAOBgNV
# BAMTB2FtZXJvb3QwHhcNMjEwNTIxMTg0NDE0WhcNMjYwNTIxMTg1NDE0WjBBMRMw
# EQYKCZImiZPyLGQBGRYDR0JMMRMwEQYKCZImiZPyLGQBGRYDQU1FMRUwEwYDVQQD
# EwxBTUUgQ1MgQ0EgMDEwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDJ
# mlIJfQGejVbXKpcyFPoFSUllalrinfEV6JMc7i+bZDoL9rNHnHDGfJgeuRIYO1LY
# /1f4oMTrhXbSaYRCS5vGc8145WcTZG908bGDCWr4GFLc411WxA+Pv2rteAcz0eHM
# H36qTQ8L0o3XOb2n+x7KJFLokXV1s6pF/WlSXsUBXGaCIIWBXyEchv+sM9eKDsUO
# LdLTITHYJQNWkiryMSEbxqdQUTVZjEz6eLRLkofDAo8pXirIYOgM770CYOiZrcKH
# K7lYOVblx22pdNawY8Te6a2dfoCaWV1QUuazg5VHiC4p/6fksgEILptOKhx9c+ia
# piNhMrHsAYx9pUtppeaFAgMBAAGjggTcMIIE2DASBgkrBgEEAYI3FQEEBQIDAgAC
# MCMGCSsGAQQBgjcVAgQWBBQSaCRCIUfL1Gu+Mc8gpMALI38/RzAdBgNVHQ4EFgQU
# llGE4Gtve/7YBqvD8oXmKa5q+dQwggEEBgNVHSUEgfwwgfkGBysGAQUCAwUGCCsG
# AQUFBwMBBggrBgEFBQcDAgYKKwYBBAGCNxQCAQYJKwYBBAGCNxUGBgorBgEEAYI3
# CgMMBgkrBgEEAYI3FQYGCCsGAQUFBwMJBggrBgEFBQgCAgYKKwYBBAGCN0ABAQYL
# KwYBBAGCNwoDBAEGCisGAQQBgjcKAwQGCSsGAQQBgjcVBQYKKwYBBAGCNxQCAgYK
# KwYBBAGCNxQCAwYIKwYBBQUHAwMGCisGAQQBgjdbAQEGCisGAQQBgjdbAgEGCisG
# AQQBgjdbAwEGCisGAQQBgjdbBQEGCisGAQQBgjdbBAEGCisGAQQBgjdbBAIwGQYJ
# KwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMBIGA1UdEwEB/wQI
# MAYBAf8CAQAwHwYDVR0jBBgwFoAUKV5RXmSuNLnrrJwNp4x1AdEJCygwggFoBgNV
# HR8EggFfMIIBWzCCAVegggFToIIBT4YxaHR0cDovL2NybC5taWNyb3NvZnQuY29t
# L3BraWluZnJhL2NybC9hbWVyb290LmNybIYjaHR0cDovL2NybDIuYW1lLmdibC9j
# cmwvYW1lcm9vdC5jcmyGI2h0dHA6Ly9jcmwzLmFtZS5nYmwvY3JsL2FtZXJvb3Qu
# Y3JshiNodHRwOi8vY3JsMS5hbWUuZ2JsL2NybC9hbWVyb290LmNybIaBqmxkYXA6
# Ly8vQ049YW1lcm9vdCxDTj1BTUVSb290LENOPUNEUCxDTj1QdWJsaWMlMjBLZXkl
# MjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9uLERDPUFNRSxE
# Qz1HQkw/Y2VydGlmaWNhdGVSZXZvY2F0aW9uTGlzdD9iYXNlP29iamVjdENsYXNz
# PWNSTERpc3RyaWJ1dGlvblBvaW50MIIBqwYIKwYBBQUHAQEEggGdMIIBmTBHBggr
# BgEFBQcwAoY7aHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraWluZnJhL2NlcnRz
# L0FNRVJvb3RfYW1lcm9vdC5jcnQwNwYIKwYBBQUHMAKGK2h0dHA6Ly9jcmwyLmFt
# ZS5nYmwvYWlhL0FNRVJvb3RfYW1lcm9vdC5jcnQwNwYIKwYBBQUHMAKGK2h0dHA6
# Ly9jcmwzLmFtZS5nYmwvYWlhL0FNRVJvb3RfYW1lcm9vdC5jcnQwNwYIKwYBBQUH
# MAKGK2h0dHA6Ly9jcmwxLmFtZS5nYmwvYWlhL0FNRVJvb3RfYW1lcm9vdC5jcnQw
# gaIGCCsGAQUFBzAChoGVbGRhcDovLy9DTj1hbWVyb290LENOPUFJQSxDTj1QdWJs
# aWMlMjBLZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9u
# LERDPUFNRSxEQz1HQkw/Y0FDZXJ0aWZpY2F0ZT9iYXNlP29iamVjdENsYXNzPWNl
# cnRpZmljYXRpb25BdXRob3JpdHkwDQYJKoZIhvcNAQELBQADggIBAFAQI7dPD+jf
# XtGt3vJp2pyzA/HUu8hjKaRpM3opya5G3ocprRd7vdTHb8BDfRN+AD0YEmeDB5HK
# QoG6xHPI5TXuIi5sm/LeADbV3C2q0HQOygS/VT+m1W7a/752hMIn+L4ZuyxVeSBp
# fwf7oQ4YSZPh6+ngZvBHgfBaVz4O9/wcfw91QDZnTgK9zAh9yRKKls2bziPEnxeO
# ZMVNaxyV0v152PY2xjqIafIkUjK6vY9LtVFjJXenVUAmn3WCPWNFC1YTIIHw/mD2
# cTfPy7QA1pT+GPARAKt0bKtq9aCd/Ym0b5tPbpgCiRtzyb7fbNS1dE740re0COE6
# 7YV2wbeo2sXixzvLftH8L7s9xv9wV+G22qyKt6lmKLjFK1yMw4Ni5fMabcgmzRvS
# jAcbqgp3tk4a8emaaH0rz8MuuIP+yrxtREPXSqL/C5bzMzsikuDW9xH10graZzSm
# PjilzpRfRdu20/9UQmC7eVPZ4j1WNa1oqPHfzET3ChIzJ6Q9G3NPCB+7KwX0OQmK
# yv7IDimj8U/GlsHD1z+EF/fYMf8YXG15LamaOAohsw/ywO6SYSreVW+5Y0mzJutn
# BC9Cm9ozj1+/4kqksrlhZgR/CSxhFH3BTweH8gP2FEISRtShDZbuYymynY1un+Ry
# fiK9+iVTLdD1h/SxyxDpZMtimb4CgJQlMYIZzzCCGcsCAQEwWDBBMRMwEQYKCZIm
# iZPyLGQBGRYDR0JMMRMwEQYKCZImiZPyLGQBGRYDQU1FMRUwEwYDVQQDEwxBTUUg
# Q1MgQ0EgMDECEzYAAAIA7fyNt5zeoUgAAgAAAgAwDQYJYIZIAWUDBAIBBQCgga4w
# GQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisG
# AQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIC4AkCux3y3oeYTNKYE1TaYt1nZUwcj5
# brm5x0im8lWTMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBvAGYA
# dKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEA
# Gzo9GogPlb0O9y2BZIYN6rERaypcoH9TPWfPme21W5RQskzRtGL/6Tikjp5IAZZA
# OF/0Fh52ifVDjuRlgQqJ+pp9j1tN5u4m/ElNIKP7FMsyV0zOrj3eGq5fLopTmN+x
# G12Q1BPBrtku5mQd5P1R/ScgTe/vy9pHD1Cd6w53lOt8XQzEvvLFA5Wl0or2xfw0
# kRPBp8P5Y50NgLMNcgVJnS3ns+cA5Nfk4lkPgiUjGPjvCCE8G6RWrFhhifM8rneO
# NBLD4A1fvq+QqP7TrW67FgASa6x9Tgl20CjExEkZr2qkVNOcGuuoKlJSf1ftMZQA
# RkC4o/NUK2EiypwZ4U0m1qGCF5cwgheTBgorBgEEAYI3AwMBMYIXgzCCF38GCSqG
# SIb3DQEHAqCCF3AwghdsAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsqhkiG9w0B
# CRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUA
# BCA1Uxx4jSAL170Bg5gwqE4GnQayIFxfCPYy5ryLjUQn2gIGaEsdgnaJGBMyMDI1
# MDcwMjA3MDgzNC40MjRaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBP
# cGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046ODkwMC0wNUUwLUQ5
# NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WgghHtMIIH
# IDCCBQigAwIBAgITMwAAAg4syyh9lSB1YwABAAACDjANBgkqhkiG9w0BAQsFADB8
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1N
# aWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yNTAxMzAxOTQzMDNaFw0y
# NjA0MjIxOTQzMDNaMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYD
# VQQLEx5uU2hpZWxkIFRTUyBFU046ODkwMC0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1p
# Y3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUAA4IC
# DwAwggIKAoICAQCs5t7iRtXt0hbeo9ME78ZYjIo3saQuWMBFQ7X4s9vooYRABTOf
# 2poTHatx+EwnBUGB1V2t/E6MwsQNmY5XpM/75aCrZdxAnrV9o4Tu5sBepbbfehsr
# OWRBIGoJE6PtWod1CrFehm1diz3jY3H8iFrh7nqefniZ1SnbcWPMyNIxuGFzpQiD
# A+E5YS33meMqaXwhdb01Cluymh/3EKvknj4dIpQZEWOPM3jxbRVAYN5J2tOrYkJc
# dDx0l02V/NYd1qkvUBgPxrKviq5kz7E6AbOifCDSMBgcn/X7RQw630Qkzqhp0kDU
# 2qei/ao9IHmuuReXEjnjpgTsr4Ab33ICAKMYxOQe+n5wqEVcE9OTyhmWZJS5AnWU
# Tniok4mgwONBWQ1DLOGFkZwXT334IPCqd4/3/Ld/ItizistyUZYsml/C4ZhdALbv
# fYwzv31Oxf8NTmV5IGxWdHnk2Hhh4bnzTKosEaDrJvQMiQ+loojM7f5bgdyBBnYQ
# Bm5+/iJsxw8k227zF2jbNI+Ows8HLeZGt8t6uJ2eVjND1B0YtgsBP0csBlnnI+4+
# dvLYRt0cAqw6PiYSz5FSZcbpi0xdAH/jd3dzyGArbyLuo69HugfGEEb/sM07rcoP
# 1o3cZ8eWMb4+MIB8euOb5DVPDnEcFi4NDukYM91g1Dt/qIek+rtE88VS8QIDAQAB
# o4IBSTCCAUUwHQYDVR0OBBYEFIVxRGlSEZE+1ESK6UGI7YNcEIjbMB8GA1UdIwQY
# MBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRpbWUt
# U3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYIKwYB
# BQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWlj
# cm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1UdEwEB
# /wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMA0G
# CSqGSIb3DQEBCwUAA4ICAQB14L2TL+L8OXLxnGSal2h30mZ7FsBFooiYkUVOY05F
# 9pnwPTVufEDGWEpNNy2OfaUHWIOoQ/9/rjwO0hS2SpB0BzMAk2gyz92NGWOpWbpB
# dMvrrRDpiWZi/uLS4ZGdRn3P2DccYmlkNP+vaRAXvnv+mp27KgI79mJ9hGyCQbvt
# MIjkbYoLqK7sF7Wahn9rLjX1y5QJL4lvEy3QmA9KRBj56cEv/lAvzDq7eSiqRq/p
# Cyqyc8uzmQ8SeKWyWu6DjUA9vi84QsmLjqPGCnH4cPyg+t95RpW+73snhew1iCV+
# wXu2RxMnWg7EsD5eLkJHLszUIPd+XClD+FTvV03GfrDDfk+45flH/eKRZc3MUZtn
# hLJjPwv3KoKDScW4iV6SbCRycYPkqoWBrHf7SvDA7GrH2UOtz1Wa1k27sdZgpG6/
# c9CqKI8CX5vgaa+A7oYHb4ZBj7S8u8sgxwWK7HgWDRByOH3CiJu4LJ8h3TiRkRAr
# mHRp0lbNf1iAKuL886IKE912v0yq55t8jMxjBU7uoLsrYVIoKkzh+sAkgkpGOoZL
# 14+dlxVM91Bavza4kODTUlwzb+SpXsSqVx8nuB6qhUy7pqpgww1q4SNhAxFnFxsx
# iTlaoL75GNxPR605lJ2WXehtEi7/+YfJqvH+vnqcpqCjyQ9hNaVzuOEHX4Myuqcj
# wjCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZIhvcNAQEL
# BQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNV
# BAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEwMB4X
# DTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4MzIyNVowfDELMAkGA1UEBhMCVVMxEzAR
# BgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3Rh
# bXAgUENBIDIwMTAwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDk4aZM
# 57RyIQt5osvXJHm9DtWC0/3unAcH0qlsTnXIyjVX9gF/bErg4r25PhdgM/9cT8dm
# 95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLAEBjoYH1qUoNEt6aORmsHFPPFdvWGUNzB
# RMhxXFExN6AKOG6N7dcP2CZTfDlhAnrEqv1yaa8dq6z2Nr41JmTamDu6GnszrYBb
# fowQHJ1S/rboYiXcag/PXfT+jlPP1uyFVk3v3byNpOORj7I5LFGc6XBpDco2LXCO
# Mcg1KL3jtIckw+DJj361VI/c+gVVmG1oO5pGve2krnopN6zL64NF50ZuyjLVwIYw
# XE8s4mKyzbnijYjklqwBSru+cakXW2dg3viSkR4dPf0gz3N9QZpGdc3EXzTdEonW
# /aUgfX782Z5F37ZyL9t9X4C626p+Nuw2TPYrbqgSUei/BQOj0XOmTTd0lBw0gg/w
# EPK3Rxjtp+iZfD9M269ewvPV2HM9Q07BMzlMjgK8QmguEOqEUUbi0b1qGFphAXPK
# Z6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJNmSLW6CmgyFdXzB0kZSU2LlQ+QuJYfM2
# BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6r1AFemzFER1y7435UsSFF5PAPBXbGjfH
# CBUYP3irRbb1Hode2o+eFnJpxq57t7c+auIurQIDAQABo4IB3TCCAdkwEgYJKwYB
# BAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIEFgQUKqdS/mTEmr6CkTxGNSnPEP8v
# BO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMFwGA1UdIARVMFMwUQYM
# KwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAKBggrBgEF
# BQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYD
# VR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvXzpoYxDBW
# BgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2Ny
# bC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYIKwYBBQUH
# AQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtp
# L2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDANBgkqhkiG9w0BAQsF
# AAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL/Klv6lwUtj5OR2R4sQaTlz0xM7U518Jx
# Nj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu6WZnOlNN3Zi6th542DYunKmCVgADsAW+
# iehp4LoJ7nvfam++Kctu2D9IdQHZGN5tggz1bSNU5HhTdSRXud2f8449xvNo32X2
# pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfgQJY4rPf5KYnDvBewVIVCs/wMnosZiefw
# C2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8sCXgU6ZGyqVvfSaN0DLzskYDSPeZKPmY7
# T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCrdTDFNLB62FD+CljdQDzHVG2dY3RILLFO
# Ry3BFARxv2T5JL5zbcqOCb2zAVdJVGTZc9d/HltEAY5aGZFrDZ+kKNxnGSgkujhL
# mm77IVRrakURR6nxt67I6IleT53S0Ex2tVdUCbFpAUR+fKFhbHP+CrvsQWY9af3L
# wUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8CwYKiexcdFYmNcP7ntdAoGokLjzbaukz5
# m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9JZTmdHRbatGePu1+oDEzfbzL6Xu/OHBE
# 0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNQMIICOAIB
# ATCB+aGB0aSBzjCByzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UE
# CxMeblNoaWVsZCBUU1MgRVNOOjg5MDAtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNy
# b3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQBK6HY/ZWLn
# OcMEQsjkDAoB/JZWCKCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpX
# YXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQg
# Q29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAy
# MDEwMA0GCSqGSIb3DQEBCwUAAgUA7A9PkDAiGA8yMDI1MDcwMjA2MjYyNFoYDzIw
# MjUwNzAzMDYyNjI0WjB3MD0GCisGAQQBhFkKBAExLzAtMAoCBQDsD0+QAgEAMAoC
# AQACAhKLAgH/MAcCAQACAhI5MAoCBQDsEKEQAgEAMDYGCisGAQQBhFkKBAIxKDAm
# MAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcN
# AQELBQADggEBAE4BBsPhT23Qodcag4dmclHhWX9NF+YFju1pXO290AEm5Sqx3AR+
# +wh/2PQJ/yDngzp/6ukx5xQZzxL8NgMNuH1uSFUCQNiLYzX3PpHvvz/k0RXNBYCT
# rNoVrS5Gk43uy63MRxaK8fnKzUhqRxr7vLg9xQPCUlGjBTOM2TNxI6sqcz9uzdCW
# 43F+x/VgNLRWoTTDgaInQf882V7xHGCLoRw5K8SF5pL5jKVDN7d7uI6PkGxkwARe
# aleeIgr3IbU/YvjGEmMtecLXo5TOuhrnA7r2bhV1kohZEdmSyxx9+p7rStvWO37x
# mI/9jT3T1PQHhDn9CWmUl6zattzgqz6vdZoxggQNMIIECQIBATCBkzB8MQswCQYD
# VQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3Nv
# ZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAg4syyh9lSB1YwABAAACDjANBglg
# hkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqG
# SIb3DQEJBDEiBCDxrt9I09xQ2eu3tvuIwiAlQkAlGpRGSVtrSxkX2aG5IzCB+gYL
# KoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIAF0HXMl8OmBkK267mxobKSihwOdP0eU
# NXQMypPzTxKGMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAC
# EzMAAAIOLMsofZUgdWMAAQAAAg4wIgQgioinHxwTqR6XrI8NMXYArCycLcMfRDJ6
# 5i2wHug0wQgwDQYJKoZIhvcNAQELBQAEggIAXqvvs0aHWNiceDO1SXhfC0TAS/X8
# ZFgA/cMWt22Pvguoi/5pPEfViQLVwEtUFf1edVTJ7IZZ7wXPsYRaOeOSq8P8SH4F
# e7NgaUO20dUjvt87rkl0ItrqMtsC0vZPxRqf1Shs5G/Yk0K0LZYIHDyle7LvowtK
# pg3kNlk7pyPvRroGeMYCwJUlSyoTkLWWBQnA8eaz1+rIjGf3puj3f8e75jFhgYO8
# nbtrzs1ZPPw8LNvZdaUUv/Rt/pGO8i784jf8nIuv3PCxGrV4oPnqy17JpqGj2Wu0
# ZySt2wmnli3/Q/LWx2mKwflxGqOq5ShEGKbTAfsKMvUCsiqeCOsLm+9n9fl31Q0b
# mhJGCQ5R5I87d4F6/i8iWjl4lmfKIe5vIQD7FPOKbznJSvHb37N8AYhZZLCq0zKF
# TCxC4GPFSEUYNBK7gPWoVIdO8ulZ7cSMnRNSej+aA5+gVJXllpb3/m9/W5l3itTR
# i0RQkIVlcJ2j9RoDkvzoNc/RcD3FWYQjoqP/2iF9g+TEYmCQ+OYKedRHAWmaz4n2
# 180ZoLN9dHtbR7xbJcT4ekUAjWFKaIlfk1u/Sftw40IyCZO/qi4aKyN3QY6l6tY7
# FWKcTN/QyQeXkLq0821jjhIL+jTDBjk/pXBLdEGADM7ZJ9Qn9PfVna9B5cAXWAO8
# nJTXbOLkZONngX4=
# SIG # End signature block

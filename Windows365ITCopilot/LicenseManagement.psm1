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
        Write-Host "Import the Cloud PCs list from $CloudPCListPath"
     
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

                # Create new Entra groups for group base license Cloud PCs
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
                throw "Access forbidden: You do not have permission to create an Entra group. It requires the admin with 'Group.ReadWrite.All' permission."
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
                throw "Access forbidden: You do not have permission to assign provisioning policy to the Entra group. It requires the admin with 'CloudPC.ReadWrite.All' permission."
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
# MIIsAAYJKoZIhvcNAQcCoIIr8TCCK+0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAGy2RU5AVpJYaN
# LqSrDV31LKxypXLAjuyxVrWlD/dTYKCCEW4wggh+MIIHZqADAgECAhM2AAACAO38
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
# fiK9+iVTLdD1h/SxyxDpZMtimb4CgJQlMYIZ6DCCGeQCAQEwWDBBMRMwEQYKCZIm
# iZPyLGQBGRYDR0JMMRMwEQYKCZImiZPyLGQBGRYDQU1FMRUwEwYDVQQDEwxBTUUg
# Q1MgQ0EgMDECEzYAAAIA7fyNt5zeoUgAAgAAAgAwDQYJYIZIAWUDBAIBBQCgga4w
# GQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisG
# AQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIKh4vkEutnaUKMy4XkY5L0OHgklGEFkH
# v+AjhYsFmG31MEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBvAGYA
# dKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEA
# Hsnk1SHBq9WBBBJdRehYkudX/9rriesln+jhThFtMHR0d9kdDgxFJxT+NeDOoXaF
# S4u6PEB27tHVInU2+IuZfV7WvxYt1FrlnziatpwJ+cUNwzUsjqVatn9A3HtWAkp4
# yeXjP3owHNwuKQT/y8madIOpRHmUCcV3IhQaZyCo81aE+l8Zj/jwk0tAoOt8BCdo
# i6IxuoJfmzLTIk4Uz4j73vF0J0cZ+3q2viGSnPNaN/UI9qyUv6hQiHYpfUKB25sv
# pN2/uTSKaRTcN0eYRKnzm1IKx646z8NOMn0FcjuK107lKAloMc+L2G5YDOq/SXQ2
# JXpckxSACteSj8hbOW3eXKGCF7AwghesBgorBgEEAYI3AwMBMYIXnDCCF5gGCSqG
# SIb3DQEHAqCCF4kwgheFAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFaBgsqhkiG9w0B
# CRABBKCCAUkEggFFMIIBQQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUA
# BCDlaNDv2K05pPqJ3eBkBCeuNRC+pltqpjcAxo5ODeZ23gIGaFMN+5HBGBMyMDI1
# MDcxMTA4MjY1Ni4yOTRaMASAAgH0oIHZpIHWMIHTMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFuZCBP
# cGVyYXRpb25zIExpbWl0ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo1NzFB
# LTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vydmlj
# ZaCCEf4wggcoMIIFEKADAgECAhMzAAAB+8vLbDdn5TCVAAEAAAH7MA0GCSqGSIb3
# DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAk
# BgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4XDTI0MDcyNTE4
# MzExM1oXDTI1MTAyMjE4MzExM1owgdMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpX
# YXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQg
# Q29ycG9yYXRpb24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlv
# bnMgTGltaXRlZDEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjU3MUEtMDVFMC1E
# OTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAqMJWQeWAq4LwvSjYsjP0Uvhvm0j0
# aAOJiMLg0sLfxKoTXAdKD6oMuq5rF5oEiOxV+9ox0H95Q8fhoZq3x9lxguZyTOK4
# l2xtcgtJCtjXRllM2bTpjOg35RUrBy0cAloBU9GJBs7LBNrcbH6rBiOvqDQNicPR
# Zwq16xyjMidU1J1AJuat9yLn7taifoD58blYEcBvkj5dH1la9zU846QDeOoRO6Nc
# qHLsDx8/zVKZxP30mW6Y7RMsqtB8cGCgGwVVurOnaNLXs31qTRTyVHX8ppOdoSih
# CXeqebgJCRzG8zG/e/k0oaBjFFGl+8uFELwCyh4wK9Z5+azTzfa2GD4p6ihtskXs
# 3lnW05UKfDJhAADt6viOc0Rk/c8zOiqzh0lKpf/eWUY2o/hvcDPZNgLaHvyfDqb8
# AWaKvO36iRZSXqhSw8SxJo0TCpsbCjmtx0LpHnqbb1UF7cq09kCcfWTDPcN12pbY
# Lqck0bIIfPKbc7HnrkNQks/mSbVZTnDyT3O8zF9q4DCfWesSr1akycDduGxCdKBv
# gtJh1YxDq1skTweYx5iAWXnB7KMyls3WQZbTubTCLLt8Xn8t+slcKm5DkvobubmH
# SriuTA3wTyIy4FxamTKm0VDu9mWds8MtjUSJVwNVVlBXaQ3ZMcVjijyVoUNVuBY9
# McwYcIQK62wQ20ECAwEAAaOCAUkwggFFMB0GA1UdDgQWBBRHVSGYUNQ3RwOl71zI
# AuUjIKg1KjAfBgNVHSMEGDAWgBSfpxVdAF5iXYP05dJlpxtTNRnpcjBfBgNVHR8E
# WDBWMFSgUqBQhk5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9N
# aWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcmwwbAYIKwYB
# BQUHAQEEYDBeMFwGCCsGAQUFBzAChlBodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20v
# cGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEw
# KDEpLmNydDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4G
# A1UdDwEB/wQEAwIHgDANBgkqhkiG9w0BAQsFAAOCAgEAwzoIKOY2dnUjfWuMiGoz
# /ovoc1e86VwWaZNFdgRmOoQuRe4nLdtZONtTHNk3Sj3nkyBszzxSbZEQ0DduyKHH
# I5P8V87jFttGnlR0wPP22FAebbvAbutkMMVQMFzhVBWiWD0VAnu9x0fjifLKDAVX
# Lwoun5rCFqwbasXFc7H/0DPiC+DBn3tUxefvcxUCys4+DC3s8CYp7WWXpZ8Wb/vd
# BhDliHmB7pWcmsB83uc4/P2GmAI3HMkOEu7fCaSYoQhouWOr07l/KM4TndylIirm
# 8f2WwXQcFEzmUvISM6ludUwGlVNfTTJUq2bTDEd3tlDKtV9AUY3rrnFwHTwJryLt
# T4IFhvgBfND3mL1eeSakKf7xTII4Jyt15SXhHd5oI/XGjSgykgJrWA57rGnAC7ru
# 3/ZbFNCMK/Jj6X8X4L6mBOYa2NGKwH4A37YGDrecJ/qXXWUYvfLYqHGf8ThYl12Y
# g1rwSKpWLolA/B1eqBw4TRcvVY0IvNNi5sm+//HJ9Aw6NJuR/uDR7X7vDXicpXMl
# RNgFMyADb8AFIvQPdHqcRpRorY+YUGlvzeJx/2gNYyezAokbrFhACsJ2BfyeLyCE
# o6AuwEHn511PKE8dK4JvlmLSoHj7VFR3NHDk3zRkx0ExkmF8aOdpvoKhuwBCxoZ/
# JhbzSzrvZ74GVjKKIyt5FA0wggdxMIIFWaADAgECAhMzAAAAFcXna54Cm0mZAAAA
# AAAVMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBB
# dXRob3JpdHkgMjAxMDAeFw0yMTA5MzAxODIyMjVaFw0zMDA5MzAxODMyMjVaMHwx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1p
# Y3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMIICIjANBgkqhkiG9w0BAQEFAAOC
# Ag8AMIICCgKCAgEA5OGmTOe0ciELeaLL1yR5vQ7VgtP97pwHB9KpbE51yMo1V/YB
# f2xK4OK9uT4XYDP/XE/HZveVU3Fa4n5KWv64NmeFRiMMtY0Tz3cywBAY6GB9alKD
# RLemjkZrBxTzxXb1hlDcwUTIcVxRMTegCjhuje3XD9gmU3w5YQJ6xKr9cmmvHaus
# 9ja+NSZk2pg7uhp7M62AW36MEBydUv626GIl3GoPz130/o5Tz9bshVZN7928jaTj
# kY+yOSxRnOlwaQ3KNi1wjjHINSi947SHJMPgyY9+tVSP3PoFVZhtaDuaRr3tpK56
# KTesy+uDRedGbsoy1cCGMFxPLOJiss254o2I5JasAUq7vnGpF1tnYN74kpEeHT39
# IM9zfUGaRnXNxF803RKJ1v2lIH1+/NmeRd+2ci/bfV+AutuqfjbsNkz2K26oElHo
# vwUDo9Fzpk03dJQcNIIP8BDyt0cY7afomXw/TNuvXsLz1dhzPUNOwTM5TI4CvEJo
# LhDqhFFG4tG9ahhaYQFzymeiXtcodgLiMxhy16cg8ML6EgrXY28MyTZki1ugpoMh
# XV8wdJGUlNi5UPkLiWHzNgY1GIRH29wb0f2y1BzFa/ZcUlFdEtsluq9QBXpsxREd
# cu+N+VLEhReTwDwV2xo3xwgVGD94q0W29R6HXtqPnhZyacaue7e3PmriLq0CAwEA
# AaOCAd0wggHZMBIGCSsGAQQBgjcVAQQFAgMBAAEwIwYJKwYBBAGCNxUCBBYEFCqn
# Uv5kxJq+gpE8RjUpzxD/LwTuMB0GA1UdDgQWBBSfpxVdAF5iXYP05dJlpxtTNRnp
# cjBcBgNVHSAEVTBTMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNodHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0w
# EwYDVR0lBAwwCgYIKwYBBQUHAwgwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEw
# CwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU1fZWy4/o
# olxiaNE9lJBb186aGMQwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNy
# b3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYt
# MjMuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5j
# cnQwDQYJKoZIhvcNAQELBQADggIBAJ1VffwqreEsH2cBMSRb4Z5yS/ypb+pcFLY+
# TkdkeLEGk5c9MTO1OdfCcTY/2mRsfNB1OW27DzHkwo/7bNGhlBgi7ulmZzpTTd2Y
# urYeeNg2LpypglYAA7AFvonoaeC6Ce5732pvvinLbtg/SHUB2RjebYIM9W0jVOR4
# U3UkV7ndn/OOPcbzaN9l9qRWqveVtihVJ9AkvUCgvxm2EhIRXT0n4ECWOKz3+SmJ
# w7wXsFSFQrP8DJ6LGYnn8AtqgcKBGUIZUnWKNsIdw2FzLixre24/LAl4FOmRsqlb
# 30mjdAy87JGA0j3mSj5mO0+7hvoyGtmW9I/2kQH2zsZ0/fZMcm8Qq3UwxTSwethQ
# /gpY3UA8x1RtnWN0SCyxTkctwRQEcb9k+SS+c23Kjgm9swFXSVRk2XPXfx5bRAGO
# WhmRaw2fpCjcZxkoJLo4S5pu+yFUa2pFEUep8beuyOiJXk+d0tBMdrVXVAmxaQFE
# fnyhYWxz/gq77EFmPWn9y8FBSX5+k77L+DvktxW/tM4+pTFRhLy/AsGConsXHRWJ
# jXD+57XQKBqJC4822rpM+Zv/Cuk0+CQ1ZyvgDbjmjJnW4SLq8CdCPSWU5nR0W2rR
# nj7tfqAxM328y+l7vzhwRNGQ8cirOoo6CGJ/2XBjU02N7oJtpQUQwXEGahC0HVUz
# WLOhcGbyoYIDWTCCAkECAQEwggEBoYHZpIHWMIHTMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFuZCBP
# cGVyYXRpb25zIExpbWl0ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo1NzFB
# LTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vydmlj
# ZaIjCgEBMAcGBSsOAwIaAxUABHHn7NCGusZz2RfVbyuwYwPykBWggYMwgYCkfjB8
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1N
# aWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQsFAAIFAOwb
# NKEwIhgPMjAyNTA3MTEwNjU4NDFaGA8yMDI1MDcxMjA2NTg0MVowdzA9BgorBgEE
# AYRZCgQBMS8wLTAKAgUA7Bs0oQIBADAKAgEAAgIFEQIB/zAHAgEAAgITFjAKAgUA
# 7ByGIQIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAID
# B6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBCwUAA4IBAQDA+hJvnH7Od6RfH6cf
# Udgm6AQVLC27Ov8/bXg+qObIjIEHkYqet0g3me/uBrSOaK9KDnYeWktVMo4Akkhz
# onnmUGZleUqDsZOMQu3qTO0PRzZsclTBhvMbOVwvSM8efe/49Rkk77ES17dyR5eQ
# 0A7MK5ZiY2auz8cg4/5G6GGKNhu3zTPJCoJy6C/EcQqqvX5/i60/MEtex19JrGme
# hvD/Jy6Nexq+2csYbxIp5DsNK7j6XVNWrId0vyn+nzvcgb2Bjm8TdQWH6QtFNHRG
# THeAUJ9HQoTUNf/7n04BoH+Y1g+9kVNf3n+yRdI/mDoJkA5QOjGONCwyo9hUlNKh
# crGoMYIEDTCCBAkCAQEwgZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAC
# EzMAAAH7y8tsN2flMJUAAQAAAfswDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqGSIb3
# DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0BCQQxIgQgptwO4GkTh8NqEl7q
# ONvQ+riQ5RDjQ/5fQqCc5B9dEO8wgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHkMIG9
# BCA52wKr/KCFlVNYiWsCLsB4qhjEYEP3xHqYqDu1SSTlGDCBmDCBgKR+MHwxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jv
# c29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB+8vLbDdn5TCVAAEAAAH7MCIE
# IGFM3fuozHf8AYC7/5ybgLlp1MvDskHqCx5NOvd1u268MA0GCSqGSIb3DQEBCwUA
# BIICAE2yzNaXCkIffhTsXBI7ZTFIFk4Z5DbusclrgXRl0m8APPEzUB4YJ4r8YCnO
# 3hkGJ5VkzP4Wm7kU7oFT4Pja0shgL8JIUj2cg25ARS3pFxESbtCy+a5PvdKz/S8o
# ff3MexO8PQX2le8iLjHpDcOvdFRWG9nV8yqHNbaUZdVpsW8D/tht6NJ1+ywRS20P
# Wuv+PB+wvIH/uW/c80gfujf8jWBjD7cbn+pjXQCWP0ijM9Il85uwhhK5voCqrHyM
# IGLueYOPHzZk8iLxg9U+dozHgOpY8eoFt8cLbIS6YYrkB14c56gBshTN3I84tti/
# o2znlYknK53FuwkeDP/ivwsxdJQYKLBRq9Il9mcxraThG8eJ1HEN5QQOv0zoL24A
# 4E5o7oWGNschh786istQLs4N7w9/SjENZ9qHcoapBoyfGPbwasN80IxlUsy9V6DY
# IcxPQs5HLcQ59d00qkO25je31TUiyjHIA4os40397hz5l2Tmhc34Q1Mw4C2rhsWq
# Gfm7qODu+BIrj88lzxV5O3sqrIMG7VCnBsWvspx1/PBma4E4MJRiz7LQuelgGe4I
# l1UPT/zmgZL5eUvMroFVsWP5WCiDctimmJjPBBCzvGvEBk/XTZfQBUOSpQ/VVBUA
# TZRJgnKQBgFRs5/z6Dqkj5Ilnh11i//nN46gAtSxElYo7Vnm
# SIG # End signature block

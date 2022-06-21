<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

#v0.1

$URL443 = @(
    "rdweb.wvd.microsoft.com"
    "rdbroker.wvd.microsoft.com"
    #Provisioning and Azure network connection endpoints:
    "cpcsaamssa1prodprap01.blob.core.windows.net"
    "cpcsaamssa1prodprau01.blob.core.windows.net"
    "cpcsaamssa1prodpreu01.blob.core.windows.net"
    "cpcsaamssa1prodpreu02.blob.core.windows.net"
    "cpcsaamssa1prodprna01.blob.core.windows.net"
    "cpcsaamssa1prodprna02.blob.core.windows.net"
    "cpcsacnrysa1prodprna02.blob.core.windows.net"
    "cpcsacnrysa1prodprap01.blob.core.windows.net"
    "cpcsacnrysa1prodprau01.blob.core.windows.net"
    "cpcsacnrysa1prodpreu01.blob.core.windows.net"
    "cpcsacnrysa1prodpreu02.blob.core.windows.net"
    "cpcsacnrysa1prodprna01.blob.core.windows.net"
    "cpcstcnryprodprap01.blob.core.windows.net"
    "cpcstcnryprodprau01.blob.core.windows.net"
    "cpcstcnryprodpreu01.blob.core.windows.net"
    "cpcstcnryprodprna01.blob.core.windows.net"
    "cpcstcnryprodprna02.blob.core.windows.net"
    "cpcstprovprodpreu01.blob.core.windows.net"
    "cpcstprovprodpreu02.blob.core.windows.net"
    "cpcstprovprodprna01.blob.core.windows.net"
    "cpcstprovprodprna02.blob.core.windows.net"
    "cpcstprovprodprap01.blob.core.windows.net"
    "cpcstprovprodprau01.blob.core.windows.net"
    "prna01.prod.cpcgateway.trafficmanager.net"
    "prna02.prod.cpcgateway.trafficmanager.net"
    "preu01.prod.cpcgateway.trafficmanager.net"
    "preu02.prod.cpcgateway.trafficmanager.net"
    "prap01.prod.cpcgateway.trafficmanager.net"
    "prau01.prod.cpcgateway.trafficmanager.net"
    #Cloud PC communication endpoints
    "endpointdiscovery.cmdagent.trafficmanager.net"
    "registration.prna01.cmdagent.trafficmanager.net"
    "registration.preu01.cmdagent.trafficmanager.net"
    "registration.prap01.cmdagent.trafficmanager.net"
    "registration.prau01.cmdagent.trafficmanager.net"
    #Registration endpoints
    "login.microsoftonline.com"
    "login.live.com"
    "enterpriseregistration.windows.net"
    "global.azure-devices-provisioning.net" #(443 & 5671 outbound)
    "hm-iot-in-prod-preu01.azure-devices.net" #(443 & 5671 outbound)
    "hm-iot-in-prod-prap01.azure-devices.net" #(443 & 5671 outbound)
    "hm-iot-in-prod-prna01.azure-devices.net" #(443 & 5671 outbound)
    "hm-iot-in-prod-prau01.azure-devices.net"
)

$URL5671 = @(
    "global.azure-devices-provisioning.net" #(443 & 5671 outbound)
    "hm-iot-in-prod-preu01.azure-devices.net" #(443 & 5671 outbound)
    "hm-iot-in-prod-prap01.azure-devices.net" #(443 & 5671 outbound)
    "hm-iot-in-prod-prna01.azure-devices.net" #(443 & 5671 outbound)
    "hm-iot-in-prod-prau01.azure-devices.net"
)

$AgentURL = @(
    "rdbroker.wvd.microsoft.com"
    "rdbroker-g-us-r0.wvd.microsoft.com"
    "rddiagnostics-g-us-r0.wvd.microsoft.com"
    "mrsglobalsteus2prod.blob.core.windows.net"
    "gcs.prod.monitoring.core.windows.net"
    "production.diagnostics.monitoring.core.windows.net"
    "eastus2-shared.prod.warm.ingest.monitor.core.windows.net"
    "qos.prod.warm.ingest.monitor.core.windows.net"
)

write-host "Checking addresses requiring port 443"
foreach ($URL in $URL443) {
    $result = Test-NetConnection -ComputerName $url -port 443
    if ($result.TcpTestSucceeded -eq $true) {
        write-host "$URL - Success!"
    }
    else {
        write-host "$URL - Failed" -ForegroundColor Red
    }
}

write-host " "
write-host "Checking addresses requiring port 5671"
foreach ($URL in $URL5671) {
    $result = Test-NetConnection -ComputerName $url -port 5671
    if ($result.TcpTestSucceeded -eq $true) {
        write-host "$URL - Success!"
    }
    else {
        write-host "$URL - Failed" -ForegroundColor Red
    }
}

write-host " "
write-host "Checking addresses required by Agent on port 443"
foreach ($URL in $AgentURL) {
    $result = Test-NetConnection -ComputerName $url -port 443
    if ($result.TcpTestSucceeded -eq $true) {
        write-host "$URL - Success!"
    }
    else {
        write-host "$URL - Failed" -ForegroundColor Red
    }
}

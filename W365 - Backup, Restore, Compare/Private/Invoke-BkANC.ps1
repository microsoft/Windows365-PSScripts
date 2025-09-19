function Invoke-BkANC {
    param($outputdir)
    
    # 3. Cloud PC On-Premises Connections
    try {
        $onPremConnections = Get-MgDeviceManagementVirtualEndpointOnPremiseConnection
        foreach ($ANC in $onPremConnections) {
            try {
                $String = Join-Path -Path $outputdir -ChildPath ("ANCs\" + $ANC.DisplayName + ".json")
                Export-Json -FileName $String -Object $ANC
            } catch {
                Write-Warning "Failed to export ANC '$($ANC.DisplayName)': $_"
            }
        }
    } catch {
        Write-Error "Failed to retrieve On-Premises Connections: $_"
    }
}
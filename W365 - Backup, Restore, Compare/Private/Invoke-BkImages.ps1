function Invoke-BkImages {
    param($outputdir)
    
    # 2. Cloud PC Images
    try {
        $images = Get-MgDeviceManagementVirtualEndpointDeviceImage
        foreach ($image in $images) {
            try {
                $String = Join-Path -Path $outputdir -ChildPath ("customimages\" + $image.DisplayName + ".json")
                Export-Json -FileName $String -Object $image
            }
            catch {
                Write-Warning "Failed to export image '$($image.DisplayName)': $_"
            }
        }
    }
    catch {
        Write-Error "Failed to retrieve device images: $_"
    }
}
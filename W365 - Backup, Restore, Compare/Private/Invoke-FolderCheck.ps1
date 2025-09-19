function Invoke-FolderCheck {
    param($path)
    
    # Output directory for JSON files with timestamp
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $outputDir = Join-Path $path "W365-Configs-$timestamp"
    try {
        if (-not (Test-Path $outputDir)) {
            New-Item -Path $outputDir -ItemType Directory -ErrorAction Stop | Out-Null
            New-Item -Path (Join-Path $outputDir 'provisioningpolicies') -ItemType Directory -ErrorAction Stop | Out-Null
            New-Item -Path (Join-Path $outputDir 'customimages') -ItemType Directory -ErrorAction Stop | Out-Null
            New-Item -Path (Join-Path $outputDir 'UserSettings') -ItemType Directory -ErrorAction Stop | Out-Null
            New-Item -Path (Join-Path $outputDir 'ANCs') -ItemType Directory -ErrorAction Stop | Out-Null
        }
        return $outputDir
    }
    catch {
        Write-Error "Failed to create output directories: $_"
        return $null
    }
}
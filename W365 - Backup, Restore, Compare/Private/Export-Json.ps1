function Export-Json {
    <#
    .SYNOPSIS
        Helper function to export objects as JSON files.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$FileName,
        [Parameter(Mandatory)]
        $Object
    )
    try {
        $json = $Object | ConvertTo-Json -Depth 100
        $json | Out-File -FilePath $FileName -Encoding utf8
    }
    catch {
        Write-Error "Failed to export JSON to file '$FileName': $_"
    }
}
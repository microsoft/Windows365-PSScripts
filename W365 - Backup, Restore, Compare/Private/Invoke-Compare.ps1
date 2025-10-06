function Invoke-Compare {
    <#
    .SYNOPSIS
        Helper function to compare two JSON files and output differences for array properties.
    #>

    param ($JSON1, $JSON2)
    
    try {
        # Read and convert both JSON files to PowerShell objects
        $obj1 = Get-Content -Path $JSON1 -ErrorAction Stop | ConvertFrom-Json
        $obj2 = Get-Content -Path $JSON2 -ErrorAction Stop | ConvertFrom-Json
    }
    catch {
        Write-Error "Failed to read or parse JSON files: $_"
        return
    }

    # Get all property names from both objects
    try {
        $allProps = ($obj1.PSObject.Properties.Name + $obj2.PSObject.Properties.Name) | Sort-Object -Unique
    }
    catch {
        Write-Error "Failed to retrieve property names: $_"
        return
    }

    foreach ($prop in $allProps) {
        try {
            $val1 = $obj1.$prop
            $val2 = $obj2.$prop

            if (($null -ne $val1) -and ($null -ne $val2)) {
                $diff = Compare-Object -ReferenceObject $val1 -DifferenceObject $val2
                if ($diff) {
                    Write-Host "Property '$prop' (array) differs:"
                    $diff | ForEach-Object {
                        Write-Host "  $($_.SideIndicator) $($_.InputObject)"
                    }
                }
            }
        }
        catch {
            Write-Error "Error comparing property '$prop': $_"
        }
    }
}
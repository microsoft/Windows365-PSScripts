function Select-FileDialog {
    param(
        [string]$Title = 'Select a file',
        [string]$InitialDirectory = [Environment]::GetFolderPath('Desktop'),
        [string]$Filter = 'JSON Files (*.json)|*.json',
        [switch]$MultiSelect
    )

    Add-Type -AssemblyName System.Windows.Forms

    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = $Title
    $dlg.InitialDirectory = $InitialDirectory
    $dlg.Filter = $Filter
    $dlg.Multiselect = $MultiSelect.IsPresent

    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        if ($dlg.Multiselect) { return $dlg.FileNames } else { return $dlg.FileName }
    }

    return $null
}
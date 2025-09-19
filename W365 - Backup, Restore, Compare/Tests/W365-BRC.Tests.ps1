BeforeAll {
    # Import the module for testing
    Import-Module "$PSScriptRoot\..\W365-BRC.psm1" -Force
}

Describe "W365-BRC Module Tests" {
    Context "Module Import" {
        It "Should import the module successfully" {
            Get-Module W365-BRC | Should -Not -BeNullOrEmpty
        }
        
        It "Should export only the expected public functions" {
            $ExportedCommands = (Get-Module W365-BRC).ExportedCommands.Keys
            $ExportedCommands | Should -Contain "Invoke-W365Backup"
            $ExportedCommands | Should -Contain "Invoke-W365Restore"
            $ExportedCommands | Should -Contain "Invoke-W365Compare"
            $ExportedCommands.Count | Should -Be 3
        }
    }
    
    Context "Public Functions" {
        It "Should have Invoke-W365Backup function available" {
            Get-Command Invoke-W365Backup -Module W365-BRC | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Invoke-W365Restore function available" {
            Get-Command Invoke-W365Restore -Module W365-BRC | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Invoke-W365Compare function available" {
            Get-Command Invoke-W365Compare -Module W365-BRC | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Function Parameters" {
        It "Invoke-W365Backup should have correct parameters" {
            $Command = Get-Command Invoke-W365Backup -Module W365-BRC
            $Command.Parameters.Keys | Should -Contain "Object"
            $Command.Parameters.Keys | Should -Contain "Path"
        }
        
        It "Invoke-W365Restore should have correct parameters" {
            $Command = Get-Command Invoke-W365Restore -Module W365-BRC
            $Command.Parameters.Keys | Should -Contain "Object"
            $Command.Parameters.Keys | Should -Contain "JSON"
        }
    }
}

AfterAll {
    # Clean up
    Remove-Module W365-BRC -Force -ErrorAction SilentlyContinue
}
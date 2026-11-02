# Pester tests for Test-CippExchangeInputValidation priority handling

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $ValidationPath = Join-Path $RepoRoot 'Modules/CIPPCore/Public/Tools/Test-CippExchangeInputValidation.ps1'
    $ToolsDir = Join-Path $RepoRoot 'Modules/CIPPCore/Public/Tools'

    Get-ChildItem -Path $ToolsDir -Filter '*Quarantine*.ps1' | ForEach-Object { . $_.FullName }
    . $ValidationPath
}

Describe 'Test-CippExchangeInputValidation - Priority validation' {
    Context 'Accepts integer types' {
        It 'accepts Int16 priority' {
            [int16]$priority = 5
            $result = Test-CippExchangeInputValidation -Priority $priority
            $result.IsValid | Should -Be $true
        }

        It 'accepts Int32 priority' {
            [int32]$priority = 100
            $result = Test-CippExchangeInputValidation -Priority $priority
            $result.IsValid | Should -Be $true
        }

        It 'accepts Int64 priority (JSON deserialization)' {
            [int64]$priority = 42
            $result = Test-CippExchangeInputValidation -Priority $priority
            $result.IsValid | Should -Be $true
        }

        It 'accepts whole double (5.0)' {
            [double]$priority = 5.0
            $result = Test-CippExchangeInputValidation -Priority $priority
            $result.IsValid | Should -Be $true
        }

        It 'accepts zero priority' {
            $result = Test-CippExchangeInputValidation -Priority 0
            $result.IsValid | Should -Be $true
        }

        It 'accepts maximum priority 9999' {
            $result = Test-CippExchangeInputValidation -Priority 9999
            $result.IsValid | Should -Be $true
        }
    }

    Context 'Rejects invalid types and values' {
        It 'rejects boolean true' {
            [bool]$priority = $true
            $result = Test-CippExchangeInputValidation -Priority $priority
            $result.IsValid | Should -Be $false
            $result.Errors | Should -Match 'must be an integer, not a boolean'
        }

        It 'rejects boolean false' {
            [bool]$priority = $false
            $result = Test-CippExchangeInputValidation -Priority $priority
            $result.IsValid | Should -Be $false
            $result.Errors | Should -Match 'must be an integer, not a boolean'
        }

        It 'rejects non-whole double (5.7)' {
            [double]$priority = 5.7
            $result = Test-CippExchangeInputValidation -Priority $priority
            $result.IsValid | Should -Be $false
            $result.Errors | Should -Match 'must be a whole number, not a decimal'
        }

        It 'rejects non-whole double (3.14)' {
            [double]$priority = 3.14
            $result = Test-CippExchangeInputValidation -Priority $priority
            $result.IsValid | Should -Be $false
            $result.Errors | Should -Match 'must be a whole number, not a decimal'
        }

        It 'rejects negative priority' {
            $result = Test-CippExchangeInputValidation -Priority -1
            $result.IsValid | Should -Be $false
            $result.Errors | Should -Match 'must be between 0 and 9999'
        }

        It 'rejects priority above 9999' {
            $result = Test-CippExchangeInputValidation -Priority 10000
            $result.IsValid | Should -Be $false
            $result.Errors | Should -Match 'must be between 0 and 9999'
        }
    }

    Context 'Newline rejection in various fields' {
        It 'rejects email with trailing newline' {
            $result = Test-CippExchangeInputValidation -EmailAddresses @("user@example.com`n")
            $result.IsValid | Should -Be $false
            $result.Errors | Should -Match 'cannot contain newline'
        }

        It 'rejects domain with trailing newline' {
            $result = Test-CippExchangeInputValidation -Domains @("example.com`n")
            $result.IsValid | Should -Be $false
            $result.Errors | Should -Match 'cannot contain newline'
        }

        It 'rejects QuarantineTag with newline' {
            $result = Test-CippExchangeInputValidation -QuarantineTag "MyTag`n"
            $result.IsValid | Should -Be $false
            $result.Errors | Should -Match 'cannot contain newline'
        }

        It 'rejects IP with newline' {
            $result = Test-CippExchangeInputValidation -IPAddresses @("192.168.1.1`n")
            $result.IsValid | Should -Be $false
            $result.Errors | Should -Match 'cannot contain newline'
        }
    }
}

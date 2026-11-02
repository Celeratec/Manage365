BeforeAll {
    $CIPPRootPath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $env:CIPPRootPath = $CIPPRootPath
    Import-Module "$CIPPRootPath/Modules/CIPPCore" -Force
}

Describe 'Test-CippExchangeInputValidation - IP Range Breadth Checks' {
    It 'Rejects IPv4 range larger than /16 (0.0.0.0-255.255.255.255)' {
        $Result = Test-CippExchangeInputValidation -IPAddresses @('0.0.0.0-255.255.255.255') -StrictIPValidation
        $Result.IsValid | Should -Be $false
        $Result.Errors | Should -Match 'exceeds /16 maximum'
    }

    It 'Rejects IPv4 range exactly at /15 boundary (10.0.0.0-10.1.255.255)' {
        $Result = Test-CippExchangeInputValidation -IPAddresses @('10.0.0.0-10.1.255.255') -StrictIPValidation
        $Result.IsValid | Should -Be $false
        $Result.Errors | Should -Match 'exceeds /16 maximum'
    }

    It 'Accepts IPv4 range exactly at /16 boundary (10.0.0.0-10.0.255.255)' {
        $Result = Test-CippExchangeInputValidation -IPAddresses @('10.0.0.0-10.0.255.255') -StrictIPValidation
        $Result.IsValid | Should -Be $true
    }

    It 'Accepts IPv4 range smaller than /16 (192.168.1.0-192.168.1.255)' {
        $Result = Test-CippExchangeInputValidation -IPAddresses @('192.168.1.0-192.168.1.255') -StrictIPValidation
        $Result.IsValid | Should -Be $true
    }

    It 'Rejects IPv4 range with end < start' {
        $Result = Test-CippExchangeInputValidation -IPAddresses @('10.0.0.100-10.0.0.10') -StrictIPValidation
        $Result.IsValid | Should -Be $false
        $Result.Errors | Should -Match 'end must be >= start'
    }

    It 'Rejects full IPv6 range (::-ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff)' {
        $Result = Test-CippExchangeInputValidation -IPAddresses @('::-ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff') -StrictIPValidation
        $Result.IsValid | Should -Be $false
        $Result.Errors | Should -Match 'exceeds /32 maximum'
    }

    It 'Rejects IPv6 range with different top 32 bits' {
        $Result = Test-CippExchangeInputValidation -IPAddresses @('2001:db8::-2001:db9::ffff') -StrictIPValidation
        $Result.IsValid | Should -Be $false
        $Result.Errors | Should -Match 'exceeds /32 maximum'
    }

    It 'Accepts IPv6 range within /32 (same top 32 bits)' {
        $Result = Test-CippExchangeInputValidation -IPAddresses @('2001:db8::-2001:db8::ffff') -StrictIPValidation
        $Result.IsValid | Should -Be $true
    }
}

Describe 'Test-CippExchangeInputValidation - Strict Dotted-Quad Validation' {
    It 'Rejects IPv4 with leading zeros (010.1.1.1)' {
        $Result = Test-CippExchangeInputValidation -IPAddresses @('010.1.1.1') -StrictIPValidation
        $Result.IsValid | Should -Be $false
        $Result.Errors | Should -Match 'leading zeros'
    }

    It 'Rejects IPv4 CIDR with leading zeros (010.1.1.0/24)' {
        $Result = Test-CippExchangeInputValidation -IPAddresses @('010.1.1.0/24') -StrictIPValidation
        $Result.IsValid | Should -Be $false
        $Result.Errors | Should -Match 'leading zeros'
    }

    It 'Rejects shorthand CIDR notation (10/16)' {
        $Result = Test-CippExchangeInputValidation -IPAddresses @('10/16') -StrictIPValidation
        $Result.IsValid | Should -Be $false
        $Result.Errors | Should -Match 'dotted-quad'
    }

    It 'Accepts valid dotted-quad CIDR (10.0.0.0/16)' {
        $Result = Test-CippExchangeInputValidation -IPAddresses @('10.0.0.0/16') -StrictIPValidation
        $Result.IsValid | Should -Be $true
    }

    It 'Rejects IPv4 range with leading zeros in start IP' {
        $Result = Test-CippExchangeInputValidation -IPAddresses @('010.0.0.1-10.0.0.10') -StrictIPValidation
        $Result.IsValid | Should -Be $false
        $Result.Errors | Should -Match 'leading zeros'
    }
}

Describe 'Test-CippExchangeInputValidation - Priority Validation' {
    It 'Accepts integer priority (5)' {
        $Result = Test-CippExchangeInputValidation -Priority 5
        $Result.IsValid | Should -Be $true
    }

    It 'Accepts zero priority' {
        $Result = Test-CippExchangeInputValidation -Priority 0
        $Result.IsValid | Should -Be $true
    }

    It 'Rejects negative priority' {
        $Result = Test-CippExchangeInputValidation -Priority -1
        $Result.IsValid | Should -Be $false
        $Result.Errors | Should -Match 'between 0 and 9999'
    }

    It 'Rejects priority over 9999' {
        $Result = Test-CippExchangeInputValidation -Priority 10000
        $Result.IsValid | Should -Be $false
        $Result.Errors | Should -Match 'between 0 and 9999'
    }
}

Describe 'Test-CippExchangeInputValidation - Regex Anchor Tests' {
    It 'Uses \\z anchor to reject email with embedded newline' {
        $Result = Test-CippExchangeInputValidation -EmailAddresses @("test@example.com`nmalicious")
        $Result.IsValid | Should -Be $false
    }

    It 'Uses \\z anchor to reject domain with embedded newline' {
        $Result = Test-CippExchangeInputValidation -Domains @("example.com`nmalicious")
        $Result.IsValid | Should -Be $false
    }

    It 'Uses \\z anchor to reject policy name with embedded newline (evil`n)' {
        $Result = Test-CippExchangeInputValidation -PolicyName "evil`n"
        $Result.IsValid | Should -Be $false
        $Result.Errors | Should -Match 'newline'
    }

    It 'Uses \\z anchor to reject rule name with embedded newline' {
        $Result = Test-CippExchangeInputValidation -RuleName "evil`n"
        $Result.IsValid | Should -Be $false
        $Result.Errors | Should -Match 'newline'
    }
}

Describe 'Test-CippExchangeInputValidation - CIDR Leading Zero Tests' {
    It 'Rejects CIDR prefix with leading zeros (/032)' {
        $Result = Test-CippExchangeInputValidation -IPAddresses @('1.2.3.4/032') -StrictIPValidation
        $Result.IsValid | Should -Be $false
        $Result.Errors | Should -Match 'leading zeros'
    }

    It 'Accepts CIDR prefix without leading zeros (/32)' {
        $Result = Test-CippExchangeInputValidation -IPAddresses @('1.2.3.4/32') -StrictIPValidation
        $Result.IsValid | Should -Be $true
    }
}

Describe 'Test-CippExchangeInputValidation - Whitespace and Newline Tests' {
    It 'Trims leading/trailing whitespace from email' {
        $Result = Test-CippExchangeInputValidation -EmailAddresses @('  test@example.com  ')
        $Result.IsValid | Should -Be $true
    }

    It 'Rejects email with embedded LF' {
        $Result = Test-CippExchangeInputValidation -EmailAddresses @("test@example.com`nmalicious")
        $Result.IsValid | Should -Be $false
        $Result.Errors | Should -Match 'newline'
    }

    It 'Trims leading/trailing whitespace from IP' {
        $Result = Test-CippExchangeInputValidation -IPAddresses @('  10.0.0.1  ') -StrictIPValidation
        $Result.IsValid | Should -Be $true
    }

    It 'Rejects IP with embedded LF' {
        $Result = Test-CippExchangeInputValidation -IPAddresses @("10.0.0.1`nmalicious") -StrictIPValidation
        $Result.IsValid | Should -Be $false
        $Result.Errors | Should -Match 'newline'
    }
}

Describe 'Test-CippExchangeInputValidation - Priority Float Rejection' {
    It 'Rejects float priority as string (5.7)' {
        $Result = Test-CippExchangeInputValidation -Priority '5.7'
        $Result.IsValid | Should -Be $false
        $Result.Errors | Should -Match 'decimal'
    }

    It 'Rejects float priority as double' {
        $Result = Test-CippExchangeInputValidation -Priority ([double]5.7)
        $Result.IsValid | Should -Be $false
        $Result.Errors | Should -Match 'decimal'
    }

    It 'Accepts integer priority' {
        $Result = Test-CippExchangeInputValidation -Priority 5
        $Result.IsValid | Should -Be $true
    }
}

Describe 'Test-CippExchangeInputValidation - SentToMemberOf Validation' {
    It 'Accepts valid email in SentToMemberOf' {
        $Result = Test-CippExchangeInputValidation -SentToMemberOf @('group@example.com')
        $Result.IsValid | Should -Be $true
    }

    It 'Accepts valid GUID in SentToMemberOf' {
        $Result = Test-CippExchangeInputValidation -SentToMemberOf @('12345678-1234-1234-1234-123456789012')
        $Result.IsValid | Should -Be $true
    }

    It 'Rejects invalid value in SentToMemberOf' {
        $Result = Test-CippExchangeInputValidation -SentToMemberOf @('not-valid')
        $Result.IsValid | Should -Be $false
        $Result.Errors | Should -Match 'email address or GUID'
    }

    It 'Rejects SentToMemberOf with embedded newline' {
        $Result = Test-CippExchangeInputValidation -SentToMemberOf @("group@example.com`nmalicious")
        $Result.IsValid | Should -Be $false
        $Result.Errors | Should -Match 'newline'
    }
}

Describe 'Test-CippExchangeInputValidation - QuarantineTag Validation' {
    It 'Accepts valid quarantine tag' {
        $Result = Test-CippExchangeInputValidation -QuarantineTag 'DefaultFullAccessPolicy'
        $Result.IsValid | Should -Be $true
    }

    It 'Rejects quarantine tag with special characters' {
        $Result = Test-CippExchangeInputValidation -QuarantineTag 'Invalid<>Tag'
        $Result.IsValid | Should -Be $false
        $Result.Errors | Should -Match 'alphanumeric'
    }

    It 'Rejects quarantine tag with embedded newline' {
        $Result = Test-CippExchangeInputValidation -QuarantineTag "ValidTag`nmalicious"
        $Result.IsValid | Should -Be $false
        $Result.Errors | Should -Match 'newline'
    }
}

Describe 'Test-CippExchangeInputValidation - Region Case-Sensitive Validation' {
    It 'Accepts uppercase region code' {
        $Result = Test-CippExchangeInputValidation -RegionBlockList @('US', 'GB')
        $Result.IsValid | Should -Be $true
    }

    It 'Rejects lowercase region code (case-sensitive)' {
        $Result = Test-CippExchangeInputValidation -RegionBlockList @('us')
        $Result.IsValid | Should -Be $false
        $Result.Errors | Should -Match 'uppercase'
    }

    It 'Rejects region code with embedded newline' {
        $Result = Test-CippExchangeInputValidation -RegionBlockList @("US`nmalicious")
        $Result.IsValid | Should -Be $false
        $Result.Errors | Should -Match 'newline'
    }
}

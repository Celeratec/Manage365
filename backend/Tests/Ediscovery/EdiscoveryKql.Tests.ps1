# backend/Tests/Ediscovery/EdiscoveryKql.Tests.ps1
BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    foreach ($Name in @('New-CIPPEdiscoveryKql', 'Get-CIPPEdiscoverySearchPlan')) {
        . (Join-Path $RepoRoot "Modules/CIPPCore/Public/Ediscovery/$Name.ps1")
    }
}

Describe 'New-CIPPEdiscoveryKql' {
    It 'joins multiple terms with OR and quotes each phrase' {
        $Result = New-CIPPEdiscoveryKql -Terms @('project falcon', 'alpha beta')
        $Result.Kql | Should -Be '("project falcon" OR "alpha beta")'
        $Result.TermCount | Should -Be 2
        $Result.Terms | Should -Be @('project falcon', 'alpha beta')
        $Result.KqlHash | Should -Match '\A[a-f0-9]{64}\z'
    }

    It 'escapes double quotes inside terms' {
        $Result = New-CIPPEdiscoveryKql -Terms @('say "hello"')
        $Result.Kql | Should -Be '("say \"hello\"")'
    }

    It 'appends sent date bounds when both dates are supplied' {
        $From = [datetime]'2024-01-01'
        $To = [datetime]'2024-06-30'
        $Result = New-CIPPEdiscoveryKql -Terms @('project falcon') -DateFrom $From -DateTo $To
        $Result.Kql | Should -Be '("project falcon") AND sent>=2024-01-01 AND sent<=2024-06-30'
    }

    It 'trims terms and drops empty entries' {
        $Result = New-CIPPEdiscoveryKql -Terms @('  a  ', '', 'b')
        $Result.TermCount | Should -Be 2
        $Result.Kql | Should -Be '("a" OR "b")'
    }

    It 'refuses zero terms after trim' {
        { New-CIPPEdiscoveryKql -Terms @('  ', '') } | Should -Throw '*1 to 25*'
    }

    It 'refuses more than 25 terms' {
        $Many = 1..26 | ForEach-Object { "term$_" }
        { New-CIPPEdiscoveryKql -Terms $Many } | Should -Throw '*1 to 25*'
    }

    It 'refuses terms longer than 128 characters' {
        $Long = 'x' * 129
        { New-CIPPEdiscoveryKql -Terms @($Long) } | Should -Throw '*128*'
    }

    It 'refuses injection characters and contentQuery passthrough' {
        { New-CIPPEdiscoveryKql -Terms @('a;b') } | Should -Throw '*Invalid term*'
        { New-CIPPEdiscoveryKql -Terms @('a|b') } | Should -Throw '*Invalid term*'
        { New-CIPPEdiscoveryKql -Terms @('contentQuery=evil') } | Should -Throw '*Invalid term*'
    }

    It 'requires dateFrom and dateTo together' {
        { New-CIPPEdiscoveryKql -Terms @('a') -DateFrom ([datetime]'2024-01-01') } | Should -Throw '*together*'
        { New-CIPPEdiscoveryKql -Terms @('a') -DateTo ([datetime]'2024-01-01') } | Should -Throw '*together*'
    }

    It 'refuses dateTo before dateFrom' {
        $From = [datetime]'2024-06-01'
        $To = [datetime]'2024-01-01'
        { New-CIPPEdiscoveryKql -Terms @('a') -DateFrom $From -DateTo $To } | Should -Throw '*dateTo*'
    }

    It 'refuses a date span over 5 years' {
        $From = [datetime]'2020-01-01'
        $To = [datetime]'2025-01-02'
        { New-CIPPEdiscoveryKql -Terms @('a') -DateFrom $From -DateTo $To } | Should -Throw '*5 years*'
    }

    It 'allows exactly 1825 days inclusive' {
        $From = [datetime]'2020-01-01'
        $To = $From.AddDays(1825)
        { New-CIPPEdiscoveryKql -Terms @('a') -DateFrom $From -DateTo $To } | Should -Not -Throw
    }

    It 'produces a stable KqlHash for the same KQL string' {
        $A = New-CIPPEdiscoveryKql -Terms @('project falcon')
        $B = New-CIPPEdiscoveryKql -Terms @('project falcon')
        $A.KqlHash | Should -Be $B.KqlHash
        $A.KqlHash | Should -Not -BeNullOrEmpty
    }
}

Describe 'Get-CIPPEdiscoverySearchPlan' {
    It 'builds displayName, externalId, custodian, kql, and limits' {
        $Plan = Get-CIPPEdiscoverySearchPlan `
            -TicketNumber '1234567' `
            -CaseLabel 'Example Matter 2026-001' `
            -CustodianUpn 'custodian@contoso.example' `
            -Terms @('project falcon') `
            -DateFrom ([datetime]'2024-01-01') `
            -DateTo ([datetime]'2024-06-30')

        $Plan.DisplayName | Should -Be '1234567 - Example Matter 2026-001'
        $Plan.ExternalId | Should -Be '1234567'
        $Plan.CustodianUpn | Should -Be 'custodian@contoso.example'
        $Plan.Kql | Should -Be '("project falcon") AND sent>=2024-01-01 AND sent<=2024-06-30'
        $Plan.KqlHash | Should -Match '\A[a-f0-9]{64}\z'
        $Plan.TermCount | Should -Be 1
        $Plan.Limits.MaxTerms | Should -Be 25
        $Plan.Limits.MaxDateSpanDays | Should -Be 1825
        $Plan.Limits.MaxCustodians | Should -Be 1
        $Plan.Limits.MailboxOnly | Should -BeTrue
        $Plan.Limits.StatisticsOptions | Should -Be 'includeQueryStats,includeUnindexedStats'
    }

    It 'refuses invalid ticket numbers' {
        { Get-CIPPEdiscoverySearchPlan -TicketNumber '12' -CustodianUpn 'a@b.example' -Terms @('x') } | Should -Throw '*ticket*'
        { Get-CIPPEdiscoverySearchPlan -TicketNumber '123456789' -CustodianUpn 'a@b.example' -Terms @('x') } | Should -Throw '*ticket*'
    }

    It 'refuses empty custodianUpn' {
        { Get-CIPPEdiscoverySearchPlan -TicketNumber '1234567' -CustodianUpn ' ' -Terms @('x') } | Should -Throw '*custodian*'
    }

    It 'surfaces KQL validation errors from term limits' {
        $Many = 1..26 | ForEach-Object { "t$_" }
        { Get-CIPPEdiscoverySearchPlan -TicketNumber '1234567' -CustodianUpn 'a@b.example' -Terms $Many } | Should -Throw '*1 to 25*'
    }
}
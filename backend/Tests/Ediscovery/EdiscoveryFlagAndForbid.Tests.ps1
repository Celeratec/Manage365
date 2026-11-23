# backend/Tests/Ediscovery/EdiscoveryFlagAndForbid.Tests.ps1
Describe 'EdiscoverySearch feature flag' {
    It 'ships enabled and lists config, readiness, cases, and search endpoints' {
        $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
        $Flags = Get-Content (Join-Path $RepoRoot 'Config/FeatureFlags.json') -Raw | ConvertFrom-Json
        $Flag = $Flags | Where-Object { $_.Id -eq 'EdiscoverySearch' }
        $Flag | Should -Not -BeNullOrEmpty
        $Flag.Enabled | Should -BeTrue
        foreach ($Name in @(
                'ListEdiscoveryConfig', 'ExecEdiscoveryConfig', 'ListEdiscoveryReadiness',
                'ListEdiscoveryCases', 'ExecEdiscoveryCase', 'ListEdiscoveryCaseSearches',
                'ExecEdiscoveryCaseSearch', 'ListEdiscoveryCaseHolds', 'ExecEdiscoveryCaseHold',
                'ListEdiscoveryCaseOperations', 'ExecEdiscoveryCaseExport', 'ExecEdiscoverySearch'
            )) {
            $Flag.Endpoints | Should -Contain $Name
        }
    }
}

Describe 'Test-CIPPEdiscoveryForbiddenAction' {
    BeforeAll {
        . (Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))) 'Modules/CIPPCore/Public/Ediscovery/Test-CIPPEdiscoveryForbiddenAction.ps1')
    }
    It 'refuses purge, case delete, hold remove, and purgeData paths' {
        { Test-CIPPEdiscoveryForbiddenAction -Action 'delete' -Resource 'case' } | Should -Throw '*refused*'
        { Test-CIPPEdiscoveryForbiddenAction -Action 'remove' -Resource 'hold' } | Should -Throw '*refused*'
        { Test-CIPPEdiscoveryForbiddenAction -Action 'purge' } | Should -Throw '*refused*'
        { Test-CIPPEdiscoveryForbiddenAction -RawPath '/security/cases/ediscoveryCases/x/searches/y/purgeData' } | Should -Throw '*refused*'
    }
    It 'allows create case and estimateStatistics' {
        Test-CIPPEdiscoveryForbiddenAction -Action 'create' -Resource 'case' | Should -BeTrue
        Test-CIPPEdiscoveryForbiddenAction -Action 'estimateStatistics' -Resource 'search' | Should -BeTrue
    }
}
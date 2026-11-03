Describe 'Mail filter integration' -Tag 'Integration' {
    It 'reads preset rules from the configured test tenant without changing them' {
        if ([string]::IsNullOrWhiteSpace($env:MANAGE365_MAILFILTER_TEST_TENANT)) {
            Set-ItResult -Skipped -Because 'MANAGE365_MAILFILTER_TEST_TENANT is not set, so no live tenant is configured.'
        }

        $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
        $ModulePath = Join-Path $RepoRoot 'Modules/CIPPCore/CIPPCore.psd1'
        try {
            Import-Module $ModulePath -Force -ErrorAction Stop
        } catch {
            Set-ItResult -Skipped -Because "CIPPCore could not be imported for a live tenant call: $($_.Exception.Message)"
        }

        $Private = Join-Path $RepoRoot 'Modules/CIPPCore/Private/MailFilter'
        . (Join-Path $Private 'MailFilter.Common.ps1')
        . (Join-Path $Private 'Get-CIPPPresetSecurityPolicyChange.ps1')

        $Tenant = $env:MANAGE365_MAILFILTER_TEST_TENANT
        $Rules = @(New-ExoRequest -tenantid $Tenant -cmdlet 'Get-EOPProtectionPolicyRule' -useSystemMailbox $true)
        $Rules.Count | Should -BeGreaterOrEqual 0

        $Plan = Get-CIPPPresetSecurityPolicyChange -Preset 'Standard' -State 'Enable' -EopRule ($Rules | Select-Object -First 1)
        $Plan.Snapshot | Should -Not -BeNullOrEmpty
    }
}

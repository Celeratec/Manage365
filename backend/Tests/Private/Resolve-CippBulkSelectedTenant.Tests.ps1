# Resolve-CippBulkSelectedTenant rejects AllTenants when BlockAllTenants is set,
# and otherwise resolves by customerId against Get-Tenants.

BeforeAll {
    $AuthDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Modules/CIPPCore/Public/Authentication'
    . (Join-Path $AuthDir 'Resolve-CippBulkSelectedTenant.ps1')

    $script:Tenants = @(
        [pscustomobject]@{ customerId = 'aaaaaaaa-0000-0000-0000-000000000000'; defaultDomainName = 'a.onmicrosoft.com' }
        [pscustomobject]@{ customerId = 'bbbbbbbb-0000-0000-0000-000000000000'; defaultDomainName = 'b.onmicrosoft.com' }
    )
}

Describe 'Resolve-CippBulkSelectedTenant' {
    BeforeEach {
        Mock Test-CippAccess { 'AllTenants' }
        Mock Test-CippAllTenantsBlocked { $false }
        Mock Get-Tenants { $script:Tenants }
    }

    It 'refuses an AllTenants entry when the caller roles block AllTenants' {
        Mock Test-CippAllTenantsBlocked { $true }
        {
            Resolve-CippBulkSelectedTenant -Request ([pscustomobject]@{}) -SelectedTenants @(
                [pscustomobject]@{ customerId = 'AllTenants'; defaultDomainName = 'AllTenants' }
            )
        } | Should -Throw -ExceptionType ([System.UnauthorizedAccessException])
    }

    It 'returns the AllTenants sentinel for an unrestricted caller' {
        $Result = Resolve-CippBulkSelectedTenant -Request ([pscustomobject]@{}) -SelectedTenants @(
            [pscustomobject]@{ customerId = 'AllTenants'; defaultDomainName = 'AllTenants' }
        )
        $Result.customerId | Should -Be 'AllTenants'
        $Result.defaultDomainName | Should -Be 'AllTenants'
    }

    It 'still resolves individually selected tenants when AllTenants is blocked' {
        Mock Test-CippAllTenantsBlocked { $true }
        $Result = @(Resolve-CippBulkSelectedTenant -Request ([pscustomobject]@{}) -SelectedTenants @(
                [pscustomobject]@{ customerId = 'aaaaaaaa-0000-0000-0000-000000000000'; defaultDomainName = 'a.onmicrosoft.com' }
            ))
        $Result.Count | Should -Be 1
        $Result[0].defaultDomainName | Should -Be 'a.onmicrosoft.com'
    }
}

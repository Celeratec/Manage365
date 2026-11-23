# backend/Tests/Ediscovery/EdiscoveryConfig.Tests.ps1
BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))

    function Get-CIPPTable { param($TableName) }
    function Get-CIPPAzDataTableEntity { param($Filter) }
    function Add-CIPPAzDataTableEntity { param($Entity, [switch]$Force) }

    foreach ($Name in @('Get-CIPPEdiscoveryTenantConfig', 'Set-CIPPEdiscoveryTenantConfig')) {
        . (Join-Path $RepoRoot "Modules/CIPPCore/Public/Ediscovery/$Name.ps1")
    }
}

Describe 'Set-CIPPEdiscoveryTenantConfig' {
    It 'stores appId and certificate secret name only' {
        $Table = @{ mock = $true }
        Mock Get-CIPPTable { $Table }
        $Stored = $null
        Mock Add-CIPPAzDataTableEntity { param($Entity) $script:Stored = $Entity }
        Mock Get-CIPPEdiscoveryTenantConfig {
            [pscustomobject]@{
                TenantFilter = 'contoso.onmicrosoft.com'
                AppId = '11111111-1111-1111-1111-111111111111'
                CertificateSecretName = 'ediscovery-contoso-cert'
                CertificatePasswordSecretName = ''
                Enabled = $true
                Notes = ''
            }
        }
        $Result = Set-CIPPEdiscoveryTenantConfig -TenantFilter 'contoso.onmicrosoft.com' `
            -AppId '11111111-1111-1111-1111-111111111111' -CertificateSecretName 'ediscovery-contoso-cert'
        $Result.AppId | Should -Be '11111111-1111-1111-1111-111111111111'
        $Result.CertificateSecretName | Should -Be 'ediscovery-contoso-cert'
    }
    It 'refuses SAM application id' {
        $env:ApplicationID = '22222222-2222-2222-2222-222222222222'
        { Set-CIPPEdiscoveryTenantConfig -TenantFilter 'contoso.onmicrosoft.com' `
            -AppId '22222222-2222-2222-2222-222222222222' -CertificateSecretName 'x' } | Should -Throw '*SAM*'
        $env:ApplicationID = $null
    }
    It 'refuses non-GUID appId and empty cert name' {
        { Set-CIPPEdiscoveryTenantConfig -TenantFilter 'contoso.onmicrosoft.com' -AppId 'not-a-guid' -CertificateSecretName 'x' } | Should -Throw '*GUID*'
        { Set-CIPPEdiscoveryTenantConfig -TenantFilter 'contoso.onmicrosoft.com' -AppId '11111111-1111-1111-1111-111111111111' -CertificateSecretName '' } | Should -Throw '*certificate*'
    }
}

Describe 'Get-CIPPEdiscoveryTenantConfig' {
    It 'returns null when no row exists' {
        $Table = @{ mock = $true }
        Mock Get-CIPPAzDataTableEntity { @() }
        Get-CIPPEdiscoveryTenantConfig -TenantFilter 'missing.onmicrosoft.com' -Table $Table | Should -BeNullOrEmpty
    }
    It 'maps table entity fields' {
        $Table = @{ mock = $true }
        Mock Get-CIPPAzDataTableEntity {
            [pscustomobject]@{
                PartitionKey = 'contoso.onmicrosoft.com'
                RowKey = 'config'
                AppId = '11111111-1111-1111-1111-111111111111'
                CertificateSecretName = 'ediscovery-contoso-cert'
                CertificatePasswordSecretName = 'ediscovery-contoso-cert-pw'
                Enabled = $true
                Notes = 'test'
            }
        }
        $Result = Get-CIPPEdiscoveryTenantConfig -TenantFilter 'contoso.onmicrosoft.com' -Table $Table
        $Result.TenantFilter | Should -Be 'contoso.onmicrosoft.com'
        $Result.AppId | Should -Be '11111111-1111-1111-1111-111111111111'
        $Result.CertificateSecretName | Should -Be 'ediscovery-contoso-cert'
        $Result.Enabled | Should -BeTrue
    }
}
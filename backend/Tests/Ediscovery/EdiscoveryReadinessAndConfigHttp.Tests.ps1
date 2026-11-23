BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))

    enum HttpStatusCode {
        OK = 200
        BadRequest = 400
        Forbidden = 403
        InternalServerError = 500
    }
    class HttpResponseContext {
        [object]$StatusCode
        [object]$Headers
        [object]$Body
        [object]$ContentType
    }

    function Get-CIPPEdiscoveryTenantConfig { param($TenantFilter) }
    function Set-CIPPEdiscoveryTenantConfig { param($TenantFilter, $AppId, $CertificateSecretName, $CertificatePasswordSecretName, $Enabled, $Notes) }
    function Get-CIPPEdiscoveryAccessToken { param($TenantFilter, $Config) }
    function Invoke-CIPPEdiscoveryRequest { param($AccessToken, $Method, $Path, $Classification, $Transport) }
    function Test-CIPPGuardedWriteRequest { param($Request, [switch]$IsWrite, [switch]$DefaultDryRun) }
    function Add-CIPPGuardedWriteAudit { param($Endpoint, $Tenant, $Ticket, $Caller, $Request, $Before, $After, [bool]$DryRun, $Result) }
    function Write-LogMessage { param($headers, $API, $tenant, $message, $Sev, $LogData) }
    function Get-CippException { param($Exception) [pscustomobject]@{ NormalizedError = $Exception.Exception.Message } }

    foreach ($Path in @(
            'Modules/CIPPCore/Public/Ediscovery/Get-CIPPEdiscoveryReadiness.ps1',
            'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Security/Invoke-ListEdiscoveryConfig.ps1',
            'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Security/Invoke-ExecEdiscoveryConfig.ps1',
            'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Security/Invoke-ListEdiscoveryReadiness.ps1'
        )) {
        $FullPath = Join-Path $RepoRoot $Path
        if (Test-Path -LiteralPath $FullPath) { . $FullPath }
    }
}

Describe 'Get-CIPPEdiscoveryReadiness' {
    It 'reports MissingConfig with setup remediation when no config exists' {
        Mock Get-CIPPEdiscoveryTenantConfig { $null }

        $Result = Get-CIPPEdiscoveryReadiness -TenantFilter 'contoso.onmicrosoft.com'

        $Result.ConfigPresent | Should -BeFalse
        $Result.Status | Should -Be 'MissingConfig'
        $Result.Remediation -join ' ' | Should -Match 'eDiscovery.ReadWrite.All'
        $Result.Remediation -join ' ' | Should -Match 'eDiscoveryManager'
    }

    It 'reports Disabled without attempting token acquisition' {
        Mock Get-CIPPEdiscoveryTenantConfig {
            [pscustomobject]@{ Enabled = $false; AppId = '11111111-1111-1111-1111-111111111111'; CertificateSecretName = 'ediscovery-contoso-cert' }
        }
        Mock Get-CIPPEdiscoveryAccessToken { throw 'should not request token' }

        $Result = Get-CIPPEdiscoveryReadiness -TenantFilter 'contoso.onmicrosoft.com'

        $Result.ConfigPresent | Should -BeTrue
        $Result.Enabled | Should -BeFalse
        $Result.TokenOk | Should -BeFalse
        $Result.Status | Should -Be 'Disabled'
    }

    It 'reports Ready when token acquisition and cases list succeed' {
        Mock Get-CIPPEdiscoveryTenantConfig {
            [pscustomobject]@{ Enabled = $true; AppId = '11111111-1111-1111-1111-111111111111'; CertificateSecretName = 'ediscovery-contoso-cert' }
        }
        Mock Get-CIPPEdiscoveryAccessToken { [pscustomobject]@{ AccessToken = 'tok' } }
        Mock Invoke-CIPPEdiscoveryRequest {
            param($AccessToken, $Method, $Path, $Classification)
            $AccessToken | Should -Be 'tok'
            $Method | Should -Be 'GET'
            $Path | Should -Be '/v1.0/security/cases/ediscoveryCases'
            $Classification | Should -Be 'read'
            [pscustomobject]@{ Results = @() }
        }

        $Result = Get-CIPPEdiscoveryReadiness -TenantFilter 'contoso.onmicrosoft.com'

        $Result.TokenOk | Should -BeTrue
        $Result.CasesListOk | Should -BeTrue
        $Result.Status | Should -Be 'Ready'
    }

    It 'reports Forbidden when cases list returns a 403' {
        Mock Get-CIPPEdiscoveryTenantConfig {
            [pscustomobject]@{ Enabled = $true; AppId = '11111111-1111-1111-1111-111111111111'; CertificateSecretName = 'ediscovery-contoso-cert' }
        }
        Mock Get-CIPPEdiscoveryAccessToken { [pscustomobject]@{ AccessToken = 'tok' } }
        Mock Invoke-CIPPEdiscoveryRequest { throw 'Graph 403 Forbidden' }

        $Result = Get-CIPPEdiscoveryReadiness -TenantFilter 'contoso.onmicrosoft.com'

        $Result.TokenOk | Should -BeTrue
        $Result.CasesListOk | Should -BeFalse
        $Result.Status | Should -Be 'Forbidden'
    }
}

Describe 'Invoke-ExecEdiscoveryConfig' {
    It 'defaults dryRun true and does not call Set when dryRun' {
        Mock Test-CIPPGuardedWriteRequest {
            [pscustomobject]@{ Ok = $true; Tenant = 'contoso.onmicrosoft.com'; Ticket = '1234567'; WhatIf = $true; Reason = 'setup'; Caller = 'test' }
        }
        Mock Set-CIPPEdiscoveryTenantConfig { throw 'should not set' }
        $script:CapturedAuditRequest = $null
        Mock Add-CIPPGuardedWriteAudit {
            $script:CapturedAuditRequest = $Request
            'audit-1'
        }

        $Response = Invoke-ExecEdiscoveryConfig -Request @{
            Body = @{
                tenantFilter           = 'contoso.onmicrosoft.com'
                ticketNumber           = '1234567'
                reason                 = 'setup'
                appId                  = '11111111-1111-1111-1111-111111111111'
                certificateSecretName  = 'ediscovery-contoso-cert'
            }
            Headers = @{}
            Params = @{ CIPPEndpoint = 'ExecEdiscoveryConfig' }
        }

        $Response.StatusCode | Should -Be ([HttpStatusCode]::OK)
        $Response.Body.Status | Should -Be 'DryRun'
        $Response.Body.WhatIfPlan[0].TenantFilter | Should -Be 'contoso.onmicrosoft.com'
        $script:CapturedAuditRequest.PSObject.Properties.Name | Should -Contain 'CertificateSecretNamePresent'
        $script:CapturedAuditRequest.PSObject.Properties.Name | Should -Not -Contain 'certificatePasswordSecretName'
        ($script:CapturedAuditRequest | ConvertTo-Json -Depth 5) | Should -Not -Match 'ediscovery-contoso-cert'
    }

    It 'validates appId before returning dryRun plan' {
        Mock Test-CIPPGuardedWriteRequest {
            [pscustomobject]@{ Ok = $true; Tenant = 'contoso.onmicrosoft.com'; Ticket = '1234567'; WhatIf = $true; Reason = 'setup'; Caller = 'test' }
        }
        Mock Add-CIPPGuardedWriteAudit { throw 'must not audit invalid config' }

        $Response = Invoke-ExecEdiscoveryConfig -Request @{
            Body = @{
                tenantFilter          = 'contoso.onmicrosoft.com'
                ticketNumber          = '1234567'
                reason                = 'setup'
                appId                 = 'not-a-guid'
                certificateSecretName = 'ediscovery-contoso-cert'
            }
            Headers = @{}
            Params = @{ CIPPEndpoint = 'ExecEdiscoveryConfig' }
        }

        $Response.StatusCode | Should -Be ([HttpStatusCode]::BadRequest)
        $Response.Body.Results | Should -Match 'GUID'
    }

    It 'parses enabled string false as boolean false' {
        Mock Test-CIPPGuardedWriteRequest {
            [pscustomobject]@{ Ok = $true; Tenant = 'contoso.onmicrosoft.com'; Ticket = '1234567'; WhatIf = $true; Reason = 'setup'; Caller = 'test' }
        }
        Mock Add-CIPPGuardedWriteAudit { 'audit-1' }

        $Response = Invoke-ExecEdiscoveryConfig -Request @{
            Body = @{
                tenantFilter          = 'contoso.onmicrosoft.com'
                ticketNumber          = '1234567'
                reason                = 'setup'
                appId                 = '11111111-1111-1111-1111-111111111111'
                certificateSecretName = 'ediscovery-contoso-cert'
                enabled               = 'false'
            }
            Headers = @{}
            Params = @{ CIPPEndpoint = 'ExecEdiscoveryConfig' }
        }

        $Response.StatusCode | Should -Be ([HttpStatusCode]::OK)
        $Response.Body.WhatIfPlan[0].Enabled | Should -BeFalse
    }

    It 'requires a non-empty reason' {
        Mock Test-CIPPGuardedWriteRequest {
            [pscustomobject]@{ Ok = $true; Tenant = 'contoso.onmicrosoft.com'; Ticket = '1234567'; WhatIf = $false; Reason = ''; Caller = 'test' }
        }

        $Response = Invoke-ExecEdiscoveryConfig -Request @{
            Body = @{
                tenantFilter          = 'contoso.onmicrosoft.com'
                ticketNumber          = '1234567'
                appId                 = '11111111-1111-1111-1111-111111111111'
                certificateSecretName = 'ediscovery-contoso-cert'
            }
            Headers = @{}
            Params = @{ CIPPEndpoint = 'ExecEdiscoveryConfig' }
        }

        $Response.StatusCode | Should -Be ([HttpStatusCode]::BadRequest)
        $Response.Body.Results | Should -Match 'reason'
    }

    It 'refuses PFX material in body' {
        Mock Test-CIPPGuardedWriteRequest {
            [pscustomobject]@{ Ok = $true; Tenant = 'contoso.onmicrosoft.com'; Ticket = '1234567'; WhatIf = $false; Reason = 'setup'; Caller = 'test' }
        }

        $Response = Invoke-ExecEdiscoveryConfig -Request @{
            Body = @{
                tenantFilter          = 'contoso.onmicrosoft.com'
                ticketNumber          = '1234567'
                reason                = 'setup'
                appId                 = '11111111-1111-1111-1111-111111111111'
                certificateSecretName = 'x'
                pfx                   = 'AAAABBBB'
            }
            Headers = @{}
            Params = @{ CIPPEndpoint = 'ExecEdiscoveryConfig' }
        }

        $Response.StatusCode | Should -Be ([HttpStatusCode]::BadRequest)
        $Response.Body.Results | Should -Match 'pfx'
    }

    It 'refuses nested forbidden credential keys in body' {
        $Response = Invoke-ExecEdiscoveryConfig -Request @{
            Body = @{
                tenantFilter          = 'contoso.onmicrosoft.com'
                ticketNumber          = '1234567'
                reason                = 'setup'
                appId                 = '11111111-1111-1111-1111-111111111111'
                certificateSecretName = 'ediscovery-contoso-cert'
                extras                = @{ clientSecret = 'shh' }
            }
            Headers = @{}
            Params = @{ CIPPEndpoint = 'ExecEdiscoveryConfig' }
        }

        $Response.StatusCode | Should -Be ([HttpStatusCode]::BadRequest)
        $Response.Body.Results | Should -Match 'clientSecret'
    }

    It 'refuses certificate data keys in body' {
        $Response = Invoke-ExecEdiscoveryConfig -Request @{
            Body = @{
                tenantFilter          = 'contoso.onmicrosoft.com'
                ticketNumber          = '1234567'
                reason                = 'setup'
                appId                 = '11111111-1111-1111-1111-111111111111'
                certificateSecretName = 'ediscovery-contoso-cert'
                certData              = 'AAAA'
            }
            Headers = @{}
            Params = @{ CIPPEndpoint = 'ExecEdiscoveryConfig' }
        }

        $Response.StatusCode | Should -Be ([HttpStatusCode]::BadRequest)
        $Response.Body.Results | Should -Match 'certData'
    }

    It 'refuses credential-looking certificateSecretName before dryRun audit' {
        Mock Test-CIPPGuardedWriteRequest {
            [pscustomobject]@{ Ok = $true; Tenant = 'contoso.onmicrosoft.com'; Ticket = '1234567'; WhatIf = $true; Reason = 'setup'; Caller = 'test' }
        }
        Mock Add-CIPPGuardedWriteAudit { throw 'must not audit credential material' }

        $Response = Invoke-ExecEdiscoveryConfig -Request @{
            Body = @{
                tenantFilter          = 'contoso.onmicrosoft.com'
                ticketNumber          = '1234567'
                reason                = 'setup'
                appId                 = '11111111-1111-1111-1111-111111111111'
                certificateSecretName = '-----BEGIN CERTIFICATE-----'
            }
            Headers = @{}
            Params = @{ CIPPEndpoint = 'ExecEdiscoveryConfig' }
        }

        $Response.StatusCode | Should -Be ([HttpStatusCode]::BadRequest)
        $Response.Body.Results | Should -Match 'Key Vault secret name'
    }

    It 'upserts config and audits a live request' {
        Mock Test-CIPPGuardedWriteRequest {
            [pscustomobject]@{ Ok = $true; Tenant = 'contoso.onmicrosoft.com'; Ticket = '1234567'; WhatIf = $false; Reason = 'setup'; Caller = 'test' }
        }
        Mock Set-CIPPEdiscoveryTenantConfig {
            [pscustomobject]@{
                TenantFilter                  = $TenantFilter
                AppId                         = $AppId
                CertificateSecretName         = $CertificateSecretName
                CertificatePasswordSecretName = $CertificatePasswordSecretName
                Enabled                       = $Enabled
                Notes                         = $Notes
            }
        }
        Mock Add-CIPPGuardedWriteAudit { 'audit-2' }

        $Response = Invoke-ExecEdiscoveryConfig -Request @{
            Body = @{
                tenantFilter                  = 'contoso.onmicrosoft.com'
                ticketNumber                  = '1234567'
                reason                        = 'setup'
                appId                         = '11111111-1111-1111-1111-111111111111'
                certificateSecretName         = 'ediscovery-contoso-cert'
                certificatePasswordSecretName = 'ediscovery-contoso-cert-password'
                enabled                       = $true
                notes                         = 'synthetic test'
                dryRun                        = $false
            }
            Headers = @{}
            Params = @{ CIPPEndpoint = 'ExecEdiscoveryConfig' }
        }

        $Response.StatusCode | Should -Be ([HttpStatusCode]::OK)
        $Response.Body.Status | Should -Be 'Success'
        $Response.Body.AuditId | Should -Be 'audit-2'
        $Response.Body.Results.CertificateSecretName | Should -Be 'ediscovery-contoso-cert'
    }
}

Describe 'Invoke-ListEdiscoveryConfig' {
    It 'returns sanitized config without password secret name' {
        Mock Get-CIPPEdiscoveryTenantConfig {
            [pscustomobject]@{
                TenantFilter                  = 'contoso.onmicrosoft.com'
                AppId                         = '11111111-1111-1111-1111-111111111111'
                CertificateSecretName         = 'ediscovery-contoso-cert'
                CertificatePasswordSecretName = 'ediscovery-contoso-cert-password'
                Enabled                       = $true
                Notes                         = 'synthetic test'
            }
        }

        $Response = Invoke-ListEdiscoveryConfig -Request @{
            Query = @{ tenantFilter = 'contoso.onmicrosoft.com' }
            Headers = @{}
            Params = @{ CIPPEndpoint = 'ListEdiscoveryConfig' }
        }

        $Response.StatusCode | Should -Be ([HttpStatusCode]::OK)
        $Response.Body.Results.CertificateSecretName | Should -Be 'ediscovery-contoso-cert'
        $Response.Body.Results.PSObject.Properties.Name | Should -Not -Contain 'CertificatePasswordSecretName'
        ($Response.Body | ConvertTo-Json -Depth 5) | Should -Not -Match 'ediscovery-contoso-cert-password'
    }
}

Describe 'Invoke-ListEdiscoveryReadiness' {
    It 'returns readiness for requested tenant' {
        Mock Get-CIPPEdiscoveryReadiness {
            [pscustomobject]@{ ConfigPresent = $true; Enabled = $true; TokenOk = $true; CasesListOk = $true; Status = 'Ready'; Remediation = @() }
        }

        $Response = Invoke-ListEdiscoveryReadiness -Request @{
            Query = @{ tenantFilter = 'contoso.onmicrosoft.com' }
            Headers = @{}
            Params = @{ CIPPEndpoint = 'ListEdiscoveryReadiness' }
        }

        $Response.StatusCode | Should -Be ([HttpStatusCode]::OK)
        $Response.Body.Results.Status | Should -Be 'Ready'
    }
}

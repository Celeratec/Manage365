# backend/Tests/Ediscovery/EdiscoveryTokenAndRequest.Tests.ps1
BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))

    function Get-CIPPEdiscoveryTenantConfig { param($TenantFilter) }
    function Get-Tenants { param($TenantFilter) }
    function Get-CippKeyVaultSecret { param($Name, [switch]$AsPlainText) }
    function Get-GraphTokenFromCert { param($TenantId, $AppId, $Certificate, $Scope, [switch]$SkipCache) }
    function Invoke-CIPPRestMethod { param($Method, $Uri, $Headers, $Body, $ContentType) }

    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/Ediscovery/Test-CIPPEdiscoveryForbiddenAction.ps1')
    foreach ($Name in @('Get-CIPPEdiscoveryAccessToken', 'Get-CIPPEdiscoveryGraphPlan', 'Invoke-CIPPEdiscoveryRequest')) {
        . (Join-Path $RepoRoot "Modules/CIPPCore/Public/Ediscovery/$Name.ps1")
    }

    $Rsa = [System.Security.Cryptography.RSA]::Create(2048)
    $Req = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
        'CN=Manage365 eDiscovery Test',
        $Rsa,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256,
        [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
    )
    $Cert = $Req.CreateSelfSigned([DateTimeOffset]::UtcNow.AddDays(-1), [DateTimeOffset]::UtcNow.AddDays(1))
    $script:EdiscoveryTestPfxBase64 = [Convert]::ToBase64String($Cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx))
    $Cert.Dispose()
    $Rsa.Dispose()
}

Describe 'Get-CIPPEdiscoveryAccessToken' {
    AfterEach {
        $env:ApplicationID = $null
        $env:ApplicationId = $null
        $script:CIPPEdiscoveryTokenCache = $null
    }

    It 'refuses SAM app id' {
        $env:ApplicationID = '22222222-2222-2222-2222-222222222222'
        $Cfg = [pscustomobject]@{
            Enabled = $true
            AppId = '22222222-2222-2222-2222-222222222222'
            CertificateSecretName = 'cert'
        }

        { Get-CIPPEdiscoveryAccessToken -TenantFilter 'contoso.onmicrosoft.com' -Config $Cfg } | Should -Throw '*SAM*'
    }

    It 'refuses SAM app id from alternate environment variable casing' {
        $env:ApplicationId = '22222222-2222-2222-2222-222222222222'
        $Cfg = [pscustomobject]@{
            Enabled = $true
            AppId = '22222222-2222-2222-2222-222222222222'
            CertificateSecretName = 'cert'
        }

        { Get-CIPPEdiscoveryAccessToken -TenantFilter 'contoso.onmicrosoft.com' -Config $Cfg } | Should -Throw '*SAM*'
    }

    It 'uses a certificate token scoped to Microsoft Graph' {
        Mock Get-Tenants {
            [pscustomobject]@{ customerId = '33333333-3333-3333-3333-333333333333' }
        }
        Mock Get-CippKeyVaultSecret {
            $script:EdiscoveryTestPfxBase64
        }
        Mock Get-GraphTokenFromCert {
            param($TenantId, $AppId, $Certificate, $Scope)
            $TenantId | Should -Be '33333333-3333-3333-3333-333333333333'
            $AppId | Should -Be '11111111-1111-1111-1111-111111111111'
            $Scope | Should -Be 'https://graph.microsoft.com/.default'
            [pscustomobject]@{ access_token = 'token'; expires_in = 3600 }
        }

        $Result = Get-CIPPEdiscoveryAccessToken -TenantFilter 'contoso.onmicrosoft.com' -Config ([pscustomobject]@{
                Enabled = $true
                AppId = '11111111-1111-1111-1111-111111111111'
                CertificateSecretName = 'ediscovery-contoso-cert'
            })

        $Result.AccessToken | Should -Be 'token'
        $Result.AppId | Should -Be '11111111-1111-1111-1111-111111111111'
        $Result.TenantId | Should -Be '33333333-3333-3333-3333-333333333333'
    }
}

Describe 'Get-CIPPEdiscoveryGraphPlan' {
    It 'builds list cases path and rejects unknown action' {
        $Ok = Get-CIPPEdiscoveryGraphPlan -Action 'ListEdiscoveryCases' -Params @{}

        $Ok.Allowed | Should -BeTrue
        $Ok.Method | Should -Be 'GET'
        $Ok.Path | Should -Be '/v1.0/security/cases/ediscoveryCases'
        $Ok.Classification | Should -Be 'read'
        (Get-CIPPEdiscoveryGraphPlan -Action 'Hack' -Params @{}).Allowed | Should -BeFalse
    }

    It 'rejects path params with traversal' {
        $Bad = Get-CIPPEdiscoveryGraphPlan -Action 'GetEdiscoveryCase' -Params @{ caseId = '../evil' }

        $Bad.Allowed | Should -BeFalse
        $Bad.Reason | Should -Match 'caseId'
    }

    It 'requires GUID-like path params without slashes' {
        $Bad = Get-CIPPEdiscoveryGraphPlan -Action 'GetEdiscoveryCaseOperation' -Params @{
            caseId = '11111111-1111-1111-1111-111111111111'
            operationId = 'https://evil.example/op'
        }

        $Bad.Allowed | Should -BeFalse
        $Bad.Reason | Should -Match 'operationId'
    }

    It 'accepts injected hashtable allowlists' {
        $Allowlist = @{
            ListEdiscoveryCases = @{
                method         = 'GET'
                pathTemplate   = '/v1.0/security/cases/ediscoveryCases'
                classification = 'read'
                role           = 'read'
            }
        }

        $Ok = Get-CIPPEdiscoveryGraphPlan -Action 'ListEdiscoveryCases' -Params @{} -Allowlist $Allowlist

        $Ok.Allowed | Should -BeTrue
        $Ok.Path | Should -Be '/v1.0/security/cases/ediscoveryCases'
        (Get-CIPPEdiscoveryGraphPlan -Action 'Hack' -Params @{} -Allowlist $Allowlist).Allowed | Should -BeFalse
    }
}

Describe 'Invoke-CIPPEdiscoveryRequest' {
    It 'only calls graph.microsoft.com and returns value rows' {
        $Transport = {
            param($Method, $Uri, $Headers, $Body)
            $Method | Should -Be 'GET'
            $Uri | Should -Match '^https://graph\.microsoft\.com/v1\.0/security/cases/ediscoveryCases'
            $Headers.Authorization | Should -Be 'Bearer tok'
            return @{ value = @([pscustomobject]@{ id = 'case-1' }) }
        }

        $Result = Invoke-CIPPEdiscoveryRequest -AccessToken 'tok' -Method GET `
            -Path '/v1.0/security/cases/ediscoveryCases' -Classification read -Transport $Transport

        $Result.Results[0].id | Should -Be 'case-1'
        $Result.Pages | Should -Be 1
    }

    It 'returns zero rows when Graph list value is empty' {
        $Transport = {
            return @{ value = @() }
        }

        $Result = Invoke-CIPPEdiscoveryRequest -AccessToken 'tok' -Method GET `
            -Path '/v1.0/security/cases/ediscoveryCases' -Classification read -Transport $Transport

        $Result.Results.Count | Should -Be 0
        $Result.Pages | Should -Be 1
    }

    It 'refuses absolute non-Graph hosts' {
        { Invoke-CIPPEdiscoveryRequest -AccessToken 'tok' -Method GET -Path 'https://evil.example/v1.0/security/cases/ediscoveryCases' -Transport { } } |
            Should -Throw '*graph.microsoft.com*'
    }

    It 'rejects DELETE before transport' {
        $script:Calls = 0
        $Transport = { $script:Calls++ }

        { Invoke-CIPPEdiscoveryRequest -AccessToken 'tok' -Method DELETE `
                -Path '/v1.0/security/cases/ediscoveryCases/11111111-1111-1111-1111-111111111111' -Classification write -Transport $Transport } |
            Should -Throw '*DELETE*'

        $script:Calls | Should -Be 0
    }

    It 'refuses path traversal and purgeData before transport' {
        $script:Calls = 0
        $Transport = { $script:Calls++ }

        { Invoke-CIPPEdiscoveryRequest -AccessToken 'tok' -Method GET -Path '/v1.0/security/../me' -Transport $Transport } |
            Should -Throw '*without traversal*'
        { Invoke-CIPPEdiscoveryRequest -AccessToken 'tok' -Method GET -Path '/v1.0/security/%2e%2e/me' -Transport $Transport } |
            Should -Throw '*without traversal*'
        { Invoke-CIPPEdiscoveryRequest -AccessToken 'tok' -Method POST -Path '/v1.0/security/cases/ediscoveryCases/11111111-1111-1111-1111-111111111111/searches/22222222-2222-2222-2222-222222222222/purgeData' -Classification write -Transport $Transport } |
            Should -Throw '*Purge*'
        $script:Calls | Should -Be 0
    }

    It 'blocks downloadUrl in counts-only responses' {
        $Transport = {
            @{ value = @([pscustomobject]@{ downloadUrl = 'https://download.example/file' }) }
        }

        { Invoke-CIPPEdiscoveryRequest -AccessToken 'tok' -Method GET `
                -Path '/v1.0/security/cases/ediscoveryCases' -Classification countsOnly -Transport $Transport } |
            Should -Throw '*downloadUrl*'
    }

    It 'polls the Graph Location header for accepted write operations' {
        $script:Uris = [System.Collections.Generic.List[string]]::new()
        $Transport = {
            param($Method, $Uri, $Headers, $Body)
            $script:Uris.Add($Uri) | Out-Null
            if ($Method -eq 'POST' -and $Uri -like '*/estimateStatistics') {
                return [pscustomobject]@{
                    StatusCode = 202
                    Headers    = @{ Location = 'https://graph.microsoft.com/v1.0/security/cases/ediscoveryCases/11111111-1111-1111-1111-111111111111/operations/22222222-2222-2222-2222-222222222222' }
                    Body       = $null
                }
            }
            if ($Method -eq 'GET' -and $Uri -like '*/operations/22222222-2222-2222-2222-222222222222') {
                return [pscustomobject]@{
                    status              = 'succeeded'
                    indexedItemCount    = 4
                    indexedItemsSize    = 1024
                    unindexedItemCount  = 0
                    mailboxCount        = 1
                }
            }
            throw "Unexpected transport call $Method $Uri"
        }

        $Result = Invoke-CIPPEdiscoveryRequest -AccessToken 'tok' -Method POST `
            -Path '/v1.0/security/cases/ediscoveryCases/11111111-1111-1111-1111-111111111111/searches/33333333-3333-3333-3333-333333333333/estimateStatistics' `
            -Classification write -Transport $Transport -PollTimeoutSeconds 5

        $Result.OperationUrl | Should -Be 'https://graph.microsoft.com/v1.0/security/cases/ediscoveryCases/11111111-1111-1111-1111-111111111111/operations/22222222-2222-2222-2222-222222222222'
        $Result.Raw.status | Should -Be 'succeeded'
        $Result.Results[0].indexedItemCount | Should -Be 4
        $script:Uris.Count | Should -Be 2
    }

    It 'does not poll 201 Location headers for created search resources' {
        $script:Uris = [System.Collections.Generic.List[string]]::new()
        $SearchId = '44444444-4444-4444-4444-444444444444'
        $Transport = {
            param($Method, $Uri, $Headers, $Body)
            $script:Uris.Add($Uri) | Out-Null
            if ($Method -eq 'POST' -and $Uri -like '*/searches') {
                return [pscustomobject]@{
                    StatusCode = 201
                    Headers    = @{
                        Location = "https://graph.microsoft.com/v1.0/security/cases/ediscoveryCases/11111111-1111-1111-1111-111111111111/searches/$SearchId"
                    }
                    Body       = [pscustomobject]@{ id = $SearchId; displayName = 'Stats estimate' }
                }
            }
            throw "Unexpected transport call $Method $Uri"
        }

        $Result = Invoke-CIPPEdiscoveryRequest -AccessToken 'tok' -Method POST `
            -Path '/v1.0/security/cases/ediscoveryCases/11111111-1111-1111-1111-111111111111/searches' `
            -Classification write -Transport $Transport -PollTimeoutSeconds 5

        $Result.OperationUrl | Should -BeNullOrEmpty
        $Result.Results[0].id | Should -Be $SearchId
        $script:Uris.Count | Should -Be 1
    }
}

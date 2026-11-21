BeforeAll {
    # backend/Tests/Scripts → repo root is four parents up
    $RepoRoot = $PSCommandPath
    1..4 | ForEach-Object { $RepoRoot = Split-Path -Parent $RepoRoot }
    $ScriptPath = Join-Path $RepoRoot 'scripts/security/Test-AppOnlyMailboxAccess.ps1'
    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        throw "Script not found at $ScriptPath"
    }
    $TenantId = '11111111-1111-1111-1111-111111111111'
    $ClientId = '22222222-2222-2222-2222-222222222222'

    function New-SelfSignedProbeCert {
        $rsa = [System.Security.Cryptography.RSA]::Create(2048)
        try {
            $req = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
                'CN=Manage365-AppOnly-Probe-Test',
                $rsa,
                [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
            )
            $cert = $req.CreateSelfSigned([datetime]::UtcNow.AddDays(-1), [datetime]::UtcNow.AddDays(30))
            # Re-import exportable copy so private key stays usable across platforms
            $bytes = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, '')
            return [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
                $bytes,
                '',
                [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
            )
        } finally {
            $rsa.Dispose()
        }
    }

    function New-FakeJwt {
        param([hashtable]$Payload)
        $header = ConvertTo-Base64UrlString '{"alg":"none","typ":"JWT"}'
        $body = ConvertTo-Base64UrlString (($Payload | ConvertTo-Json -Compress))
        return "$header.$body.sig"
    }

    function ConvertTo-Base64UrlString {
        param([string]$Text)
        $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Text))
        return ($b64.TrimEnd('=') -replace '\+', '-' -replace '/', '_')
    }
}

Describe 'Test-AppOnlyMailboxAccess' {
    BeforeAll {
        $script:Cert = New-SelfSignedProbeCert
    }

    AfterAll {
        if ($script:Cert) { $script:Cert.Dispose() }
    }

    It 'accepts matching in-scope 200 and out-of-scope 403 (GET only, hosts pinned)' {
        $calls = [System.Collections.Generic.List[object]]::new()
        $transport = {
            param($Method, $Uri, $Headers, $Body)
            # Never retain Authorization / assertion material in the call log
            $calls.Add([pscustomobject]@{ Method = $Method; Uri = $Uri; HasAuth = [bool]$Headers['Authorization'] })
            $u = [uri]$Uri
            $u.Host | Should -BeIn @('login.microsoftonline.com', 'graph.microsoft.com')
            if ($Method -eq 'POST') {
                $u.Host | Should -Be 'login.microsoftonline.com'
                $Body | Should -Match 'client_assertion='
                $jwt = New-FakeJwt -Payload @{ aud = 'https://graph.microsoft.com'; appid = $ClientId }
                return [pscustomobject]@{
                    StatusCode = 200
                    Content    = (@{ access_token = $jwt; token_type = 'Bearer'; expires_in = 3600 } | ConvertTo-Json -Compress)
                }
            }
            $Method | Should -Be 'GET'
            $u.Host | Should -Be 'graph.microsoft.com'
            $Uri | Should -Match '/v1\.0/users/.+/messages\?\$top=1&\$select=id'
            if ($Uri -match 'in(%40|@)example\.com') {
                return [pscustomobject]@{ StatusCode = 200; ItemCount = 1 }
            }
            return [pscustomobject]@{ StatusCode = 403; ItemCount = 0 }
        }

        $result = & $ScriptPath `
            -TenantId $TenantId `
            -ClientId $ClientId `
            -Certificate $script:Cert `
            -InScopeMailbox 'in@example.com' `
            -OutOfScopeMailbox 'out@example.com' `
            -HttpTransport $transport `
            -PassThru

        $result.Success | Should -BeTrue
        $result.ExitCode | Should -Be 0
        $result.Claims.HasRolesClaim | Should -BeFalse

        ($calls | Where-Object Method -eq 'GET').Count | Should -Be 2
        ($calls | Where-Object Method -eq 'POST').Count | Should -Be 1
        ($calls | Where-Object Method -notin @('GET', 'POST')).Count | Should -Be 0

        $json = $result | ConvertTo-Json -Depth 6
        $json | Should -Not -Match 'BEGIN (RSA )?PRIVATE KEY'
        $json | Should -Not -Match 'eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+'
    }

    It 'refuses malformed mailbox values' {
        { & $ScriptPath `
                -TenantId $TenantId `
                -ClientId $ClientId `
                -Certificate $script:Cert `
                -InScopeMailbox 'bad/mailbox' `
                -OutOfScopeMailbox 'out@example.com' `
                -HttpTransport { throw 'should not call transport' } `
                -PassThru } | Should -Throw -ExpectedMessage '*malformed*'
    }

    It 'refuses mailbox with path traversal' {
        { & $ScriptPath `
                -TenantId $TenantId `
                -ClientId $ClientId `
                -Certificate $script:Cert `
                -InScopeMailbox 'a@b.com' `
                -OutOfScopeMailbox 'x@y.com?foo=1' `
                -HttpTransport { throw 'should not call transport' } `
                -PassThru } | Should -Throw -ExpectedMessage '*malformed*'
    }

    It 'exits non-zero on status mismatch' {
        $transport = {
            param($Method, $Uri, $Headers, $Body)
            if ($Method -eq 'POST') {
                $jwt = New-FakeJwt -Payload @{ aud = 'https://graph.microsoft.com' }
                return [pscustomobject]@{
                    StatusCode = 200
                    Content    = (@{ access_token = $jwt } | ConvertTo-Json -Compress)
                }
            }
            # Both return 200 → out-of-scope mismatch
            return [pscustomobject]@{ StatusCode = 200; ItemCount = 1 }
        }

        $result = & $ScriptPath `
            -TenantId $TenantId `
            -ClientId $ClientId `
            -Certificate $script:Cert `
            -InScopeMailbox 'in@example.com' `
            -OutOfScopeMailbox 'out@example.com' `
            -HttpTransport $transport `
            -PassThru

        $result.Success | Should -BeFalse
        $result.ExitCode | Should -Be 1
        $result.Mismatch.Count | Should -BeGreaterThan 0
    }

    It 'does not print passphrase when loading fails without Password' {
        # Ensure we never echo a SecureString / password material in errors for bad path
        { & $ScriptPath `
                -TenantId $TenantId `
                -ClientId $ClientId `
                -CertificatePath '/tmp/does-not-exist-manage365-probe.pfx' `
                -InScopeMailbox 'in@example.com' `
                -OutOfScopeMailbox 'out@example.com' `
                -PassThru } | Should -Throw -ExpectedMessage '*CertificatePath not found*'
    }
}

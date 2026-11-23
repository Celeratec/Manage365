BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))

    enum HttpStatusCode {
        OK = 200
        BadRequest = 400
        Conflict = 409
        TooManyRequests = 429
        InternalServerError = 500
    }
    class HttpResponseContext {
        [object]$StatusCode
        [object]$Headers
        [object]$Body
        [object]$ContentType
    }

    function Test-CIPPGuardedWriteRequest { param($Request, [switch]$IsWrite, [switch]$DefaultDryRun) }
    function Add-CIPPGuardedWriteAudit { param($Endpoint, $Tenant, $Ticket, $Caller, $Request, $Before, $After, [bool]$DryRun, $Result) }
    function Get-CIPPEdiscoveryAccessToken { param($TenantFilter) }
    function Invoke-CIPPEdiscoveryRequest { param($AccessToken, $Method, $Path, $Body, $Classification, $PollTimeoutSeconds) }
    function Write-LogMessage { param($headers, $API, $tenant, $message, $Sev, $LogData) }
    function Get-CippException { param($Exception) [pscustomobject]@{ NormalizedError = $Exception.Exception.Message } }

    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/Ediscovery/ConvertTo-CIPPEdiscoveryCountsOnly.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/Ediscovery/New-CIPPEdiscoveryKql.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/Ediscovery/Get-CIPPEdiscoverySearchPlan.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/Ediscovery/Get-CIPPEdiscoveryGraphPlan.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/Ediscovery/Invoke-CIPPEdiscoverySearchAction.ps1')
}

Describe 'ConvertTo-CIPPEdiscoveryCountsOnly' {
    It 'strips content-like keys from nested fixture responses' {
        $Fixture = @{
            indexedItemCount = 10
            subject = 'Secret subject'
            downloadUrl = 'https://download.example/file'
            nested = @{
                sender = 'sender@contoso.example'
                preview = 'secret preview'
                snippet = 'secret snippet'
                fileName = 'secret.msg'
                content = 'secret content'
                recipient = 'recipient@contoso.example'
                body = 'secret body'
                safeCount = 2
            }
        }

        $Result = ConvertTo-CIPPEdiscoveryCountsOnly -Value $Fixture
        $Json = $Result | ConvertTo-Json -Depth 8

        $Result.indexedItemCount | Should -Be 10
        $Result.nested.safeCount | Should -Be 2
        $Json | Should -Not -Match 'Secret subject|download\.example|sender@contoso|secret preview|secret snippet|secret\.msg|secret content|recipient@contoso|secret body'
    }
}

Describe 'Invoke-CIPPEdiscoverySearchAction' {
    BeforeEach {
        $script:TransportCalls = 0
        $script:CapturedAuditRequest = $null
        $script:CapturedAuditAfter = $null
        $script:GraphCalls = [System.Collections.Generic.List[object]]::new()

        Mock Test-CIPPGuardedWriteRequest {
            [pscustomobject]@{
                Ok = $true
                Tenant = 'contoso.onmicrosoft.com'
                Ticket = '1234567'
                WhatIf = $true
                Reason = 'synthetic test'
                Caller = 'test'
            }
        }
        Mock Add-CIPPGuardedWriteAudit {
            $script:CapturedAuditRequest = $Request
            $script:CapturedAuditAfter = $After
            'audit-1'
        }
        Mock Get-CIPPEdiscoveryAccessToken { [pscustomobject]@{ AccessToken = 'tok' } }
        Mock Invoke-CIPPEdiscoveryRequest { $script:TransportCalls++; throw 'should not call Graph' }
        Mock Write-LogMessage {}
    }

    It 'defaults to dryRun, returns a plan, and makes no Graph calls' {
        $Response = Invoke-CIPPEdiscoverySearchAction -Request @{
            Body = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                ticketNumber = '1234567'
                reason = 'synthetic test'
                caseLabel = 'Example Matter 2026-001'
                custodianUpn = 'custodian@contoso.example'
                terms = @('project falcon')
            }
            Headers = @{}
            Params = @{ CIPPEndpoint = 'ExecEdiscoverySearch' }
        }

        $Response.StatusCode | Should -Be ([HttpStatusCode]::OK)
        $Response.Body.Status | Should -Be 'DryRun'
        $Response.Body.AuditId | Should -Be 'audit-1'
        $Response.Body.After.Terms | Should -Be @('project falcon')
        $script:TransportCalls | Should -Be 0
        $script:CapturedAuditRequest.ticket | Should -Be '1234567'
        $script:CapturedAuditRequest.actor | Should -Be 'test'
        $script:CapturedAuditRequest.TermCount | Should -Be 1
        $script:CapturedAuditRequest.KqlHash | Should -Match '\A[a-f0-9]{64}\z'
        $script:CapturedAuditRequest.Status | Should -Be 'DryRun'
        foreach ($BlockedKey in @('Terms', 'Kql', 'contentQuery', 'DisplayName', 'Limits', 'CustodianUpn')) {
            $script:CapturedAuditRequest.PSObject.Properties.Name | Should -Not -Contain $BlockedKey
            $script:CapturedAuditAfter.PSObject.Properties.Name | Should -Not -Contain $BlockedKey
        }
        ($script:CapturedAuditRequest | ConvertTo-Json -Depth 8) | Should -Not -Match 'project falcon|custodian@contoso'
    }

    It 'returns 400 when reason is missing after guarded-write evaluation' {
        Mock Test-CIPPGuardedWriteRequest {
            [pscustomobject]@{
                Ok = $true
                Tenant = 'contoso.onmicrosoft.com'
                Ticket = '1234567'
                WhatIf = $true
                Reason = ''
                Caller = 'test'
            }
        }

        $Response = Invoke-CIPPEdiscoverySearchAction -Request @{
            Body = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                ticketNumber = '1234567'
                caseLabel = 'Example Matter 2026-001'
                custodianUpn = 'custodian@contoso.example'
                terms = @('project falcon')
            }
            Headers = @{}
            Params = @{ CIPPEndpoint = 'ExecEdiscoverySearch' }
        }

        $Response.StatusCode | Should -Be ([HttpStatusCode]::BadRequest)
        $Response.Body.Status | Should -Be 'Failed'
        $script:TransportCalls | Should -Be 0
    }

    It 'returns 400 for more than 25 terms without Graph calls' {
        $Response = Invoke-CIPPEdiscoverySearchAction -Request @{
            Body = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                ticketNumber = '1234567'
                reason = 'synthetic test'
                caseLabel = 'Example Matter 2026-001'
                custodianUpn = 'custodian@contoso.example'
                terms = 1..26 | ForEach-Object { "term$_" }
            }
            Headers = @{}
            Params = @{ CIPPEndpoint = 'ExecEdiscoverySearch' }
        }

        $Response.StatusCode | Should -Be ([HttpStatusCode]::BadRequest)
        $Response.Body.Results | Should -Match '1 to 25'
        $script:TransportCalls | Should -Be 0
    }

    It 'live-runs case, custodian, mailbox source, search, and one estimate per term' {
        Mock Test-CIPPGuardedWriteRequest {
            [pscustomobject]@{
                Ok = $true
                Tenant = 'contoso.onmicrosoft.com'
                Ticket = '1234567'
                WhatIf = $false
                Reason = 'synthetic test'
                Caller = 'test'
            }
        }
        Mock Invoke-CIPPEdiscoveryRequest {
            $script:TransportCalls++
            $script:GraphCalls.Add([pscustomobject]@{ Method = $Method; Path = $Path; Body = $Body; Classification = $Classification })

            if ($Method -eq 'GET' -and $Path -eq '/v1.0/security/cases/ediscoveryCases') {
                return [pscustomobject]@{ Results = @() }
            }
            if ($Path -eq '/v1.0/security/cases/ediscoveryCases') {
                return [pscustomobject]@{ Results = @([pscustomobject]@{ id = '11111111-1111-1111-1111-111111111111' }) }
            }
            if ($Path -like '*/custodians') {
                return [pscustomobject]@{ Results = @([pscustomobject]@{ id = '22222222-2222-2222-2222-222222222222' }) }
            }
            if ($Path -like '*/userSources') {
                return [pscustomobject]@{ Results = @([pscustomobject]@{ id = '33333333-3333-3333-3333-333333333333' }) }
            }
            if ($Path -like '*/searches' -and $Path -notlike '*/estimateStatistics') {
                return [pscustomobject]@{ Results = @([pscustomobject]@{ id = '44444444-4444-4444-4444-444444444444' }) }
            }
            if ($Path -like '*/estimateStatistics') {
                return [pscustomobject]@{
                    Raw = [pscustomobject]@{
                        status = 'succeeded'
                        indexedItemCount = 7
                        indexedItemsSize = 2048
                        mailboxCount = 1
                        unindexedItemCount = 0
                    }
                    Results = @([pscustomobject]@{
                            status = 'succeeded'
                            indexedItemCount = 7
                            indexedItemsSize = 2048
                            mailboxCount = 1
                            unindexedItemCount = 0
                        })
                }
            }
            throw "Unexpected Graph call $Method $Path"
        }

        $Response = Invoke-CIPPEdiscoverySearchAction -Request @{
            Body = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                ticketNumber = '1234567'
                reason = 'synthetic test'
                dryRun = $false
                caseLabel = 'Example Matter 2026-001'
                custodianUpn = 'custodian@contoso.example'
                terms = @('project falcon', 'alpha beta')
            }
            Headers = @{}
            Params = @{ CIPPEndpoint = 'ExecEdiscoverySearch' }
        }

        $Response.StatusCode | Should -Be ([HttpStatusCode]::OK)
        $Response.Body.Status | Should -Be 'Success'
        $Response.Body.Results.perTerm.Count | Should -Be 2
        $Response.Body.Results.perTerm[0].term | Should -Be 'project falcon'
        $Response.Body.Results.Note | Should -Match 'overlap'
        @($script:GraphCalls | Where-Object { $_.Path -like '*/estimateStatistics' }).Count | Should -Be 2
        $script:CapturedAuditRequest.ticket | Should -Be '1234567'
        $script:CapturedAuditRequest.actor | Should -Be 'test'
        $script:CapturedAuditRequest.TermCount | Should -Be 2
        $script:CapturedAuditRequest.KqlHash | Should -Match '\A[a-f0-9]{64}\z'
        $script:CapturedAuditRequest.Status | Should -Be 'Success'
        foreach ($BlockedKey in @('Terms', 'Kql', 'contentQuery', 'DisplayName', 'Limits', 'CustodianUpn', 'caseId', 'searchIds')) {
            $script:CapturedAuditRequest.PSObject.Properties.Name | Should -Not -Contain $BlockedKey
        }
        $script:CapturedAuditAfter.caseId | Should -Be '11111111-1111-1111-1111-111111111111'
        $script:CapturedAuditAfter.searchIds.Count | Should -Be 2
        foreach ($BlockedKey in @('Terms', 'Kql', 'contentQuery', 'DisplayName', 'Limits', 'CustodianUpn')) {
            $script:CapturedAuditAfter.PSObject.Properties.Name | Should -Not -Contain $BlockedKey
        }
        ($script:CapturedAuditRequest | ConvertTo-Json -Depth 8) | Should -Not -Match 'project falcon|alpha beta|custodian@contoso'
        ($script:CapturedAuditAfter | ConvertTo-Json -Depth 8) | Should -Not -Match 'project falcon|alpha beta|custodian@contoso'
    }
}

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $EntrypointRoot = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions'
    $RolePattern = [regex]::new('(?is)\.ROLE\s+([A-Za-z0-9.]+)')

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

    $EntrypointFile = Join-Path $EntrypointRoot 'Security/Invoke-ExecEdiscoverySearch.ps1'
    if (-not (Test-Path -LiteralPath $EntrypointFile)) { throw "Invoke-ExecEdiscoverySearch.ps1 not found at $EntrypointFile" }
    . $EntrypointFile

    $EntrypointText = [System.IO.File]::ReadAllText($EntrypointFile)
    $script:EntrypointRole = if ($RolePattern.Match($EntrypointText).Success) { $RolePattern.Match($EntrypointText).Groups[1].Value } else { $null }
}

Describe 'Invoke-ExecEdiscoverySearch entrypoint metadata' {
    It 'is marked Entrypoint with Security.Ediscovery.ReadWrite' {
        $EntrypointFile = Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))) 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Security/Invoke-ExecEdiscoverySearch.ps1'
        $Text = [System.IO.File]::ReadAllText($EntrypointFile)
        $Text | Should -Match '\.FUNCTIONALITY\s+.*\bEntrypoint\b'
        $script:EntrypointRole | Should -Be 'Security.Ediscovery.ReadWrite'
    }
}

Describe 'Invoke-ExecEdiscoverySearch HTTP envelope' {
    BeforeEach {
        $script:TransportCalls = 0
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
        Mock Add-CIPPGuardedWriteAudit { 'audit-entrypoint-1' }
        Mock Get-CIPPEdiscoveryAccessToken { [pscustomobject]@{ AccessToken = 'tok' } }
        Mock Invoke-CIPPEdiscoveryRequest { $script:TransportCalls++; throw 'should not call Graph' }
        Mock Write-LogMessage {}
    }

    It 'returns DryRun envelope through the HTTP entrypoint without Graph calls' {
        $Response = Invoke-ExecEdiscoverySearch -Request @{
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
        } -TriggerMetadata @{}

        $Response.StatusCode | Should -Be ([HttpStatusCode]::OK)
        $Response.Body.Status | Should -Be 'DryRun'
        $Response.Body.AuditId | Should -Be 'audit-entrypoint-1'
        $Response.Body.After.TermCount | Should -Be 1
        $Response.Body.Rollback | Should -Not -BeNullOrEmpty
        $script:TransportCalls | Should -Be 0
    }

    It 'returns guarded-write failure envelope without calling Graph' {
        Mock Test-CIPPGuardedWriteRequest {
            [pscustomobject]@{
                Ok = $false
                StatusCode = [HttpStatusCode]::BadRequest
                Message = 'ticketNumber is required.'
            }
        }

        $Response = Invoke-ExecEdiscoverySearch -Request @{
            Body = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                reason = 'synthetic test'
                caseLabel = 'Example Matter 2026-001'
                custodianUpn = 'custodian@contoso.example'
                terms = @('project falcon')
            }
            Headers = @{}
            Params = @{ CIPPEndpoint = 'ExecEdiscoverySearch' }
        } -TriggerMetadata @{}

        $Response.StatusCode | Should -Be ([HttpStatusCode]::BadRequest)
        $Response.Body.Status | Should -Be 'Failed'
        $Response.Body.Results | Should -Match 'ticketNumber'
        $script:TransportCalls | Should -Be 0
    }
}
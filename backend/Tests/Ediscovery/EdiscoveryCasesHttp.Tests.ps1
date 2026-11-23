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

    function Get-CIPPEdiscoveryAccessToken { param($TenantFilter) }
    function Invoke-CIPPEdiscoveryRequest { param($AccessToken, $Method, $Path, $Body, $Classification) }
    function Test-CIPPGuardedWriteRequest { param($Request, [switch]$IsWrite, [switch]$DefaultDryRun) }
    function Add-CIPPGuardedWriteAudit { param($Endpoint, $Tenant, $Ticket, $Caller, $Request, $Before, $After, [bool]$DryRun, $Result) }
    function Write-LogMessage { param($headers, $API, $tenant, $message, $Sev, $LogData) }
    function Get-CippException { param($Exception) [pscustomobject]@{ NormalizedError = $Exception.Exception.Message } }

    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/Ediscovery/Test-CIPPEdiscoveryForbiddenAction.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/Ediscovery/Get-CIPPEdiscoveryGraphPlan.ps1')
    foreach ($Name in @(
            'Invoke-ExecEdiscoveryCase',
            'Invoke-ExecEdiscoveryCaseHold',
            'Invoke-ExecEdiscoveryCaseSearch',
            'Invoke-ExecEdiscoveryCaseExport'
        )) {
        . (Join-Path $RepoRoot "Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Security/$Name.ps1")
    }
}

Describe 'eDiscovery Cases endpoint forbidden actions' {
    BeforeEach {
        $script:Calls = 0
        Mock Get-CIPPEdiscoveryAccessToken { [pscustomobject]@{ AccessToken = 'tok' } }
        Mock Invoke-CIPPEdiscoveryRequest { $script:Calls++; throw 'should not run' }
        Mock Test-CIPPGuardedWriteRequest {
            [pscustomobject]@{ Ok = $true; Tenant = 'contoso.onmicrosoft.com'; Ticket = '1234567'; WhatIf = $false; Reason = 'synthetic test'; Caller = 'test' }
        }
    }

    It 'ExecEdiscoveryCase delete does not call transport' {
        $Response = Invoke-ExecEdiscoveryCase -Request @{
            Body = @{ tenantFilter = 'contoso.onmicrosoft.com'; action = 'delete'; caseId = '11111111-1111-1111-1111-111111111111'; ticketNumber = '1234567'; reason = 'nope'; dryRun = $false }
            Headers = @{}
            Params = @{ CIPPEndpoint = 'ExecEdiscoveryCase' }
        }

        $Response.StatusCode | Should -Be ([HttpStatusCode]::BadRequest)
        $script:Calls | Should -Be 0
    }

    It 'ExecEdiscoveryCaseHold remove does not call transport' {
        $Response = Invoke-ExecEdiscoveryCaseHold -Request @{
            Body = @{ tenantFilter = 'contoso.onmicrosoft.com'; action = 'remove'; caseId = '11111111-1111-1111-1111-111111111111'; holdId = '22222222-2222-2222-2222-222222222222'; ticketNumber = '1234567'; reason = 'nope'; dryRun = $false }
            Headers = @{}
            Params = @{ CIPPEndpoint = 'ExecEdiscoveryCaseHold' }
        }

        $Response.StatusCode | Should -Be ([HttpStatusCode]::BadRequest)
        $script:Calls | Should -Be 0
    }

    It 'ExecEdiscoveryCaseSearch delete does not call transport' {
        $Response = Invoke-ExecEdiscoveryCaseSearch -Request @{
            Body = @{ tenantFilter = 'contoso.onmicrosoft.com'; action = 'delete'; caseId = '11111111-1111-1111-1111-111111111111'; searchId = '22222222-2222-2222-2222-222222222222'; ticketNumber = '1234567'; reason = 'nope'; dryRun = $false }
            Headers = @{}
            Params = @{ CIPPEndpoint = 'ExecEdiscoveryCaseSearch' }
        }

        $Response.StatusCode | Should -Be ([HttpStatusCode]::BadRequest)
        $script:Calls | Should -Be 0
    }

    It 'ExecEdiscoveryCaseSearch purge does not call transport' {
        $Response = Invoke-ExecEdiscoveryCaseSearch -Request @{
            Body = @{ tenantFilter = 'contoso.onmicrosoft.com'; action = 'purge'; caseId = '11111111-1111-1111-1111-111111111111'; searchId = '22222222-2222-2222-2222-222222222222'; ticketNumber = '1234567'; reason = 'nope'; dryRun = $false }
            Headers = @{}
            Params = @{ CIPPEndpoint = 'ExecEdiscoveryCaseSearch' }
        }

        $Response.StatusCode | Should -Be ([HttpStatusCode]::BadRequest)
        $script:Calls | Should -Be 0
    }

    It 'ExecEdiscoveryCaseExport refuses exports without transport' {
        $Response = Invoke-ExecEdiscoveryCaseExport -Request @{
            Body = @{ tenantFilter = 'contoso.onmicrosoft.com'; caseId = '11111111-1111-1111-1111-111111111111'; searchId = '22222222-2222-2222-2222-222222222222'; ticketNumber = '1234567'; reason = 'export'; dryRun = $false }
            Headers = @{}
            Params = @{ CIPPEndpoint = 'ExecEdiscoveryCaseExport' }
        }

        $Response.StatusCode | Should -Be ([HttpStatusCode]::BadRequest)
        $Response.Body.Results | Should -Match 'not available'
        $script:Calls | Should -Be 0
    }
}

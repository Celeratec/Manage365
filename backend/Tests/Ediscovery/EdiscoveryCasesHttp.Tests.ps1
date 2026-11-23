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

    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/Ediscovery/ConvertTo-CIPPEdiscoveryCountsOnly.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/Ediscovery/Test-CIPPEdiscoveryForbiddenAction.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/Ediscovery/Get-CIPPEdiscoveryGraphPlan.ps1')
    foreach ($Name in @(
            'Invoke-ExecEdiscoveryCase',
            'Invoke-ExecEdiscoveryCaseHold',
            'Invoke-ExecEdiscoveryCaseSearch',
            'Invoke-ExecEdiscoveryCaseExport',
            'Invoke-ListEdiscoveryCaseHolds',
            'Invoke-ListEdiscoveryCaseOperations',
            'Invoke-ListEdiscoveryCaseSearches'
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

Describe 'eDiscovery Cases endpoint redaction' {
    BeforeEach {
        Mock Get-CIPPEdiscoveryAccessToken { [pscustomobject]@{ AccessToken = 'tok' } }
        Mock Test-CIPPGuardedWriteRequest {
            [pscustomobject]@{ Ok = $true; Tenant = 'contoso.onmicrosoft.com'; Ticket = '1234567'; WhatIf = $true; Reason = 'synthetic test'; Caller = 'test' }
        }
        Mock Write-LogMessage {}
        $script:CapturedAuditRequest = $null
        Mock Add-CIPPGuardedWriteAudit {
            $script:CapturedAuditRequest = $Request
            'audit-1'
        }
    }

    It 'audits eDiscovery writes without content query or raw sources' {
        $Response = Invoke-ExecEdiscoveryCaseHold -Request @{
            Body = @{
                tenantFilter = 'contoso.onmicrosoft.com'
                action = 'create'
                caseId = '11111111-1111-1111-1111-111111111111'
                displayName = 'Hold'
                contentQuery = 'subject:"Secret Matter"'
                userSources = @(@{ email = 'client@example.com'; includedSources = 'mailbox,site' })
                siteSources = @(@{ siteWebUrl = 'https://contoso.sharepoint.com/sites/secret' })
                ticketNumber = '1234567'
                reason = 'synthetic test'
            }
            Headers = @{}
            Params = @{ CIPPEndpoint = 'ExecEdiscoveryCaseHold' }
        }

        $Response.StatusCode | Should -Be ([HttpStatusCode]::OK)
        $script:CapturedAuditRequest.Keys | Should -Not -Contain 'contentQuery'
        $script:CapturedAuditRequest.Keys | Should -Not -Contain 'userSources'
        $script:CapturedAuditRequest.Keys | Should -Not -Contain 'siteSources'
        $script:CapturedAuditRequest.contentQueryHash | Should -Not -BeNullOrEmpty
        $script:CapturedAuditRequest.userSourcesCount | Should -Be 1
        $script:CapturedAuditRequest.siteSourcesCount | Should -Be 1
        ($script:CapturedAuditRequest | ConvertTo-Json -Depth 8) | Should -Not -Match 'Secret Matter|client@example.com|sharepoint.com/sites/secret'
    }

    It 'returns searches without content query text' {
        Mock Invoke-CIPPEdiscoveryRequest {
            [pscustomobject]@{
                Results = @(
                    [pscustomobject]@{
                        id = 'search-1'
                        displayName = 'Search'
                        description = 'Counts only'
                        contentQuery = 'subject:"Secret Matter"'
                        createdBy = [pscustomobject]@{ user = [pscustomobject]@{ displayName = 'Admin' } }
                        createdDateTime = '2026-11-23T00:00:00Z'
                        lastModifiedDateTime = '2026-11-23T00:00:00Z'
                        dataSourceScopes = 'allTenantSources'
                        lastEstimateStatisticsOperation = [pscustomobject]@{
                            createdDateTime = '2026-11-23T00:01:00Z'
                            indexedItemCount = 5
                            indexedItemsSize = 1024
                            unindexedItemCount = 1
                            status = 'succeeded'
                        }
                    }
                )
            }
        }

        $Response = Invoke-ListEdiscoveryCaseSearches -Request @{
            Query = @{ tenantFilter = 'contoso.onmicrosoft.com'; caseId = '11111111-1111-1111-1111-111111111111' }
            Headers = @{}
            Params = @{ CIPPEndpoint = 'ListEdiscoveryCaseSearches' }
        }

        $Response.StatusCode | Should -Be ([HttpStatusCode]::OK)
        $Response.Body.Results[0].PSObject.Properties.Name | Should -Not -Contain 'contentQuery'
        $Response.Body.Results[0].contentQueryPresent | Should -BeTrue
        ($Response.Body | ConvertTo-Json -Depth 8) | Should -Not -Match 'Secret Matter'
    }

    It 'returns holds without content query text or raw source details' {
        Mock Invoke-CIPPEdiscoveryRequest {
            [pscustomobject]@{
                Results = @(
                    [pscustomobject]@{
                        id = 'hold-1'
                        displayName = 'Hold'
                        description = 'Counts only'
                        status = 'enabled'
                        isEnabled = $true
                        contentQuery = 'subject:"Secret Matter"'
                        userSources = @([pscustomobject]@{ email = 'client@example.com' })
                        siteSources = @([pscustomobject]@{ siteWebUrl = 'https://contoso.sharepoint.com/sites/secret' })
                        createdBy = [pscustomobject]@{ user = [pscustomobject]@{ displayName = 'Admin' } }
                        createdDateTime = '2026-11-23T00:00:00Z'
                        lastModifiedDateTime = '2026-11-23T00:00:00Z'
                    }
                )
            }
        }

        $Response = Invoke-ListEdiscoveryCaseHolds -Request @{
            Query = @{ tenantFilter = 'contoso.onmicrosoft.com'; caseId = '11111111-1111-1111-1111-111111111111' }
            Headers = @{}
            Params = @{ CIPPEndpoint = 'ListEdiscoveryCaseHolds' }
        }

        $Response.StatusCode | Should -Be ([HttpStatusCode]::OK)
        $Response.Body.Results[0].PSObject.Properties.Name | Should -Not -Contain 'contentQuery'
        $Response.Body.Results[0].PSObject.Properties.Name | Should -Not -Contain 'userSources'
        $Response.Body.Results[0].PSObject.Properties.Name | Should -Not -Contain 'siteSources'
        $Response.Body.Results[0].userSourcesCount | Should -Be 1
        $Response.Body.Results[0].siteSourcesCount | Should -Be 1
        ($Response.Body | ConvertTo-Json -Depth 8) | Should -Not -Match 'Secret Matter|client@example.com|sharepoint.com/sites/secret'
    }

    It 'returns operations without subjects or download URLs' {
        Mock Invoke-CIPPEdiscoveryRequest {
            [pscustomobject]@{
                Results = @(
                    [pscustomobject]@{
                        id = 'operation-1'
                        '@odata.type' = '#microsoft.graph.security.ediscoveryEstimateOperation'
                        action = 'estimateStatistics'
                        status = 'succeeded'
                        percentProgress = 100
                        createdBy = [pscustomobject]@{ user = [pscustomobject]@{ displayName = 'Admin' } }
                        createdDateTime = '2026-11-23T00:00:00Z'
                        completedDateTime = '2026-11-23T00:02:00Z'
                        resultInfo = [pscustomobject]@{
                            subject = 'Secret Matter'
                            downloadUrl = 'https://download.example/secret'
                            itemCount = 5
                        }
                    }
                )
            }
        }

        $Response = Invoke-ListEdiscoveryCaseOperations -Request @{
            Query = @{ tenantFilter = 'contoso.onmicrosoft.com'; caseId = '11111111-1111-1111-1111-111111111111' }
            Headers = @{}
            Params = @{ CIPPEndpoint = 'ListEdiscoveryCaseOperations' }
        }

        $Response.StatusCode | Should -Be ([HttpStatusCode]::OK)
        ($Response.Body | ConvertTo-Json -Depth 8) | Should -Not -Match 'Secret Matter|download.example'
    }
}

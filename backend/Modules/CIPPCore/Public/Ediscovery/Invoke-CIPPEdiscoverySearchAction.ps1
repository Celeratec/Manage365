function Get-CIPPEdiscoverySearchBodyValue {
    [CmdletBinding()]
    param($Body, [string]$Name)

    if ($null -eq $Body) { return $null }
    if ($Body -is [System.Collections.IDictionary]) {
        if ($Body.Contains($Name)) { return $Body[$Name] }
        return $null
    }
    if ($Body.PSObject.Properties[$Name]) { return $Body.$Name }
    return $null
}

function Get-CIPPEdiscoverySearchHttpResponse {
    [CmdletBinding()]
    param(
        [object]$StatusCode,
        $Body,
        $Headers
    )

    $Response = [HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = $Body
    }
    if ($Headers) { $Response.Headers = $Headers }
    return $Response
}

function Get-CIPPEdiscoverySearchObjectValue {
    [CmdletBinding()]
    param($Value, [string]$Name)

    if ($null -eq $Value) { return $null }
    if ($Value -is [System.Collections.IDictionary]) {
        if ($Value.Contains($Name)) { return $Value[$Name] }
        return $null
    }
    if ($Value.PSObject.Properties[$Name]) { return $Value.$Name }
    return $null
}

function Get-CIPPEdiscoverySearchResultMetric {
    [CmdletBinding()]
    param($Response)

    $Source = $null
    $Raw = Get-CIPPEdiscoverySearchObjectValue -Value $Response -Name 'Raw'
    if ($Raw) {
        $Source = $Raw
    } else {
        $Results = @(Get-CIPPEdiscoverySearchObjectValue -Value $Response -Name 'Results')
        if ($Results.Count -gt 0) { $Source = $Results[0] }
    }

    [pscustomobject]@{
        indexedItemCount   = [int](Get-CIPPEdiscoverySearchObjectValue -Value $Source -Name 'indexedItemCount')
        indexedItemsSize   = [int64](Get-CIPPEdiscoverySearchObjectValue -Value $Source -Name 'indexedItemsSize')
        mailboxCount       = [int](Get-CIPPEdiscoverySearchObjectValue -Value $Source -Name 'mailboxCount')
        unindexedItemCount = [int](Get-CIPPEdiscoverySearchObjectValue -Value $Source -Name 'unindexedItemCount')
    }
}

function Invoke-CIPPEdiscoveryPlannedRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$AccessToken,
        [Parameter(Mandatory)][string]$Action,
        [hashtable]$Params,
        $Body,
        [int]$PollTimeoutSeconds = 300
    )

    $Plan = Get-CIPPEdiscoveryGraphPlan -Action $Action -Params $Params
    if (-not $Plan.Allowed) {
        throw $Plan.Reason
    }

    Invoke-CIPPEdiscoveryRequest -AccessToken $AccessToken -Method $Plan.Method -Path $Plan.Path -Body $Body -Classification $Plan.Classification -PollTimeoutSeconds $PollTimeoutSeconds
}

function Invoke-CIPPEdiscoverySearchAction {
    <#
    .SYNOPSIS
        Runs a guarded, stats-only Purview eDiscovery search workflow.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Request
    )

    $APIName = if ($Request.Params.CIPPEndpoint) { $Request.Params.CIPPEndpoint } else { 'ExecEdiscoverySearch' }
    $Headers = $Request.Headers

    try {
        $Gate = Test-CIPPGuardedWriteRequest -Request $Request -IsWrite -DefaultDryRun
        if (-not $Gate.Ok) {
            $ResponseHeaders = @{}
            if ($Gate.StatusCode -eq 429) { $ResponseHeaders['Retry-After'] = [string]$Gate.RetryAfter }
            return Get-CIPPEdiscoverySearchHttpResponse -StatusCode $Gate.StatusCode -Headers $ResponseHeaders -Body ([pscustomobject]@{
                    Results = $Gate.Message
                    Status  = 'Failed'
                })
        }
        if ([string]::IsNullOrWhiteSpace([string]$Gate.Reason)) {
            return Get-CIPPEdiscoverySearchHttpResponse -StatusCode ([HttpStatusCode]::BadRequest) -Body ([pscustomobject]@{
                    Results = 'reason is required for eDiscovery search actions.'
                    Status  = 'Failed'
                })
        }

        $Body = $Request.Body
        $TenantFilter = [string](Get-CIPPEdiscoverySearchBodyValue -Body $Body -Name 'tenantFilter')
        $TicketNumber = [string](Get-CIPPEdiscoverySearchBodyValue -Body $Body -Name 'ticketNumber')
        $CaseLabel = [string](Get-CIPPEdiscoverySearchBodyValue -Body $Body -Name 'caseLabel')
        $CustodianUpn = [string](Get-CIPPEdiscoverySearchBodyValue -Body $Body -Name 'custodianUpn')
        $Terms = @(Get-CIPPEdiscoverySearchBodyValue -Body $Body -Name 'terms')
        $DateFromRaw = Get-CIPPEdiscoverySearchBodyValue -Body $Body -Name 'dateFrom'
        $DateToRaw = Get-CIPPEdiscoverySearchBodyValue -Body $Body -Name 'dateTo'

        $ExtraCustodians = @(Get-CIPPEdiscoverySearchBodyValue -Body $Body -Name 'custodians')
        if ($ExtraCustodians.Count -gt 1) {
            return Get-CIPPEdiscoverySearchHttpResponse -StatusCode ([HttpStatusCode]::BadRequest) -Body ([pscustomobject]@{
                    Results = 'Only one custodian is supported for eDiscovery stats searches.'
                    Status  = 'Failed'
                })
        }

        $DateFrom = [datetime]::MinValue
        $DateTo = [datetime]::MinValue
        $HasDateRange = $false
        if ($DateFromRaw -or $DateToRaw) {
            if (-not $DateFromRaw -or -not $DateToRaw) {
                return Get-CIPPEdiscoverySearchHttpResponse -StatusCode ([HttpStatusCode]::BadRequest) -Body ([pscustomobject]@{
                        Results = 'dateFrom and dateTo must be supplied together.'
                        Status  = 'Failed'
                    })
            }
            if (-not [datetime]::TryParse([string]$DateFromRaw, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$DateFrom) -or
                -not [datetime]::TryParse([string]$DateToRaw, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$DateTo)) {
                return Get-CIPPEdiscoverySearchHttpResponse -StatusCode ([HttpStatusCode]::BadRequest) -Body ([pscustomobject]@{
                        Results = 'dateFrom and dateTo must be valid dates.'
                        Status  = 'Failed'
                    })
            }
            $HasDateRange = $true
        }

        $PlanParams = @{
            TicketNumber = $TicketNumber
            CustodianUpn = $CustodianUpn
            Terms        = $Terms
            CaseLabel    = $CaseLabel
        }
        if ($HasDateRange) {
            $PlanParams.DateFrom = $DateFrom
            $PlanParams.DateTo = $DateTo
        }
        $SearchPlan = Get-CIPPEdiscoverySearchPlan @PlanParams

        $OperatorAfter = [pscustomobject]@{
            DisplayName  = $SearchPlan.DisplayName
            ExternalId   = $SearchPlan.ExternalId
            CustodianUpn = $SearchPlan.CustodianUpn
            TermCount    = $SearchPlan.TermCount
            KqlHash      = $SearchPlan.KqlHash
            Terms        = $SearchPlan.Terms
            Limits       = $SearchPlan.Limits
        }
        if ($Gate.WhatIf) {
            $AuditPayload = New-CIPPEdiscoveryStatsSearchAuditPayload -Gate $Gate -TermCount $SearchPlan.TermCount -KqlHash $SearchPlan.KqlHash -Status 'DryRun'
            $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $AuditPayload -After $AuditPayload -DryRun $true -Result 'DryRun'
            return Get-CIPPEdiscoverySearchHttpResponse -StatusCode ([HttpStatusCode]::OK) -Body ([pscustomobject]@{
                    Status   = 'DryRun'
                    AuditId  = $AuditId
                    Before   = $null
                    After    = $OperatorAfter
                    Rollback = 'No Graph changes were made.'
                    Results  = [pscustomobject]@{
                        Note = 'DryRun only. Live execution creates/reuses a case, custodian mailbox source, and one estimate per term. Per-term counts may overlap.'
                    }
                })
        }

        if (-not $script:CIPPEdiscoverySearchActionLocks) {
            $script:CIPPEdiscoverySearchActionLocks = @{}
        }
        $LockKey = ([string]$Gate.Tenant).ToLowerInvariant()
        if ($script:CIPPEdiscoverySearchActionLocks[$LockKey]) {
            return Get-CIPPEdiscoverySearchHttpResponse -StatusCode ([HttpStatusCode]::Conflict) -Body ([pscustomobject]@{
                    Results = 'An eDiscovery search estimate is already in flight for this tenant.'
                    Status  = 'Failed'
                })
        }
        $script:CIPPEdiscoverySearchActionLocks[$LockKey] = $true

        try {
            $Token = Get-CIPPEdiscoveryAccessToken -TenantFilter $TenantFilter
            $AccessToken = [string]$Token.AccessToken

            $Cases = Invoke-CIPPEdiscoveryPlannedRequest -AccessToken $AccessToken -Action 'ListEdiscoveryCases' -Params @{} -PollTimeoutSeconds 300
            $ExistingCase = @($Cases.Results | Where-Object {
                    [string]$_.externalId -eq $SearchPlan.ExternalId -and
                    [string]$_.displayName -eq $SearchPlan.DisplayName -and
                    [string]$_.description -match 'Manage365 stats-only eDiscovery search' -and
                    [string]$_.status -notmatch '(?i)closed'
                } | Select-Object -First 1)
            if ($ExistingCase.Count -gt 0) {
                $Case = $ExistingCase[0]
            } else {
                $CaseResponse = Invoke-CIPPEdiscoveryPlannedRequest -AccessToken $AccessToken -Action 'CreateEdiscoveryCase' -Params @{} -Body @{
                    displayName = $SearchPlan.DisplayName
                    description = 'Manage365 stats-only eDiscovery search.'
                    externalId  = $SearchPlan.ExternalId
                } -PollTimeoutSeconds 300
                $Case = @($CaseResponse.Results | Select-Object -First 1)[0]
            }

            $CaseId = [string]$Case.id
            if ([string]::IsNullOrWhiteSpace($CaseId)) {
                throw 'eDiscovery case id was not returned by Graph.'
            }

            $Custodians = Invoke-CIPPEdiscoveryPlannedRequest -AccessToken $AccessToken -Action 'ListEdiscoveryCustodians' -Params @{ caseId = $CaseId } -PollTimeoutSeconds 300
            $Custodian = @($Custodians.Results | Where-Object {
                    [string]$_.email -ieq $SearchPlan.CustodianUpn -or
                    [string]$_.userPrincipalName -ieq $SearchPlan.CustodianUpn
                } | Select-Object -First 1)
            if ($Custodian.Count -gt 0) {
                $Custodian = $Custodian[0]
            } else {
                $CustodianResponse = Invoke-CIPPEdiscoveryPlannedRequest -AccessToken $AccessToken -Action 'CreateEdiscoveryCustodian' -Params @{ caseId = $CaseId } -Body @{
                    email = $SearchPlan.CustodianUpn
                } -PollTimeoutSeconds 300
                $Custodian = @($CustodianResponse.Results | Select-Object -First 1)[0]
            }
            $CustodianId = [string]$Custodian.id
            if ([string]::IsNullOrWhiteSpace($CustodianId)) {
                throw 'eDiscovery custodian id was not returned by Graph.'
            }

            $UserSources = Invoke-CIPPEdiscoveryPlannedRequest -AccessToken $AccessToken -Action 'ListEdiscoveryUserSources' -Params @{ caseId = $CaseId; custodianId = $CustodianId } -PollTimeoutSeconds 300
            $UserSource = @($UserSources.Results | Where-Object {
                    ([string]$_.email -ieq $SearchPlan.CustodianUpn -or [string]$_.userPrincipalName -ieq $SearchPlan.CustodianUpn) -and
                    ([string]::IsNullOrWhiteSpace([string]$_.includedSources) -or [string]$_.includedSources -match '(?i)mailbox')
                } | Select-Object -First 1)
            if ($UserSource.Count -gt 0) {
                $UserSource = $UserSource[0]
            } else {
                $UserSourceResponse = Invoke-CIPPEdiscoveryPlannedRequest -AccessToken $AccessToken -Action 'CreateEdiscoveryUserSource' -Params @{ caseId = $CaseId; custodianId = $CustodianId } -Body @{
                    email           = $SearchPlan.CustodianUpn
                    includedSources = 'mailbox'
                } -PollTimeoutSeconds 300
                $UserSource = @($UserSourceResponse.Results | Select-Object -First 1)[0]
            }
            $UserSourceId = [string]$UserSource.id
            if ([string]::IsNullOrWhiteSpace($UserSourceId) -or $UserSourceId -notmatch '\A[a-fA-F0-9\-]{1,64}\z') {
                throw 'eDiscovery user source id was not returned by Graph.'
            }

            $SearchIds = [System.Collections.Generic.List[string]]::new()
            $ExistingSearches = Invoke-CIPPEdiscoveryPlannedRequest -AccessToken $AccessToken -Action 'ListEdiscoverySearches' -Params @{ caseId = $CaseId } -PollTimeoutSeconds 300
            $PerTerm = foreach ($Term in @($SearchPlan.Terms)) {
                $TermPlanParams = @{
                    TicketNumber = $SearchPlan.ExternalId
                    CustodianUpn = $SearchPlan.CustodianUpn
                    CaseLabel    = $CaseLabel
                    Terms        = @($Term)
                }
                if ($HasDateRange) {
                    $TermPlanParams.DateFrom = $DateFrom
                    $TermPlanParams.DateTo = $DateTo
                }
                $TermPlan = Get-CIPPEdiscoverySearchPlan @TermPlanParams
                $TermSearchName = "$($SearchPlan.DisplayName) - term $($TermPlan.KqlHash.Substring(0, 12))"
                $Search = @($ExistingSearches.Results | Where-Object {
                        [string]$_.displayName -eq $TermSearchName -and
                        [string]$_.description -match 'Manage365 stats-only per-term estimate'
                    } | Select-Object -First 1)
                if ($Search.Count -gt 0) {
                    $Search = $Search[0]
                } else {
                    $SearchResponse = Invoke-CIPPEdiscoveryPlannedRequest -AccessToken $AccessToken -Action 'CreateEdiscoverySearch' -Params @{ caseId = $CaseId } -Body @{
                        displayName      = $TermSearchName
                        description      = 'Manage365 stats-only per-term estimate.'
                        contentQuery     = $TermPlan.Kql
                        dataSourceScopes = 'none'
                    } -PollTimeoutSeconds 300
                    $Search = @($SearchResponse.Results | Select-Object -First 1)[0]
                }
                $SearchId = [string]$Search.id
                if ([string]::IsNullOrWhiteSpace($SearchId)) {
                    throw 'eDiscovery search id was not returned by Graph.'
                }
                $SearchIds.Add($SearchId) | Out-Null

                $LinkedSources = Invoke-CIPPEdiscoveryPlannedRequest -AccessToken $AccessToken -Action 'ListEdiscoverySearchCustodianSources' -Params @{ caseId = $CaseId; searchId = $SearchId } -PollTimeoutSeconds 300
                $SourceAlreadyLinked = @($LinkedSources.Results | Where-Object { [string]$_.id -eq $UserSourceId }).Count -gt 0
                if (-not $SourceAlreadyLinked) {
                    $SourceUrl = "https://graph.microsoft.com/v1.0/security/cases/ediscoveryCases/$CaseId/custodians/$CustodianId/userSources/$UserSourceId"
                    $null = Invoke-CIPPEdiscoveryPlannedRequest -AccessToken $AccessToken -Action 'AddEdiscoverySearchCustodianSource' -Params @{ caseId = $CaseId; searchId = $SearchId } -Body @{
                        '@odata.id' = $SourceUrl
                    } -PollTimeoutSeconds 300
                }

                $EstimateResponse = Invoke-CIPPEdiscoveryPlannedRequest -AccessToken $AccessToken -Action 'EstimateEdiscoverySearch' -Params @{ caseId = $CaseId; searchId = $SearchId } -Body @{} -PollTimeoutSeconds 300
                $Metrics = Get-CIPPEdiscoverySearchResultMetric -Response $EstimateResponse
                [pscustomobject]@{
                    term      = $Term
                    itemCount = $Metrics.indexedItemCount
                    size      = $Metrics.indexedItemsSize
                }
            }

            $IndexedItemCount = 0
            $IndexedItemsSize = [int64]0
            foreach ($Row in @($PerTerm)) {
                $IndexedItemCount += [int]$Row.itemCount
                $IndexedItemsSize += [int64]$Row.size
            }

            $Results = [pscustomobject]@{
                indexedItemCount   = $IndexedItemCount
                indexedItemsSize   = $IndexedItemsSize
                mailboxCount       = 1
                unindexedItemCount = 0
                perTerm            = @($PerTerm)
                Note               = 'Per-term counts are estimated independently and may overlap.'
            }

            $AuditRequest = New-CIPPEdiscoveryStatsSearchAuditPayload -Gate $Gate -TermCount $SearchPlan.TermCount -KqlHash $SearchPlan.KqlHash -Status 'Success'
            $AuditAfter = New-CIPPEdiscoveryStatsSearchAuditPayload -Gate $Gate -TermCount $SearchPlan.TermCount -KqlHash $SearchPlan.KqlHash -Status 'Success' -CaseId $CaseId -SearchIds @($SearchIds)
            $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $AuditRequest -After $AuditAfter -DryRun $false -Result 'Success'
            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message 'Completed stats-only eDiscovery search estimate.' -Sev 'Info'

            return Get-CIPPEdiscoverySearchHttpResponse -StatusCode ([HttpStatusCode]::OK) -Body ([pscustomobject]@{
                    Status   = 'Success'
                    AuditId  = $AuditId
                    Before   = $null
                    After    = $OperatorAfter
                    Rollback = 'No destructive Graph action was performed. Remove the search/case manually in Purview if policy allows.'
                    Results  = $Results
                })
        } finally {
            $script:CIPPEdiscoverySearchActionLocks.Remove($LockKey)
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Result = "Failed to run eDiscovery stats search: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Error' -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
        if ($ErrorMessage.NormalizedError -match '1 to 25|ticketNumber|custodianUpn|dateTo|dateFrom|5 years|Only one custodian') {
            $StatusCode = [HttpStatusCode]::BadRequest
        }
        return Get-CIPPEdiscoverySearchHttpResponse -StatusCode $StatusCode -Body ([pscustomobject]@{
                Results = $Result
                Status  = 'Failed'
            })
    }
}

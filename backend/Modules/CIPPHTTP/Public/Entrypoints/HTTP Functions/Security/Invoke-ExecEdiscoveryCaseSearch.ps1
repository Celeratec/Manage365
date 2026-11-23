function Invoke-ExecEdiscoveryCaseSearch {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Security.Ediscovery.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $null = $TriggerMetadata
    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Body.tenantFilter
    $Action = $Request.Body.action
    $CaseId = $Request.Body.caseId
    $SearchId = $Request.Body.searchId

    try {
        Test-CIPPEdiscoveryForbiddenAction -Action $Action -Resource 'search' | Out-Null
    } catch {
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = [PSCustomObject]@{ Results = $_.Exception.Message; Status = 'Failed' }
        }
    }

    $ActionMap = @{
        create             = 'CreateEdiscoverySearch'
        update             = 'UpdateEdiscoverySearch'
        estimateStatistics = 'EstimateEdiscoverySearch'
    }
    if (-not $ActionMap.ContainsKey([string]$Action)) {
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = [PSCustomObject]@{ Results = "Unknown or unsupported eDiscovery search action: $Action"; Status = 'Failed' }
        }
    }

    if ([string]$Action -in @('create', 'update')) {
        $HasContentQuery = if ($Request.Body -is [System.Collections.IDictionary]) { $Request.Body.Contains('contentQuery') } else { $null -ne $Request.Body.PSObject.Properties['contentQuery'] }
        $HasDataSourceScopes = if ($Request.Body -is [System.Collections.IDictionary]) { $Request.Body.Contains('dataSourceScopes') } else { $null -ne $Request.Body.PSObject.Properties['dataSourceScopes'] }
        if ($HasContentQuery -or $HasDataSourceScopes) {
            return [HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = [PSCustomObject]@{
                    Results = 'Free-form contentQuery and dataSourceScopes are not accepted for eDiscovery search create/update. Use ExecEdiscoverySearch for mailbox-only stats estimates.'
                    Status  = 'Failed'
                }
            }
        }
    }

    try {
        $Gate = Test-CIPPGuardedWriteRequest -Request $Request -IsWrite -DefaultDryRun
        if (-not $Gate.Ok) {
            $ResponseHeaders = @{}
            if ($Gate.StatusCode -eq 429) { $ResponseHeaders['Retry-After'] = [string]$Gate.RetryAfter }
            return [HttpResponseContext]@{ StatusCode = $Gate.StatusCode; Headers = $ResponseHeaders; Body = @{ Results = $Gate.Message; Status = 'Failed' } }
        }
        if ([string]::IsNullOrWhiteSpace([string]$Gate.Reason)) {
            return [HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{ Results = 'reason is required for eDiscovery search changes.'; Status = 'Failed' }
            }
        }

        $GraphAction = $ActionMap[[string]$Action]
        $Plan = Get-CIPPEdiscoveryGraphPlan -Action $GraphAction -Params @{ caseId = $CaseId; searchId = $SearchId }
        if (-not $Plan.Allowed) {
            return [HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{ Results = $Plan.Reason; Status = 'Failed' }
            }
        }

        switch ($Action) {
            'create' {
                $SearchBody = @{
                    displayName    = $Request.Body.displayName
                    description    = $Request.Body.description
                    contentQuery   = $Request.Body.contentQuery
                }

                if ($Request.Body.dataSourceScopes) {
                    $SearchBody.dataSourceScopes = $Request.Body.dataSourceScopes
                }

                $RequestBody = $SearchBody
                $ResponseBody = "Successfully created eDiscovery search '$($Request.Body.displayName)'"
            }
            'update' {
                $UpdateBody = @{}
                if ($Request.Body.displayName) { $UpdateBody.displayName = $Request.Body.displayName }
                if ($Request.Body.description) { $UpdateBody.description = $Request.Body.description }
                if ($null -ne $Request.Body.contentQuery) { $UpdateBody.contentQuery = $Request.Body.contentQuery }
                $RequestBody = $UpdateBody
                $ResponseBody = "Successfully updated eDiscovery search '$SearchId'"
            }
            'estimateStatistics' {
                $RequestBody = @{}
                $ResponseBody = "Search estimate started for '$SearchId'. This may take several minutes to complete."
            }
        }

        $AuditRequest = ConvertTo-CIPPEdiscoveryCountsOnly -Value $Request.Body

        if ($Gate.WhatIf) {
            $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $AuditRequest -DryRun $true -Result 'DryRun'
            $StatusCode = [HttpStatusCode]::OK
            $Body = [PSCustomObject]@{ Results = "Would $Action eDiscovery search."; Status = 'DryRun'; AuditId = $AuditId; WhatIfPlan = @($Plan) }
        } else {
            $Token = Get-CIPPEdiscoveryAccessToken -TenantFilter $TenantFilter
            $null = Invoke-CIPPEdiscoveryRequest -AccessToken $Token.AccessToken -Method $Plan.Method -Path $Plan.Path -Body $RequestBody -Classification $Plan.Classification
            $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $AuditRequest -DryRun $false -Result 'Success'
            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $ResponseBody -Sev 'Info'
            $StatusCode = [HttpStatusCode]::OK
            $Body = [PSCustomObject]@{ Results = $ResponseBody; Status = 'Success'; AuditId = $AuditId }
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Result = "Failed to $Action eDiscovery search: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Error' -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
        $Body = [PSCustomObject]@{ Results = $Result }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}

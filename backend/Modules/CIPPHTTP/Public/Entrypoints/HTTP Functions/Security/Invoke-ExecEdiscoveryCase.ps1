function Invoke-ExecEdiscoveryCase {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Security.Ediscovery.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Body.tenantFilter
    $Action = $Request.Body.action
    $CaseId = $Request.Body.caseId

    try {
        Test-CIPPEdiscoveryForbiddenAction -Action $Action -Resource 'case' | Out-Null
    } catch {
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = [PSCustomObject]@{ Results = $_.Exception.Message; Status = 'Failed' }
        }
    }

    $ActionMap = @{
        create = 'CreateEdiscoveryCase'
        update = 'UpdateEdiscoveryCase'
        close  = 'CloseEdiscoveryCase'
        reopen = 'ReopenEdiscoveryCase'
    }
    if (-not $ActionMap.ContainsKey([string]$Action)) {
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = [PSCustomObject]@{ Results = "Unknown or unsupported eDiscovery case action: $Action"; Status = 'Failed' }
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
                Body       = @{ Results = 'reason is required for eDiscovery case changes.'; Status = 'Failed' }
            }
        }

        $GraphAction = $ActionMap[[string]$Action]
        $Plan = Get-CIPPEdiscoveryGraphPlan -Action $GraphAction -Params @{ caseId = $CaseId }
        if (-not $Plan.Allowed) {
            return [HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{ Results = $Plan.Reason; Status = 'Failed' }
            }
        }

        switch ($Action) {
            'create' {
                $RequestBody = @{
                    displayName = $Request.Body.displayName
                    description = $Request.Body.description
                    externalId  = $Request.Body.externalId
                }
                $ResponseBody = "Successfully created eDiscovery case '$($Request.Body.displayName)'"
            }
            'update' {
                $RequestBody = @{}
                if ($Request.Body.displayName) { $RequestBody.displayName = $Request.Body.displayName }
                if ($Request.Body.description) { $RequestBody.description = $Request.Body.description }
                $ResponseBody = "Successfully updated eDiscovery case '$CaseId'"
            }
            'close' {
                $RequestBody = @{}
                $ResponseBody = "Successfully closed eDiscovery case '$CaseId'"
            }
            'reopen' {
                $RequestBody = @{}
                $ResponseBody = "Successfully reopened eDiscovery case '$CaseId'"
            }
        }

        $AuditRequest = ConvertTo-CIPPEdiscoveryCountsOnly -Value $Request.Body

        if ($Gate.WhatIf) {
            $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $AuditRequest -DryRun $true -Result 'DryRun'
            $StatusCode = [HttpStatusCode]::OK
            $Body = [PSCustomObject]@{ Results = "Would $Action eDiscovery case."; Status = 'DryRun'; AuditId = $AuditId; WhatIfPlan = @($Plan) }
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
        $Result = "Failed to $Action eDiscovery case: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Error' -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
        $Body = [PSCustomObject]@{ Results = $Result }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}

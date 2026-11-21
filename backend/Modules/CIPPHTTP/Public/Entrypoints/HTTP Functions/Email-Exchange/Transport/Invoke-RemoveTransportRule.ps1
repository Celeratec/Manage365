Function Invoke-RemoveTransportRule {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.TransportRule.ReadWrite
    .DESCRIPTION
        Deletes a transport rule by guid. Without ticketNumber/dryRun/reason the legacy behavior
        is unchanged. When any of those fields is present the guarded envelope applies and
        confirmRuleName must equal the rule's current Name.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers

    $TenantFilter = $Request.Query.tenantFilter ?? $Request.body.tenantFilter
    $Identity = $Request.Query.guid ?? $Request.body.guid

    $Params = @{
        Identity = $Identity
    }

    if (-not (Test-CIPPTransportRuleGuardedMode -Request $Request)) {
        try {
            $cmdlet = 'Remove-TransportRule'
            $null = New-ExoRequest -tenantid $TenantFilter -cmdlet $cmdlet -cmdParams $Params -UseSystemMailbox $true
            $Result = "Deleted $($Identity)"
            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Deleted transport rule $($Identity)" -Sev Info
            $StatusCode = [HttpStatusCode]::OK
        } catch {
            $ErrorMessage = Get-CippException -Exception $_
            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Failed deleting transport rule $($Identity). Error:$($ErrorMessage.NormalizedError)" -Sev Error -LogData $ErrorMessage
            $Result = $ErrorMessage.NormalizedError
            $StatusCode = [HttpStatusCode]::InternalServerError
        }

        return ([HttpResponseContext]@{
                StatusCode = $StatusCode
                Body       = @{ Results = $Result }
            })
    }

    if (-not (Test-CIPPGuardedTenantWritesEnabled)) {
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::Forbidden
            Body       = @{ Results = 'Guarded tenant writes are disabled. Enable the GuardedTenantWrites feature flag, or omit ticketNumber/dryRun/reason to use the legacy path.'; Status = 'Failed' }
        }
    }

    $Request = Merge-CIPPTransportRuleGuardedRequestBody -Request $Request
    if ([string]::IsNullOrWhiteSpace([string]$Request.Body.tenantFilter) -and -not [string]::IsNullOrWhiteSpace($TenantFilter)) {
        $Request.Body | Add-Member -NotePropertyName tenantFilter -NotePropertyValue $TenantFilter -Force
    }

    $Gate = Test-CIPPGuardedWriteRequest -Request $Request -IsWrite -DefaultDryRun
    if (-not $Gate.Ok) {
        # HttpResponseContext in CI/Azure stubs is StatusCode/Body/ContentType only — do not set Headers.
        $Body = @{ Results = $Gate.Message; Status = 'Failed' }
        if ($Gate.StatusCode -eq 429 -and $null -ne $Gate.RetryAfter) { $Body.RetryAfter = $Gate.RetryAfter }
        return [HttpResponseContext]@{ StatusCode = $Gate.StatusCode; Body = $Body }
    }

    $ConfirmName = [string]($Request.Body.confirmRuleName ?? $Request.Query.confirmRuleName ?? $Request.Body.ConfirmRuleName)
    if ([string]::IsNullOrWhiteSpace($ConfirmName)) {
        $Reason = 'confirmRuleName is required in guarded mode and must match the rule Name.'
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -DryRun $Gate.WhatIf -Result $Reason
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = $Reason; Status = 'Failed'; AuditId = $AuditId } }
    }

    $Before = $null
    try {
        $BeforeRaw = New-ExoRequest -tenantid $Gate.Tenant -cmdlet 'Get-TransportRule' -cmdParams @{ Identity = $Identity } -UseSystemMailbox $true
        $Before = Get-CIPPTransportRuleProjection $BeforeRaw
    } catch {
        $Before = $null
    }
    if ($null -eq $Before) {
        $Reason = 'Transport rule not found.'
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -DryRun $Gate.WhatIf -Result $Reason
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = $Reason; Status = 'Failed'; AuditId = $AuditId } }
    }

    if ([string]$Before.Name -cne $ConfirmName) {
        $Reason = "confirmRuleName does not match the rule Name '$($Before.Name)'."
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -DryRun $Gate.WhatIf -Result $Reason
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = $Reason; Status = 'Failed'; AuditId = $AuditId; Before = $Before } }
    }

    $Rollback = @{ Description = 'Recreate this transport rule manually from Before.'; Rule = $Before }
    $WhatIfPlan = @([pscustomobject]@{ Cmdlet = 'Remove-TransportRule'; Parameters = $Params })

    if ($Gate.WhatIf) {
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -DryRun $true -Result 'DryRun'
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{ Results = 'Would run Remove-TransportRule'; Status = 'DryRun'; AuditId = $AuditId; Before = $Before; After = $null; WhatIfPlan = $WhatIfPlan; Rollback = $Rollback; ticketNumber = $Gate.Ticket; dryRun = $true }
        }
    }

    try {
        $null = New-ExoRequest -tenantid $Gate.Tenant -cmdlet 'Remove-TransportRule' -cmdParams $Params -UseSystemMailbox $true
        $Result = "Deleted $($Identity)"
        Write-LogMessage -headers $Headers -API $APIName -tenant $Gate.Tenant -message "Deleted transport rule $($Identity)" -Sev Info
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -After $null -DryRun $false -Result 'Success'
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{ Results = $Result; Status = 'Success'; AuditId = $AuditId; Before = $Before; After = $null; Rollback = $Rollback; ticketNumber = $Gate.Ticket; dryRun = $false }
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Message = $ErrorMessage.NormalizedError
        Write-LogMessage -headers $Headers -API $APIName -tenant $Gate.Tenant -message "Failed deleting transport rule $($Identity). Error:$Message" -Sev Error -LogData $ErrorMessage
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -DryRun $false -Result $Message
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::InternalServerError; Body = @{ Results = $Message; Status = 'Failed'; AuditId = $AuditId; Before = $Before; Rollback = $Rollback } }
    }
}

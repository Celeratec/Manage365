function Invoke-EditTransportRule {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.TransportRule.ReadWrite
    .DESCRIPTION
        Enables or disables a transport rule by guid. Without ticketNumber/dryRun/reason the
        legacy behavior is unchanged. When any of those fields is present the guarded envelope
        applies (ticket required, dryRun defaults true, GuardedTenantWrites must be on).
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers

    $TenantFilter = $Request.Query.tenantFilter ?? $Request.body.tenantFilter
    $Identity = $Request.Query.guid ?? $Request.body.guid
    $State = $Request.Query.state ?? $Request.body.state

    $Params = @{
        Identity = $Identity
    }

    if (-not (Test-CIPPTransportRuleGuardedMode -Request $Request)) {
        try {
            $cmdlet = if ($State -eq 'enable') { 'Enable-TransportRule' } else { 'Disable-TransportRule' }
            $null = New-ExoRequest -tenantid $TenantFilter -cmdlet $cmdlet -cmdParams $Params -UseSystemMailbox $true
            $Result = "Set transport rule $($Identity) to $($State)"
            Write-LogMessage -Headers $Headers -API $APINAME -tenant $TenantFilter -message $Result -sev Info
            $StatusCode = [HttpStatusCode]::OK
        } catch {
            $ErrorMessage = Get-CippException -Exception $_
            Write-LogMessage -Headers $Headers -API $APINAME -tenant $TenantFilter -message "Failed setting transport rule $($Identity) to $($State). Error:$($ErrorMessage.NormalizedError)" -Sev 'Error' -LogData $ErrorMessage
            $Result = $ErrorMessage.NormalizedError
            $StatusCode = [HttpStatusCode]::InternalServerError
        }

        return ([HttpResponseContext]@{
                StatusCode = $StatusCode
                Body       = @{Results = $Result }
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
        $ResponseHeaders = @{}
        if ($Gate.StatusCode -eq 429) { $ResponseHeaders['Retry-After'] = [string]$Gate.RetryAfter }
        $AuditId = $null
        if ($Gate.StatusCode -ne 429 -and -not [string]::IsNullOrWhiteSpace($Gate.Tenant)) {
            $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -DryRun $true -Result $Gate.Message
        }
        return [HttpResponseContext]@{ StatusCode = $Gate.StatusCode; Headers = $ResponseHeaders; Body = @{ Results = $Gate.Message; Status = 'Failed'; AuditId = $AuditId } }
    }

    $Normalized = ConvertTo-CIPPTransportRuleGuardedFields -Enabled $State -State $State
    if (-not $Normalized.Ok -or -not $Normalized.HasEnabled) {
        $Message = if (-not $Normalized.Ok) { $Normalized.Message } else { 'state must be enable/disable (or Enabled/Disabled/true/false).' }
        # Accept legacy enable/disable strings as well as Normalized values
        $StateLower = [string]$State
        if ($StateLower -match '^(?i)enable(d)?$') {
            $Normalized = [pscustomobject]@{ Ok = $true; HasEnabled = $true; EnabledBool = $true }
        } elseif ($StateLower -match '^(?i)disable(d)?$') {
            $Normalized = [pscustomobject]@{ Ok = $true; HasEnabled = $true; EnabledBool = $false }
        } else {
            $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -DryRun $Gate.WhatIf -Result $Message
            return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = $Message; Status = 'Failed'; AuditId = $AuditId } }
        }
    }

    $Cmdlet = if ($Normalized.EnabledBool) { 'Enable-TransportRule' } else { 'Disable-TransportRule' }
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

    $Rollback = @{
        Cmdlet     = if ($Before.State -match '^(?i)enabled$') { 'Enable-TransportRule' } else { 'Disable-TransportRule' }
        Parameters = @{ Identity = $Identity }
    }
    $WhatIfPlan = @([pscustomobject]@{ Cmdlet = $Cmdlet; Parameters = $Params })

    if ($Gate.WhatIf) {
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -DryRun $true -Result 'DryRun'
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{ Results = "Would run $Cmdlet"; Status = 'DryRun'; AuditId = $AuditId; Before = $Before; After = $null; WhatIfPlan = $WhatIfPlan; Rollback = $Rollback; ticketNumber = $Gate.Ticket; dryRun = $true }
        }
    }

    try {
        $null = New-ExoRequest -tenantid $Gate.Tenant -cmdlet $Cmdlet -cmdParams $Params -UseSystemMailbox $true
        $AfterRaw = New-ExoRequest -tenantid $Gate.Tenant -cmdlet 'Get-TransportRule' -cmdParams @{ Identity = $Identity } -UseSystemMailbox $true
        $After = Get-CIPPTransportRuleProjection $AfterRaw
        $ExpectedState = if ($Normalized.EnabledBool) { 'Enabled' } else { 'Disabled' }
        if ([string]$After.State -ne $ExpectedState) {
            $Reason = "After state mismatch: expected $ExpectedState, got $($After.State)."
            $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -After $After -DryRun $false -Result $Reason
            return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::OK; Body = @{ Results = $Reason; Status = 'Failed'; AuditId = $AuditId; Before = $Before; After = $After; Rollback = $Rollback } }
        }
        $Result = "Set transport rule $($Identity) to $($State)"
        Write-LogMessage -Headers $Headers -API $APIName -tenant $Gate.Tenant -message $Result -sev Info
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -After $After -DryRun $false -Result 'Success'
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{ Results = $Result; Status = 'Success'; AuditId = $AuditId; Before = $Before; After = $After; Rollback = $Rollback; ticketNumber = $Gate.Ticket; dryRun = $false }
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Message = $ErrorMessage.NormalizedError
        Write-LogMessage -Headers $Headers -API $APIName -tenant $Gate.Tenant -message "Failed setting transport rule $($Identity) to $($State). Error:$Message" -Sev 'Error' -LogData $ErrorMessage
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -DryRun $false -Result $Message
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::InternalServerError; Body = @{ Results = $Message; Status = 'Failed'; AuditId = $AuditId; Before = $Before; Rollback = $Rollback } }
    }
}

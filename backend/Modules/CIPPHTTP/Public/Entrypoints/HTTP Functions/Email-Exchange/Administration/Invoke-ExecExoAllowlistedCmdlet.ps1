function Invoke-ExecExoAllowlistedCmdlet {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.Security.ReadWrite
    .DESCRIPTION
        Runs one allowlisted Exchange cmdlet. Any other cmdlet or parameter returns 403 and is audited. Requires tenantFilter, ticketNumber (6 to 8 digits), and dryRun.
        Set-Mailbox: Identity and CustomAttribute1 through CustomAttribute15.
        New-ServicePrincipal: AppId, ObjectId, ServiceId, DisplayName.
        New-ManagementScope: Name and RecipientRestrictionFilter (1024 characters max).
        New-ManagementRoleAssignment: App, Role, CustomResourceScope, Name. Role must be exactly Application Mail.Read, Application Calendars.Read, or Application Mail.ReadBasic.
        Remove-ManagementRoleAssignment: Identity. Remove-ServicePrincipal: Identity. Remove-ManagementScope: Identity.
        Test-ServicePrincipalAuthorization: Identity and Resource. Test-ApplicationAccessPolicy: Identity and AppId.
        Enable-OrganizationCustomization takes no parameters. Set-AdminAuditLogConfig: UnifiedAuditLogIngestionEnabled boolean.
        Set-MailboxJunkEmailConfiguration: Identity, TrustedSendersAndDomains, and BlockedSendersAndDomains. TrustedSendersToAdd and BlockedSendersToAdd are rejected.
        Set-AcceptedDomain: Identity (trimmed domain name, 1-253 characters) and DomainType (Authoritative, InternalRelay, or ExternalRelay).
        Set-DkimSigningConfig: Identity (trimmed domain name) and Enabled (true/false/1/0, coerced to bool).
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Gate = Test-CIPPGuardedWriteRequest -Request $Request -IsWrite
    if (-not $Gate.Ok) {
        $Headers = @{}
        if ($Gate.StatusCode -eq 429) { $Headers['Retry-After'] = [string]$Gate.RetryAfter }
        return [HttpResponseContext]@{ StatusCode = $Gate.StatusCode; Headers = $Headers; Body = @{ Results = $Gate.Message; Status = 'Failed' } }
    }

    $Cmdlet = [string]$Request.Body.Cmdlet
    $Plan = Get-CIPPExoAllowlistedCmdletPlan -Cmdlet $Cmdlet -Parameters $Request.Body.Parameters
    if (-not $Plan.Allowed) {
        $Code = if ($Plan.Reason -match 'not on the allowlist|not allowed on') { [HttpStatusCode]::Forbidden } else { [HttpStatusCode]::BadRequest }
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -DryRun $Gate.WhatIf -Result $Plan.Reason
        return [HttpResponseContext]@{ StatusCode = $Code; Body = @{ Results = $Plan.Reason; Status = 'Failed'; AuditId = $AuditId } }
    }

    $Before = $null
    if ($Cmdlet -like 'Set-*' -or $Cmdlet -like 'Remove-*') {
        $GetCmdlet = $Cmdlet -replace '^(Set|Remove)-', 'Get-'
        try {
            $GetParams = @{}
            if ($Plan.Parameters.ContainsKey('Identity')) { $GetParams.Identity = $Plan.Parameters.Identity }
            $Before = New-ExoRequest -tenantid $Gate.Tenant -cmdlet $GetCmdlet -cmdParams $GetParams -useSystemMailbox $true
        } catch {
            $Before = $null
        }
    }

    $WhatIfPlan = @([pscustomobject]@{ Cmdlet = $Plan.Cmdlet; Parameters = $Plan.Parameters })
    if ($Gate.WhatIf) {
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -DryRun $true -Result 'DryRun'
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{ Results = "Would run $Cmdlet"; Status = 'DryRun'; AuditId = $AuditId; Before = $Before; After = $null; WhatIfPlan = $WhatIfPlan }
        }
    }

    try {
        $After = New-ExoRequest -tenantid $Gate.Tenant -cmdlet $Plan.Cmdlet -cmdParams $Plan.Parameters -useSystemMailbox $true
        $Summary = "$Cmdlet completed for $($Gate.Tenant)."
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $Gate.Tenant -message $Summary -Sev 'Info'
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -After $After -DryRun $false -Result 'Success'
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{ Results = $Summary; Status = 'Success'; AuditId = $AuditId; Before = $Before; After = $After; WhatIfPlan = @() }
        }
    } catch {
        $Message = $_.Exception.Message
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -DryRun $false -Result $Message
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::InternalServerError; Body = @{ Results = $Message; Status = 'Failed'; AuditId = $AuditId; Before = $Before } }
    }
}

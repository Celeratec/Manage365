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
        Set-AcceptedDomain: Identity (domain name, 1-253 characters, no leading/trailing whitespace, no control characters, each label ≤63 characters) and DomainType (Authoritative, InternalRelay, or ExternalRelay).
        Set-DkimSigningConfig: Identity (domain name, same constraints as Set-AcceptedDomain) and Enabled (true/false/1/0, coerced to bool).
        Disable-Mailbox: Identity, Archive (must be true), and Confirm (must be false). Only archive disable is allowed; full mailbox disable is rejected.
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
    if ($Cmdlet -like 'Set-*' -or $Cmdlet -like 'Remove-*' -or $Cmdlet -like 'Disable-*') {
        $GetCmdlet = $Cmdlet -replace '^(Set|Remove|Disable)-', 'Get-'
        try {
            $GetParams = @{}
            if ($Plan.Parameters.ContainsKey('Identity')) { $GetParams.Identity = $Plan.Parameters.Identity }
            $Before = New-ExoRequest -tenantid $Gate.Tenant -cmdlet $GetCmdlet -cmdParams $GetParams -useSystemMailbox $true
        } catch {
            $Before = $null
        }
    }

    if ($Cmdlet -eq 'Disable-Mailbox' -and $Plan.Parameters.Archive -eq $true) {
        if ($null -eq $Before) {
            $Reason = 'Failed to read mailbox state. Verify the Identity and tenant permissions.'
            $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -DryRun $Gate.WhatIf -Result $Reason
            return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = $Reason; Status = 'Failed'; AuditId = $AuditId; Before = $Before } }
        }
        $HasArchive = $false
        $ParsedGuid = [guid]::Empty
        $HasValidGuid = [guid]::TryParse($Before.ArchiveGuid, [ref]$ParsedGuid) -and $ParsedGuid -ne [guid]::Empty
        $HasActiveArchive = $Before.ArchiveStatus -eq 'Active' -or $null -ne $Before.ArchiveDatabase
        if ($HasValidGuid -and $HasActiveArchive) {
            $HasArchive = $true
        }
        if (-not $HasArchive) {
            $Reason = 'Mailbox has no active archive to disable (ArchiveGuid is not a valid non-zero GUID, or ArchiveStatus is not Active and ArchiveDatabase is null).'
            $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -DryRun $Gate.WhatIf -Result $Reason
            return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = $Reason; Status = 'Failed'; AuditId = $AuditId; Before = $Before } }
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
        if ($Cmdlet -like 'Disable-*' -and $Plan.Parameters.ContainsKey('Identity')) {
            try {
                $GetCmdlet = $Cmdlet -replace '^Disable-', 'Get-'
                $After = New-ExoRequest -tenantid $Gate.Tenant -cmdlet $GetCmdlet -cmdParams @{ Identity = $Plan.Parameters.Identity } -useSystemMailbox $true
            } catch {
                $After = $null
            }
        }
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

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
        Set-TransportRule: Identity plus Mode (Audit|AuditAndNotify|Enforce) and/or Priority (integer >= 0). Also requires Exchange.TransportRule.ReadWrite; dryRun defaults to true for transport-rule cmdlets.
        Enable-TransportRule / Disable-TransportRule: Identity only; same TransportRule role and dryRun default.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $CmdletPeek = [string]$Request.Body.Cmdlet
    $TransportCmdlets = @('Set-TransportRule', 'Enable-TransportRule', 'Disable-TransportRule')
    $IsTransport = $CmdletPeek -in $TransportCmdlets
    if ($IsTransport) {
        $Gate = Test-CIPPGuardedWriteRequest -Request $Request -IsWrite -DefaultDryRun
    } else {
        $Gate = Test-CIPPGuardedWriteRequest -Request $Request -IsWrite
    }
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

    if ($Cmdlet -in $TransportCmdlets) {
        $Permissions = @(Get-CippRequestAllowedPermissions)
        if ($Permissions -notcontains 'Exchange.TransportRule.ReadWrite') {
            $Reason = 'Transport-rule cmdlets through ExecExoAllowlistedCmdlet require Exchange.TransportRule.ReadWrite.'
            $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -DryRun $Gate.WhatIf -Result $Reason
            return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::Forbidden; Body = @{ Results = $Reason; Status = 'Failed'; AuditId = $AuditId } }
        }
    }

    function Get-CIPPTransportRuleProjection {
        param($Rule)
        return [pscustomobject]@{
            Name            = [string]$Rule.Name
            Guid            = [string]$Rule.Guid
            Priority        = [int]$Rule.Priority
            State           = [string]$Rule.State
            Mode            = [string]$Rule.Mode
            RuleErrorAction = [string]$Rule.RuleErrorAction
        }
    }

    $Before = $null
    $BeforeList = $null
    $Rollback = $null
    if ($Cmdlet -eq 'Set-TransportRule') {
        try {
            $AllRules = @(New-ExoRequest -tenantid $Gate.Tenant -cmdlet 'Get-TransportRule' -cmdParams @{} -useSystemMailbox $true)
        } catch {
            $AllRules = @()
        }
        $BeforeList = @($AllRules | ForEach-Object { Get-CIPPTransportRuleProjection $_ } | Sort-Object Priority, Name)
        $Target = $AllRules | Where-Object {
            [string]$_.Guid -eq $Plan.Parameters.Identity -or [string]$_.Name -eq $Plan.Parameters.Identity -or [string]$_.Identity -eq $Plan.Parameters.Identity
        } | Select-Object -First 1
        if (-not $Target) {
            $Reason = 'Transport rule not found.'
            $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $BeforeList -DryRun $Gate.WhatIf -Result $Reason
            return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = $Reason; Status = 'Failed'; AuditId = $AuditId; Before = $BeforeList } }
        }
        $Before = Get-CIPPTransportRuleProjection $Target
        if ($Plan.Parameters.ContainsKey('Priority')) {
            $N = $BeforeList.Count
            if ($Plan.Parameters.Priority -gt ($N - 1) -or $Plan.Parameters.Priority -lt 0) {
                $Reason = "Priority must be between 0 and $($N - 1) for $N existing rules."
                $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $BeforeList -DryRun $Gate.WhatIf -Result $Reason
                return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = $Reason; Status = 'Failed'; AuditId = $AuditId; Before = $BeforeList } }
            }
            $Before = $BeforeList
        }
        $SameMode = (-not $Plan.Parameters.ContainsKey('Mode')) -or ([string]$Target.Mode -eq [string]$Plan.Parameters.Mode)
        $SamePri = (-not $Plan.Parameters.ContainsKey('Priority')) -or ([int]$Target.Priority -eq [int]$Plan.Parameters.Priority)
        if ($SameMode -and $SamePri) {
            $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -DryRun $Gate.WhatIf -Result 'NoChange'
            return [HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
                Body       = @{ Results = 'No change.'; Status = 'Success'; AuditId = $AuditId; Before = $Before; After = $Before; WhatIfPlan = @() }
            }
        }
        $RollbackParams = @{ Identity = $Plan.Parameters.Identity }
        if ($Plan.Parameters.ContainsKey('Mode')) { $RollbackParams.Mode = [string]$Target.Mode }
        if ($Plan.Parameters.ContainsKey('Priority')) { $RollbackParams.Priority = [int]$Target.Priority }
        $Rollback = @{ Cmdlet = 'Set-TransportRule'; Parameters = $RollbackParams }
    } elseif ($Cmdlet -like 'Set-*' -or $Cmdlet -like 'Remove-*' -or $Cmdlet -like 'Disable-*' -or $Cmdlet -eq 'Enable-TransportRule') {
        $GetCmdlet = if ($Cmdlet -eq 'Enable-TransportRule') { 'Get-TransportRule' } else { $Cmdlet -replace '^(Set|Remove|Disable|Enable)-', 'Get-' }
        try {
            $GetParams = @{}
            if ($Plan.Parameters.ContainsKey('Identity')) { $GetParams.Identity = $Plan.Parameters.Identity }
            $Before = New-ExoRequest -tenantid $Gate.Tenant -cmdlet $GetCmdlet -cmdParams $GetParams -useSystemMailbox $true
        } catch {
            $Before = $null
        }
        if ($Cmdlet -in @('Enable-TransportRule', 'Disable-TransportRule') -and $null -eq $Before) {
            $Reason = 'Transport rule not found.'
            $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -DryRun $Gate.WhatIf -Result $Reason
            return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = $Reason; Status = 'Failed'; AuditId = $AuditId } }
        }
        if ($Cmdlet -in @('Enable-TransportRule', 'Disable-TransportRule')) {
            $Rollback = @{
                Cmdlet     = $(if ($Cmdlet -eq 'Enable-TransportRule') { 'Disable-TransportRule' } else { 'Enable-TransportRule' })
                Parameters = @{ Identity = $Plan.Parameters.Identity }
            }
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
        $Body = @{ Results = "Would run $Cmdlet"; Status = 'DryRun'; AuditId = $AuditId; Before = $Before; After = $null; WhatIfPlan = $WhatIfPlan }
        if ($null -ne $Rollback) { $Body.Rollback = $Rollback }
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::OK; Body = $Body }
    }

    try {
        $After = New-ExoRequest -tenantid $Gate.Tenant -cmdlet $Plan.Cmdlet -cmdParams $Plan.Parameters -useSystemMailbox $true
        if ($Cmdlet -eq 'Set-TransportRule') {
            $AllAfter = @(New-ExoRequest -tenantid $Gate.Tenant -cmdlet 'Get-TransportRule' -cmdParams @{} -useSystemMailbox $true)
            $AfterList = @($AllAfter | ForEach-Object { Get-CIPPTransportRuleProjection $_ } | Sort-Object Priority, Name)
            $TargetAfter = $AllAfter | Where-Object {
                [string]$_.Guid -eq $Plan.Parameters.Identity -or [string]$_.Name -eq $Plan.Parameters.Identity -or [string]$_.Identity -eq $Plan.Parameters.Identity
            } | Select-Object -First 1
            if (-not $TargetAfter) {
                throw 'Transport rule missing after Set-TransportRule.'
            }
            if ($Plan.Parameters.ContainsKey('Mode') -and [string]$TargetAfter.Mode -ne [string]$Plan.Parameters.Mode) {
                throw "Mode mismatch after Set-TransportRule: expected $($Plan.Parameters.Mode), got $($TargetAfter.Mode)."
            }
            if ($Plan.Parameters.ContainsKey('Priority') -and [int]$TargetAfter.Priority -ne [int]$Plan.Parameters.Priority) {
                throw "Priority mismatch after Set-TransportRule: expected $($Plan.Parameters.Priority), got $($TargetAfter.Priority)."
            }
            # Other rules must keep Mode/State; relative order among non-targets preserved for Priority shifts
            if ($Plan.Parameters.ContainsKey('Priority')) {
                $BeforeByGuid = @{}
                foreach ($Row in @($BeforeList)) { $BeforeByGuid[[string]$Row.Guid] = $Row }
                foreach ($Row in $AfterList) {
                    if ([string]$Row.Guid -eq [string](Get-CIPPTransportRuleProjection $TargetAfter).Guid) { continue }
                    $Prev = $BeforeByGuid[[string]$Row.Guid]
                    if ($Prev -and ([string]$Prev.Mode -ne [string]$Row.Mode -or [string]$Prev.State -ne [string]$Row.State)) {
                        throw "Unexpected Mode/State change on rule $($Row.Name) after Priority update."
                    }
                }
                $After = $AfterList
            } else {
                $After = Get-CIPPTransportRuleProjection $TargetAfter
            }
        } elseif ($Cmdlet -like 'Disable-*' -and $Plan.Parameters.ContainsKey('Identity')) {
            try {
                $GetCmdlet = $Cmdlet -replace '^Disable-', 'Get-'
                $After = New-ExoRequest -tenantid $Gate.Tenant -cmdlet $GetCmdlet -cmdParams @{ Identity = $Plan.Parameters.Identity } -useSystemMailbox $true
            } catch {
                $After = $null
            }
        } elseif ($Cmdlet -eq 'Enable-TransportRule' -and $Plan.Parameters.ContainsKey('Identity')) {
            try {
                $After = New-ExoRequest -tenantid $Gate.Tenant -cmdlet 'Get-TransportRule' -cmdParams @{ Identity = $Plan.Parameters.Identity } -useSystemMailbox $true
            } catch {
                $After = $null
            }
        }
        $Summary = "$Cmdlet completed for $($Gate.Tenant)."
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $Gate.Tenant -message $Summary -Sev 'Info'
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -After $After -DryRun $false -Result 'Success'
        $Body = @{ Results = $Summary; Status = 'Success'; AuditId = $AuditId; Before = $Before; After = $After; WhatIfPlan = @() }
        if ($null -ne $Rollback) { $Body.Rollback = $Rollback }
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::OK; Body = $Body }
    } catch {
        $Message = $_.Exception.Message
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -DryRun $false -Result $Message
        $Body = @{ Results = $Message; Status = 'Failed'; AuditId = $AuditId; Before = $Before }
        if ($null -ne $Rollback) { $Body.Rollback = $Rollback }
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::InternalServerError; Body = $Body }
    }
}

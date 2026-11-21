function Invoke-CIPPAzArmWriteAction {
    <#
    .SYNOPSIS
        Shared runner for ExecAz* / ListAzWebAppSettingNames: ticket gate, dryRun default true, before/after, audit.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        $Request,

        [scriptblock]$Transport
    )

    $APIName = [string]($Request.Params.CIPPEndpoint ?? $Action)
    $Gate = Test-CIPPGuardedWriteRequest -Request $Request -IsWrite -DefaultDryRun
    if (-not $Gate.Ok) {
        $Body = @{ Results = $Gate.Message; Status = 'Failed' }
        if ($Gate.StatusCode -eq 429 -and $null -ne $Gate.RetryAfter) { $Body.RetryAfter = $Gate.RetryAfter }
        return [HttpResponseContext]@{ StatusCode = $Gate.StatusCode; Body = $Body }
    }
    if ([string]::IsNullOrWhiteSpace($Gate.Reason)) {
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -DryRun $Gate.WhatIf -Result 'reason is required.'
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'reason is required.'; Status = 'Failed'; AuditId = $AuditId } }
    }

    $Config = Get-CIPPAzArmTenantConfig -TenantFilter $Gate.Tenant
    $Params = @{}
    if ($Request.Body) {
        if ($Request.Body -is [hashtable]) {
            foreach ($Key in @($Request.Body.Keys)) { $Params[$Key] = $Request.Body[$Key] }
        } else {
            foreach ($Prop in $Request.Body.PSObject.Properties) { $Params[$Prop.Name] = $Prop.Value }
        }
    }

    $Plan = Get-CIPPAzArmWritePlan -Action $Action -Config $Config -Params $Params -TicketNumber $Gate.Ticket
    if (-not $Plan.Allowed) {
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -DryRun $Gate.WhatIf -Result $Plan.Reason
        $Code = if ($Plan.Reason -match 'not on the Azure ARM|not allowlisted|refused') { [HttpStatusCode]::Forbidden } else { [HttpStatusCode]::BadRequest }
        return [HttpResponseContext]@{ StatusCode = $Code; Body = @{ Results = $Plan.Reason; Status = 'Failed'; AuditId = $AuditId } }
    }

    try {
        $TokenInfo = Get-CIPPAzArmAccessToken -TenantFilter $Gate.Tenant -Profile $Plan.Profile -Config $Config
        $AccessToken = if ($TokenInfo -is [string]) { $TokenInfo } else { [string]$TokenInfo.AccessToken }
    } catch {
        $Msg = [string]$_.Exception.Message
        if ($Msg -match '(?i)bearer\s+[A-Za-z0-9\-._~+/]+=*') {
            $Msg = $Msg -replace '(?i)bearer\s+[A-Za-z0-9\-._~+/]+=*', 'Bearer [redacted]'
        }
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -DryRun $Gate.WhatIf -Result $Msg
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::Forbidden; Body = @{ Results = $Msg; Status = 'Failed'; AuditId = $AuditId } }
    }

    $Before = $null
    if ($Plan.GetPath -and $Action -ne 'ListAzWebAppSettingNames') {
        try {
            $BeforeResult = Invoke-CIPPAzArmRequest -AccessToken $AccessToken -Method GET -Path $Plan.GetPath -ApiVersion $Plan.GetApiVersion -Classification read -Transport $Transport
            $Before = $BeforeResult.Results | Select-Object -First 1
        } catch {
            $Before = $null
        }
    }

    if ($Plan.CreateOnly -and $null -ne $Before) {
        $Reason = 'Resource already exists; set allowUpdate:true to update, or choose a new name.'
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -DryRun $Gate.WhatIf -Result $Reason
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = $Reason; Status = 'Failed'; AuditId = $AuditId; Before = $Before } }
    }

    if ($Action -eq 'ExecAzDelete') {
        if ($null -eq $Before) {
            $Reason = 'Resource not found; nothing to delete.'
            $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -DryRun $Gate.WhatIf -Result $Reason
            return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = $Reason; Status = 'Failed'; AuditId = $AuditId } }
        }
        $Tags = @{}
        if ($Before.tags) {
            if ($Before.tags -is [hashtable]) { $Tags = @{} + $Before.tags }
            else { foreach ($P in $Before.tags.PSObject.Properties) { $Tags[$P.Name] = [string]$P.Value } }
        }
        if ([string]$Tags['managedBy'] -ne 'manage365' -or [string]$Tags['ticket'] -ne [string]$Gate.Ticket) {
            $Reason = 'ExecAzDelete only removes resources tagged managedBy=manage365 with the same ticketNumber.'
            $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -DryRun $Gate.WhatIf -Result $Reason
            return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::Forbidden; Body = @{ Results = $Reason; Status = 'Failed'; AuditId = $AuditId; Before = $Before } }
        }
    }

    $WhatIfPlan = @($Plan.Requests | ForEach-Object {
            [pscustomobject]@{
                Method         = $_.Method
                Path           = $_.Path
                ApiVersion     = $_.ApiVersion
                Classification = $_.Classification
                BodyRedacted   = if ($_.MergeAppSettings) { @{ names = @($_.Body.Keys) } } else { $_.Body }
            }
        })

    if ($Gate.WhatIf -or $Action -eq 'ListAzWebAppSettingNames') {
        if ($Action -eq 'ListAzWebAppSettingNames') {
            # Always executes the sensitive read (change profile); never returns secret values.
            $Req = $Plan.Requests[0]
            $Raw = Invoke-CIPPAzArmRequest -AccessToken $AccessToken -Method $Req.Method -Path $Req.Path -ApiVersion $Req.ApiVersion `
                -Classification readSensitive -PermitDenyFragment $Req.PermitDenyFragment -Body $Req.Body -Transport $Transport
            $Props = $Raw.Raw.properties ?? $Raw.Raw
            $Names = @()
            $Refs = @{}
            if ($Props) {
                $Bag = @{}
                if ($Props -is [hashtable]) { $Bag = $Props }
                else { foreach ($P in $Props.PSObject.Properties) { $Bag[$P.Name] = [string]$P.Value } }
                foreach ($Key in @($Bag.Keys)) {
                    $Names += $Key
                    $Val = [string]$Bag[$Key]
                    if ($Val -match '^@Microsoft\.KeyVault\(') { $Refs[$Key] = $Val }
                }
            }
            $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -DryRun $false -Result 'Success'
            return [HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
                Body       = @{
                    Results            = [pscustomobject]@{ Names = $Names; KeyVaultReferences = $Refs }
                    Status             = 'Success'
                    AuditId            = $AuditId
                    AccessProfile      = $Plan.Profile
                    ticketNumber       = $Gate.Ticket
                }
            }
        }

        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -DryRun $true -Result 'DryRun'
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{
                Results       = "Would run $Action"
                Status        = 'DryRun'
                AuditId       = $AuditId
                Before        = $Before
                After         = $null
                WhatIfPlan    = $WhatIfPlan
                Rollback      = $Plan.Rollback
                AccessProfile = $Plan.Profile
                ticketNumber  = $Gate.Ticket
                dryRun        = $true
            }
        }
    }

    try {
        foreach ($Req in $Plan.Requests) {
            $BodyToSend = $Req.Body
            if ($Req.MergeAppSettings) {
                # Read-merge-write: GET existing names via allowlisted list is change-profile only;
                # for merge we GET the site and PUT only the provided keys overlay when existing unknown —
                # use empty base then overlay (caller supplies full desired set for new apps).
                $Merged = @{}
                if ($null -ne $Before -and $Before.properties -and $Before.properties.siteConfig) {
                    # cannot read secret values from site GET; merge is overlay-only of requested keys
                }
                foreach ($Key in @($Req.Body.Keys)) { $Merged[$Key] = $Req.Body[$Key] }
                $BodyToSend = $Merged
            }
            $null = Invoke-CIPPAzArmRequest -AccessToken $AccessToken -Method $Req.Method -Path $Req.Path -ApiVersion $Req.ApiVersion `
                -Classification $Req.Classification -Body $BodyToSend -PermitDenyFragment $Req.PermitDenyFragment `
                -Transport $Transport
        }

        $After = $null
        if ($Plan.GetPath) {
            try {
                $AfterResult = Invoke-CIPPAzArmRequest -AccessToken $AccessToken -Method GET -Path $Plan.GetPath -ApiVersion $Plan.GetApiVersion -Classification read -Transport $Transport
                $After = $AfterResult.Results | Select-Object -First 1
            } catch {
                $After = $null
            }
        }

        if ($Action -eq 'ExecAzDelete') {
            if ($null -ne $After) {
                $Reason = 'Delete reported success but resource still exists.'
                $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -After $After -DryRun $false -Result $Reason
                return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::OK; Body = @{ Results = $Reason; Status = 'Failed'; AuditId = $AuditId; Before = $Before; After = $After; Rollback = $Plan.Rollback } }
            }
        } elseif ($Plan.GetPath -and $null -eq $After -and $Action -ne 'ExecAzResourceProvider') {
            $Reason = 'After state could not be read; treat as Failed.'
            $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -After $After -DryRun $false -Result $Reason
            return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::OK; Body = @{ Results = $Reason; Status = 'Failed'; AuditId = $AuditId; Before = $Before; After = $After; Rollback = $Plan.Rollback } }
        }

        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -After $After -DryRun $false -Result 'Success'
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{
                Results       = "$Action completed."
                Status        = 'Success'
                AuditId       = $AuditId
                Before        = $Before
                After         = $After
                Rollback      = $Plan.Rollback
                Applied       = $WhatIfPlan
                AccessProfile = $Plan.Profile
                ticketNumber  = $Gate.Ticket
                dryRun        = $false
            }
        }
    } catch {
        $Msg = [string]$_.Exception.Message
        if ($Msg -match '(?i)bearer\s+[A-Za-z0-9\-._~+/]+=*') {
            $Msg = $Msg -replace '(?i)bearer\s+[A-Za-z0-9\-._~+/]+=*', 'Bearer [redacted]'
        }
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -DryRun $false -Result $Msg
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::InternalServerError; Body = @{ Results = $Msg; Status = 'Failed'; AuditId = $AuditId; Before = $Before; Rollback = $Plan.Rollback } }
    }
}

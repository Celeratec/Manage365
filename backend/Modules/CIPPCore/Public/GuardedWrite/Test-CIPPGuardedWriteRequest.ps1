function Test-CIPPGuardedWriteRequest {
    <#
    .SYNOPSIS
        Validates the shared ticket, tenant, and rate-limit envelope for a guarded write.
    .DESCRIPTION
        ticketNumber must be 6 to 8 digits. dryRun accepts only real booleans, 1, and 0.
        TicketNumber and WhatIf are accepted as the same fields. Each worker allows 100
        requests per 10 seconds per caller and 10 writes per minute per tenant. A limited
        request returns Ok false and StatusCode 429.
    #>
    [CmdletBinding()]
    param(
        $Request,
        [switch]$IsWrite
    )

    $Tenant = [string]($Request.Body.tenantFilter | Select-Object -First 1)
    $Ticket = [string]($Request.Body.ticketNumber | Select-Object -First 1)
    if ([string]::IsNullOrWhiteSpace($Ticket)) {
        $Ticket = [string]($Request.Body.TicketNumber | Select-Object -First 1)
    }
    $Reason = [string]$Request.Body.reason
    if ([string]::IsNullOrWhiteSpace($Reason)) { $Reason = [string]$Request.Body.Reason }
    if ([string]::IsNullOrWhiteSpace($Tenant)) {
        return [pscustomobject]@{ Ok = $false; StatusCode = 400; Message = 'tenantFilter is required.' }
    }
    if ($Ticket -notmatch '^\d{6,8}$') {
        return [pscustomobject]@{ Ok = $false; StatusCode = 400; Message = 'ticketNumber must be 6 to 8 digits.' }
    }

    $DryRunRaw = $Request.Body.dryRun
    if ($null -eq $DryRunRaw -or "$DryRunRaw" -eq '') { $DryRunRaw = $Request.Body.WhatIf }
    $WhatIf = $false
    if ($null -ne $DryRunRaw -and "$DryRunRaw" -ne '') {
        if ("$DryRunRaw" -notin @('true', 'false', '1', '0', 'True', 'False')) {
            return [pscustomobject]@{ Ok = $false; StatusCode = 400; Message = 'dryRun must be true or false.' }
        }
        $WhatIf = "$DryRunRaw" -in @('true', 'True', '1')
    }

    $Caller = 'API'
    $Principal = [string]$Request.Headers.'x-ms-client-principal-name'
    if (-not [string]::IsNullOrWhiteSpace($Principal)) { $Caller = $Principal }

    if (-not $script:CIPPGuardedWriteHits) {
        $script:CIPPGuardedWriteHits = [System.Collections.Generic.List[object]]::new()
    }
    $Now = [datetime]::UtcNow
    $CallerHits = @($script:CIPPGuardedWriteHits | Where-Object { $_.Caller -eq $Caller -and $_.At -gt $Now.AddSeconds(-10) })
    if ($CallerHits.Count -ge 100) {
        return [pscustomobject]@{ Ok = $false; StatusCode = 429; RetryAfter = 10; Message = 'Too many requests for this caller.' }
    }
    if ($IsWrite) {
        $TenantWrites = @($script:CIPPGuardedWriteHits | Where-Object { $_.Tenant -eq $Tenant -and $_.Write -and $_.At -gt $Now.AddMinutes(-1) })
        if ($TenantWrites.Count -ge 10) {
            return [pscustomobject]@{ Ok = $false; StatusCode = 429; RetryAfter = 60; Message = 'Too many writes for this tenant.' }
        }
    }
    $script:CIPPGuardedWriteHits.Add([pscustomobject]@{ Caller = $Caller; Tenant = $Tenant; Write = [bool]$IsWrite; At = $Now })

    return [pscustomobject]@{
        Ok         = $true
        StatusCode = 200
        Tenant     = $Tenant
        Ticket     = $Ticket
        WhatIf     = $WhatIf
        DryRun     = $WhatIf
        Reason     = $Reason
        Caller     = $Caller
    }
}

function Invoke-ExecSecurityDefaults {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.AppGovernance.ReadWrite
    .DESCRIPTION
        Reads or sets identity security defaults. Enabling warns when Conditional Access policies already exist.
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

    $Uri = 'https://graph.microsoft.com/v1.0/policies/identitySecurityDefaultsEnforcementPolicy'
    $Before = New-GraphGetRequest -uri $Uri -tenantid $Gate.Tenant -asApp $true -noPagination $true
    $EnabledRaw = $Request.Body.Enabled
    if ($null -eq $EnabledRaw -or "$EnabledRaw" -eq '') {
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -After $Before -DryRun $Gate.WhatIf -Result 'Success'
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::OK; Body = @{ Results = 'Security defaults read.'; Status = 'Success'; AuditId = $AuditId; Before = $Before; After = $Before; WhatIfPlan = @() } }
    }
    if ("$EnabledRaw" -notin @('true', 'false', 'True', 'False', '1', '0')) {
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'Enabled must be true or false.'; Status = 'Failed' } }
    }
    $Enabled = "$EnabledRaw" -in @('true', 'True', '1')
    $Warning = $null
    if ($Enabled) {
        $Policies = @(New-GraphGetRequest -uri 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies' -tenantid $Gate.Tenant -asApp $true)
        if ($Policies.Count -gt 0) { $Warning = 'Conditional Access policies exist. Enabling security defaults disables those policies.' }
    }
    if ($Gate.WhatIf) {
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -DryRun $true -Result 'DryRun'
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{ Results = "Would set security defaults to $Enabled."; Status = 'DryRun'; AuditId = $AuditId; Before = $Before; Warning = $Warning; WhatIfPlan = @(@{ isEnabled = $Enabled }) }
        }
    }
    $After = New-GraphPOSTRequest -uri $Uri -tenantid $Gate.Tenant -type PATCH -body (@{ isEnabled = $Enabled } | ConvertTo-Json -Compress) -asApp $true
    $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -After $After -DryRun $false -Result 'Success'
    Write-LogMessage -headers $Request.Headers -API $APIName -tenant $Gate.Tenant -message "Set security defaults to $Enabled." -Sev 'Info'
    return [HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = @{ Results = "Security defaults set to $Enabled."; Status = 'Success'; AuditId = $AuditId; Before = $Before; After = $After; Warning = $Warning; WhatIfPlan = @() }
    }
}

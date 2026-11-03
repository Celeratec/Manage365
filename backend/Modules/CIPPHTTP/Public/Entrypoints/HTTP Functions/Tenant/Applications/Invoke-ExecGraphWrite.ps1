function Invoke-ExecGraphWrite {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.AppGovernance.ReadWrite
    .DESCRIPTION
        Graph POST, PATCH, or DELETE limited to the server-side allowlist. Reads the resource first and records it as Before. AllPrincipals consent requires Tenant.AppGovernance.AllPrincipals.
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

    $Method = $Request.Body.Method
    $Path = $Request.Body.Path
    $ApiVersion = $Request.Body.ApiVersion
    $WriteBody = $Request.Body.Body
    $Permissions = @(Get-CippRequestAllowedPermissions)
    $Plan = Get-CIPPGraphWritePlan -Method $Method -Path $Path -ApiVersion $ApiVersion -Body $WriteBody -AllowAllPrincipals:($Permissions -contains 'Tenant.AppGovernance.AllPrincipals')
    if (-not $Plan.Allowed) {
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -DryRun $Gate.WhatIf -Result $Plan.Reason
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::Forbidden; Body = @{ Results = $Plan.Reason; Status = 'Failed'; AuditId = $AuditId } }
    }

    $Before = $null
    try {
        $Before = New-GraphGetRequest -uri $Plan.Uri -tenantid $Gate.Tenant -asApp $true -noPagination $true -SkipValueExtraction
    } catch {
        $Before = $null
    }

    if ($Gate.WhatIf) {
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -DryRun $true -Result 'DryRun'
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{ Results = "Would $Method $Path"; Status = 'DryRun'; AuditId = $AuditId; Before = $Before; After = $null; WhatIfPlan = @($Plan) }
        }
    }

    try {
        $Payload = if ($null -eq $Plan.Body) { $null } else { $Plan.Body | ConvertTo-Json -Depth 20 -Compress }
        if ($Plan.Method -eq 'DELETE') {
            $null = New-GraphPOSTRequest -uri $Plan.Uri -tenantid $Gate.Tenant -type DELETE -asApp $true
            $After = $null
        } else {
            $After = New-GraphPOSTRequest -uri $Plan.Uri -tenantid $Gate.Tenant -type $Plan.Method -body $Payload -asApp $true
        }
        $Summary = "$($Plan.Method) $($Plan.Uri) completed for $($Gate.Tenant)."
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

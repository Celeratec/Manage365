function Invoke-ExecPermissionGrantPreApproval {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.AppGovernance.ReadWrite
    .DESCRIPTION
        Creates, updates, or deletes a permission grant pre-approval policy. Scope type is group, chat, or tenant.
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

    $Action = [string]$Request.Body.Action
    $Id = [string]$Request.Body.Id
    if ($Action -notin @('Create', 'Update', 'Delete')) {
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'Action must be Create, Update, or Delete.'; Status = 'Failed' } }
    }
    if ($Action -in @('Update', 'Delete') -and [string]::IsNullOrWhiteSpace($Id)) {
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'Id is required for Update and Delete.'; Status = 'Failed' } }
    }
    foreach ($Condition in @($Request.Body.Conditions)) {
        if ($null -eq $Condition) { continue }
        if ([string]$Condition.scopeType -notin @('group', 'chat', 'tenant')) {
            return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'scopeType must be group, chat, or tenant.'; Status = 'Failed' } }
        }
    }

    $Base = 'https://graph.microsoft.com/beta/policies/permissionGrantPreApprovalPolicies'
    $Uri = if ($Action -eq 'Create') { $Base } else { "$Base/$Id" }
    $Before = $null
    if ($Action -ne 'Create') {
        try { $Before = New-GraphGetRequest -uri $Uri -tenantid $Gate.Tenant -asApp $true -noPagination $true } catch { $Before = $null }
    }
    $Method = switch ($Action) {
        'Create' { 'POST' }
        'Update' { 'PATCH' }
        'Delete' { 'DELETE' }
    }
    $Payload = if ($Action -eq 'Delete') { $null } else { @{ conditions = @($Request.Body.Conditions) } | ConvertTo-Json -Depth 12 -Compress }
    if ($Gate.WhatIf) {
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -DryRun $true -Result 'DryRun'
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{ Results = "Would $Action a permission grant pre-approval policy."; Status = 'DryRun'; AuditId = $AuditId; Before = $Before; WhatIfPlan = @(@{ Method = $Method; Uri = $Uri }) }
        }
    }
    $After = New-GraphPOSTRequest -uri $Uri -tenantid $Gate.Tenant -type $Method -body $Payload -asApp $true
    $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -After $After -DryRun $false -Result 'Success'
    return [HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = @{ Results = "$Action completed."; Status = 'Success'; AuditId = $AuditId; Before = $Before; After = $After; WhatIfPlan = @() }
    }
}

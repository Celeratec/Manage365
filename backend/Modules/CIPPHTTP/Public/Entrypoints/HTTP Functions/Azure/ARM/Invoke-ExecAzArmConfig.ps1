function Invoke-ExecAzArmConfig {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Azure.Resources.ReadWrite
    .DESCRIPTION
        Creates or updates the per-tenant Azure ARM access config (credential references only). Requires ticketNumber and dryRun. Does not call Azure Resource Manager.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $Gate = Test-CIPPGuardedWriteRequest -Request $Request -IsWrite
    if (-not $Gate.Ok) {
        $Headers = @{}
        if ($Gate.StatusCode -eq 429) { $Headers['Retry-After'] = [string]$Gate.RetryAfter }
        return [HttpResponseContext]@{ StatusCode = $Gate.StatusCode; Headers = $Headers; Body = @{ Results = $Gate.Message; Status = 'Failed' } }
    }

    $Mode = [string]$Request.Body.mode
    $SubscriptionId = [string]$Request.Body.subscriptionId
    $AllowedRgs = @($Request.Body.allowedResourceGroups)
    $Profiles = $Request.Body.profiles
    $Enabled = if ($null -eq $Request.Body.enabled) { $true } else { [bool]$Request.Body.enabled }
    $ManagingTenantId = [string]$Request.Body.managingTenantId
    $Notes = [string]$Request.Body.notes
    $ChangeWindow = $Request.Body.changeWindow

    if ($Mode -notin @('lighthouse', 'servicePrincipal')) {
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'mode must be lighthouse or servicePrincipal.'; Status = 'Failed' } }
    }
    if ($null -eq $Profiles) {
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'profiles object is required (reader/change/rbac credential references).'; Status = 'Failed' } }
    }
    $ProfileHash = @{}
    if ($Profiles -is [hashtable] -or $Profiles -is [System.Collections.IDictionary]) {
        foreach ($Key in @($Profiles.Keys)) { $ProfileHash[$Key] = $Profiles[$Key] }
    } else {
        foreach ($P in $Profiles.PSObject.Properties) { $ProfileHash[$P.Name] = $P.Value }
    }

    $Plan = [pscustomobject]@{
        Mode                  = $Mode
        SubscriptionId        = $SubscriptionId
        AllowedResourceGroups = $AllowedRgs
        ProfileNames          = @($ProfileHash.Keys)
        Enabled               = $Enabled
        ManagingTenantId      = $ManagingTenantId
    }

    if ($Gate.WhatIf) {
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint 'ExecAzArmConfig' -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -DryRun $true -Result 'DryRun'
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{ Results = 'Would upsert Azure ARM tenant config.'; Status = 'DryRun'; AuditId = $AuditId; WhatIfPlan = @($Plan) }
        }
    }

    try {
        $null = Set-CIPPAzArmTenantConfig -TenantFilter $Gate.Tenant -Mode $Mode -SubscriptionId $SubscriptionId `
            -AllowedResourceGroups $AllowedRgs -Profiles $ProfileHash -Enabled $Enabled `
            -ManagingTenantId $ManagingTenantId -Notes $Notes -ChangeWindow $ChangeWindow
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint 'ExecAzArmConfig' -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -DryRun $false -Result 'Success'
        $Safe = Get-CIPPAzArmTenantConfig -TenantFilter $Gate.Tenant
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{
                Results = [pscustomobject]@{
                    TenantFilter          = $Safe.TenantFilter
                    Mode                  = $Safe.Mode
                    SubscriptionId        = $Safe.SubscriptionId
                    AllowedResourceGroups = $Safe.AllowedResourceGroups
                    Enabled               = $Safe.Enabled
                    ProfileNames          = @($Safe.Profiles.Keys)
                }
                Status  = 'Success'
                AuditId = $AuditId
            }
        }
    } catch {
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = $_.Exception.Message; Status = 'Failed' } }
    }
}

function Invoke-ExecEdiscoveryConfig {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Security.Ediscovery.ReadWrite
    .DESCRIPTION
        Creates or updates dedicated per-tenant eDiscovery config references. dryRun defaults true and credential material is refused.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $null = $TriggerMetadata
    $GetBodyKeys = {
        param($Body)
        if ($null -eq $Body) { return @() }
        if ($Body -is [System.Collections.IDictionary]) { return @($Body.Keys) }
        return @($Body.PSObject.Properties.Name)
    }

    $ForbiddenKeys = @('pfx', 'privateKey', 'clientSecret', 'certificateBase64')
    $BodyKeys = @(& $GetBodyKeys $Request.Body)
    foreach ($Key in $BodyKeys) {
        if ([string]$Key -in $ForbiddenKeys) {
            return [HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{ Results = "Body key '$Key' is not allowed. Store credential material in Key Vault and submit secret names only."; Status = 'Failed' }
            }
        }
    }

    $Gate = Test-CIPPGuardedWriteRequest -Request $Request -IsWrite -DefaultDryRun
    if (-not $Gate.Ok) {
        $Headers = @{}
        if ($Gate.StatusCode -eq 429) { $Headers['Retry-After'] = [string]$Gate.RetryAfter }
        return [HttpResponseContext]@{ StatusCode = $Gate.StatusCode; Headers = $Headers; Body = @{ Results = $Gate.Message; Status = 'Failed' } }
    }
    if ([string]::IsNullOrWhiteSpace([string]$Gate.Reason)) {
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'reason is required for eDiscovery config changes.'; Status = 'Failed' }
        }
    }

    $AppId = [string]$Request.Body.appId
    $CertificateSecretName = [string]$Request.Body.certificateSecretName
    $CertificatePasswordSecretName = [string]$Request.Body.certificatePasswordSecretName
    $Enabled = if ($null -eq $Request.Body.enabled) { $true } else { [bool]$Request.Body.enabled }
    $Notes = [string]$Request.Body.notes

    $Plan = [pscustomobject]@{
        TenantFilter                         = [string]$Gate.Tenant
        AppId                                = $AppId
        CertificateSecretName                = $CertificateSecretName
        CertificatePasswordSecretNamePresent = -not [string]::IsNullOrWhiteSpace($CertificatePasswordSecretName)
        Enabled                              = $Enabled
    }

    if ($Gate.WhatIf) {
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint 'ExecEdiscoveryConfig' -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -DryRun $true -Result 'DryRun'
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{ Results = 'Would upsert eDiscovery tenant config.'; Status = 'DryRun'; AuditId = $AuditId; WhatIfPlan = @($Plan) }
        }
    }

    try {
        $Before = Get-CIPPEdiscoveryTenantConfig -TenantFilter $Gate.Tenant
        $After = Set-CIPPEdiscoveryTenantConfig -TenantFilter $Gate.Tenant -AppId $AppId `
            -CertificateSecretName $CertificateSecretName -CertificatePasswordSecretName $CertificatePasswordSecretName `
            -Enabled $Enabled -Notes $Notes
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint 'ExecEdiscoveryConfig' -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -After $After -DryRun $false -Result 'Success'
        $Safe = [pscustomobject]@{
            TenantFilter          = [string]$After.TenantFilter
            AppId                 = [string]$After.AppId
            CertificateSecretName = [string]$After.CertificateSecretName
            Enabled               = [bool]$After.Enabled
            Notes                 = [string]$After.Notes
        }
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{ Results = $Safe; Status = 'Success'; AuditId = $AuditId }
        }
    } catch {
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = $_.Exception.Message; Status = 'Failed' }
        }
    }
}

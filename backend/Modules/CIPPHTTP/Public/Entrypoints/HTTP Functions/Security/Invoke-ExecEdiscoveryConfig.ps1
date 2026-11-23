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
    $ForbiddenKeys = @('pfx', 'privateKey', 'clientSecret', 'certificateBase64')
    $CollectBodyKeys = {
        param($Node, $Keys)
        if ($null -eq $Node) { return }
        if ($Node -is [string]) { return }
        if ($Node -is [System.Collections.IDictionary]) {
            foreach ($Key in @($Node.Keys)) {
                $Keys.Add([string]$Key) | Out-Null
                & $CollectBodyKeys $Node[$Key] $Keys
            }
            return
        }
        if ($Node -is [System.Collections.IEnumerable]) {
            foreach ($Item in $Node) { & $CollectBodyKeys $Item $Keys }
            return
        }
        foreach ($Prop in @($Node.PSObject.Properties)) {
            $Keys.Add([string]$Prop.Name) | Out-Null
            & $CollectBodyKeys $Prop.Value $Keys
        }
    }

    $BodyKeys = [System.Collections.Generic.List[string]]::new()
    & $CollectBodyKeys $Request.Body $BodyKeys
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

    $TestKvSecretName = {
        param([string]$Name, [string]$FieldLabel)
        if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
        if ($Name -match '(?i)-----BEGIN|private.?key|\.pfx') {
            return "$FieldLabel must be a Key Vault secret name, not certificate material."
        }
        if ($Name -match '\s') {
            return "$FieldLabel must be a Key Vault secret name, not embedded credential material."
        }
        if ($Name.Length -gt 127) {
            return "$FieldLabel must be a Key Vault secret name, not embedded credential material."
        }
        if ($Name -match '(?i)^[A-Za-z0-9+/]{64,}=*$') {
            return "$FieldLabel must be a Key Vault secret name, not embedded credential material."
        }
        return $null
    }

    $CertificateSecretName = [string]$Request.Body.certificateSecretName
    $CertificatePasswordSecretName = [string]$Request.Body.certificatePasswordSecretName

    foreach ($Check in @(
            @{ Name = $CertificateSecretName; Label = 'certificateSecretName' }
            @{ Name = $CertificatePasswordSecretName; Label = 'certificatePasswordSecretName' }
        )) {
        $SecretError = & $TestKvSecretName $Check.Name $Check.Label
        if ($SecretError) {
            return [HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{ Results = $SecretError; Status = 'Failed' }
            }
        }
    }

    $AppId = [string]$Request.Body.appId
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
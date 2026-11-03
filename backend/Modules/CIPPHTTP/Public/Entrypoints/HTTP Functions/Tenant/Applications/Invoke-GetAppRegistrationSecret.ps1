function Invoke-GetAppRegistrationSecret {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.AppGovernance.ReadWrite
    .DESCRIPTION
        Returns the client secret stored by ExecAppRegistration exactly once, then deletes it from Key Vault. The secret can be retrieved for 24 hours after it was stored. It is not written to the log or the audit row. Requires tenantFilter, ticketNumber (6 to 8 digits), dryRun, AppId, and CredentialKeyId. dryRun does not read or delete the secret.
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

    $AppId = [string]$Request.Body.AppId
    $KeyId = [string]$Request.Body.CredentialKeyId
    $GuidPattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    if ($AppId -notmatch $GuidPattern -or $KeyId -notmatch $GuidPattern) {
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'AppId and CredentialKeyId must be the GUIDs returned by ExecAppRegistration.'; Status = 'Failed' } }
    }
    $SecretName = "appreg-$AppId-$KeyId"
    $AuditRequest = @{ AppId = $AppId; CredentialKeyId = $KeyId; tenantFilter = $Gate.Tenant }

    if ($Gate.DryRun) {
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $AuditRequest -DryRun $true -Result 'DryRun'
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{ Results = 'Would retrieve the application secret once.'; Status = 'DryRun'; AuditId = $AuditId; ticketNumber = $Gate.Ticket; dryRun = $true }
        }
    }

    try {
        $Stored = Get-CippKeyVaultSecret -Name $SecretName -IncludeAttributes
    } catch {
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $AuditRequest -DryRun $false -Result 'NotFound'
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::NotFound; Body = @{ Results = 'No retrievable secret exists for that application credential.'; Status = 'Failed'; AuditId = $AuditId } }
    }

    $Expired = $null -eq $Stored.Created -or $Stored.Created -lt [datetimeoffset]::UtcNow.AddHours(-24)
    if ($Expired) {
        try {
            Remove-CippKeyVaultSecret -Name $SecretName
        } catch {
            Write-LogMessage -headers $Request.Headers -API $APIName -tenant $Gate.Tenant -message "Expired application secret for $AppId could not be deleted." -Sev 'Error'
        }
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $AuditRequest -DryRun $false -Result 'Expired'
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::Gone; Body = @{ Results = 'The one-time secret link has expired.'; Status = 'Failed'; AuditId = $AuditId } }
    }

    try {
        Remove-CippKeyVaultSecret -Name $SecretName
    } catch {
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $AuditRequest -DryRun $false -Result 'DeleteFailed'
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::InternalServerError; Body = @{ Results = 'The secret could not be retired, so it was not returned.'; Status = 'Failed'; AuditId = $AuditId } }
    }

    $Value = [string]$Stored.Value
    $Stored = $null
    Write-LogMessage -headers $Request.Headers -API $APIName -tenant $Gate.Tenant -message "Retrieved application secret for $AppId once." -Sev 'Info'
    $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $AuditRequest -After @{ Retrieved = $true } -DryRun $false -Result 'Success' -SecretValues @($Value)
    return [HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = @{
            Results        = 'Retrieved the application secret once. It has been deleted from Key Vault.'
            Status         = 'Success'
            AuditId        = $AuditId
            AppId          = $AppId
            CredentialKeyId = $KeyId
            Secret         = $Value
            ticketNumber   = $Gate.Ticket
            dryRun         = $false
        }
    }
}

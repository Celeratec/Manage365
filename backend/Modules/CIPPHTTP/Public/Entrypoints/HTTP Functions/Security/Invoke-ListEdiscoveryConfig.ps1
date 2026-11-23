function Invoke-ListEdiscoveryConfig {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Security.Ediscovery.Read
    .DESCRIPTION
        Returns sanitized per-tenant eDiscovery config references. No certificate password secret name is returned.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $null = $TriggerMetadata
    $TenantFilter = [string]($Request.Query.tenantFilter ?? $Request.Body.tenantFilter)
    if ([string]::IsNullOrWhiteSpace($TenantFilter)) {
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'tenantFilter is required.'; Status = 'Failed' }
        }
    }

    try {
        $Config = Get-CIPPEdiscoveryTenantConfig -TenantFilter $TenantFilter
        $Safe = if ($Config) {
            [pscustomobject]@{
                TenantFilter          = [string]$Config.TenantFilter
                AppId                 = [string]$Config.AppId
                CertificateSecretName = [string]$Config.CertificateSecretName
                Enabled               = [bool]$Config.Enabled
                Notes                 = [string]$Config.Notes
            }
        } else {
            $null
        }

        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{ Results = $Safe; Status = 'Success' }
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-LogMessage -headers $Request.Headers -API $Request.Params.CIPPEndpoint -tenant $TenantFilter -message "Failed to retrieve eDiscovery config: $($ErrorMessage.NormalizedError)" -Sev 'Error' -LogData $ErrorMessage
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::InternalServerError
            Body       = @{ Results = "Failed to retrieve eDiscovery config: $($ErrorMessage.NormalizedError)"; Status = 'Failed' }
        }
    }
}

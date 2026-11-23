function Invoke-ListEdiscoveryReadiness {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Security.Ediscovery.Read
    .DESCRIPTION
        Checks dedicated eDiscovery app readiness for a tenant.
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
        $Readiness = Get-CIPPEdiscoveryReadiness -TenantFilter $TenantFilter
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{ Results = $Readiness; Status = 'Success' }
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        Write-LogMessage -headers $Request.Headers -API $Request.Params.CIPPEndpoint -tenant $TenantFilter -message "Failed to check eDiscovery readiness: $($ErrorMessage.NormalizedError)" -Sev 'Error' -LogData $ErrorMessage
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::InternalServerError
            Body       = @{ Results = "Failed to check eDiscovery readiness: $($ErrorMessage.NormalizedError)"; Status = 'Failed' }
        }
    }
}

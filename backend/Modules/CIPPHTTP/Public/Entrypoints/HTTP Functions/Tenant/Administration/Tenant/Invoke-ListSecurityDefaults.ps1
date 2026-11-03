function Invoke-ListSecurityDefaults {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.AppGovernance.Read
    .DESCRIPTION
        Reads whether identity security defaults are enabled.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $Tenant = [string]($Request.Query.tenantFilter ?? $Request.Body.tenantFilter)
    if ([string]::IsNullOrWhiteSpace($Tenant)) {
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'tenantFilter is required.' } }
    }
    $Policy = New-GraphGetRequest -uri 'https://graph.microsoft.com/v1.0/policies/identitySecurityDefaultsEnforcementPolicy' -tenantid $Tenant -asApp $true -noPagination $true
    return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::OK; Body = @{ Results = $Policy } }
}

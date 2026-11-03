function Invoke-ListUserAuthMethods {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Identity.User.Read
    .DESCRIPTION
        Lists a user's authentication methods with phone numbers and secrets masked.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $Tenant = [string]($Request.Query.tenantFilter ?? $Request.Body.tenantFilter)
    $UserId = [string]($Request.Query.userId ?? $Request.Body.userId)
    if ([string]::IsNullOrWhiteSpace($Tenant) -or [string]::IsNullOrWhiteSpace($UserId)) {
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'tenantFilter and userId are required.' } }
    }
    $Methods = @(New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users/$UserId/authentication/methods" -tenantid $Tenant -asApp $true)
    $Masked = @($Methods | ForEach-Object { Protect-CIPPAuthMethod -Method $_ })
    return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::OK; Body = @{ Results = $Masked } }
}

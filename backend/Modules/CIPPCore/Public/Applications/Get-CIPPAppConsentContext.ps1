function Get-CIPPAppConsentCaller {
    <#
    .SYNOPSIS
        The signed-in caller, from the EasyAuth client principal.
    .FUNCTIONALITY
        Internal
    #>
    param($Headers)
    $Caller = 'Unknown'
    if ($Headers -and $Headers.'x-ms-client-principal') {
        try {
            $Parsed = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String([string]$Headers.'x-ms-client-principal')) | ConvertFrom-Json
            if (-not [string]::IsNullOrWhiteSpace($Parsed.userDetails)) { $Caller = [string]$Parsed.userDetails }
        } catch {
            Write-Information "Could not read the caller from the client principal: $($_.Exception.Message)"
        }
    }
    $Caller
}

function Get-CIPPAppConsentContext {
    <#
    .SYNOPSIS
        Tenant, action, and caller for a user-scoped app consent request.
    .FUNCTIONALITY
        Internal
    #>
    param($Request)
    $Tenant = ConvertTo-CIPPRequestValue $Request.Query.tenantFilter
    if ([string]::IsNullOrWhiteSpace($Tenant)) { $Tenant = ConvertTo-CIPPRequestValue $Request.Body.tenantFilter }
    $Action = ConvertTo-CIPPRequestValue $Request.Query.Action
    if ([string]::IsNullOrWhiteSpace($Action)) { $Action = ConvertTo-CIPPRequestValue $Request.Body.Action }
    [pscustomobject]@{
        TenantFilter = $Tenant
        Action       = $Action
        Caller       = Get-CIPPAppConsentCaller $Request.Headers
        Headers      = $Request.Headers
        APIName      = [string]$Request.Params.CIPPEndpoint
    }
}

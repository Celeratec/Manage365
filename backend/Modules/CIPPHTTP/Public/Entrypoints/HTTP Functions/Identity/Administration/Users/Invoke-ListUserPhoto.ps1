Function Invoke-ListUserPhoto {
    <#
    .FUNCTIONALITY
        Entrypoint,AnyTenant
    .ROLE
        Identity.User.Read
    .DESCRIPTION
        Retrieves the profile photo for a specific Entra ID user as raw image bytes.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $tenantFilter = $Request.Query.tenantFilter
    $userId = $Request.Query.UserID

    if ([string]::IsNullOrWhiteSpace($tenantFilter) -or [string]::IsNullOrWhiteSpace($userId)) {
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = 'TenantFilter and UserID are required'
            })
    }

    # AnyTenant: enforce tenant scope here; Get-Tenants is narrowed to the caller's allowed tenants
    $AllowedTenants = Test-CIPPAccess -Request $Request -TenantList
    if ($AllowedTenants -notcontains 'AllTenants' -and -not (Get-Tenants -TenantFilter $tenantFilter)) {
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::Forbidden
                Body       = 'Access to this tenant is not allowed'
            })
    }

    try {
        # photo/$value is binary. Invoke-WebRequest keeps the bytes intact; Graph JSON helpers do not.
        $URI = "https://graph.microsoft.com/v1.0/users/$userId/photo/`$value"

        try {
            $graphToken = Get-GraphToken -tenantid $tenantFilter
            $PhotoResponse = Invoke-WebRequest -Uri $URI -Headers $graphToken -Method GET -ErrorAction Stop

            $ContentType = $PhotoResponse.Headers['Content-Type']
            if (-not $ContentType) {
                $ContentType = 'image/jpeg'
            }
            if ($ContentType -is [array]) {
                $ContentType = $ContentType[0]
            }

            return ([HttpResponseContext]@{
                    StatusCode  = [HttpStatusCode]::OK
                    ContentType = $ContentType
                    Body        = [byte[]]$PhotoResponse.Content
                })
        } catch {
            $StatusCode = $_.Exception.Response.StatusCode.value__
            if ($StatusCode -eq 404) {
                return ([HttpResponseContext]@{
                        StatusCode = [HttpStatusCode]::NotFound
                        Body       = 'User does not have a profile photo'
                    })
            }
            throw $_
        }
    } catch {
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::NotFound
                Body       = "Unable to retrieve user photo: $($_.Exception.Message)"
            })
    }
}

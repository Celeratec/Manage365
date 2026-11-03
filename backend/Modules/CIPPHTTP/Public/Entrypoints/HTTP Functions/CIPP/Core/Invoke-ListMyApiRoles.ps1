function Invoke-ListMyApiRoles {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        CIPP.Core.Read
    .DESCRIPTION
        Returns the permissions this caller can use. The list is the same one the access check uses, so a 403 on another endpoint can be compared with it.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $Permissions = @(Get-CippRequestAllowedPermissions | Where-Object { $_ })
    $Roles = @()
    if ($script:CippAccessUserContext) {
        $Roles = @($script:CippAccessUserContext.Roles | Where-Object { $_ })
    }
    return [HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = @{ Results = $Permissions; Roles = $Roles }
    }
}

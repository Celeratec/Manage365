function Invoke-CIPPGrantAppToUsers {
    <#
    .SYNOPSIS
        Creates the service principal if needed, requires assignment, assigns each user, and merges a Principal grant.
    .DESCRIPTION
        Scope names are checked against the resource service principal before anything is written.
        An existing service principal, assignment, or grant is reused. Created ids are returned for rollback.
        This never writes an AllPrincipals grant.
    .FUNCTIONALITY
        Internal
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$TenantFilter,
        [Parameter(Mandatory = $true)][string]$AppId,
        [Parameter(Mandatory = $true)][string[]]$UserIds,
        [Parameter(Mandatory = $true)][string[]]$Scopes,
        [bool]$RequireAssignment = $true,
        $Headers,
        [string]$APIName = 'ExecGrantAppToUsers'
    )

    $Users = @($UserIds | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $ScopeText = (@($Scopes) -join ' ').Trim()
    if ($Users.Count -eq 0) { throw [System.ArgumentException]::new('At least one user is required') }
    if ([string]::IsNullOrWhiteSpace($ScopeText)) { throw [System.ArgumentException]::new('At least one scope is required') }

    $Resource = Get-CIPPResourceServicePrincipal -TenantFilter $TenantFilter
    $Published = if ($Resource.oauth2PermissionScopes) { $Resource.oauth2PermissionScopes } else { $Resource.publishedPermissionScopes }
    $ResolvedScope = Resolve-CIPPPublishedScopes -Requested $ScopeText -Published $Published

    $Caller = Get-CIPPAppConsentCaller $Headers
    $ServicePrincipal = Invoke-CIPPServicePrincipalAction -TenantFilter $TenantFilter -Action Create -AppId $AppId -Headers $Headers -APIName $APIName
    $SpId = [string]$ServicePrincipal.ServicePrincipal.id
    $CreatedSp = if ($ServicePrincipal.Created) { $SpId } else { $null }

    if ($RequireAssignment -and -not [bool]$ServicePrincipal.ServicePrincipal.appRoleAssignmentRequired) {
        $null = Invoke-CIPPServicePrincipalAction -TenantFilter $TenantFilter -Action Update -Id $SpId -AppRoleAssignmentRequired $true -Headers $Headers -APIName $APIName
    }

    $NewAssignments = [System.Collections.Generic.List[string]]::new()
    $NewGrants = [System.Collections.Generic.List[string]]::new()
    foreach ($UserId in $Users) {
        $Assignment = Invoke-CIPPAppRoleAssignment -TenantFilter $TenantFilter -Action Add -ServicePrincipalId $SpId -PrincipalId $UserId -Headers $Headers -APIName $APIName
        if ($Assignment.Created) { [void]$NewAssignments.Add([string]$Assignment.Assignment.id) }
        $Grant = Invoke-CIPPOAuth2PermissionGrant -TenantFilter $TenantFilter -Action Add -ServicePrincipalId $SpId -PrincipalId $UserId -Scope $ResolvedScope -ResourceId ([string]$Resource.id) -Headers $Headers -APIName $APIName
        if ($Grant.Created) { [void]$NewGrants.Add([string]$Grant.Grant.id) }
    }

    $Created = [pscustomobject]@{
        servicePrincipalId   = $CreatedSp
        appRoleAssignmentIds = $(if ($NewAssignments.Count) { [string[]]$NewAssignments } else { $null })
        grantIds             = $(if ($NewGrants.Count) { [string[]]$NewGrants } else { $null })
    }
    Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Granted app $AppId ($SpId) to $($Users -join ', ') with scopes '$ResolvedScope' in $TenantFilter. Caller $Caller. Created service principal $($Created.servicePrincipalId); assignments $($Created.appRoleAssignmentIds -join ','); grants $($Created.grantIds -join ',')." -Sev 'Info' -LogData @{
        Tenant = $TenantFilter; Caller = $Caller; App = $AppId; Users = ($Users -join ' '); Scopes = $ResolvedScope; ServicePrincipalId = $SpId; GrantIds = @($Created.grantIds)
    }
    [pscustomobject]@{
        ServicePrincipal = $ServicePrincipal.ServicePrincipal
        Created          = $Created
    }
}

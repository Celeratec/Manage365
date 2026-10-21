function Resolve-CIPPPublishedScopes {
    param($Requested, $Published)
    $Canonical = @{}
    foreach ($Scope in @($Published)) {
        $Name = [string]$Scope.value
        if (-not [string]::IsNullOrWhiteSpace($Name)) { $Canonical[$Name.ToLowerInvariant()] = $Name }
    }
    $Resolved = [System.Collections.Generic.List[string]]::new()
    $Unknown = [System.Collections.Generic.List[string]]::new()
    foreach ($Raw in @($Requested)) {
        foreach ($Part in ([string]$Raw -split '\s+')) {
            if ([string]::IsNullOrWhiteSpace($Part)) { continue }
            $Key = $Part.ToLowerInvariant()
            if (-not $Canonical.ContainsKey($Key)) { [void]$Unknown.Add($Part); continue }
            if (-not $Resolved.Contains([string]$Canonical[$Key])) { [void]$Resolved.Add([string]$Canonical[$Key]) }
        }
    }
    if ($Unknown.Count -gt 0) {
        throw [System.ArgumentException]::new("Unknown scope(s): $($Unknown -join ', '). The resource service principal does not publish them.")
    }
    if ($Resolved.Count -eq 0) { throw [System.ArgumentException]::new('At least one scope is required') }
    (@($Resolved) | Sort-Object) -join ' '
}

function Get-CIPPResourceServicePrincipal {
    param([string]$TenantFilter, [string]$ResourceId, [string]$ResourceAppId)
    if ($ResourceId) {
        return New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/servicePrincipals/${ResourceId}?`$select=id,appId,oauth2PermissionScopes,publishedPermissionScopes" -tenantid $TenantFilter
    }
    $AppId = if ($ResourceAppId) { $ResourceAppId } else { '00000003-0000-0000-c000-000000000000' }
    New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/servicePrincipals(appId='$AppId')?`$select=id,appId,oauth2PermissionScopes,publishedPermissionScopes" -tenantid $TenantFilter
}

function Invoke-CIPPOAuth2PermissionGrant {
    <#
    .SYNOPSIS
        Adds, updates, or removes a Principal oauth2PermissionGrant. AllPrincipals is refused.
    .FUNCTIONALITY
        Internal
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$TenantFilter,
        [Parameter(Mandatory = $true)][ValidateSet('Add', 'Update', 'Remove')][string]$Action,
        [string]$ServicePrincipalId,
        [string]$PrincipalId,
        [string]$Scope,
        [string]$ConsentType = 'Principal',
        [string]$ResourceId,
        [string]$ResourceAppId,
        [string]$GrantId,
        $Headers,
        [string]$APIName = 'ExecOAuth2PermissionGrant'
    )

    if ($ConsentType -ne 'Principal') {
        throw [System.ArgumentException]::new('ExecOAuth2PermissionGrant only creates Principal grants. AllPrincipals consent is refused.')
    }
    $Caller = Get-CIPPAppConsentCaller $Headers

    if ($Action -eq 'Remove') {
        if ([string]::IsNullOrWhiteSpace($GrantId)) { throw [System.ArgumentException]::new('GrantId is required') }
        $null = New-GraphPOSTRequest -uri "https://graph.microsoft.com/v1.0/oauth2PermissionGrants/$GrantId" -tenantid $TenantFilter -type DELETE
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Removed oauth2PermissionGrant $GrantId in $TenantFilter. Caller $Caller." -Sev 'Info' -LogData @{
            Tenant = $TenantFilter; Caller = $Caller; GrantId = $GrantId
        }
        return [pscustomobject]@{ GrantId = $GrantId; Removed = $true }
    }

    $Resource = Get-CIPPResourceServicePrincipal -TenantFilter $TenantFilter -ResourceId $ResourceId -ResourceAppId $ResourceAppId
    $Published = if ($Resource.oauth2PermissionScopes) { $Resource.oauth2PermissionScopes } else { $Resource.publishedPermissionScopes }
    $ResolvedScope = Resolve-CIPPPublishedScopes -Requested $Scope -Published $Published

    if ($Action -eq 'Update') {
        if ([string]::IsNullOrWhiteSpace($GrantId)) { throw [System.ArgumentException]::new('GrantId is required') }
        $Body = @{ scope = $ResolvedScope } | ConvertTo-Json -Compress
        $Grant = New-GraphPOSTRequest -uri "https://graph.microsoft.com/v1.0/oauth2PermissionGrants/$GrantId" -tenantid $TenantFilter -type PATCH -body $Body
        if (-not $Grant.id) { $Grant = [pscustomobject]@{ id = $GrantId; scope = $ResolvedScope; consentType = 'Principal' } }
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Updated Principal grant $GrantId to '$ResolvedScope' in $TenantFilter. Caller $Caller." -Sev 'Info' -LogData @{
            Tenant = $TenantFilter; Caller = $Caller; Scopes = $ResolvedScope; GrantId = $GrantId
        }
        return [pscustomobject]@{ Grant = $Grant; Created = $false }
    }

    if ([string]::IsNullOrWhiteSpace($ServicePrincipalId) -or [string]::IsNullOrWhiteSpace($PrincipalId)) {
        throw [System.ArgumentException]::new('ServicePrincipalId and PrincipalId are required')
    }
    $Existing = @(New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/servicePrincipals/$ServicePrincipalId/oauth2PermissionGrants" -tenantid $TenantFilter | Where-Object {
            $_.consentType -eq 'Principal' -and $_.principalId -eq $PrincipalId -and $_.resourceId -eq $Resource.id
        })
    if ($Existing.Count -gt 0) {
        $Merged = Resolve-CIPPPublishedScopes -Requested @($Existing[0].scope, $ResolvedScope) -Published $Published
        $Body = @{ scope = $Merged } | ConvertTo-Json -Compress
        if ($Merged -ne [string]$Existing[0].scope) {
            $null = New-GraphPOSTRequest -uri "https://graph.microsoft.com/v1.0/oauth2PermissionGrants/$($Existing[0].id)" -tenantid $TenantFilter -type PATCH -body $Body
        }
        $Grant = [pscustomobject]@{ id = $Existing[0].id; scope = $Merged; consentType = 'Principal'; principalId = $PrincipalId; resourceId = $Resource.id }
        $Created = $false
    } else {
        $Body = @{
            clientId    = $ServicePrincipalId
            consentType = 'Principal'
            principalId = $PrincipalId
            resourceId  = [string]$Resource.id
            scope       = $ResolvedScope
        } | ConvertTo-Json -Compress
        $Grant = New-GraphPOSTRequest -uri 'https://graph.microsoft.com/v1.0/oauth2PermissionGrants' -tenantid $TenantFilter -type POST -body $Body
        $Created = $true
    }
    Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Principal grant $($Grant.id) for $PrincipalId on $ServicePrincipalId scopes '$($Grant.scope)' in $TenantFilter. Caller $Caller." -Sev 'Info' -LogData @{
        Tenant = $TenantFilter; Caller = $Caller; App = $ServicePrincipalId; Users = $PrincipalId; Scopes = [string]$Grant.scope; GrantId = [string]$Grant.id
    }
    [pscustomobject]@{ Grant = $Grant; Created = $Created }
}

function Invoke-CIPPAppRoleAssignment {
    <#
    .SYNOPSIS
        Adds or removes one app role assignment for a user or group. The default role is the unprivileged 00000000-0000-0000-0000-000000000000 role.
    .FUNCTIONALITY
        Internal
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$TenantFilter,
        [Parameter(Mandatory = $true)][ValidateSet('Add', 'Remove')][string]$Action,
        [string]$ServicePrincipalId,
        [string]$PrincipalId,
        [string]$AppRoleId = '00000000-0000-0000-0000-000000000000',
        [string]$AssignmentId,
        $Headers,
        [string]$APIName = 'ExecAppRoleAssignment'
    )

    $Caller = Get-CIPPAppConsentCaller $Headers
    if ($Action -eq 'Add') {
        if ([string]::IsNullOrWhiteSpace($ServicePrincipalId) -or [string]::IsNullOrWhiteSpace($PrincipalId)) {
            throw [System.ArgumentException]::new('ServicePrincipalId and PrincipalId are required')
        }
        $Existing = @(New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/servicePrincipals/$ServicePrincipalId/appRoleAssignedTo" -tenantid $TenantFilter | Where-Object {
                $_.principalId -eq $PrincipalId -and ($_.appRoleId -eq $AppRoleId -or [string]::IsNullOrWhiteSpace([string]$_.appRoleId))
            })
        if ($Existing.Count -gt 0) {
            $Assignment = $Existing[0]
            $Created = $false
        } else {
            $Body = @{ principalId = $PrincipalId; resourceId = $ServicePrincipalId; appRoleId = $AppRoleId } | ConvertTo-Json -Compress
            $Assignment = New-GraphPOSTRequest -uri "https://graph.microsoft.com/v1.0/servicePrincipals/$ServicePrincipalId/appRoleAssignedTo" -tenantid $TenantFilter -type POST -body $Body
            $Created = $true
        }
        $Message = "App role assignment $($Assignment.id) for $PrincipalId on $ServicePrincipalId in $TenantFilter. Caller $Caller."
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -Sev 'Info' -LogData @{
            Tenant = $TenantFilter; Caller = $Caller; App = $ServicePrincipalId; Users = $PrincipalId; AssignmentId = [string]$Assignment.id
        }
        return [pscustomobject]@{ Assignment = $Assignment; Created = $Created }
    }

    if ([string]::IsNullOrWhiteSpace($AssignmentId)) { throw [System.ArgumentException]::new('AssignmentId is required') }
    $DeleteUri = if ($ServicePrincipalId) {
        "https://graph.microsoft.com/v1.0/servicePrincipals/$ServicePrincipalId/appRoleAssignedTo/$AssignmentId"
    } else {
        "https://graph.microsoft.com/v1.0/appRoleAssignments/$AssignmentId"
    }
    $null = New-GraphPOSTRequest -uri $DeleteUri -tenantid $TenantFilter -type DELETE
    Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Removed app role assignment $AssignmentId in $TenantFilter. Caller $Caller." -Sev 'Info' -LogData @{
        Tenant = $TenantFilter; Caller = $Caller; App = $ServicePrincipalId; AssignmentId = $AssignmentId
    }
    [pscustomobject]@{ AssignmentId = $AssignmentId; Removed = $true }
}

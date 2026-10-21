function Invoke-CIPPServicePrincipalAction {
    <#
    .SYNOPSIS
        Creates a service principal, or sets whether it requires assignment. Does not grant consent.
    .FUNCTIONALITY
        Internal
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$TenantFilter,
        [Parameter(Mandatory = $true)][ValidateSet('Create', 'Update')][string]$Action,
        [string]$AppId,
        [string]$Id,
        $AppRoleAssignmentRequired,
        $Headers,
        [string]$APIName = 'ExecServicePrincipals',
        [switch]$NoAuthCheck
    )

    $Caller = Get-CIPPAppConsentCaller $Headers
    $GraphParams = @{ tenantid = $TenantFilter }
    if ($NoAuthCheck) { $GraphParams.NoAuthCheck = $true }

    $Guid = '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$'
    if ($AppId -and $AppId -notmatch $Guid) { throw [System.ArgumentException]::new('Invalid AppId') }
    if ($Id -and $Id -notmatch $Guid -and $Id -notmatch '^[A-Za-z0-9_-]+$') { throw [System.ArgumentException]::new('Invalid service principal id') }

    try {
        $Existing = $null
        if ($Id) {
            $Existing = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/servicePrincipals/${Id}?`$select=id,appId,displayName,appRoleAssignmentRequired" @GraphParams
        } elseif ($AppId) {
            try {
                $Existing = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/servicePrincipals(appId='$AppId')?`$select=id,appId,displayName,appRoleAssignmentRequired" @GraphParams
            } catch {
                $Failure = Get-CIPPGraphFailure -ErrorRecord $_
                if ($Failure.StatusCode -eq 404 -or $Failure.Message -match 'does not exist|Request_ResourceNotFound|ResourceNotFound') {
                    $Existing = $null
                } else {
                    $GraphError = [System.Exception]::new($Failure.Message)
                    $GraphError.Data['StatusCode'] = $Failure.StatusCode
                    throw $GraphError
                }
            }
        }

        if ($Action -eq 'Create') {
            if (-not $AppId) { throw [System.ArgumentException]::new('AppId is required') }
            if ($Existing.id) {
                $Result = [pscustomobject]@{ ServicePrincipal = $Existing; Created = $false }
            } else {
                $Body = @{ appId = $AppId } | ConvertTo-Json -Compress
                $CreatedSp = New-GraphPOSTRequest -uri 'https://graph.microsoft.com/v1.0/servicePrincipals' -type POST -body $Body @GraphParams
                $Result = [pscustomobject]@{ ServicePrincipal = $CreatedSp; Created = $true }
            }
        } else {
            if (-not $Existing.id) { throw [System.ArgumentException]::new('Service principal was not found') }
            if ($null -eq $AppRoleAssignmentRequired) { throw [System.ArgumentException]::new('appRoleAssignmentRequired must be true or false.') }
            $Required = [System.Convert]::ToBoolean($AppRoleAssignmentRequired)
            $Body = @{ appRoleAssignmentRequired = $Required } | ConvertTo-Json -Compress
            $null = New-GraphPOSTRequest -uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($Existing.id)" -type PATCH -body $Body @GraphParams
            $Existing | Add-Member -NotePropertyName appRoleAssignmentRequired -NotePropertyValue $Required -Force
            $Result = [pscustomobject]@{ ServicePrincipal = $Existing; Created = $false }
        }
    } catch [System.ArgumentException] {
        throw
    } catch {
        if ($_.Exception.Data -and $_.Exception.Data.Contains('StatusCode')) { throw }
        $Failure = Get-CIPPGraphFailure -ErrorRecord $_
        $GraphError = [System.Exception]::new($Failure.Message)
        $GraphError.Data['StatusCode'] = $Failure.StatusCode
        throw $GraphError
    }

    $Message = if ($Action -eq 'Create' -and $Result.Created) {
        "Created service principal $($Result.ServicePrincipal.id) for app $AppId in $TenantFilter without granting consent. Caller $Caller."
    } elseif ($Action -eq 'Create') {
        "Service principal $($Result.ServicePrincipal.id) for app $AppId already exists in $TenantFilter. No consent was granted. Caller $Caller."
    } else {
        "Set appRoleAssignmentRequired=$([bool]$Result.ServicePrincipal.appRoleAssignmentRequired) on service principal $($Result.ServicePrincipal.id) in $TenantFilter. Caller $Caller."
    }
    Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -Sev 'Info' -LogData @{
        Tenant = $TenantFilter; Caller = $Caller; App = $AppId; ServicePrincipalId = [string]$Result.ServicePrincipal.id; Action = $Action
    }
    $Result
}

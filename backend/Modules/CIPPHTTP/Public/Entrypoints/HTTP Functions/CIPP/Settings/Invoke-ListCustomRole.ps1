function Invoke-ListCustomRole {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        CIPP.Core.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    $DefaultRoles = @('readonly', 'editor', 'admin', 'superadmin')
    $Table = Get-CippTable -tablename 'CustomRoles'
    $CustomRoles = Get-CIPPAzDataTableEntity @Table -Filter "PartitionKey eq 'CustomRoles'"

    $CippRolesJson = Join-Path -Path $env:CIPPRootPath -ChildPath 'Config\cipp-roles.json'
    $BaseRoleConfig = if (Test-Path $CippRolesJson) {
        [System.IO.File]::ReadAllText($CippRolesJson) | ConvertFrom-Json
    } else {
        $null
    }

    $AccessRoleGroupTable = Get-CippTable -tablename 'AccessRoleGroups'
    $RoleGroups = Get-CIPPAzDataTableEntity @AccessRoleGroupTable -Filter "PartitionKey eq 'AccessRoleGroups'"

    $AccessIPRangeTable = Get-CippTable -tablename 'AccessIPRanges'
    $AccessIPRanges = Get-CIPPAzDataTableEntity @AccessIPRangeTable -Filter "PartitionKey eq 'AccessIPRanges'"

    $TenantList = Get-Tenants -IncludeErrors

    $RoleList = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($Role in $DefaultRoles) {
        $RoleGroup = $RoleGroups | Where-Object -Property RowKey -EQ $Role

        $IPRangeEntity = $AccessIPRanges | Where-Object -Property RowKey -EQ $Role
        if ($IPRangeEntity) {
            try {
                $IPRanges = @($IPRangeEntity.IPRanges | ConvertFrom-Json)
            } catch {
                $IPRanges = @()
            }
        } else {
            $IPRanges = @()
        }

        $BaseRules = if ($BaseRoleConfig -and $BaseRoleConfig.$Role) {
            [pscustomobject]@{
                Include = @($BaseRoleConfig.$Role.include)
                Exclude = @($BaseRoleConfig.$Role.exclude)
            }
        } else {
            $null
        }

        $RoleList.Add([pscustomobject]@{
                RoleName        = $Role
                Type            = 'Built-In'
                Permissions     = ''
                PermissionRules = $BaseRules
                AllowedTenants  = @('AllTenants')
                BlockedTenants  = @()
                EntraGroup      = $RoleGroup.GroupName ?? $null
                EntraGroupId    = $RoleGroup.GroupId ?? $null
                IPRange         = $IPRanges
            })
    }
    foreach ($Role in $CustomRoles) {
        $Role | Add-Member -NotePropertyName RoleName -NotePropertyValue $Role.RowKey -Force
        $Role | Add-Member -NotePropertyName Type -NotePropertyValue 'Custom' -Force

        if ($Role.Permissions) {
            try {
                $Role.Permissions = $Role.Permissions | ConvertFrom-Json
            } catch {
                $Role.Permissions = ''
            }
        }
        if ($Role.PSObject.Properties.Name -contains 'PermissionRules' -and $Role.PermissionRules) {
            try {
                $Role.PermissionRules = $Role.PermissionRules | ConvertFrom-Json
            } catch {
                $Role.PermissionRules = $null
            }
        } else {
            $Role | Add-Member -NotePropertyName PermissionRules -NotePropertyValue $null -Force
        }
        if ($Role.AllowedTenants) {
            try {
                $AllowedTenants = $Role.AllowedTenants | ConvertFrom-Json -ErrorAction Stop | ForEach-Object {
                    if ($_ -is [PSCustomObject] -and $_.type -eq 'Group') {
                        # Return group objects as-is for frontend display
                        [PSCustomObject]@{
                            type  = 'Group'
                            value = $_.value
                            label = $_.label
                        }
                    } else {
                        # Convert tenant customer ID to domain name object for frontend
                        $TenantId = $_
                        $TenantInfo = $TenantList | Where-Object { $_.customerId -eq $TenantId }
                        if ($TenantInfo) {
                            [PSCustomObject]@{
                                type        = 'Tenant'
                                value       = $TenantInfo.defaultDomainName
                                label       = "$($TenantInfo.displayName) ($($TenantInfo.defaultDomainName))"
                                addedFields = @{
                                    defaultDomainName = $TenantInfo.defaultDomainName
                                    displayName       = $TenantInfo.displayName
                                    customerId        = $TenantInfo.customerId
                                }
                            }
                        }
                    }
                } | Where-Object { $_ -ne $null }
                $AllowedTenants = $AllowedTenants ?? @('AllTenants')
                $Role.AllowedTenants = @($AllowedTenants)
            } catch {
                $Role.AllowedTenants = @('AllTenants')
            }
        } else {
            $Role | Add-Member -NotePropertyName AllowedTenants -NotePropertyValue @() -Force
        }
        if ($Role.BlockedTenants) {
            try {
                $BlockedTenants = $Role.BlockedTenants | ConvertFrom-Json -ErrorAction Stop | ForEach-Object {
                    if ($_ -is [PSCustomObject] -and $_.type -eq 'Group') {
                        # Return group objects as-is for frontend display
                        [PSCustomObject]@{
                            type  = 'Group'
                            value = $_.value
                            label = $_.label
                        }
                    } else {
                        # Convert tenant customer ID to domain name object for frontend
                        $TenantId = $_
                        $TenantInfo = $TenantList | Where-Object { $_.customerId -eq $TenantId }
                        if ($TenantInfo) {
                            [PSCustomObject]@{
                                type        = 'Tenant'
                                value       = $TenantInfo.defaultDomainName
                                label       = "$($TenantInfo.displayName) ($($TenantInfo.defaultDomainName))"
                                addedFields = @{
                                    defaultDomainName = $TenantInfo.defaultDomainName
                                    displayName       = $TenantInfo.displayName
                                    customerId        = $TenantInfo.customerId
                                }
                            }
                        }
                    }
                } | Where-Object { $_ -ne $null }
                $BlockedTenants = $BlockedTenants ?? @()
                $Role.BlockedTenants = @($BlockedTenants)
            } catch {
                $Role.BlockedTenants = @()
            }
        } else {
            $Role | Add-Member -NotePropertyName BlockedTenants -NotePropertyValue @() -Force
        }

        $RoleGroup = $RoleGroups | Where-Object -Property RowKey -EQ $Role.RowKey
        if ($RoleGroup) {
            $EntraGroup = $RoleGroups | Where-Object -Property RowKey -EQ $Role.RowKey | Select-Object GroupName, GroupId
            $Role | Add-Member -NotePropertyName EntraGroup -NotePropertyValue $EntraGroup.GroupName -Force
            $Role | Add-Member -NotePropertyName EntraGroupId -NotePropertyValue $EntraGroup.GroupId -Force
        }

        # Custom roles keep their IP allow-list in AccessIPRanges (same as the built-in roles
        # above); surface it here so this read-only list carries it too.
        $IPRangeEntity = $AccessIPRanges | Where-Object -Property RowKey -EQ $Role.RowKey
        if ($IPRangeEntity) {
            try {
                $IPRanges = @($IPRangeEntity.IPRanges | ConvertFrom-Json)
            } catch {
                $IPRanges = @()
            }
        } else {
            $IPRanges = @()
        }
        $Role | Add-Member -NotePropertyName IPRange -NotePropertyValue $IPRanges -Force

        $RoleList.Add($Role)
    }
    $Body = @($RoleList)

    return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = ConvertTo-Json -InputObject $Body -Depth 5
        })
}


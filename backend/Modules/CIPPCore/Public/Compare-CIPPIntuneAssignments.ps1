function Compare-CIPPIntuneAssignments {
    <#
    .SYNOPSIS
        Compares existing Intune policy assignments against expected assignment settings.
    .DESCRIPTION
        Returns $true if the existing assignments match the expected settings, $false if they differ,
        or $null if the comparison could not be completed (e.g. Graph error).
    .PARAMETER ExistingAssignments
        The current assignments on the policy, as returned by Get-CIPPIntunePolicyAssignments.
    .PARAMETER ExpectedAssignTo
        The expected assignment target type: allLicensedUsers, AllDevices, AllDevicesAndUsers,
        customGroup, or On (no assignment).
    .PARAMETER ExpectedCustomGroup
        The expected custom group name(s), comma-separated. Used when ExpectedAssignTo is 'customGroup'.
    .PARAMETER ExpectedExcludeGroup
        The expected exclusion group name(s), comma-separated.
    .PARAMETER ExpectedAssignmentFilter
        The expected assignment filter display name. Wildcards supported.
    .PARAMETER ExpectedAssignmentFilterType
        'include' or 'exclude'. Defaults to 'include'.
    .PARAMETER TenantFilter
        The tenant to query for group/filter resolution.
    .FUNCTIONALITY
        Internal
    #>
    param(
        [object[]]$ExistingAssignments,
        [string]$ExpectedAssignTo,
        [string]$ExpectedCustomGroup,
        [string]$ExpectedExcludeGroup,
        [string]$ExpectedAssignmentFilter,
        [string]$ExpectedAssignmentFilterType = 'include',
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter
    )

    try {
        # Normalize existing targets
        $ExistingTargetTypes = @($ExistingAssignments.target.'@odata.type' | Where-Object { $_ })
        $ExistingIncludeGroupIds = @(
            $ExistingAssignments |
                Where-Object { $_.target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget' } |
                ForEach-Object { $_.target.groupId }
        )
        $ExistingExcludeGroupIds = @(
            $ExistingAssignments |
                Where-Object { $_.target.'@odata.type' -eq '#microsoft.graph.exclusionGroupAssignmentTarget' } |
                ForEach-Object { $_.target.groupId }
        )

        # Read the broad targets through the same helper remediation writes them with, so a policy
        # type that expresses one of them differently is expected the way it is actually applied.
        $BroadTarget = Get-CIPPIntuneAssignmentTarget -AssignTo $Target.AssignTo -PolicyType $PolicyType
        $ExpectedIncludeTypes = if ($Target.AssignTo -eq 'customGroup') {
            @($GroupType)
        } else {
            @($BroadTarget.Targets | ForEach-Object { $_.'@odata.type' })
        }
        # A broad target expressed as a group assignment (App Protection's "all users") is an
        # expected group, not an unexpected extra one.
        $BroadGroupIds = @($BroadTarget.Targets | Where-Object { $_.groupId } | ForEach-Object { $_.groupId })

        # Intune reports some broad group targets back under an equivalent type. Accepting only the
        # shape remediation writes flags a working assignment as a deviation on every run.
        $EquivalentTypes = [System.Collections.Generic.List[string]]::new()
        $SatisfiedBroadIds = [System.Collections.Generic.List[string]]::new()
        foreach ($BroadId in @($BroadTarget.Equivalents.Keys)) {
            $Types = @($BroadTarget.Equivalents[$BroadId])
            $EquivalentTypes.AddRange([string[]]$Types)
            if (@($Types | Where-Object { $_ -in $ExistingIncludeTypes }).Count -gt 0) {
                $SatisfiedBroadIds.Add($BroadId)
            }
        }

        # Groups are looked up once and reused for name->id resolution and for naming the ids that
        # turn out to differ.
        $AllGroupsCache = $null
        $ResolveGroupNames = {
            param($NameList)
            $Ids = [System.Collections.Generic.List[string]]::new()
            $Unresolved = [System.Collections.Generic.List[string]]::new()
            foreach ($Name in @($NameList.Split(',').Trim() | Where-Object { $_ })) {
                # Square brackets are wildcard character classes to -like; group names containing
                # them are literal. Matches the escaping Set-CIPPAssignedPolicy applies.
                $Pattern = $Name -replace '\[', '`[' -replace '\]', '`]'
                $Matched = @($AllGroupsCache | Where-Object { $_.displayName -like $Pattern } | Select-Object -ExpandProperty id)
                if ($Matched.Count -eq 0) { $Unresolved.Add($Name) } else { $Ids.AddRange([string[]]$Matched) }
            }
            [PSCustomObject]@{ Ids = @($Ids); Unresolved = @($Unresolved) }
        }

        # Compare include target types (ignore exclusion targets)
        $ExistingIncludeTypes = @($ExistingTargetTypes | Where-Object { $_ -ne '#microsoft.graph.exclusionGroupAssignmentTarget' })
        $TargetTypeMatch = $true
        if ($Target.Managed) {
            $MissingTypes = @($ExpectedIncludeTypes | Where-Object { $_ -ne $GroupType -and $_ -notin $ExistingIncludeTypes })
            $ExtraTypes = @($ExistingIncludeTypes | Where-Object { $_ -ne $GroupType -and $_ -notin $ExpectedIncludeTypes -and $_ -notin $EquivalentTypes })
            if ($MissingTypes.Count -gt 0) {
                $TargetTypeMatch = $false
                $Reasons.Add("Policy is not assigned to $(($MissingTypes -replace '#microsoft\.graph\.', '') -join ', ')")
            }
            if ($ExtraTypes.Count -gt 0) {
                $TargetTypeMatch = $false
                $Reasons.Add("Policy is assigned to $(($ExtraTypes -replace '#microsoft\.graph\.', '') -join ', '), which the standard does not expect")
            }
        }

        # -- include groups --------------------------------------------------------------------
        $ExpectedGroupIds = @()
        $UnresolvedGroups = [System.Collections.Generic.List[string]]::new()
        if ($Target.AssignTo -eq 'customGroup' -and $ExpectedCustomGroup) {
            $Resolved = & $ResolveGroupNames $ExpectedCustomGroup
            $ExpectedGroupIds = $Resolved.Ids
            foreach ($Name in $Resolved.Unresolved) { $UnresolvedGroups.Add($Name) }
        }
        $ExpectedGroupIds = @($ExpectedGroupIds) + $BroadGroupIds
        $MissingIncludeIds = @($ExpectedGroupIds | Where-Object { $_ -notin $ExistingIncludeGroupIds -and $_ -notin $SatisfiedBroadIds })
        $ExtraIncludeIds = if ($Target.Managed) {
            @($ExistingIncludeGroupIds | Where-Object { $_ -notin $ExpectedGroupIds })
        } else { @() }

        # For custom groups, resolve names to IDs and compare
        $IncludeGroupMatch = $true
        if ($ExpectedAssignTo -eq 'customGroup' -and $ExpectedCustomGroup) {
            $AllGroupsCache = New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/groups?$select=id,displayName&$top=999' -tenantid $TenantFilter
            $ExpectedGroupIds = @(
                $ExpectedCustomGroup.Split(',').Trim() | ForEach-Object {
                    $name = $_
                    $AllGroupsCache | Where-Object { $_.displayName -like ($name -replace '\[', '`[' -replace '\]', '`]') } | Select-Object -ExpandProperty id
                } | Where-Object { $_ }
            )
            $MissingIds = @($ExpectedGroupIds | Where-Object { $_ -notin $ExistingIncludeGroupIds })
            $ExtraIds   = @($ExistingIncludeGroupIds | Where-Object { $_ -notin $ExpectedGroupIds })
            $IncludeGroupMatch = ($MissingIds.Count -eq 0 -and $ExtraIds.Count -eq 0)
        }

        # Compare exclusion groups
        $ExcludeGroupMatch = $true
        if ($ExpectedExcludeGroup) {
            if (-not $AllGroupsCache) {
                $AllGroupsCache = New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/groups?$select=id,displayName&$top=999' -tenantid $TenantFilter
            }
            $ExpectedExcludeIds = @(
                $ExpectedExcludeGroup.Split(',').Trim() | ForEach-Object {
                    $name = $_
                    $AllGroupsCache | Where-Object { $_.displayName -like ($name -replace '\[', '`[' -replace '\]', '`]') } | Select-Object -ExpandProperty id
                } | Where-Object { $_ }
            )
            $MissingExcludeIds = @($ExpectedExcludeIds | Where-Object { $_ -notin $ExistingExcludeGroupIds })
            $ExtraExcludeIds   = @($ExistingExcludeGroupIds | Where-Object { $_ -notin $ExpectedExcludeIds })
            $ExcludeGroupMatch = ($MissingExcludeIds.Count -eq 0 -and $ExtraExcludeIds.Count -eq 0)
        } elseif ($ExistingExcludeGroupIds.Count -gt 0) {
            # No exclusions expected but some exist
            $ExcludeGroupMatch = $false
        }

        # Compare assignment filter
        $FilterMatch = $true
        if ($ExpectedAssignmentFilter) {
            $ExistingFilterIds = @(
                $ExistingAssignments |
                    Where-Object { $_.target.deviceAndAppManagementAssignmentFilterId } |
                    ForEach-Object { $_.target.deviceAndAppManagementAssignmentFilterId }
            )
            if ($ExistingFilterIds.Count -eq 0) {
                $FilterMatch = $false
            } else {
                $AllFilters = New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/deviceManagement/assignmentFilters' -tenantid $TenantFilter
                $ExpectedFilter = $AllFilters | Where-Object { $_.displayName -like $ExpectedAssignmentFilter } | Select-Object -First 1
                $FilterMatch = $ExpectedFilter -and ($ExpectedFilter.id -in $ExistingFilterIds)
            }
        }

        return $TargetTypeMatch -and $IncludeGroupMatch -and $ExcludeGroupMatch -and $FilterMatch

    } catch {
        Write-Warning "Compare-CIPPIntuneAssignments failed for tenant $TenantFilter : $($_.Exception.Message)"
        return $null  # null = unknown, don't treat as mismatch
    }
}

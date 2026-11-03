function Test-CIPPCAPolicyRemoval {
    <#
    .SYNOPSIS
        Names the protected Conditional Access fields a proposed policy would drop.
    .DESCRIPTION
        grantControls, sessionControls, conditions, excludeUsers, and excludeGroups are protected.
        A proposed policy that clears one of them, or that removes an excluded user or group, is
        refused unless ConfirmRemoval names that field.
    #>
    [CmdletBinding()]
    param(
        $Current,
        $Proposed,
        [AllowEmptyCollection()]
        [string[]]$ConfirmRemoval = @()
    )

    $Dropped = [System.Collections.Generic.List[string]]::new()
    $Confirmed = @($ConfirmRemoval | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    $CurrentGrants = @($Current.grantControls.builtInControls) + @($Current.grantControls.customAuthenticationFactors) + @($Current.grantControls.termsOfUse)
    $ProposedGrants = @($Proposed.grantControls.builtInControls) + @($Proposed.grantControls.customAuthenticationFactors) + @($Proposed.grantControls.termsOfUse)
    $CurrentGrants = @($CurrentGrants | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    $ProposedGrants = @($ProposedGrants | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($CurrentGrants.Count -gt 0 -and $ProposedGrants.Count -eq 0 -and 'grantControls' -notin $Confirmed) {
        $Dropped.Add('grantControls')
    }

    $SessionHasValue = $false
    if ($null -ne $Current.sessionControls) {
        foreach ($Prop in @($Current.sessionControls.PSObject.Properties)) {
            if ($null -ne $Prop.Value) { $SessionHasValue = $true }
        }
    }
    if ($SessionHasValue -and $null -eq $Proposed.sessionControls -and 'sessionControls' -notin $Confirmed) {
        $Dropped.Add('sessionControls')
    }

    if ($null -ne $Current.conditions -and $null -eq $Proposed.conditions -and 'conditions' -notin $Confirmed) {
        $Dropped.Add('conditions')
    }

    foreach ($Field in @('excludeUsers', 'excludeGroups')) {
        $Before = @($Current.conditions.users.$Field | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        $After = @($Proposed.conditions.users.$Field | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        $Missing = @($Before | Where-Object { $_ -notin $After })
        if ($Missing.Count -gt 0 -and $Field -notin $Confirmed) { $Dropped.Add($Field) }
    }

    return @($Dropped)
}

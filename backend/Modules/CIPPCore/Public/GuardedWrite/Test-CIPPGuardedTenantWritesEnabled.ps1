function Test-CIPPGuardedTenantWritesEnabled {
    <#
    .SYNOPSIS
        Returns whether the GuardedTenantWrites feature flag is currently enabled.
    .DESCRIPTION
        Uses Get-CIPPFeatureFlag. Missing or disabled flags return false. Used by endpoints
        that stay off the flag's Endpoints list (so the UI keeps working) but still require
        the flag when a caller opts into the guarded envelope.
    #>
    [CmdletBinding()]
    param()

    try {
        $Flag = Get-CIPPFeatureFlag -Id 'GuardedTenantWrites'
        return ($null -ne $Flag -and $Flag.Enabled -eq $true)
    } catch {
        return $false
    }
}

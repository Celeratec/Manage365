function Test-CIPPExoParameterName {
    <#
    .SYNOPSIS
        Returns true when an Exchange cmdlet parameter name is allowlist-safe.
    .DESCRIPTION
        Parameter names must start with an ASCII letter and contain only ASCII letters and digits.
        Shared by Get-CIPPExoAllowlistedCmdletPlan and Get-CIPPExoReadTestCmdletPlan.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name
    )

    return $Name -cmatch '\A[A-Za-z][A-Za-z0-9]*\z'
}

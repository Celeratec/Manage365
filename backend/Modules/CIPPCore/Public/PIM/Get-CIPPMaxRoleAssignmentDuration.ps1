function Get-CIPPMaxRoleAssignmentDuration {
    <#
    .SYNOPSIS
        ISO 8601 ceiling for a CIPP role assignment or JIT admin window.
    .DESCRIPTION
        Single source for the maximum lifetime ExecPIMRoleAssignment and ExecJITAdmin will accept.
        The value lives in Config/RoleAssignment.json as MaxRoleAssignmentDuration and defaults to
        P365D. CIPP rejects anything longer. It does not shorten a request to fit the cap, and it
        does not raise a tenant's own PIM policy: Entra can still refuse a long assignment.
    #>
    [CmdletBinding()]
    param()

    $Fallback = 'P365D'
    $Configured = $null
    $Candidates = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrWhiteSpace($env:CIPPRootPath)) {
        $Candidates.Add((Join-Path $env:CIPPRootPath 'Config/RoleAssignment.json'))
    }
    $Dir = $PSScriptRoot
    for ($i = 0; $i -lt 6 -and $Dir; $i++) {
        $Candidates.Add((Join-Path $Dir 'Config/RoleAssignment.json'))
        $Dir = Split-Path -Parent $Dir
    }
    foreach ($Path in $Candidates) {
        if (-not (Test-Path -LiteralPath $Path)) { continue }
        try {
            $Json = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
            $Configured = [string]$Json.MaxRoleAssignmentDuration
            if (-not [string]::IsNullOrWhiteSpace($Configured)) { break }
        } catch {
            Write-Information "Could not read MaxRoleAssignmentDuration from $Path`: $($_.Exception.Message)"
        }
    }
    if ([string]::IsNullOrWhiteSpace($Configured)) { $Configured = $Fallback }
    try {
        $null = [System.Xml.XmlConvert]::ToTimeSpan($Configured)
    } catch {
        throw "MaxRoleAssignmentDuration '$Configured' is not a valid ISO 8601 duration."
    }
    return $Configured
}

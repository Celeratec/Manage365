function Resolve-CIPPGuardedWriteConfigPath {
    <#
    .SYNOPSIS
        Resolves the path to a GuardedWrite allowlist config file that works in both
        source and compiled module layouts.
    .DESCRIPTION
        In the source layout (used by Pester and local dev), the Config directory is
        four levels up from GuardedWrite functions via $PSScriptRoot/../../../Config.

        In the compiled/containerized layout (production), CIPPCore is compiled to
        /app/API/Modules/CIPPCore (Public/Private/Classes are removed), and Config
        is at /app/API/Config. So $PSScriptRoot/../../../Config would resolve to
        /app/Config, which doesn't exist.

        This function:
        1. Tries $env:CIPPRootPath/Config/<file> if CIPPRootPath is set (production: /app/API)
        2. Falls back to candidates that work in source (four '..') and compiled (two '..')
        3. Throws a clear error if no file is found
    .PARAMETER RelativePath
        The relative path under Config/, e.g. 'GuardedWrites/ExoCmdletAllowlist.json'
    .PARAMETER PSScriptRoot
        The $PSScriptRoot from the calling function
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RelativePath,

        [Parameter(Mandatory)]
        [string]$PSScriptRoot
    )

    $Candidates = [System.Collections.Generic.List[string]]::new()

    if (-not [string]::IsNullOrWhiteSpace($env:CIPPRootPath)) {
        $Candidates.Add((Join-Path $env:CIPPRootPath "Config/$RelativePath"))
    }

    $Candidates.Add((Join-Path $PSScriptRoot "../../../../Config/$RelativePath"))

    $Candidates.Add((Join-Path $PSScriptRoot "../../Config/$RelativePath"))

    foreach ($Path in $Candidates) {
        try {
            if (Test-Path -LiteralPath $Path -PathType Leaf -ErrorAction Stop) {
                return $Path
            }
        } catch {
        }
    }

    throw "GuardedWrite config file not found. Searched: $($Candidates -join ', '). " +
    "Ensure Config/$RelativePath exists in the module or set CIPPRootPath correctly."
}

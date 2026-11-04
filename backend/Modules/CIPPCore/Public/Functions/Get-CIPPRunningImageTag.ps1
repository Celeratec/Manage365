function Get-CIPPRunningImageTag {
    <#
    .SYNOPSIS
        The Manage365 image tag this process was built with.
    .DESCRIPTION
        APP_VERSION stays on the CIPP baseline, so VersionHistory only moves when that
        baseline changes. The release the container is actually running is the tag in
        version.json, written at image build next to the frontend. IMAGE_TAG is the same
        value, used when the file is not on disk.
    .FUNCTIONALITY
        Internal
    #>
    [CmdletBinding()]
    param()

    $Candidates = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrWhiteSpace($env:CIPPRootPath)) {
        $Candidates.Add((Join-Path (Split-Path -Parent $env:CIPPRootPath) 'Frontend/version.json'))
    }
    $Candidates.Add('/app/Frontend/version.json')

    foreach ($Path in $Candidates) {
        if (-not (Test-Path -LiteralPath $Path)) { continue }
        try {
            $Json = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
            $Tag = [string]$Json.tag
            if (-not [string]::IsNullOrWhiteSpace($Tag)) { return $Tag }
        } catch {
            Write-Information "Could not read image tag from ${Path}: $($_.Exception.Message)"
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($env:IMAGE_TAG)) { return [string]$env:IMAGE_TAG }
    return $null
}

function Test-CIPPTeamsAppPackage {
    <#
    .SYNOPSIS
        Checks a Teams app package is a zip of at most 5 MB whose manifest id matches.
    #>
    [CmdletBinding()]
    param(
        [string]$PackageBase64,
        [string]$ExpectedManifestId
    )

    if ([string]::IsNullOrWhiteSpace($ExpectedManifestId)) {
        return [pscustomobject]@{ Allowed = $false; Reason = 'ExpectedManifestId is required.' }
    }
    if ([string]::IsNullOrWhiteSpace($PackageBase64)) {
        return [pscustomobject]@{ Allowed = $false; Reason = 'PackageBase64 or PackageBlobRef is required.' }
    }
    try {
        $Bytes = [Convert]::FromBase64String($PackageBase64)
    } catch {
        return [pscustomobject]@{ Allowed = $false; Reason = 'PackageBase64 is not valid base64.' }
    }
    if ($Bytes.Length -gt 5MB) {
        return [pscustomobject]@{ Allowed = $false; Reason = 'The Teams app package must be 5 MB or smaller.' }
    }
    Add-Type -AssemblyName System.IO.Compression
    $Stream = [System.IO.MemoryStream]::new($Bytes)
    try {
        $Zip = [System.IO.Compression.ZipArchive]::new($Stream, [System.IO.Compression.ZipArchiveMode]::Read)
        $Entry = $Zip.GetEntry('manifest.json')
        if (-not $Entry) {
            $Entry = @($Zip.Entries | Where-Object { $_.FullName -eq 'manifest.json' -or $_.Name -eq 'manifest.json' } | Select-Object -First 1)
        }
        if (-not $Entry) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'The package does not contain manifest.json.' }
        }
        $Reader = [System.IO.StreamReader]::new($Entry.Open())
        try { $Manifest = $Reader.ReadToEnd() | ConvertFrom-Json } finally { $Reader.Dispose() }
    } finally {
        if ($Zip) { $Zip.Dispose() }
        $Stream.Dispose()
    }
    if ([string]$Manifest.id -ne $ExpectedManifestId) {
        return [pscustomobject]@{ Allowed = $false; Reason = "manifest.json id '$($Manifest.id)' does not match ExpectedManifestId." }
    }
    return [pscustomobject]@{ Allowed = $true; Reason = $null; ManifestId = [string]$Manifest.id; Size = $Bytes.Length }
}

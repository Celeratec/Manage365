function Test-CIPPEdiscoveryForbiddenAction {
    [CmdletBinding()]
    param(
        [string]$Action,
        [string]$Resource,
        [string]$RawPath
    )
    $ActionL = ([string]$Action).ToLowerInvariant()
    $ResourceL = ([string]$Resource).ToLowerInvariant()
    $PathL = ([string]$RawPath).ToLowerInvariant()

    if ($PathL -match 'purgedata' -or $ActionL -eq 'purge' -or $ActionL -eq 'purgedata') {
        throw 'Purge is refused by Manage365 eDiscovery policy.'
    }
    if ($ResourceL -eq 'case' -and $ActionL -eq 'delete') {
        throw 'Case delete is refused by Manage365 eDiscovery policy.'
    }
    if ($ResourceL -eq 'hold' -and $ActionL -in @('remove', 'delete')) {
        throw 'Hold removal is refused by Manage365 eDiscovery policy.'
    }
    if ($ResourceL -eq 'search' -and $ActionL -eq 'delete') {
        throw 'Search delete is refused by Manage365 eDiscovery policy.'
    }
    if ($PathL -match '/ediscoverycases/[^/]+$' -and $ActionL -eq 'delete') {
        throw 'Case delete is refused by Manage365 eDiscovery policy.'
    }
    return $true
}
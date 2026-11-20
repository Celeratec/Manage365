function Test-CIPPAzArmSegment {
    <#
    .SYNOPSIS
        Validates a path segment used to build ARM URLs (no traversal, no URL injection).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value,

        [ValidateSet('guid', 'resourceGroup', 'resourceName', 'safeToken')]
        [string]$Kind = 'safeToken'
    )

    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    if ($Value -match '[\x00-\x1F\x7F]' -or $Value.Contains('/') -or $Value.Contains('\') -or $Value.Contains('..') -or $Value.Contains('?') -or $Value.Contains('#')) {
        return $false
    }
    switch ($Kind) {
        'guid' {
            return $Value -match '\A[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}\z'
        }
        'resourceGroup' {
            return $Value -match '\A[A-Za-z0-9_\-\.\(\)]{1,90}\z'
        }
        'resourceName' {
            return $Value -match '\A[A-Za-z0-9][A-Za-z0-9_\-\.]{0,59}\z'
        }
        'safeToken' {
            return $Value -match '\A[A-Za-z0-9_\-\.]{1,128}\z'
        }
        default {
            throw "Unhandled segment kind: $Kind"
        }
    }
}

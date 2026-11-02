function Get-CippNormalizedTenantFilter {
    <#
    .SYNOPSIS
        Normalizes tenant filter input from request body.
    .DESCRIPTION
        Handles arrays, single values, and {value:} object form.
        Rejects arrays with multiple values.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $TenantFilter
    )

    # Handle null/empty
    if ($null -eq $TenantFilter -or $TenantFilter -eq '') {
        throw 'tenantFilter is required'
    }

    # Handle {value: 'tenant'} object form (autocomplete)
    if ($TenantFilter -is [PSCustomObject] -or $TenantFilter -is [Hashtable]) {
        if ($TenantFilter.value) {
            return [string]$TenantFilter.value
        }
        throw 'tenantFilter object must have a value property'
    }

    # Handle array
    if ($TenantFilter -is [array]) {
        if ($TenantFilter.Count -eq 0) {
            throw 'tenantFilter cannot be an empty array'
        }
        if ($TenantFilter.Count -gt 1) {
            throw 'tenantFilter must be a single tenant, not an array of multiple tenants'
        }
        # Single-element array - extract the value
        $SingleValue = $TenantFilter[0]
        # Check if the array element is also an object with value property
        if (($SingleValue -is [PSCustomObject] -or $SingleValue -is [Hashtable]) -and $SingleValue.value) {
            return [string]$SingleValue.value
        }
        return [string]$SingleValue
    }

    # Single string value
    return [string]$TenantFilter
}

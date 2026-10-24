function Invoke-CIPPGraphExchangeAdminRequest {
    <#
    .SYNOPSIS
        Call Microsoft Graph admin/exchange mailbox import-export APIs (app-only).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        [ValidateSet('GET', 'POST', 'DELETE', 'PATCH')]
        [string]$Method,

        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [object]$Body,
        [switch]$SkipAuth
    )

    switch ($Method) {
        'GET' {
            if ($SkipAuth) { throw 'GET requires authorization.' }
            return New-GraphGetRequest -uri $Uri -tenantid $TenantFilter -AsApp $true -noPagination:($Uri -notmatch '\$top')
        }
        'POST' {
            $Json = if ($null -ne $Body) { $Body | ConvertTo-Json -Depth 25 -Compress } else { '{}' }
            if ($SkipAuth) {
                return Invoke-CIPPRestMethod -Uri $Uri -Method POST -Body $Json -ContentType 'application/json; charset=utf-8'
            }
            return New-GraphPOSTRequest -uri $Uri -tenantid $TenantFilter -type POST -body $Json -AsApp $true
        }
        'DELETE' {
            if ($SkipAuth) { throw 'DELETE requires authorization.' }
            $Headers = Get-GraphToken -tenantid $TenantFilter -AsApp $true
            if (-not $Headers['User-Agent']) { $Headers['User-Agent'] = Get-CippUserAgent }
            $null = Invoke-CIPPRestMethod -Uri $Uri -Method DELETE -Headers $Headers
            return $null
        }
        default {
            $Json = if ($null -ne $Body) { $Body | ConvertTo-Json -Depth 25 -Compress } else { '{}' }
            return New-GraphPOSTRequest -uri $Uri -tenantid $TenantFilter -type $Method -body $Json -AsApp $true
        }
    }
}

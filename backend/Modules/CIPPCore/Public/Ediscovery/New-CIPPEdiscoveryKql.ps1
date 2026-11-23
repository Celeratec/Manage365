function New-CIPPEdiscoveryKql {
    <#
    .SYNOPSIS
        Builds Purview eDiscovery KQL from validated search terms (OR across phrases for hit-union stats).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string[]]$Terms,

        [datetime]$DateFrom,
        [datetime]$DateTo
    )

    $Clean = @($Terms | ForEach-Object { [string]$_.Trim() } | Where-Object { $_ })
    if ($Clean.Count -lt 1 -or $Clean.Count -gt 25) {
        throw 'terms must contain 1 to 25 items.'
    }

    $Parts = foreach ($T in $Clean) {
        if ($T.Length -gt 128) {
            throw 'Each term must be 128 characters or fewer.'
        }
        if ($T -match '[;\n\r|]|contentQuery') {
            throw 'Invalid term.'
        }
        $Esc = $T.Replace('\', '\\').Replace('"', '\"')
        '"{0}"' -f $Esc
    }

    $Kql = '(' + ($Parts -join ' OR ') + ')'

    if ($DateFrom -and $DateTo) {
        if (($DateTo.Date - $DateFrom.Date).TotalDays -gt 1825) {
            throw 'Date range exceeds 5 years.'
        }
        if ($DateTo -lt $DateFrom) {
            throw 'dateTo must be on or after dateFrom.'
        }
        $Kql = "$Kql AND sent>=$($DateFrom.ToString('yyyy-MM-dd')) AND sent<=$($DateTo.ToString('yyyy-MM-dd'))"
    } elseif ($DateFrom -or $DateTo) {
        throw 'dateFrom and dateTo must be supplied together.'
    }

    $Sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $Hash = [System.BitConverter]::ToString(
            $Sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Kql))
        ).Replace('-', '').ToLowerInvariant()
    } finally {
        $Sha256.Dispose()
    }

    [pscustomobject]@{
        Kql       = $Kql
        TermCount = $Clean.Count
        KqlHash   = $Hash
        Terms     = $Clean
    }
}
function Test-CIPPMailFilterRequestField {
    <#
    .SYNOPSIS
        Reports whether a query or body field was sent, including an explicit null.
    #>
    param(
        $Request,
        [Parameter(Mandatory)]
        [string]$Name
    )

    foreach ($Source in @($Request.Body, $Request.Query)) {
        if ($null -eq $Source) { continue }
        if ($Source -is [System.Collections.IDictionary]) {
            if ($Source.Contains($Name)) { return $true }
        } elseif ($Source.PSObject.Properties.Name -contains $Name) {
            return $true
        }
    }
    return $false
}

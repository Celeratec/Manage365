function Test-CIPPTransportRuleGuardedMode {
    <#
    .SYNOPSIS
        Returns true when a transport-rule request opts into the guarded write envelope.
    .DESCRIPTION
        Any of ticketNumber/TicketNumber, dryRun/WhatIf/preview/Preview, or reason/Reason
        on Body or Query triggers guarded mode. Absence of all keeps legacy behavior.
    #>
    [CmdletBinding()]
    param($Request)

    $Sources = @($Request.Body, $Request.Query) | Where-Object { $null -ne $_ }
    foreach ($Source in $Sources) {
        foreach ($Name in @('ticketNumber', 'TicketNumber', 'dryRun', 'WhatIf', 'preview', 'Preview', 'reason', 'Reason')) {
            $Value = $Source.$Name
            if ($null -ne $Value -and "$Value" -ne '') {
                return $true
            }
        }
    }
    return $false
}

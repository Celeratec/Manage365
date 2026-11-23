function Get-CIPPEdiscoverySearchPlan {
    <#
    .SYNOPSIS
        Builds a dry-run stats search plan (case identity, custodian, KQL, policy limits).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TicketNumber,

        [Parameter(Mandatory)]
        [string]$CustodianUpn,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string[]]$Terms,

        [string]$CaseLabel,

        [datetime]$DateFrom,
        [datetime]$DateTo
    )

    if ($TicketNumber -notmatch '\A\d{6,8}\z') {
        throw 'ticketNumber must be 6 to 8 digits.'
    }

    $Custodian = [string]$CustodianUpn.Trim()
    if ([string]::IsNullOrWhiteSpace($Custodian)) {
        throw 'custodianUpn is required.'
    }

    $Label = ([string]$CaseLabel).Trim()
    if ($Label.Length -gt 128) {
        throw 'caseLabel must be 128 characters or fewer.'
    }

    $KqlParams = @{ Terms = $Terms }
    if ($DateFrom -and $DateTo) {
        $KqlParams['DateFrom'] = $DateFrom
        $KqlParams['DateTo'] = $DateTo
    }
    $KqlResult = New-CIPPEdiscoveryKql @KqlParams

    $DisplayName = if ([string]::IsNullOrWhiteSpace($Label)) {
        $TicketNumber
    } else {
        "$TicketNumber - $Label"
    }

    [pscustomobject]@{
        DisplayName    = $DisplayName
        ExternalId     = $TicketNumber
        CustodianUpn   = $Custodian
        Kql            = $KqlResult.Kql
        KqlHash        = $KqlResult.KqlHash
        TermCount      = $KqlResult.TermCount
        Terms          = $KqlResult.Terms
        Limits         = [pscustomobject]@{
            MaxTerms          = 25
            MaxDateSpanDays   = 1825
            MaxCustodians     = 1
            MailboxOnly       = $true
            StatisticsOptions = 'includeQueryStats,includeUnindexedStats'
        }
    }
}
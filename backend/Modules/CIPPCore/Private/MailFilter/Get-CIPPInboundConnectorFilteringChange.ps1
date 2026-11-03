function Test-CIPPMailFilterIpAddress {
    param([string]$Value)

    $Text = $Value.Trim()
    $Address = $null
    $Network = $Text
    if ($Text.Contains('/')) {
        $Parts = $Text.Split('/', 2)
        $Network = $Parts[0]
        $Prefix = 0
        if (-not [int]::TryParse($Parts[1], [ref]$Prefix)) { throw "EFSkipIPs value '$Value' is not an IP address." }
    }
    if (-not [System.Net.IPAddress]::TryParse($Network, [ref]$Address)) {
        throw "EFSkipIPs value '$Value' is not an IP address."
    }
    return $Text
}

function Get-CIPPInboundConnectorFilteringChange {
    <#
    .SYNOPSIS
        Builds a Set-InboundConnector change for Enhanced Filtering.
    #>
    param(
        [Parameter(Mandatory)][string]$Identity,
        $Connector,
        [bool]$HasSkipIPs,
        $SkipIPs,
        [bool]$HasSkipLastIP,
        $SkipLastIP,
        [bool]$HasUsers,
        $Users
    )

    $ConnectorIdentity = Test-CIPPMailFilterIdentity -Value $Identity -Label 'identity'
    if ($null -eq $Connector) { throw "Inbound connector '$ConnectorIdentity' was not found." }
    if (-not $HasSkipIPs -and -not $HasSkipLastIP -and -not $HasUsers) {
        throw 'Send efSkipIPs, efSkipLastIP, or efUsers.'
    }

    $BeforeIPs = @(ConvertTo-CIPPMailFilterStringList (Get-CIPPMailFilterProperty $Connector 'EFSkipIPs'))
    $BeforeLast = Get-CIPPMailFilterProperty $Connector 'EFSkipLastIP'
    $BeforeUsers = @(ConvertTo-CIPPMailFilterStringList (Get-CIPPMailFilterProperty $Connector 'EFUsers'))

    $Parameters = @{ Identity = $ConnectorIdentity }
    $RollbackParameters = @{ Identity = $ConnectorIdentity }
    $Diff = [System.Collections.Generic.List[object]]::new()

    if ($HasSkipIPs) {
        $After = @($(ConvertTo-CIPPMailFilterStringList $SkipIPs) | ForEach-Object { Test-CIPPMailFilterIpAddress $_ })
        $Parameters.EFSkipIPs = if ($After.Count -eq 0) { $null } else { $After }
        $RollbackParameters.EFSkipIPs = if ($BeforeIPs.Count -eq 0) { $null } else { $BeforeIPs }
        $Row = Get-CIPPMailFilterDiffRow -Field 'EFSkipIPs' -Before $BeforeIPs -After $After -ProtectionActive $false
        if ($Row) { $Diff.Add($Row) }
    }
    if ($HasSkipLastIP) {
        $AfterLast = [bool](ConvertTo-CIPPMailFilterBool $SkipLastIP)
        $Parameters.EFSkipLastIP = $AfterLast
        $RollbackParameters.EFSkipLastIP = [bool](ConvertTo-CIPPMailFilterBool $BeforeLast)
        $Row = Get-CIPPMailFilterDiffRow -Field 'EFSkipLastIP' -Before ([string]$BeforeLast) -After ([string]$AfterLast) -ProtectionActive $false
        if ($Row) { $Diff.Add($Row) }
    }
    if ($HasUsers) {
        $AfterUsers = @(ConvertTo-CIPPMailFilterStringList $Users)
        $Parameters.EFUsers = if ($AfterUsers.Count -eq 0) { $null } else { $AfterUsers }
        $RollbackParameters.EFUsers = if ($BeforeUsers.Count -eq 0) { $null } else { $BeforeUsers }
        $Row = Get-CIPPMailFilterDiffRow -Field 'EFUsers' -Before $BeforeUsers -After $AfterUsers -ProtectionActive $false
        if ($Row) { $Diff.Add($Row) }
    }

    $Commands = @()
    if ($Diff.Count -gt 0) {
        $Commands = @(@{ Cmdlet = 'Set-InboundConnector'; Parameters = $Parameters })
    }

    @{
        Snapshot = [ordered]@{
            Identity     = $ConnectorIdentity
            EFSkipIPs    = $BeforeIPs
            EFSkipLastIP = $BeforeLast
            EFUsers      = $BeforeUsers
        }
        Diff     = @($Diff)
        Commands = $Commands
        Rollback = $(if ($Commands.Count -eq 0) { @() } else { @(@{ Cmdlet = 'Set-InboundConnector'; Parameters = $RollbackParameters }) })
    }
}

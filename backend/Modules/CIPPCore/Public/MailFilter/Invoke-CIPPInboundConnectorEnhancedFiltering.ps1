function Invoke-CIPPInboundConnectorEnhancedFiltering {
    <#
    .SYNOPSIS
        Sets Enhanced Filtering skip IPs, skip-last-IP, and users on an inbound connector.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TenantFilter,
        [Parameter(Mandatory)][string]$TicketNumber,
        [Parameter(Mandatory)][string]$Caller,
        [Parameter(Mandatory)][string]$Identity,
        [bool]$HasSkipIPs,
        $SkipIPs,
        [bool]$HasSkipLastIP,
        $SkipLastIP,
        [bool]$HasUsers,
        $Users,
        $DryRun,
        [string]$ApiName = 'ExecInboundConnectorEnhancedFiltering'
    )

    $Tenant = Test-CIPPMailFilterIdentity -Value $TenantFilter -Label 'tenantFilter'
    $Ticket = Test-CIPPMailFilterTicket -TicketNumber $TicketNumber
    $Connectors = @(New-ExoRequest -tenantid $Tenant -cmdlet 'Get-InboundConnector' -useSystemMailbox $true)
    $Connector = $Connectors | Where-Object { $_.Identity -eq $Identity -or $_.Name -eq $Identity -or $_.Guid -eq $Identity } | Select-Object -First 1

    $Plan = Get-CIPPInboundConnectorFilteringChange -Identity $Identity -Connector $Connector `
        -HasSkipIPs $HasSkipIPs -SkipIPs $SkipIPs -HasSkipLastIP $HasSkipLastIP -SkipLastIP $SkipLastIP `
        -HasUsers $HasUsers -Users $Users

    return Invoke-CIPPMailFilterApply -TenantFilter $Tenant -TicketNumber $Ticket -Caller $Caller `
        -Operation "inbound connector $Identity enhanced filtering" -DryRun (ConvertTo-CIPPMailFilterBool $DryRun) `
        -AllowWeakerProtection $false -Plan $Plan -ApiName $ApiName
}

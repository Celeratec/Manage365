function Invoke-ExecInboundConnectorEnhancedFiltering {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.Connector.ReadWrite
    .DESCRIPTION
        Sets Enhanced Filtering on an inbound connector: EFSkipIPs, EFSkipLastIP, and EFUsers.
        The write snapshots the connector first, requires a numeric ticket ID, and returns a rollback payload.
        Set dryRun to true to receive the diff without applying it.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    # Tenant that owns the connector.
    $TenantFilter = $Request.Query.tenantFilter ?? $Request.Body.tenantFilter
    # Numeric ticket ID recorded with the audit row.
    $TicketNumber = $Request.Query.ticketNumber ?? $Request.Body.ticketNumber ?? $Request.Query.TicketNumber ?? $Request.Body.TicketNumber
    # Inbound connector name or identity.
    $Identity = $Request.Query.identity ?? $Request.Body.identity
    # When true, return the diff and rollback payload without changing the tenant.
    $DryRun = $Request.Query.dryRun ?? $Request.Body.dryRun
    # IP addresses Enhanced Filtering should skip.
    $EfSkipIPs = $Request.Query.efSkipIPs ?? $Request.Body.efSkipIPs
    # Skip the last IP in the received chain.
    $EfSkipLastIP = $Request.Query.efSkipLastIP ?? $Request.Body.efSkipLastIP
    # Users Enhanced Filtering applies to. An empty list clears the user scope.
    $EfUsers = $Request.Query.efUsers ?? $Request.Body.efUsers

    try {
        $Caller = Get-CIPPMailFilterCaller -Headers $Request.Headers
        $Outcome = Invoke-CIPPInboundConnectorEnhancedFiltering -TenantFilter $TenantFilter -TicketNumber $TicketNumber -Caller $Caller `
            -Identity $Identity -DryRun $DryRun -ApiName $APIName `
            -HasSkipIPs (Test-CIPPMailFilterRequestField -Request $Request -Name 'efSkipIPs') -SkipIPs $EfSkipIPs `
            -HasSkipLastIP (Test-CIPPMailFilterRequestField -Request $Request -Name 'efSkipLastIP') -SkipLastIP $EfSkipLastIP `
            -HasUsers (Test-CIPPMailFilterRequestField -Request $Request -Name 'efUsers') -Users $EfUsers
        try {
            Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message "$($Outcome.Results) Caller $Caller. Ticket $TicketNumber." -Sev $(if ($Outcome.Error) { 'Error' } else { 'Info' })
        } catch {
            $Outcome.LogWarning = $_.Exception.Message
        }
        $StatusCode = if ($Outcome.Error) { [HttpStatusCode]::InternalServerError } else { [HttpStatusCode]::OK }
        $Body = $Outcome
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Body = @{ Results = $ErrorMessage.NormalizedError; Applied = $false }
        $StatusCode = [HttpStatusCode]::BadRequest
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message "Inbound connector Enhanced Filtering change failed: $($ErrorMessage.NormalizedError)" -Sev 'Error' -LogData $ErrorMessage
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}

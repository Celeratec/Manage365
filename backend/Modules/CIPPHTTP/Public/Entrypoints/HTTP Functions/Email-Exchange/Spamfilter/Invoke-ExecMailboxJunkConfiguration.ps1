function Invoke-ExecMailboxJunkConfiguration {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.SpamFilter.ReadWrite
    .DESCRIPTION
        Adds or removes trusted (safe) senders and blocked senders on a mailbox.
        The current list is read and merged. The write does not use TrustedSendersToAdd, which fails
        against the Exchange Online REST proxy. A numeric ticket ID is required. The response includes
        the snapshot and a rollback payload. Set dryRun to true to receive the diff without applying it.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    # Tenant that owns the mailbox.
    $TenantFilter = $Request.Query.tenantFilter ?? $Request.Body.tenantFilter
    # Numeric ticket ID recorded with the audit row.
    $TicketNumber = $Request.Query.ticketNumber ?? $Request.Body.ticketNumber ?? $Request.Query.TicketNumber ?? $Request.Body.TicketNumber
    # Mailbox to update.
    $Mailbox = $Request.Query.mailbox ?? $Request.Body.mailbox
    # When true, return the diff and rollback payload without changing the mailbox.
    $DryRun = $Request.Query.dryRun ?? $Request.Body.dryRun
    # Trusted senders or domains to add. Merged with the current list.
    $TrustedSendersToAdd = $Request.Query.trustedSendersToAdd ?? $Request.Body.trustedSendersToAdd
    # Trusted senders or domains to remove.
    $TrustedSendersToRemove = $Request.Query.trustedSendersToRemove ?? $Request.Body.trustedSendersToRemove
    # Blocked senders or domains to add.
    $BlockedSendersToAdd = $Request.Query.blockedSendersToAdd ?? $Request.Body.blockedSendersToAdd
    # Blocked senders or domains to remove.
    $BlockedSendersToRemove = $Request.Query.blockedSendersToRemove ?? $Request.Body.blockedSendersToRemove

    try {
        $Caller = Get-CIPPMailFilterCaller -Headers $Request.Headers
        $Outcome = Invoke-CIPPMailboxJunkConfiguration -TenantFilter $TenantFilter -TicketNumber $TicketNumber -Caller $Caller `
            -Mailbox $Mailbox -DryRun $DryRun -ApiName $APIName `
            -TrustedToAdd $TrustedSendersToAdd -TrustedToRemove $TrustedSendersToRemove `
            -BlockedToAdd $BlockedSendersToAdd -BlockedToRemove $BlockedSendersToRemove
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
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message "Mailbox junk configuration change failed: $($ErrorMessage.NormalizedError)" -Sev 'Error' -LogData $ErrorMessage
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}

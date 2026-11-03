function Invoke-ExecFocusedInbox {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.Mailbox.ReadWrite
    .DESCRIPTION
        Turns Focused Inbox on or off for one mailbox (Set-FocusedInbox) or the whole organisation
        (Set-OrganizationConfig -FocusedInboxOn). The write snapshots the current value, requires a
        numeric ticket ID, and returns a rollback payload. Set dryRun to true to receive the diff
        without applying it.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    # Tenant to update.
    $TenantFilter = $Request.Query.tenantFilter ?? $Request.Body.tenantFilter
    # Numeric ticket ID recorded with the audit row.
    $TicketNumber = $Request.Query.ticketNumber ?? $Request.Body.ticketNumber ?? $Request.Query.TicketNumber ?? $Request.Body.TicketNumber
    # Mailbox or Organization.
    $Scope = $Request.Query.scope ?? $Request.Body.scope
    # Mailbox address. Required when scope is Mailbox.
    $Mailbox = $Request.Query.mailbox ?? $Request.Body.mailbox
    # True turns Focused Inbox on. False turns it off.
    $Enabled = $Request.Query.enabled ?? $Request.Body.enabled
    # When true, return the diff and rollback payload without changing the tenant.
    $DryRun = $Request.Query.dryRun ?? $Request.Body.dryRun

    try {
        $Caller = Get-CIPPMailFilterCaller -Headers $Request.Headers
        $Outcome = Invoke-CIPPFocusedInbox -TenantFilter $TenantFilter -TicketNumber $TicketNumber -Caller $Caller `
            -Scope $Scope -Mailbox $Mailbox -Enabled $Enabled -DryRun $DryRun -ApiName $APIName
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
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message "Focused Inbox change failed: $($ErrorMessage.NormalizedError)" -Sev 'Error' -LogData $ErrorMessage
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}

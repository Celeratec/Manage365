function Invoke-ExecMailboxSafeSender {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.SpamFilter.ReadWrite
    .DESCRIPTION
        Adds a sender to a mailbox trusted/safe senders list via Set-MailboxJunkEmailConfiguration.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $TenantFilter = $Request.Body.tenantFilter | Select-Object -First 1
    $Mailbox = Get-CippQuarantineInputValue $Request.Body.mailbox
    $Sender = Get-CippQuarantineInputValue $Request.Body.sender

    try {
        if ([string]::IsNullOrWhiteSpace($Mailbox)) { throw 'mailbox is required.' }
        if ([string]::IsNullOrWhiteSpace($Sender)) { throw 'sender is required.' }

        # TrustedSendersToAdd fails through the Exchange REST proxy. Read the current list and write the merge.
        $Current = New-ExoRequest -tenantid $TenantFilter -Anchor $Mailbox -cmdlet 'Get-MailboxJunkEmailConfiguration' -cmdParams @{ Identity = $Mailbox } -useSystemMailbox $true
        $Merged = Join-CIPPMailboxJunkSenderList -Existing $Current.TrustedSendersAndDomains -Add @($Sender)
        New-ExoRequest -tenantid $TenantFilter -Anchor $Mailbox -cmdlet 'Set-MailboxJunkEmailConfiguration' -cmdParams @{
            Identity                 = $Mailbox
            TrustedSendersAndDomains = @($Merged.List)
        } -useSystemMailbox $true

        $Result = if (@($Merged.Added) -contains $Sender) {
            "Added $Sender to the safe senders list for $Mailbox."
        } else {
            "$Sender is already on the safe senders list for $Mailbox."
        }
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Info'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $Result }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Result = "Failed to add safe sender for $Mailbox`: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Error'
        $StatusCode = [HttpStatusCode]::BadRequest
        $Body = @{ Results = $Result }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}

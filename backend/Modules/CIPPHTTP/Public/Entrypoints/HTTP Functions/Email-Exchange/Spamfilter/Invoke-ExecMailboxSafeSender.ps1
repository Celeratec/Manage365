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
    
    # Normalize tenantFilter: reject arrays, take single value
    $TenantFilter = if ($Request.Body.tenantFilter -is [array]) {
        if ($Request.Body.tenantFilter.Count -ne 1) {
            throw 'tenantFilter must be a single tenant, not an array'
        }
        $Request.Body.tenantFilter[0]
    } else {
        $Request.Body.tenantFilter
    }
    
    $Mailbox = Get-CippQuarantineInputValue $Request.Body.mailbox
    $Sender = Get-CippQuarantineInputValue $Request.Body.sender

    try {
        if ([string]::IsNullOrWhiteSpace($TenantFilter)) { throw 'tenantFilter is required.' }
        if ([string]::IsNullOrWhiteSpace($Mailbox)) { throw 'mailbox is required.' }
        if ([string]::IsNullOrWhiteSpace($Sender)) { throw 'sender is required.' }

        # Validate sender as email or domain
        $Validation = Test-CippExchangeInputValidation -EmailAddress $Sender
        if (-not $Validation.IsValid) {
            # Try as domain
            $Validation = Test-CippExchangeInputValidation -Domain $Sender
            if (-not $Validation.IsValid) {
                throw "Sender must be a valid email address or domain"
            }
        }

        New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-MailboxJunkEmailConfiguration' -cmdParams @{
            Identity                 = $Mailbox
            TrustedSendersAndDomains = @{'@odata.type' = '#Exchange.GenericHashTable'; Add = $Sender }
        }

        $Result = "Added $Sender to the safe senders list for $Mailbox."
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Info'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $Result }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Result = "Failed to add safe sender for $Mailbox`: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Error'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $Result }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}

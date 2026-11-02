function Invoke-ExecFocusedInbox {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.Mailbox.ReadWrite
    .DESCRIPTION
        Configure Focused Inbox for a specific mailbox (Get/Set-FocusedInbox).
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $TenantFilter = $Request.Body.tenantFilter | Select-Object -First 1
    $UserPrincipalName = Get-CippQuarantineInputValue $Request.Body.userPrincipalName
    $Action = $Request.Body.action  # Get, Enable, or Disable

    try {
        # Input validation
        if ([string]::IsNullOrWhiteSpace($TenantFilter)) { throw 'tenantFilter is required.' }
        if ([string]::IsNullOrWhiteSpace($UserPrincipalName)) { throw 'userPrincipalName is required.' }
        if ([string]::IsNullOrWhiteSpace($Action)) { throw 'action is required.' }
        if ($Action -notin @('Get', 'Enable', 'Disable')) { throw 'action must be Get, Enable, or Disable.' }

        if ($Action -eq 'Get') {
            # Get current Focused Inbox state
            $Result = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-FocusedInbox' -cmdParams @{
                Identity = $UserPrincipalName
            } -Anchor $UserPrincipalName

            Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message "Retrieved Focused Inbox state for $UserPrincipalName" -Sev 'Info'
            $StatusCode = [HttpStatusCode]::OK
            $Body = $Result
        } else {
            # Set Focused Inbox state
            $FocusedInboxEnabled = ($Action -eq 'Enable')
            New-ExoRequest -tenantid $TenantFilter -cmdlet 'Set-FocusedInbox' -cmdParams @{
                Identity             = $UserPrincipalName
                FocusedInboxOn       = $FocusedInboxEnabled
            } -Anchor $UserPrincipalName

            $Result = "Focused Inbox ${Action}d for $UserPrincipalName"
            Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Info'
            $StatusCode = [HttpStatusCode]::OK
            $Body = @{ Results = $Result }
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Result = "Failed to $Action Focused Inbox for $UserPrincipalName in $TenantFilter`: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Error'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $Result }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}

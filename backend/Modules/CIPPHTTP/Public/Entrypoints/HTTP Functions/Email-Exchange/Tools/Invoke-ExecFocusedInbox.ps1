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
    
    # Normalize tenantFilter
    $TenantFilter = if ($Request.Body.tenantFilter -is [array]) {
        if ($Request.Body.tenantFilter.Count -ne 1) {
            throw 'tenantFilter must be a single tenant, not an array'
        }
        $Request.Body.tenantFilter[0]
    } else {
        $Request.Body.tenantFilter
    }
    
    $UserPrincipalName = Get-CippQuarantineInputValue $Request.Body.userPrincipalName
    $Action = $Request.Body.action  # Get, Enable, or Disable

    try {
        # Input validation
        if ([string]::IsNullOrWhiteSpace($TenantFilter)) { throw 'tenantFilter is required.' }
        if ([string]::IsNullOrWhiteSpace($UserPrincipalName)) { throw 'userPrincipalName is required.' }
        if ([string]::IsNullOrWhiteSpace($Action)) { throw 'action is required.' }
        if ($Action -notin @('Get', 'Enable', 'Disable')) { throw 'action must be Get, Enable, or Disable.' }
        
        # Validate UPN
        $Validation = Test-CippExchangeInputValidation -UserPrincipalName $UserPrincipalName
        if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }

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

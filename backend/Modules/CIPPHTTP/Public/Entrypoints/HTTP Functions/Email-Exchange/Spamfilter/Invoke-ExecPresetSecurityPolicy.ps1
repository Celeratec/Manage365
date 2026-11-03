function Invoke-ExecPresetSecurityPolicy {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.SpamFilter.ReadWrite
    .DESCRIPTION
        Turns the Standard or Strict preset security policy on or off and changes its scope.
        The write snapshots the current EOP and Defender preset rules, requires a numeric ticket ID,
        and returns a rollback payload. Set dryRun to true to receive the diff without applying it.
        Disabling a preset or shrinking its scope is rejected unless allowWeakerProtection is true.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    # Tenant the preset change applies to.
    $TenantFilter = $Request.Query.tenantFilter ?? $Request.Body.tenantFilter
    # Numeric ticket ID recorded with the audit row.
    $TicketNumber = $Request.Query.ticketNumber ?? $Request.Body.ticketNumber ?? $Request.Query.TicketNumber ?? $Request.Body.TicketNumber
    # Standard or Strict.
    $Preset = $Request.Query.preset ?? $Request.Body.preset
    # Enable or Disable. Omit to leave the current state and change scope only.
    $State = $Request.Query.state ?? $Request.Body.state
    # When true, return the diff and rollback payload without changing the tenant.
    $DryRun = $Request.Query.dryRun ?? $Request.Body.dryRun
    # Explicit override that allows a change which weakens current protection.
    $AllowWeakerProtection = $Request.Query.allowWeakerProtection ?? $Request.Body.allowWeakerProtection
    # Users the preset applies to (SentTo). Send an empty list to clear them.
    $Users = $Request.Query.users ?? $Request.Body.users
    # Groups the preset applies to (SentToMemberOf).
    $Groups = $Request.Query.groups ?? $Request.Body.groups
    # Domains the preset applies to (RecipientDomainIs).
    $Domains = $Request.Query.domains ?? $Request.Body.domains
    # Users excluded from the preset.
    $ExceptUsers = $Request.Query.exceptUsers ?? $Request.Body.exceptUsers
    # Groups excluded from the preset.
    $ExceptGroups = $Request.Query.exceptGroups ?? $Request.Body.exceptGroups
    # Domains excluded from the preset.
    $ExceptDomains = $Request.Query.exceptDomains ?? $Request.Body.exceptDomains

    try {
        $Caller = Get-CIPPMailFilterCaller -Headers $Request.Headers
        $Outcome = Invoke-CIPPPresetSecurityPolicy -TenantFilter $TenantFilter -TicketNumber $TicketNumber -Caller $Caller `
            -Preset $Preset -State $State -DryRun $DryRun -AllowWeakerProtection $AllowWeakerProtection -ApiName $APIName `
            -HasUsers (Test-CIPPMailFilterRequestField -Request $Request -Name 'users') -Users $Users `
            -HasGroups (Test-CIPPMailFilterRequestField -Request $Request -Name 'groups') -Groups $Groups `
            -HasDomains (Test-CIPPMailFilterRequestField -Request $Request -Name 'domains') -Domains $Domains `
            -HasExceptUsers (Test-CIPPMailFilterRequestField -Request $Request -Name 'exceptUsers') -ExceptUsers $ExceptUsers `
            -HasExceptGroups (Test-CIPPMailFilterRequestField -Request $Request -Name 'exceptGroups') -ExceptGroups $ExceptGroups `
            -HasExceptDomains (Test-CIPPMailFilterRequestField -Request $Request -Name 'exceptDomains') -ExceptDomains $ExceptDomains
        $Severity = if ($Outcome.Blocked -or $Outcome.Error) { 'Warning' } else { 'Info' }
        try {
            Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message "$($Outcome.Results) Caller $Caller. Ticket $TicketNumber." -Sev $Severity
        } catch {
            $Outcome.LogWarning = $_.Exception.Message
        }
        $StatusCode = if ($Outcome.Blocked) { [HttpStatusCode]::BadRequest } elseif ($Outcome.Error) { [HttpStatusCode]::InternalServerError } else { [HttpStatusCode]::OK }
        $Body = $Outcome
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Body = @{ Results = $ErrorMessage.NormalizedError; Applied = $false }
        $StatusCode = [HttpStatusCode]::BadRequest
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message "Preset security policy change failed: $($ErrorMessage.NormalizedError)" -Sev 'Error' -LogData $ErrorMessage
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}

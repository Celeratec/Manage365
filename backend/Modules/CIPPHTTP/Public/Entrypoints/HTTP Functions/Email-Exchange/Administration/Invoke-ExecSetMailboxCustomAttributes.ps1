function Invoke-ExecSetMailboxCustomAttributes {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.Mailbox.ReadWrite
    .DESCRIPTION
        Sets mailbox custom attributes. Send AttributeNumber (1-15), Value (1024 characters max; empty clears), tenantFilter, ticketNumber, and dryRun to set one attribute and receive the old and new values. The existing CustomAttribute1-15 body is still accepted for the mailbox editor.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint

    $AttributeNumberRaw = $Request.Body.AttributeNumber
    if ($null -ne $AttributeNumberRaw -and "$AttributeNumberRaw" -ne '') {
        $Gate = Test-CIPPGuardedWriteRequest -Request $Request -IsWrite
        if (-not $Gate.Ok) {
            $Headers = @{}
            if ($Gate.StatusCode -eq 429) { $Headers['Retry-After'] = [string]$Gate.RetryAfter }
            return [HttpResponseContext]@{ StatusCode = $Gate.StatusCode; Headers = $Headers; Body = @{ Results = $Gate.Message; Status = 'Failed' } }
        }
        $AttributeNumber = 0
        $NumberText = [string]$AttributeNumberRaw
        if ($NumberText -notmatch '^\d+$' -or -not [int]::TryParse($NumberText, [ref]$AttributeNumber) -or $AttributeNumber -lt 1 -or $AttributeNumber -gt 15) {
            return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'AttributeNumber must be an integer from 1 to 15.'; Status = 'Failed' } }
        }
        $HasValue = $false
        if ($Request.Body -is [System.Collections.IDictionary]) {
            $HasValue = @($Request.Body.Keys) -contains 'Value'
        } elseif ($null -ne $Request.Body.PSObject) {
            $HasValue = $null -ne $Request.Body.PSObject.Properties['Value']
        }
        if (-not $HasValue) {
            return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'Value is required. Send an empty string to clear the attribute.'; Status = 'Failed' } }
        }
        $Value = [string]$Request.Body.Value
        if ($Value.Length -gt 1024) {
            return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'Value must be at most 1024 characters.'; Status = 'Failed' } }
        }
        $Identity = [string]($Request.Body.Identity | Select-Object -First 1)
        if ([string]::IsNullOrWhiteSpace($Identity)) { $Identity = [string]$Request.Body.userid }
        if ([string]::IsNullOrWhiteSpace($Identity)) {
            return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'Identity is required.'; Status = 'Failed' } }
        }
        $AttributeName = "CustomAttribute$AttributeNumber"
        try {
            $Mailbox = New-ExoRequest -tenantid $Gate.Tenant -cmdlet 'Get-Mailbox' -cmdParams @{ Identity = $Identity } -Select "Identity,$AttributeName"
        } catch {
            $ErrorMessage = Get-CippException -Exception $_
            $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -DryRun $Gate.DryRun -Result $ErrorMessage.NormalizedError
            return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::InternalServerError; Body = @{ Results = $ErrorMessage.NormalizedError; Status = 'Failed'; AuditId = $AuditId } }
        }
        $Current = $Mailbox
        if ($Mailbox -is [System.Array]) { $Current = $Mailbox | Select-Object -First 1 }
        $OldValue = [string]$Current.$AttributeName
        $Before = @{ Identity = $Identity; Attribute = $AttributeName; Value = $OldValue }
        $After = @{ Identity = $Identity; Attribute = $AttributeName; Value = $Value }
        if ($Gate.DryRun) {
            $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -After $After -DryRun $true -Result 'DryRun'
            return [HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
                Body       = @{ Results = "Would set $AttributeName on $Identity."; Status = 'DryRun'; AuditId = $AuditId; Before = $Before; After = $After; OldValue = $OldValue; NewValue = $Value; ticketNumber = $Gate.Ticket; dryRun = $true }
            }
        }
        try {
            $null = New-ExoRequest -tenantid $Gate.Tenant -cmdlet 'Set-Mailbox' -cmdParams @{ Identity = $Identity; $AttributeName = $Value }
        } catch {
            $ErrorMessage = Get-CippException -Exception $_
            $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -DryRun $false -Result $ErrorMessage.NormalizedError
            return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::InternalServerError; Body = @{ Results = $ErrorMessage.NormalizedError; Status = 'Failed'; AuditId = $AuditId; Before = $Before; OldValue = $OldValue } }
        }
        $Summary = "Set $AttributeName on $Identity."
        Write-LogMessage -API $APIName -tenant $Gate.Tenant -message $Summary -sev Info
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Before -After $After -DryRun $false -Result 'Success'
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{ Results = $Summary; Status = 'Success'; AuditId = $AuditId; Before = $Before; After = $After; OldValue = $OldValue; NewValue = $Value; ticketNumber = $Gate.Ticket; dryRun = $false }
        }
    }

    # Interact with the query or body of the request
    $TenantFilter = $Request.Body.tenantFilter
    $Identity = $Request.Body.Identity
    $UserPrincipalName = $Request.Body.userid

    $CmdParams = @{
        Identity = $Identity
    }
    $UpdatedAttributes = [System.Collections.Generic.List[string]]::new()
    $BodyPropertyNames = @($Request.Body.PSObject.Properties.Name)

    foreach ($Index in 1..15) {
        $AttributeName = "CustomAttribute$Index"
        # Only set attributes present on the body (including empty string to clear).
        # Missing keys are left unchanged so bulk/selective edits do not wipe others.
        if ($AttributeName -in $BodyPropertyNames) {
            $CmdParams[$AttributeName] = [string]$Request.Body.$AttributeName
            $UpdatedAttributes.Add($AttributeName)
        }
    }

    if ($UpdatedAttributes.Count -eq 0) {
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{ Results = 'No custom attributes were provided to update' }
            })
    }

    $ExoRequest = @{
        tenantid  = $TenantFilter
        cmdlet    = 'Set-Mailbox'
        cmdParams = $CmdParams
    }

    $AttributeList = $UpdatedAttributes -join ', '

    try {
        $null = New-ExoRequest @ExoRequest
        $Results = "Custom attributes for $UserPrincipalName have been updated ($AttributeList)"

        Write-LogMessage -API $APIName -tenant $TenantFilter -message $Results -sev Info
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Results = "Could not update custom attributes for $UserPrincipalName. Error: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -API $APIName -tenant $TenantFilter -message $Results -sev Error -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = @{ Results = $Results }
        })
}

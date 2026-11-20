function Invoke-ExecSoftDeleteMailboxFolder {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.Mailbox.ReadWrite
    .DESCRIPTION
        Soft-deletes one mailbox folder by moving it to Deleted Items (never permanent delete).
        Requires tenantFilter, userId, folderId or folderPath, folderType (mail|calendar),
        ticketNumber (6-8 digits), and Reason. preview/dryRun defaults to true (read-only).
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Parsed = Test-CIPPMailboxFolderSoftDeleteRequest -Request $Request
    if (-not $Parsed.Ok) {
        return [HttpResponseContext]@{ StatusCode = $Parsed.StatusCode; Body = @{ Results = $Parsed.Message; Status = 'Failed' } }
    }
    $Gate = Test-CIPPGuardedWriteRequest -Request $Request -IsWrite:(-not $Parsed.Preview)
    if (-not $Gate.Ok) {
        $Headers = @{}
        if ($Gate.StatusCode -eq 429) { $Headers['Retry-After'] = [string]$Gate.RetryAfter }
        return [HttpResponseContext]@{ StatusCode = $Gate.StatusCode; Headers = $Headers; Body = @{ Results = $Gate.Message; Status = 'Failed' } }
    }
    try {
        $Outcome = Invoke-CIPPMailboxFolderSoftDelete -TenantFilter $Gate.Tenant -UserId $Parsed.UserId `
            -FolderId $Parsed.FolderId -FolderPath $Parsed.FolderPath -FolderType $Parsed.FolderType -Preview $Parsed.Preview
        $AuditResult = if ($Outcome.Status -eq 'DryRun') { 'DryRun' } elseif ($Outcome.Status -eq 'Success') { 'Success' } else { [string]$Outcome.Results }
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller `
            -Request $Request.Body -Before $Outcome.Before -After $Outcome.After -DryRun $Parsed.Preview -Result $AuditResult
        $StatusCode = if ($Outcome.Status -eq 'Failed') { [HttpStatusCode]::BadRequest } else { [HttpStatusCode]::OK }
        return [HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = @{
                Results          = $Outcome.Results
                Status           = $Outcome.Status
                AuditId          = $AuditId
                Before           = $Outcome.Before
                After            = $Outcome.After
                PlannedMove      = $Outcome.PlannedMove
                deletedFolderId  = $Outcome.deletedFolderId
                originalParentId = $Outcome.originalParentId
                ticketNumber     = $Gate.Ticket
                reason           = $Parsed.Reason
                preview          = $Parsed.Preview
                dryRun           = $Parsed.Preview
            }
        }
    } catch {
        $Msg = (Get-CippException -Exception $_).NormalizedError
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -DryRun $Parsed.Preview -Result $Msg
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::InternalServerError; Body = @{ Results = $Msg; Status = 'Failed'; AuditId = $AuditId } }
    }
}

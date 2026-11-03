function Add-CIPPGuardedWriteAudit {
    <#
    .SYNOPSIS
        Writes one guarded-write audit row and returns its id.
    .DESCRIPTION
        Secrets are removed before the row is stored. A failure to write the audit row is logged
        and does not fail the tenant change that already succeeded.
    #>
    [CmdletBinding()]
    param(
        [string]$Endpoint,
        [string]$Tenant,
        [string]$Ticket,
        [string]$Caller,
        $Request,
        $Before,
        $After,
        [bool]$DryRun,
        [string]$Result,
        [string[]]$SecretValues = @()
    )

    $AuditId = [guid]::NewGuid().ToString()
    $RedactedRequest = ConvertTo-CIPPGuardedWriteRedacted -Value $Request -SecretValues $SecretValues
    $RedactedBefore = ConvertTo-CIPPGuardedWriteRedacted -Value $Before -SecretValues $SecretValues
    $RedactedAfter = ConvertTo-CIPPGuardedWriteRedacted -Value $After -SecretValues $SecretValues
    try {
        $Table = Get-CippTable -TableName 'GuardedWriteAudit'
        $Entity = @{
            PartitionKey = $Tenant
            RowKey       = $AuditId
            Endpoint     = $Endpoint
            TicketNumber = $Ticket
            Caller       = $Caller
            Request      = ($RedactedRequest | ConvertTo-Json -Depth 8 -Compress)
            Before       = ($RedactedBefore | ConvertTo-Json -Depth 8 -Compress)
            After        = ($RedactedAfter | ConvertTo-Json -Depth 8 -Compress)
            WhatIf       = $DryRun
            Result       = $Result
            TimestampUtc = [datetime]::UtcNow.ToString('o')
        }
        foreach ($Key in @('Request', 'Before', 'After', 'Result')) {
            if ([string]$Entity[$Key].Length -gt 24000) { $Entity[$Key] = $Entity[$Key].Substring(0, 24000) }
        }
        Add-CIPPAzDataTableEntity @Table -Entity $Entity -Force
    } catch {
        Write-LogMessage -API $Endpoint -tenant $Tenant -message "Guarded write audit failed for $AuditId`: $($_.Exception.Message)" -Sev 'Warning'
    }
    return $AuditId
}

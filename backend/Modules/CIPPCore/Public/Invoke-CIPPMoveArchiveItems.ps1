function Invoke-CIPPMoveArchiveItems {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Request,

        $Headers,
        [string]$APIName = 'Move Archive Items',
        [string]$Caller
    )

    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $Preview = $null
    $JobId = $null
    $Result = 'Succeeded'
    $ErrorSummary = $null

    try {
        $Preview = Get-CIPPMoveArchiveItemsPreview -TenantFilter $Request.TenantFilter -UserPrincipalName $Request.UserPrincipalName -SourceFolder $Request.SourceFolder -TargetFolder $Request.TargetFolder

        if ($Preview.QuotaIssues.Count -gt 0) {
            throw ($Preview.QuotaIssues -join ' ')
        }

        if (-not $Preview.CanProceedWithoutHoldAck -and -not $Request.HoldAcknowledged) {
            throw "Mailbox has holds ($($Preview.Holds -join ', ')). Set HoldAcknowledged=true after review to proceed."
        }

        if ($Preview.ArchiveItemCount -eq 0) {
            return [PSCustomObject]@{
                DryRun    = [bool]$Request.DryRun
                Preview   = $Preview
                Message   = 'Archive contains no items to move.'
                JobId     = $null
            }
        }

        if ($Request.DryRun) {
            return [PSCustomObject]@{
                DryRun  = $true
                Preview = $Preview
                Message = 'Dry run complete. No items were moved.'
                JobId   = $null
            }
        }

        $JobId = Start-CIPPMoveArchiveItemsJob -Request $Request -Headers $Headers -APIName $APIName -Caller $Caller
        return [PSCustomObject]@{
            DryRun  = $false
            Preview = $Preview
            Message = "Move job queued. Poll ListMoveArchiveItemsJobs with JobId $JobId."
            JobId   = $JobId
        }
    } catch {
        $Result = 'Failed'
        $ErrorSummary = (Get-CippException -Exception $_).NormalizedError
        throw
    } finally {
        $Stopwatch.Stop()
        if ($Preview) {
            $null = Add-CIPPMoveArchiveItemsAudit -TenantFilter $Request.TenantFilter -UserPrincipalName $Request.UserPrincipalName -TicketNumber $Request.TicketNumber -Operation $(if ($Request.DryRun) { 'DryRun' } else { 'Enqueue' }) -Result $Result -JobId $JobId -DryRun $Request.DryRun -Caller $Caller -ArchiveItemCountBefore $Preview.ArchiveItemCount -ArchiveItemCountAfter $(if ($Request.DryRun) { $Preview.ArchiveItemCount } else { $null }) -PrimaryItemCountBefore $Preview.PrimaryItemCount -PrimaryItemCountAfter $null -ArchiveBytesBefore $Preview.ArchiveTotalBytes -PrimaryBytesBefore $Preview.PrimaryTotalBytes -PrimaryBytesAfterMoveProjected $Preview.ProjectedPrimaryTotalBytes -DurationMs [int]$Stopwatch.ElapsedMilliseconds -ErrorSummary $ErrorSummary
        }
    }
}

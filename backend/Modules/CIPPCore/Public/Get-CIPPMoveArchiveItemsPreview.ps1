function Get-CIPPMoveArchiveItemsPreview {
    <#
    .SYNOPSIS
        Dry-run preview for moving archive items into the primary mailbox.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName,

        [string]$SourceFolder,
        [string]$TargetFolder
    )

    $SharedPrimaryLimitBytes = 50GB

    $Mailbox = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-Mailbox' -cmdParams @{
        Identity = $UserPrincipalName
    } -Select 'UserPrincipalName,RecipientTypeDetails,ArchiveGuid,ProhibitSendReceiveQuota,IssueWarningQuota,LitigationHoldEnabled,RetentionHoldEnabled,InPlaceHolds,DisplayName'

    if (-not $Mailbox) {
        throw "Mailbox not found for $UserPrincipalName"
    }

    $ArchiveEnabled = $Mailbox.ArchiveGuid -and $Mailbox.ArchiveGuid -ne '00000000-0000-0000-0000-000000000000'
    if (-not $ArchiveEnabled) {
        throw "Mailbox $UserPrincipalName does not have an Exchange Online archive enabled."
    }

    $RecipientType = [string]$Mailbox.RecipientTypeDetails
    $IsShared = $RecipientType -eq 'SharedMailbox'

    $PrimaryStats = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-MailboxStatistics' -cmdParams @{
        Identity = $UserPrincipalName
    } -Anchor $UserPrincipalName

    $ArchiveStats = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-MailboxStatistics' -cmdParams @{
        Identity = $UserPrincipalName
        Archive  = $true
    } -Anchor $UserPrincipalName

    $PrimaryBytes = Get-ExoOnlineStringBytes -SizeString ([string]$PrimaryStats.TotalItemSize)
    $ArchiveBytes = Get-ExoOnlineStringBytes -SizeString ([string]$ArchiveStats.TotalItemSize)
    $PrimaryItems = [int]($PrimaryStats.ItemCount ?? 0)
    $ArchiveItems = [int]($ArchiveStats.ItemCount ?? 0)

    $ProjectedPrimaryBytes = $PrimaryBytes + $ArchiveBytes
    $QuotaBytes = Get-ExoOnlineStringBytes -SizeString ([string]$Mailbox.ProhibitSendReceiveQuota)
    $QuotaIssues = [System.Collections.Generic.List[string]]::new()

    if ($IsShared -and $ProjectedPrimaryBytes -gt $SharedPrimaryLimitBytes) {
        $QuotaIssues.Add("Shared mailbox primary would exceed 50 GB after move (projected $([math]::Round($ProjectedPrimaryBytes / 1GB, 2)) GB).")
    } elseif ($QuotaBytes -gt 0 -and $ProjectedPrimaryBytes -gt $QuotaBytes) {
        $QuotaIssues.Add('Primary mailbox quota would be exceeded after move.')
    }

    $Holds = [System.Collections.Generic.List[string]]::new()
    if ($Mailbox.LitigationHoldEnabled -eq $true) { $Holds.Add('LitigationHold') }
    if ($Mailbox.RetentionHoldEnabled -eq $true) { $Holds.Add('RetentionHold') }
    if (@($Mailbox.InPlaceHolds).Count -gt 0) { $Holds.Add('InPlaceHolds') }

    $DefaultTarget = if ($TargetFolder) { $TargetFolder } else { 'Restored from Archive' }
    $FolderRows = @(
        [PSCustomObject]@{
            SourceFolder     = if ($SourceFolder) { $SourceFolder } else { 'Archive (all folders)' }
            TargetFolder     = if ($SourceFolder) { $DefaultTarget } else { $DefaultTarget }
            ItemCount        = $ArchiveItems
            TotalBytes       = $ArchiveBytes
            TargetExists     = $false
            Note             = 'Per-folder breakdown requires Graph/EWS discovery in the move worker; counts are archive-wide from Get-MailboxStatistics -Archive.'
        }
    )

    return [PSCustomObject]@{
        UserPrincipalName          = $Mailbox.UserPrincipalName
        DisplayName                = $Mailbox.DisplayName
        RecipientTypeDetails       = $RecipientType
        ArchiveItemCount           = $ArchiveItems
        ArchiveTotalBytes          = $ArchiveBytes
        PrimaryItemCount           = $PrimaryItems
        PrimaryTotalBytes          = $PrimaryBytes
        ProjectedPrimaryTotalBytes = $ProjectedPrimaryBytes
        ProhibitSendReceiveQuota   = $Mailbox.ProhibitSendReceiveQuota
        SharedPrimaryLimitBytes    = if ($IsShared) { $SharedPrimaryLimitBytes } else { $null }
        FolderPreview              = @($FolderRows)
        QuotaIssues                = @($QuotaIssues)
        Holds                      = @($Holds)
        CanProceedWithoutHoldAck   = ($Holds.Count -eq 0)
    }
}

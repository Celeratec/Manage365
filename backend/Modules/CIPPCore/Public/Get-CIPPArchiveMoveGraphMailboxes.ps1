function Get-CIPPArchiveMoveGraphMailboxes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName
    )

    $EncodedUser = [System.Uri]::EscapeDataString($UserPrincipalName.Trim())
    $ListUri = "https://graph.microsoft.com/beta/users/$EncodedUser/mailboxes"

    try {
        $Response = Invoke-CIPPGraphExchangeAdminRequest -TenantFilter $TenantFilter -Method GET -Uri $ListUri
        $Mailboxes = @($Response.value)
        if ($Mailboxes.Count -eq 0) { throw 'Graph returned no mailboxes for user.' }

        $Primary = $Mailboxes | Where-Object { $_.mailboxType -eq 'primary' -or $_.mailboxType -eq 'Primary' } | Select-Object -First 1
        $Archive = $Mailboxes | Where-Object { $_.mailboxType -eq 'archive' -or $_.mailboxType -eq 'Archive' } | Select-Object -First 1

        if (-not $Primary) {
            $Primary = $Mailboxes | Select-Object -First 1
        }
        if (-not $Archive) {
            throw 'Graph mailbox discovery did not return an archive mailbox. Ensure MailboxItem.ImportExport permissions and archive is enabled.'
        }

        return [PSCustomObject]@{
            PrimaryMailboxId = [string]$Primary.id
            ArchiveMailboxId = [string]$Archive.id
            Transport        = 'Graph'
        }
    } catch {
        throw "Graph mailbox discovery failed: $($_.Exception.Message). Grant MailboxFolder.Read.All, MailboxItem.ImportExport.All (app) and ensure archive is enabled; worker will attempt EWS fallback."
    }
}

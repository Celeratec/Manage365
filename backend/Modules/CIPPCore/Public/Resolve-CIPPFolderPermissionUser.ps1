function Resolve-CIPPFolderPermissionUser {
    <#
    .SYNOPSIS
        Resolve folder-permission grantees for list/set/remove operations.

    .DESCRIPTION
        Two parameter sets:

        - Permissions (batch): attach UserId to each Get-MailboxFolderPermission row.
        - User (single): resolve one grantee identifier to Exchange candidates for
          Add/Set/Remove-MailboxFolderPermission.

        Get-MailboxFolderPermission only accepts -Identity on read; never pass -User to it.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Permissions')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true, ParameterSetName = 'Permissions')]
        [string]$FolderIdentity,

        [Parameter(Mandatory = $false, ParameterSetName = 'Permissions')]
        $Permissions,

        [Parameter(Mandatory = $true, ParameterSetName = 'User')]
        $User
    )

    if ($PSCmdlet.ParameterSetName -eq 'User') {
        return Resolve-CIPPFolderPermissionGrantee -TenantFilter $TenantFilter -User $User
    }

    $Rows = @($Permissions)
    $Names = @($Rows | Where-Object { $_.User -notin 'Default', 'Anonymous', 'NT AUTHORITY\SELF' } | Select-Object -ExpandProperty User -Unique)
    if ($Names.Count -eq 0) { return $Rows }

    $Recipients = @(New-ExoBulkRequest -tenantid $TenantFilter -useSystemMailbox $true -Select 'PrimarySmtpAddress,Guid' -cmdletArray @(
            foreach ($Name in $Names) {
                @{
                    CmdletInput   = @{ CmdletName = 'Get-Recipient'; Parameters = @{ Filter = "DisplayName -eq '$($Name -replace "'", "''")'"; ResultSize = 'Unlimited' } }
                    OperationGuid = $Name
                }
            }) | Where-Object { $_.Guid })

    $ByName = @{}
    foreach ($Group in $Recipients | Group-Object OperationGuid) { $ByName[$Group.Name] = @($Group.Group) }

    # Disambiguate namesakes using the permission rows we already read (Get-MailboxFolderPermission
    # has no -User parameter in EXO REST). Match AccessRights + display name to candidate GUIDs.
    $Ambiguous = @($ByName.Keys | Where-Object { $ByName[$_].Count -gt 1 })
    $Holders = @{}
    if ($Ambiguous.Count -gt 0) {
        foreach ($Name in $Ambiguous) {
            $Candidates = @($ByName[$Name])
            foreach ($Row in @($Rows | Where-Object { [string]$_.User -eq [string]$Name })) {
                $RightsKey = ($Row.AccessRights -join ', ')
                $Key = '{0}|{1}' -f $Name, $RightsKey
                if (-not $Holders.ContainsKey($Key)) {
                    $Holders[$Key] = [System.Collections.Generic.Queue[string]]::new()
                }
                foreach ($Candidate in $Candidates) {
                    if ($Holders[$Key].Contains($Candidate.Guid)) { continue }
                    $Holders[$Key].Enqueue($Candidate.Guid)
                }
            }
        }
    }

    foreach ($Row in $Rows) {
        $UserId = $null
        $Resolved = $ByName[[string]$Row.User]
        if ($Resolved.Count -eq 1) {
            $UserId = $Resolved[0].Guid
        } elseif ($Resolved.Count -gt 1) {
            $Key = '{0}|{1}' -f $Row.User, ($Row.AccessRights -join ', ')
            if ($Holders.ContainsKey($Key) -and $Holders[$Key].Count -gt 0) { $UserId = $Holders[$Key].Dequeue() }
        }
        $Row | Add-Member -NotePropertyName 'UserId' -NotePropertyValue $UserId -Force
    }

    return $Rows
}

function Resolve-CIPPFolderPermissionGrantee {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        $User
    )

    $SystemUsers = @('Default', 'Anonymous', 'NT AUTHORITY\SELF')
    $UserString = if ($User -is [string]) { $User.Trim() } else { [string]$User }

    if ($UserString -in $SystemUsers) {
        return [PSCustomObject]@{
            User            = $UserString
            UserEmail       = $null
            UserId          = $null
            UserAmbiguous   = $false
            CandidateEmails = @()
            Candidates      = @($UserString)
        }
    }

    $Candidates = [System.Collections.Generic.List[string]]::new()
    $AddCandidate = {
        param([string]$Value)
        if ([string]::IsNullOrWhiteSpace($Value)) { return }
        if (-not $Candidates.Contains($Value)) { [void]$Candidates.Add($Value) }
    }

    & $AddCandidate $UserString

    $Recipients = [System.Collections.Generic.List[object]]::new()
    $TryRecipient = {
        param([hashtable]$Params)
        try {
            $Hit = @(New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-Recipient' -cmdParams $Params -Select 'PrimarySmtpAddress,Guid,DisplayName,ExternalDirectoryObjectId' -useSystemMailbox $true)
            foreach ($Hit in @($Hit)) {
                if ($Hit.Guid) { $Recipients.Add($Hit) }
            }
        } catch {
            Write-Verbose "Get-Recipient lookup failed: $($_.Exception.Message)"
        }
    }

    & $TryRecipient @{ Identity = $UserString }
    if ($Recipients.Count -eq 0 -and $UserString -match '@') {
        $Escaped = $UserString -replace "'", "''"
        & $TryRecipient @{ Filter = "PrimarySmtpAddress -eq '$Escaped'"; ResultSize = 'Unlimited' }
    }
    if ($Recipients.Count -eq 0) {
        $Escaped = $UserString -replace "'", "''"
        & $TryRecipient @{ Filter = "DisplayName -eq '$Escaped'"; ResultSize = 'Unlimited' }
    }

    $UniqueRecipients = @($Recipients | Sort-Object Guid -Unique)
    foreach ($Recipient in $UniqueRecipients) {
        & $AddCandidate $Recipient.PrimarySmtpAddress
        & $AddCandidate $Recipient.Guid
        & $AddCandidate $Recipient.ExternalDirectoryObjectId
        & $AddCandidate $Recipient.DisplayName
    }

    $UserEmail = if ($UniqueRecipients.Count -eq 1) {
        $UniqueRecipients[0].PrimarySmtpAddress
    } elseif ($UserString -match '@') {
        $UserString
    } else {
        $null
    }

    $DisplayUser = if ($UniqueRecipients.Count -eq 1) {
        $UniqueRecipients[0].DisplayName ?? $UserString
    } else {
        $UserString
    }

    return [PSCustomObject]@{
        User            = $DisplayUser
        UserEmail       = $UserEmail
        UserId          = if ($UniqueRecipients.Count -eq 1) { $UniqueRecipients[0].Guid } else { $null }
        UserAmbiguous   = ($UniqueRecipients.Count -gt 1)
        CandidateEmails = @($UniqueRecipients | ForEach-Object { $_.PrimarySmtpAddress } | Where-Object { $_ })
        Candidates      = @($Candidates)
    }
}

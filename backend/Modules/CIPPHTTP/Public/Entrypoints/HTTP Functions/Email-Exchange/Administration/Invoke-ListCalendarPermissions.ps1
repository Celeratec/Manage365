Function Invoke-ListCalendarPermissions {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.Mailbox.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $UserID = $Request.Query.UserID
    $TenantFilter = $Request.Query.tenantFilter
    $UseReportDB = $Request.Query.UseReportDB
    $ByUser = $Request.Query.ByUser

    try {
        # If UseReportDB is specified and no specific UserID, retrieve from report database
        if ($UseReportDB -eq 'true' -and -not $UserID) {

            # Call the report function with proper parameters
            $ReportParams = @{
                TenantFilter = $TenantFilter
            }
            if ($ByUser -eq 'true') {
                $ReportParams.ByUser = $true
            }
            try {
                # Return one page per request as { Results, Metadata } with a continuation token in Metadata.nextLink.
                if ($Request.Query.manualPagination -eq $true) {
                    # Cached rows per page, clamped between 250 and 10000. Defaults to 5000. Pages hold whole tenants.
                    $PageSize = $Request.Query.PageSize -as [int]
                    return ([HttpResponseContext]@{
                            StatusCode = [HttpStatusCode]::OK
                            # Continuation token from the previous page's Metadata.nextLink; opaque to callers.
                            Body       = Get-CIPPReportPage -TenantFilter $TenantFilter -Type 'CalendarPermissions' -PageSize $PageSize -ContinuationToken $Request.Query.nextLink -Report { param($Tenant) Get-CIPPCalendarPermissionReport -TenantFilter $Tenant -ByUser:($ByUser -eq 'true') }
                        })
                }
                $GraphRequest = Get-CIPPCalendarPermissionReport @ReportParams
                $StatusCode = [HttpStatusCode]::OK
            } catch {
                $StatusCode = [HttpStatusCode]::InternalServerError
                $GraphRequest = $_.Exception.Message
            }

            return ([HttpResponseContext]@{
                    StatusCode = $StatusCode
                    Body       = @($GraphRequest)
                })
        }

        # Live query for a single mailbox calendar folder.
        $GetCalParam = @{ Identity = $UserID; FolderScope = 'Calendar' }
        $CalendarFolders = @(New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-MailboxFolderStatistics' -anchor $UserID -cmdParams $GetCalParam -Select 'Name,FolderType')
        $CalendarFolder = $CalendarFolders | Where-Object { $_.FolderType -eq 'Calendar' } | Select-Object -First 1
        if (-not $CalendarFolder) {
            $CalendarFolder = $CalendarFolders | Select-Object -First 1
        }
        $CalParam = @{ Identity = "$($UserID):\$($CalendarFolder.Name)" }
        $MailboxSelect = 'DisplayName,UserPrincipalName,PrimarySmtpAddress,Alias,Identity,Guid,ExchangeGuid,ExternalDirectoryObjectId,RecipientType,RecipientTypeDetails'
        $Mailbox = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-Mailbox' -cmdParams @{ Identity = $UserID } -Select $MailboxSelect
        $RawPermissions = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-MailboxFolderPermission' -anchor $UserID -cmdParams $CalParam -UseSystemMailbox $true -Select 'Identity,User,AccessRights,FolderName'
        $Permissions = Resolve-CIPPFolderPermissionUser -TenantFilter $TenantFilter -FolderIdentity $CalParam.Identity -Permissions $RawPermissions

        $ResolveCache = @{}
        $GraphRequest = foreach ($Perm in @($Permissions)) {
            $UserKey = [string]$Perm.User
            if (-not $ResolveCache.ContainsKey($UserKey)) {
                $ResolveCache[$UserKey] = Resolve-CIPPFolderPermissionUser -User $Perm.User -TenantFilter $TenantFilter
            }
            $Resolved = $ResolveCache[$UserKey]

            [PSCustomObject]@{
                Identity        = $Perm.Identity
                User            = $Resolved.User ?? $(if ($Perm.User -is [string]) { $Perm.User } else { $Perm.User.DisplayName ?? [string]$Perm.User })
                UserEmail       = $Resolved.UserEmail
                UserId          = $Perm.UserId ?? $Resolved.UserId
                UserAmbiguous   = [bool]$Resolved.UserAmbiguous
                CandidateEmails = $Resolved.CandidateEmails
                UserType        = $(
                    if ($Perm.User -is [psobject] -and ($Perm.User.PSObject.Properties.Name -contains 'UserType')) {
                        $Ut = $Perm.User.UserType
                        if ($Ut -is [psobject] -and ($Ut.PSObject.Properties.Name -contains 'Value')) { $Ut.Value } else { [string]$Ut }
                    } else { $null }
                )
                AccessRights    = $Perm.AccessRights
                FolderName      = $Perm.FolderName
                FolderIdentity  = $CalParam.Identity
                MailboxInfo     = $Mailbox
            }
        }

        Write-LogMessage -API $APIName -tenant $TenantFilter -message "Calendar permissions listed for $($TenantFilter)" -sev Debug
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        $StatusCode = [HttpStatusCode]::InternalServerError
        $GraphRequest = $ErrorMessage
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = @($GraphRequest)
        })

}

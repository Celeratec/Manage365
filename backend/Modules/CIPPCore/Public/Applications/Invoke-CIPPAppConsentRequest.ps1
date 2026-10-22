function Get-CIPPConsentApprovalStages {
    param(
        [Parameter(Mandatory = $true)][string]$TenantFilter,
        [Parameter(Mandatory = $true)][string]$AppConsentRequestId,
        [Parameter(Mandatory = $true)][string]$UserConsentRequestId
    )

    # Graph does not expose approval/stages as its own collection. GET of that URL returns
    # "No HTTP resource was found". Stages are a navigation on the approval object.
    $SawResponse = $false
    $LastError = $null
    foreach ($Version in @('v1.0', 'beta')) {
        $Uri = "https://graph.microsoft.com/$Version/identityGovernance/appConsent/appConsentRequests/$AppConsentRequestId/userConsentRequests/$UserConsentRequestId/approval?`$expand=stages"
        try {
            $Approval = New-GraphGetRequest -uri $Uri -tenantid $TenantFilter
            $SawResponse = $true
        } catch {
            $LastError = $_
            continue
        }
        $Stages = @($Approval.stages | Where-Object { $_.id })
        if ($Stages.Count -gt 0) {
            return [pscustomobject]@{ Version = $Version; Stages = $Stages }
        }
    }
    if (-not $SawResponse -and $LastError) { throw $LastError }
    [pscustomobject]@{ Version = 'beta'; Stages = @() }
}

function Submit-CIPPConsentStageDecision {
    param(
        [Parameter(Mandatory = $true)][string]$TenantFilter,
        [Parameter(Mandatory = $true)][string]$Version,
        [Parameter(Mandatory = $true)][string]$AppConsentRequestId,
        [Parameter(Mandatory = $true)][string]$UserConsentRequestId,
        [Parameter(Mandatory = $true)][string]$StageId,
        [Parameter(Mandatory = $true)][string]$ReviewResult,
        [Parameter(Mandatory = $true)][string]$Justification
    )

    $Uri = "https://graph.microsoft.com/$Version/identityGovernance/appConsent/appConsentRequests/$AppConsentRequestId/userConsentRequests/$UserConsentRequestId/approval/stages/$StageId"
    $Body = @{ reviewResult = $ReviewResult; justification = $Justification } | ConvertTo-Json -Compress
    $null = New-GraphPOSTRequest -uri $Uri -tenantid $TenantFilter -type PATCH -body $Body
}

function ConvertTo-CIPPConsentReviewer {
    param($Reviewer)
    $Item = @{
        query     = [string]$Reviewer.query
        queryType = [string]$(if ($Reviewer.queryType) { $Reviewer.queryType } else { 'MicrosoftGraph' })
    }
    if ($Reviewer.PSObject.Properties.Name -contains 'queryRoot' -and -not [string]::IsNullOrWhiteSpace([string]$Reviewer.queryRoot)) {
        $Item.queryRoot = [string]$Reviewer.queryRoot
    }
    $Item
}

function ConvertTo-CIPPConsentPolicyBody {
    param($Policy, $Reviewers)
    @{
        isEnabled             = [bool]$Policy.isEnabled
        notifyReviewers       = [bool]$Policy.notifyReviewers
        remindersEnabled      = [bool]$Policy.remindersEnabled
        requestDurationInDays = $Policy.requestDurationInDays
        reviewers             = @($Reviewers)
    } | ConvertTo-Json -Compress -Depth 6
}

function Close-CIPPConsentRequestWithoutAdminConsent {
    <#
    .SYNOPSIS
        Closes a consent request the caller cannot review, without granting admin consent.
    .DESCRIPTION
        adminConsentRequestPolicy has no PATCH. The supported update is PUT of the whole policy.
        This reads the policy, adds only the calling SAM user (/users/{id} from GET /me) to reviewers,
        and writes those same settings back. A service principal is not a valid reviewer.
        The stage is then denied with "Handled via per-user grant" when the caller asked to approve.
        Approving after inserting ourselves would let Graph grant admin consent, so this path never
        sends reviewResult Approve and never writes an oauth2PermissionGrant. The original policy is
        written back afterwards, including when the decision itself fails.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$TenantFilter,
        [Parameter(Mandatory = $true)][string]$Action,
        [Parameter(Mandatory = $true)][string]$Version,
        [Parameter(Mandatory = $true)][string]$AppConsentRequestId,
        [Parameter(Mandatory = $true)][string]$UserConsentRequestId,
        [Parameter(Mandatory = $true)][string]$StageId,
        [Parameter(Mandatory = $true)][string]$Justification
    )

    $Me = New-GraphGetRequest -uri 'https://graph.microsoft.com/v1.0/me?$select=id' -tenantid $TenantFilter
    if ([string]::IsNullOrWhiteSpace([string]$Me.id)) {
        throw [System.ArgumentException]::new('CIPP is not an assigned reviewer and the calling user could not be resolved. The consent request was left unchanged.')
    }
    $PolicyUri = 'https://graph.microsoft.com/v1.0/policies/adminConsentRequestPolicy'
    $Policy = New-GraphGetRequest -uri $PolicyUri -tenantid $TenantFilter
    if (-not $Policy) { throw [System.ArgumentException]::new('Could not read the admin consent request policy. The consent request was left unchanged.') }
    $OriginalReviewers = @($Policy.reviewers | Where-Object { $_.query } | ForEach-Object { ConvertTo-CIPPConsentReviewer $_ })
    $UserQuery = "/users/$($Me.id)"
    $AlreadyReviewer = @($OriginalReviewers | Where-Object { $_.query -match [regex]::Escape([string]$Me.id) }).Count -gt 0
    if ($AlreadyReviewer) {
        $Requested = if ($Action -eq 'Approve') { 'Approve' } else { 'Deny' }
        Submit-CIPPConsentStageDecision -TenantFilter $TenantFilter -Version $Version -AppConsentRequestId $AppConsentRequestId -UserConsentRequestId $UserConsentRequestId -StageId $StageId -ReviewResult $Requested -Justification $Justification
        return [pscustomobject]@{ ReviewResult = $Requested; Justification = $Justification; Fallback = $null }
    }

    $AppliedJustification = if ($Action -eq 'Approve') { 'Handled via per-user grant' } else { $Justification }
    $Reviewers = @($OriginalReviewers + @(@{ query = $UserQuery; queryType = 'MicrosoftGraph' }))
    $Added = $false
    $DecisionError = $null
    $RestoreError = $null
    try {
        $null = New-GraphPOSTRequest -uri $PolicyUri -tenantid $TenantFilter -type PUT -body (ConvertTo-CIPPConsentPolicyBody -Policy $Policy -Reviewers $Reviewers)
        $Added = $true
        Submit-CIPPConsentStageDecision -TenantFilter $TenantFilter -Version $Version -AppConsentRequestId $AppConsentRequestId -UserConsentRequestId $UserConsentRequestId -StageId $StageId -ReviewResult 'Deny' -Justification $AppliedJustification
    } catch {
        $DecisionError = $_
    } finally {
        if ($Added) {
            try {
                $null = New-GraphPOSTRequest -uri $PolicyUri -tenantid $TenantFilter -type PUT -body (ConvertTo-CIPPConsentPolicyBody -Policy $Policy -Reviewers $OriginalReviewers)
            } catch {
                $RestoreError = $_
            }
        }
    }
    if ($RestoreError) {
        $RestoreFailure = Get-CIPPGraphFailure -ErrorRecord $RestoreError
        throw "The admin consent request policy could not be restored. $($RestoreFailure.Message)"
    }
    if ($DecisionError) { throw $DecisionError }
    [pscustomobject]@{ ReviewResult = 'Deny'; Justification = $AppliedJustification; Fallback = 'ClosedWithoutAdminConsent' }
}

function Invoke-CIPPAppConsentRequest {
    <#
    .SYNOPSIS
        Approves or denies one user consent request. A caller who is not a reviewer closes it without admin consent.
    .DESCRIPTION
        When the stage is assigned to the caller, the requested decision is patched onto that stage.
        When assignedToMe is false, the pending request is denied after a temporary reviewer add so it
        cannot be approved into admin consent. The policy is restored. No AllPrincipals grant is written.
    .FUNCTIONALITY
        Internal
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$TenantFilter,
        [Parameter(Mandatory = $true)][ValidateSet('Approve', 'Deny')][string]$Action,
        [Parameter(Mandatory = $true)][string]$AppConsentRequestId,
        [Parameter(Mandatory = $true)][string]$UserConsentRequestId,
        [string]$StageId,
        [string]$Justification,
        $Headers,
        [string]$APIName = 'ExecAppConsentRequest'
    )

    if ([string]::IsNullOrWhiteSpace($Justification)) {
        throw [System.ArgumentException]::new('Justification is required')
    }
    $Caller = Get-CIPPAppConsentCaller $Headers
    $ReviewResult = if ($Action -eq 'Approve') { 'Approve' } else { 'Deny' }
    $Lookup = Get-CIPPConsentApprovalStages -TenantFilter $TenantFilter -AppConsentRequestId $AppConsentRequestId -UserConsentRequestId $UserConsentRequestId
    if (-not [string]::IsNullOrWhiteSpace($StageId)) {
        $Stage = $Lookup.Stages | Where-Object { [string]$_.id -eq $StageId } | Select-Object -First 1
        if (-not $Stage.id) { $Stage = [pscustomobject]@{ id = $StageId } }
    } else {
        $Stage = $Lookup.Stages | Where-Object { $_.status -eq 'InProgress' } | Select-Object -First 1
        if (-not $Stage.id) { $Stage = $Lookup.Stages | Select-Object -First 1 }
    }
    if (-not $Stage.id) { throw [System.ArgumentException]::new('No approval stage was found for this user consent request') }
    $StageId = [string]$Stage.id
    $CanReview = ($Stage.PSObject.Properties.Name -notcontains 'assignedToMe') -or ($Stage.assignedToMe -eq $true)
    $UsedJustification = $Justification
    $Fallback = $null
    if ($CanReview) {
        Submit-CIPPConsentStageDecision -TenantFilter $TenantFilter -Version $Lookup.Version -AppConsentRequestId $AppConsentRequestId -UserConsentRequestId $UserConsentRequestId -StageId $StageId -ReviewResult $ReviewResult -Justification $UsedJustification
    } else {
        $Closed = Close-CIPPConsentRequestWithoutAdminConsent -TenantFilter $TenantFilter -Action $Action -Version $Lookup.Version -AppConsentRequestId $AppConsentRequestId -UserConsentRequestId $UserConsentRequestId -StageId $StageId -Justification $Justification
        $ReviewResult = [string]$Closed.ReviewResult
        $UsedJustification = [string]$Closed.Justification
        $Fallback = $Closed.Fallback
    }
    $Message = "$ReviewResult user consent request $UserConsentRequestId for app consent request $AppConsentRequestId in $TenantFilter. Admin consent was not granted. Caller $Caller. Justification: $UsedJustification"
    Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -Sev 'Info' -LogData @{
        Tenant = $TenantFilter; Caller = $Caller; AppConsentRequestId = $AppConsentRequestId; UserConsentRequestId = $UserConsentRequestId; StageId = $StageId; ReviewResult = $ReviewResult; RequestedAction = $Action; Fallback = $Fallback
    }
    [pscustomobject]@{
        ReviewResult         = $ReviewResult
        RequestedAction      = $Action
        StageId              = $StageId
        Justification        = $UsedJustification
        Fallback             = $Fallback
        AdminConsentGranted  = $false
    }
}

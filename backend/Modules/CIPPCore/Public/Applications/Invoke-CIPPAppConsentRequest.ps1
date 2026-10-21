function Invoke-CIPPAppConsentRequest {
    <#
    .SYNOPSIS
        Approves or denies one user consent request. This records the decision only and does not grant admin consent.
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
    if ([string]::IsNullOrWhiteSpace($StageId)) {
        $Stages = @(New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/identityGovernance/appConsent/appConsentRequests/$AppConsentRequestId/userConsentRequests/$UserConsentRequestId/approval/stages" -tenantid $TenantFilter)
        $Stage = @($Stages | Where-Object { $_.status -eq 'InProgress' } | Select-Object -First 1)
        if (-not $Stage.id) { $Stage = @($Stages | Select-Object -First 1) }
        if (-not $Stage.id) { throw [System.ArgumentException]::new('No approval stage was found for this user consent request') }
        $StageId = [string]$Stage.id
    }
    $Body = @{ reviewResult = $ReviewResult; justification = $Justification } | ConvertTo-Json -Compress
    $Uri = "https://graph.microsoft.com/v1.0/identityGovernance/appConsent/appConsentRequests/$AppConsentRequestId/userConsentRequests/$UserConsentRequestId/approval/stages/$StageId"
    $null = New-GraphPOSTRequest -uri $Uri -tenantid $TenantFilter -type PATCH -body $Body
    $Message = "$ReviewResult user consent request $UserConsentRequestId for app consent request $AppConsentRequestId in $TenantFilter. This does not grant admin consent. Caller $Caller. Justification: $Justification"
    Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -Sev 'Info' -LogData @{
        Tenant = $TenantFilter; Caller = $Caller; AppConsentRequestId = $AppConsentRequestId; UserConsentRequestId = $UserConsentRequestId; StageId = $StageId; ReviewResult = $ReviewResult
    }
    [pscustomobject]@{ ReviewResult = $ReviewResult; StageId = $StageId; AdminConsentGranted = $false }
}

function Invoke-ExecEditCAPolicyFull {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.ConditionalAccess.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Query.tenantFilter ?? $Request.Body.tenantFilter

    if ([string]::IsNullOrWhiteSpace($TenantFilter)) {
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'Error: tenantFilter is required' }
        }
    }

    $PolicyId = $Request.Query.PolicyId ?? $Request.Body.PolicyId
    if ([string]::IsNullOrWhiteSpace($PolicyId)) {
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'Error: PolicyId is required' }
        }
    }

    try {
        $PolicyBody = $Request.Body.PolicyBody
        if ($null -eq $PolicyBody) {
            return [HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{ Results = 'Error: PolicyBody is required' }
            }
        }

        # Strip read-only properties that cannot be PATCHed. Start from the live policy so a
        # partial body cannot silently drop grant controls, session controls, conditions, or
        # excluded users and groups.
        $CleanBody = $PolicyBody | Select-Object -Property * -ExcludeProperty id, createdDateTime, modifiedDateTime, templateId
        $Current = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/identity/conditionalAccess/policies/$PolicyId" -tenantid $TenantFilter -asApp $true -noPagination $true
        $CurrentClean = $Current | Select-Object -Property * -ExcludeProperty id, createdDateTime, modifiedDateTime, templateId
        $PolicyObject = Merge-CIPPCAPolicyUpdate -Current $CurrentClean -Patch $CleanBody
        Format-CIPPCAPolicy -Policy $PolicyObject
        $ConfirmRemoval = @($Request.Body.ConfirmRemoval | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        $Dropped = @(Test-CIPPCAPolicyRemoval -Current $Current -Proposed $PolicyObject -ConfirmRemoval $ConfirmRemoval)
        if ($Dropped.Count -gt 0) {
            $Result = "Refusing to drop $($Dropped -join ', ') from CA policy $PolicyId. Set ConfirmRemoval to those field names to confirm."
            Write-LogMessage -API $APIName -tenant $TenantFilter -headers $Headers -message $Result -sev Warning
            return [HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{ Results = $Result; ConfirmRemoval = $Dropped }
            }
        }
        $RawJSON = ConvertTo-Json -InputObject $PolicyObject -Depth 20 -Compress

        $null = New-GraphPOSTRequest `
            -uri "https://graph.microsoft.com/beta/identity/conditionalAccess/policies/$PolicyId" `
            -tenantid $TenantFilter `
            -type PATCH `
            -body $RawJSON `
            -asApp $true

        $DisplayName = $PolicyBody.displayName ?? $PolicyId
        $Result = "Successfully updated CA policy '$DisplayName' for $TenantFilter"
        Write-LogMessage -API $APIName -tenant $TenantFilter -headers $Headers -message $Result -sev Info
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Result = "Failed to update CA policy $PolicyId for ${TenantFilter}: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -API $APIName -tenant $TenantFilter -headers $Headers -message $Result -sev Error -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
    }

    return [HttpResponseContext]@{
        StatusCode = $StatusCode ?? [HttpStatusCode]::OK
        Body       = @{ Results = $Result }
    }
}

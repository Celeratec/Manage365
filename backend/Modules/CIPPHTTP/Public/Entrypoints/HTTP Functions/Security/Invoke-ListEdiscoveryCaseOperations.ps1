function Invoke-ListEdiscoveryCaseOperations {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Security.Ediscovery.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $TenantFilter = $Request.Query.tenantFilter
    $CaseId = $Request.Query.caseId

    try {
        $Plan = Get-CIPPEdiscoveryGraphPlan -Action 'ListEdiscoveryCaseOperations' -Params @{ caseId = $CaseId }
        if (-not $Plan.Allowed) { throw $Plan.Reason }
        $Token = Get-CIPPEdiscoveryAccessToken -TenantFilter $TenantFilter
        $OperationsResult = Invoke-CIPPEdiscoveryRequest -AccessToken $Token.AccessToken -Method $Plan.Method -Path $Plan.Path -Classification $Plan.Classification
        $Operations = @($OperationsResult.Results)

        $GraphRequest = foreach ($Op in $Operations) {
            [PSCustomObject]@{
                id              = $Op.id
                displayName     = $Op.'@odata.type' -replace '#microsoft.graph.security.', ''
                action          = $Op.action
                status          = $Op.status
                percentProgress = $Op.percentProgress
                createdBy       = $Op.createdBy.user.displayName
                createdDate     = $Op.createdDateTime
                completedDate   = $Op.completedDateTime
                resultInfo      = $Op.resultInfo
                exportAvailable = $false
                exportGuidance  = 'Export content download is not available in Manage365 v1.'
            }
        }

        $StatusCode = [HttpStatusCode]::OK
        $Body = [PSCustomObject]@{
            Results = @($GraphRequest)
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $StatusCode = [HttpStatusCode]::InternalServerError
        $Body = [PSCustomObject]@{
            Results = "Failed to retrieve operations for case '$CaseId': $($ErrorMessage.NormalizedError)"
        }
        Write-LogMessage -headers $Request.Headers -API $Request.Params.CIPPEndpoint -tenant $TenantFilter -message "Failed to retrieve eDiscovery operations: $($ErrorMessage.NormalizedError)" -Sev 'Error' -LogData $ErrorMessage
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}

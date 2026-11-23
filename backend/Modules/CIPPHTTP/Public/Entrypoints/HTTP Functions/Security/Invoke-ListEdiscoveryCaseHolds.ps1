function Invoke-ListEdiscoveryCaseHolds {
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
        $Plan = Get-CIPPEdiscoveryGraphPlan -Action 'ListEdiscoveryHolds' -Params @{ caseId = $CaseId }
        if (-not $Plan.Allowed) { throw $Plan.Reason }
        $Token = Get-CIPPEdiscoveryAccessToken -TenantFilter $TenantFilter
        $HoldsResult = Invoke-CIPPEdiscoveryRequest -AccessToken $Token.AccessToken -Method $Plan.Method -Path $Plan.Path -Classification $Plan.Classification
        $Holds = @($HoldsResult.Results)

        $GraphRequest = foreach ($Hold in $Holds) {
            $ContentSourcesCount = 0
            if ($Hold.userSources) { $ContentSourcesCount += ($Hold.userSources | Measure-Object).Count }
            if ($Hold.siteSources) { $ContentSourcesCount += ($Hold.siteSources | Measure-Object).Count }

            [PSCustomObject]@{
                id                  = $Hold.id
                displayName         = $Hold.displayName
                description         = $Hold.description
                status              = $Hold.status
                isEnabled           = $Hold.isEnabled
                contentQuery        = $Hold.contentQuery
                createdBy           = $Hold.createdBy.user.displayName
                createdDate         = $Hold.createdDateTime
                lastModified        = $Hold.lastModifiedDateTime
                contentSourcesCount = $ContentSourcesCount
                userSources         = $Hold.userSources
                siteSources         = $Hold.siteSources
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
            Results = "Failed to retrieve legal holds for case '$CaseId': $($ErrorMessage.NormalizedError)"
        }
        Write-LogMessage -headers $Request.Headers -API $Request.Params.CIPPEndpoint -tenant $TenantFilter -message "Failed to retrieve legal holds: $($ErrorMessage.NormalizedError)" -Sev 'Error' -LogData $ErrorMessage
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}

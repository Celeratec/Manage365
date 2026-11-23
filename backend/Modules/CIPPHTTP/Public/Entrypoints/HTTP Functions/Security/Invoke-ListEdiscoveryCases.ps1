function Invoke-ListEdiscoveryCases {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Security.Ediscovery.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $TenantFilter = $Request.Query.tenantFilter

    try {
        $Plan = Get-CIPPEdiscoveryGraphPlan -Action 'ListEdiscoveryCases' -Params @{}
        if (-not $Plan.Allowed) { throw $Plan.Reason }
        $Token = Get-CIPPEdiscoveryAccessToken -TenantFilter $TenantFilter
        $CasesResult = Invoke-CIPPEdiscoveryRequest -AccessToken $Token.AccessToken -Method $Plan.Method -Path $Plan.Path -Classification $Plan.Classification
        $Cases = @($CasesResult.Results)

        $GraphRequest = foreach ($Case in $Cases) {
            [PSCustomObject]@{
                id            = $Case.id
                displayName   = $Case.displayName
                description   = $Case.description
                status        = $Case.status
                createdBy     = $Case.createdBy.user.displayName
                createdDate   = $Case.createdDateTime
                lastModified  = $Case.lastModifiedDateTime
                closedBy      = $Case.closedBy.user.displayName
                closedDate    = $Case.closedDateTime
                externalId    = $Case.externalId
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
            Results = "Failed to retrieve eDiscovery cases: $($ErrorMessage.NormalizedError)"
        }
        Write-LogMessage -headers $Request.Headers -API $Request.Params.CIPPEndpoint -tenant $TenantFilter -message "Failed to retrieve eDiscovery cases: $($ErrorMessage.NormalizedError)" -Sev 'Error' -LogData $ErrorMessage
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}

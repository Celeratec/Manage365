function Invoke-ExecEdiscoveryCaseExport {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Security.Ediscovery.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Body.tenantFilter
    $CaseId = $Request.Body.caseId
    $SearchId = $Request.Body.searchId

    try {
        Test-CIPPEdiscoveryForbiddenAction -Action 'export' -Resource 'search' | Out-Null
    } catch {
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = [PSCustomObject]@{ Results = $_.Exception.Message; Status = 'Failed' }
        }
    }

    $null = $TenantFilter
    $null = $CaseId
    $null = $SearchId

    $Message = 'eDiscovery export and content download are not available in Manage365 v1. Use stats-only search estimates; Manage365 will not create exports or return download URLs.'
    Write-LogMessage -headers $Headers -API $APIName -tenant $Request.Body.tenantFilter -message $Message -Sev 'Warning'

    return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = [PSCustomObject]@{ Results = $Message; Status = 'Failed' }
        })
}

function Invoke-ExecEdiscoveryCaseHold {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Security.Ediscovery.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $null = $TriggerMetadata
    $Action = $Request.Body.action

    try {
        Test-CIPPEdiscoveryForbiddenAction -Action $Action -Resource 'hold' | Out-Null
    } catch {
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = [PSCustomObject]@{ Results = $_.Exception.Message; Status = 'Failed' }
        }
    }

    $ActionMap = @{
        create = 'CreateEdiscoveryHold'
        update = 'UpdateEdiscoveryHold'
    }
    if (-not $ActionMap.ContainsKey([string]$Action)) {
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = [PSCustomObject]@{ Results = "Unknown or unsupported eDiscovery hold action: $Action"; Status = 'Failed' }
        }
    }

    return [HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::BadRequest
        Body       = [PSCustomObject]@{
            Results = 'Creating or updating eDiscovery holds is disabled for the first release. Hold-add is deferred.'
            Status  = 'Failed'
        }
    }
}

function Invoke-ExecTeamsAppUpload {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Teams.AppCatalog.ReadWrite
    .DESCRIPTION
        Uploads a Teams app package after checking the zip contains manifest.json and its id matches ExpectedManifestId. Packages larger than 5 MB are refused.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Gate = Test-CIPPGuardedWriteRequest -Request $Request -IsWrite
    if (-not $Gate.Ok) {
        $Headers = @{}
        if ($Gate.StatusCode -eq 429) { $Headers['Retry-After'] = [string]$Gate.RetryAfter }
        return [HttpResponseContext]@{ StatusCode = $Gate.StatusCode; Headers = $Headers; Body = @{ Results = $Gate.Message; Status = 'Failed' } }
    }

    $Package = [string]$Request.Body.PackageBase64
    $Expected = [string]$Request.Body.ExpectedManifestId
    $Checked = Test-CIPPTeamsAppPackage -PackageBase64 $Package -ExpectedManifestId $Expected
    if (-not $Checked.Allowed) {
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request @{ ExpectedManifestId = $Expected } -DryRun $Gate.WhatIf -Result $Checked.Reason
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = $Checked.Reason; Status = 'Failed'; AuditId = $AuditId } }
    }
    $DefinitionId = [string]$Request.Body.AppDefinitionId
    $Uri = if ([string]::IsNullOrWhiteSpace($DefinitionId)) {
        'https://graph.microsoft.com/v1.0/appCatalogs/teamsApps?requiresReview=false'
    } else {
        "https://graph.microsoft.com/v1.0/appCatalogs/teamsApps/$DefinitionId/appDefinitions?requiresReview=false"
    }
    if ($Gate.WhatIf) {
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request @{ ExpectedManifestId = $Expected } -DryRun $true -Result 'DryRun'
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{ Results = "Would upload Teams app $Expected."; Status = 'DryRun'; AuditId = $AuditId; WhatIfPlan = @(@{ Uri = $Uri; ManifestId = $Expected }) }
        }
    }
    $After = New-GraphPOSTRequest -uri $Uri -tenantid $Gate.Tenant -type POST -body $Package -contentType 'application/zip' -asApp $true
    $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request @{ ExpectedManifestId = $Expected } -After $After -DryRun $false -Result 'Success'
    return [HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = @{ Results = "Uploaded Teams app $Expected."; Status = 'Success'; AuditId = $AuditId; After = $After; WhatIfPlan = @() }
    }
}

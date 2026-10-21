function Invoke-ExecServicePrincipals {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.Application.ReadWrite
    .SYNOPSIS
        Lists service principals, or creates one in the tenant named by tenantFilter without granting consent.
    .DESCRIPTION
        Action=Create posts the service principal only. Action=Update sets appRoleAssignmentRequired.
        A request without tenantFilter still targets the partner tenant, which is the previous behavior.
        A request with tenantFilter runs in that customer tenant. Neither action grants consent.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $Context = Get-CIPPAppConsentContext -Request $Request
    $TenantFilter = if ([string]::IsNullOrWhiteSpace($Context.TenantFilter)) { $env:TenantID } else { $Context.TenantFilter }
    $ExplicitTenant = -not [string]::IsNullOrWhiteSpace($Context.TenantFilter)

    $Success = $true
    $StatusCode = [HttpStatusCode]::OK

    $Action = if ($Context.Action) { $Context.Action } else { 'Default' }
    try {
        switch ($Action) {
            'Create' {
                $BlockList = @(
                    'e9a7fea1-1cc0-4cd9-a31b-9137ca5deedd', # eM Client
                    'ff8d92dc-3d82-41d6-bcbd-b9174d163620', # PerfectData Software
                    'a245e8c0-b53c-4b67-9b45-751d1dff8e6b', # Newsletter Software Supermailer
                    'b15665d9-eda6-4092-8539-0eec376afd59', # rclone
                    'a43e5392-f48b-46a4-a0f1-098b5eeb4757', # CloudSponge
                    'caffae8c-0882-4c81-9a27-d1803af53a40'  # SigParser
                )
                $Action = 'Create'

                if ($Request.Query.AppId -match '^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$') {

                    if ($BlockList -contains $Request.Query.AppId) {
                        $Results = 'Service Principal creation is blocked for this AppId'
                        $Success = $false
                        $StatusCode = [HttpStatusCode]::BadRequest
                        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Results -Sev 'Error'
                    } else {
                        $AppId = ConvertTo-CIPPRequestValue ($Request.Query.AppId ?? $Request.Body.AppId)
                        try {
                            $Created = Invoke-CIPPServicePrincipalAction -TenantFilter $TenantFilter -Action Create -AppId $AppId -Headers $Headers -APIName $APIName -NoAuthCheck:(-not $ExplicitTenant)
                            $ServicePrincipal = $Created.ServicePrincipal
                            $Results = if ($Created.Created) {
                                "Created service principal for $($ServicePrincipal.displayName) ($($ServicePrincipal.appId)) without granting consent"
                            } else {
                                "Service principal already exists for $($ServicePrincipal.displayName) ($($ServicePrincipal.appId)). No consent was granted"
                            }
                        } catch {
                            $Failure = Get-CIPPGraphFailure -ErrorRecord $_
                            $Results = "Unable to create service principal: $($Failure.Message)"
                            $Success = $false
                            $StatusCode = if ($_.Exception -is [System.ArgumentException]) { [HttpStatusCode]::BadRequest } else { $Failure.StatusCode }
                            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Results -Sev 'Error'
                        }
                    }
                } else {
                    $Results = 'Invalid AppId'
                    $Success = $false
                    $StatusCode = [HttpStatusCode]::BadRequest
                    Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Results -Sev 'Error'
                }
            }
            'Update' {
                $Action = 'Update'
                if (-not $ExplicitTenant) {
                    $Results = 'tenantFilter is required'
                    $Success = $false
                    $StatusCode = [HttpStatusCode]::BadRequest
                    break
                }
                $AppId = ConvertTo-CIPPRequestValue ($Request.Query.AppId ?? $Request.Body.AppId ?? $Request.Body.appId)
                $SpId = ConvertTo-CIPPRequestValue ($Request.Query.Id ?? $Request.Body.Id ?? $Request.Body.id)
                $RequiredText = ConvertTo-CIPPRequestValue ($Request.Query.appRoleAssignmentRequired ?? $Request.Body.appRoleAssignmentRequired)
                if ($RequiredText -notin @('true', 'false')) {
                    $Results = 'appRoleAssignmentRequired must be true or false.'
                    $Success = $false
                    $StatusCode = [HttpStatusCode]::BadRequest
                    break
                }
                try {
                    $Updated = Invoke-CIPPServicePrincipalAction -TenantFilter $TenantFilter -Action Update -AppId $AppId -Id $SpId -AppRoleAssignmentRequired ([System.Convert]::ToBoolean($RequiredText)) -Headers $Headers -APIName $APIName
                    $ServicePrincipal = $Updated.ServicePrincipal
                    $Results = "Set appRoleAssignmentRequired=$RequiredText on service principal $($ServicePrincipal.id). No consent was granted"
                } catch {
                    $Failure = Get-CIPPGraphFailure -ErrorRecord $_
                    $Results = $Failure.Message
                    $Success = $false
                    $StatusCode = if ($_.Exception -is [System.ArgumentException]) { [HttpStatusCode]::BadRequest } else { $Failure.StatusCode }
                    Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Results -Sev 'Error'
                }
            }
            default {
                if ($Request.Query.AppId) {
                    $Action = 'Get'
                    $Results = New-GraphGetRequest -Uri "https://graph.microsoft.com/beta/servicePrincipals(appId='$($Request.Query.AppId)')" -tenantid $env:TenantID -NoAuthCheck $true
                } elseif ($Request.Query.Id) {
                    $Action = 'Get'
                    $Results = New-GraphGetRequest -Uri "https://graph.microsoft.com/beta/servicePrincipals/$($Request.Query.Id)" -tenantid $env:TenantID -NoAuthCheck $true
                } else {
                    $Action = 'List'
                    $Uri = 'https://graph.microsoft.com/beta/servicePrincipals?$top=999&$orderby=displayName&$count=true'
                    if ($Request.Query.Select) {
                        $Uri = '{0}&$select={1}' -f $Uri, $Request.Query.Select
                    }

                    $Results = New-GraphGetRequest -Uri $Uri -ComplexFilter -tenantid $env:TenantID -NoAuthCheck $true
                }
            }
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Results = $ErrorMessage.NormalizedError
        $Success = $false
        $StatusCode = [HttpStatusCode]::InternalServerError
        if ($Action -eq 'Create') {
            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Failed to create service principal: $($ErrorMessage.NormalizedError)" -Sev 'Error' -LogData $ErrorMessage
        }
    }

    $Metadata = @{
        'Action'  = $Action
        'Success' = $Success
    }

    if ($ServicePrincipal) {
        $Metadata.ServicePrincipal = $ServicePrincipal
    }

    if ($Request.Query.AppId) {
        $Metadata.AppId = $Request.Query.AppId
    }

    $Body = @{
        'Results'  = $Results
        'Metadata' = $Metadata
    }

    $Json = $Body | ConvertTo-Json -Depth 10 -Compress
    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Json
        })
}

function Invoke-ListExoRequest {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        CIPP.Core.Read
    .DESCRIPTION
        Executes a read-only Exchange Online cmdlet for a tenant. Accepts Get-* and Search-* as before.
        Also accepts Test-ServicePrincipalAuthorization and Test-ApplicationAccessPolicy when listed in
        ExoReadTestAllowlist.json, with Tenant.AppGovernance.Read and strict parameter validation.
        Test-* always uses the system mailbox. Response Meta.OrganizationScopedGrant is set for
        Test-ServicePrincipalAuthorization when any row has ScopeType Organization.
    #>
    param($Request, $TriggerMetadata)
    $StatusCode = [HttpStatusCode]::OK
    try {
        $AllowedVerbs = @(
            'Get'
            'Search'
            'Test'
        )

        $Cmdlet = $Request.Body.Cmdlet
        # Parameters to splat onto the Exchange cmdlet, as an object of name/value pairs
        # (e.g. { "Identity": "user@contoso.com" }). Cast to an object so the generated schema
        # types cmdParams as an object rather than a string - a string-typed schema made the
        # client reject an object body, leaving no way to pass parameters.
        $cmdParams = if ($Request.Body.cmdParams) { [pscustomobject]$Request.Body.cmdParams } else { [PSCustomObject]@{} }
        $Verb = ($Cmdlet -split '-')[0]

        $TenantFilter = $Request.Body.TenantFilter
        if ($Request.Body.AvailableCmdlets) {
            $ExoRequest = @{
                TenantID         = $TenantFilter
                AvailableCmdlets = $true
            }
            if ($Request.Body.AsApp -eq $true) {
                $ExoRequest.AsApp = $true
            }
            if ($Request.Body.Compliance -eq $true) {
                $ExoRequest.Compliance = $true
            }
            $Results = New-ExoRequest @ExoRequest
            $Body = [PSCustomObject]@{
                Results  = $Results | Select-Object @{ Name = 'Cmdlet'; Expression = { $_ } }
                Metadata = @{
                    Count = ($Results | Measure-Object).Count
                }
            }
        } else {
            if ($AllowedVerbs -notcontains $Verb) {
                $Body = [PSCustomObject]@{
                    Results = "Invalid cmdlet: $Cmdlet"
                }
                return ([HttpResponseContext]@{
                        StatusCode = [HttpStatusCode]::BadRequest
                        Body       = $Body
                    })
                return
            }

            if ($Verb -eq 'Test') {
                $Plan = Get-CIPPExoReadTestCmdletPlan -Cmdlet $Cmdlet -Parameters $cmdParams
                if (-not $Plan.Allowed) {
                    $Body = [PSCustomObject]@{
                        Results = $Plan.Reason
                    }
                    return ([HttpResponseContext]@{
                            StatusCode = [HttpStatusCode]::BadRequest
                            Body       = $Body
                        })
                }

                $Permissions = @(Get-CippRequestAllowedPermissions)
                if ($Permissions -notcontains 'Tenant.AppGovernance.Read') {
                    $Body = [PSCustomObject]@{
                        Results = 'Test-* cmdlets through ListExoRequest require Tenant.AppGovernance.Read.'
                    }
                    return ([HttpResponseContext]@{
                            StatusCode = [HttpStatusCode]::Forbidden
                            Body       = $Body
                        })
                }

                $ExoParams = @{
                    Cmdlet           = $Plan.Cmdlet
                    cmdParams        = $Plan.Parameters
                    tenantid         = $TenantFilter
                    useSystemMailbox = $true
                }

                if ($Request.Body.Select) {
                    $ExoParams.Select = $Request.Body.Select
                }
                if ($Request.Body.Anchor) {
                    $ExoParams.Anchor = $Request.Body.Anchor
                }
                if ($Request.Body.Compliance -eq $true) {
                    $ExoParams.Compliance = $true
                }
                if ($Request.Body.AsApp -eq $true) {
                    $ExoParams.AsApp = $true
                }

                try {
                    $Results = New-ExoRequest @ExoParams
                    $RowCount = @($Results).Count
                    Write-Information "ListExoRequest Test cmdlet=$($Plan.Cmdlet) rows=$RowCount"
                    $Body = [pscustomobject]@{
                        Results = $Results
                    }
                    if ($Plan.Cmdlet -eq 'Test-ServicePrincipalAuthorization') {
                        $OrgScoped = $false
                        foreach ($Row in @($Results)) {
                            if ([string]$Row.ScopeType -eq 'Organization') {
                                $OrgScoped = $true
                                break
                            }
                        }
                        $Body | Add-Member -NotePropertyName Meta -NotePropertyValue ([pscustomobject]@{
                                OrganizationScopedGrant = $OrgScoped
                            }) -Force
                    }
                } catch {
                    $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
                    $Body = [pscustomobject]@{
                        Results = @(@{ Error = $ErrorMessage })
                    }
                    $StatusCode = [HttpStatusCode]::InternalServerError
                }
            } else {
                $ExoParams = @{
                    Cmdlet    = $Cmdlet
                    cmdParams = $cmdParams
                    tenantid  = $TenantFilter
                }

                if ($Request.Body.Select) {
                    $ExoParams.Select = $Request.Body.Select
                }

                if ($Request.Body.UseSystemMailbox -eq $true) {
                    $ExoParams.useSystemMailbox = $true
                }

                if ($Request.Body.Anchor) {
                    $ExoParams.Anchor = $Request.Body.Anchor
                }

                if ($Request.Body.Compliance -eq $true) {
                    $ExoParams.Compliance = $true
                }

                if ($Request.Body.AsApp -eq $true) {
                    $ExoParams.AsApp = $true
                }

                try {
                    $Results = New-ExoRequest @ExoParams
                    $Body = [pscustomobject]@{
                        Results = $Results
                    }
                } catch {
                    $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
                    $Body = [pscustomobject]@{
                        Results = @(@{ Error = $ErrorMessage })
                    }
                    $StatusCode = [HttpStatusCode]::InternalServerError
                }
            }
        }
    } catch {
        Write-Information "ExoRequest Error: $($_.Exception.Message)"
        $Body = [pscustomobject]@{
            Results = @(@{ Error = (Get-NormalizedError -Message $_.Exception.Message) })
        }
        $StatusCode = [HttpStatusCode]::InternalServerError
    }
    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = ConvertTo-Json -InputObject $Body -Compress
        })
}

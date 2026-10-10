function Invoke-ExecUniversalSearchV2 {
    <#
    .FUNCTIONALITY
        Entrypoint,AnyTenant
    .ROLE
        CIPP.Core.Read
    .DESCRIPTION
        Searches cached report data the caller can access and returns matches with the tenant each belongs to. type selects what is searched: Users (the default), Groups, Applications or Licenses. An explicit tenantFilter is honored only when that tenant is inside the caller's scope.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $SearchTerms = $Request.Query.searchTerms
    $Limit = if ($Request.Query.limit) { [int]$Request.Query.limit } else { 10 }
    $Type = if ($Request.Query.type) { $Request.Query.type } else { 'Users' }
    $RequestedTenant = $Request.Query.tenantFilter

    $AllowedTenants = Test-CIPPAccess -Request $Request -TenantList

    if ($AllowedTenants -notcontains 'AllTenants') {
        $ScopedTenants = @(Get-Tenants | Select-Object -ExpandProperty defaultDomainName)
        # Empty scope: a null filter would search every tenant
        if (-not $ScopedTenants) {
            return [HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
                Body       = @()
            }
        }
        if ($RequestedTenant -and ($ScopedTenants -contains $RequestedTenant)) {
            $TenantFilter = $RequestedTenant
        } else {
            $TenantFilter = $ScopedTenants
        }
    } elseif ($RequestedTenant -and $RequestedTenant -notin @('allTenants', 'AllTenants')) {
        $TenantFilter = $RequestedTenant
    } else {
        $TenantFilter = 'allTenants'
    }

    switch ($Type) {
        'Users' {
            $Results = Search-CIPPDbData -SearchTerms $SearchTerms -Types 'Users' -Limit $Limit -Properties 'id', 'userPrincipalName', 'displayName' -TenantFilter $TenantFilter
        }
        'Groups' {
            $Results = Search-CIPPDbData -SearchTerms $SearchTerms -Types 'Groups' -Limit $Limit -Properties 'id', 'displayName', 'mail', 'mailEnabled', 'securityEnabled', 'groupTypes', 'description' -TenantFilter $TenantFilter
        }
        'Applications' {
            $Results = Search-CIPPDbData -SearchTerms $SearchTerms -Types 'Apps', 'ServicePrincipals' -Limit $Limit -Properties 'id', 'appId', 'displayName', 'publisherName', 'appOwnerOrganizationId' -TenantFilter $TenantFilter
        }
        'Licenses' {
            # No Properties filter so service plan names / friendly names embedded in the JSON
            # still pass the secondary verification pass. Scoped like the other types: the
            # per-SKU result embeds per-tenant names and counts.
            $Raw = Search-CIPPDbData -SearchTerms $SearchTerms -Types 'LicenseOverview' -TenantFilter $TenantFilter

            $BySku = [ordered]@{}
            foreach ($Row in $Raw) {
                $Data = $Row.Data
                if (-not $Data -or [string]::IsNullOrWhiteSpace($Data.skuId)) { continue }
                $Key = ([string]$Data.skuId).ToLowerInvariant()

                if (-not $BySku.Contains($Key)) {
                    $BySku[$Key] = [PSCustomObject]@{
                        skuId          = [string]$Data.skuId
                        skuPartNumber  = [string]$Data.skuPartNumber
                        displayName    = [string]$Data.License
                        servicePlans   = @($Data.ServicePlans)
                        tenantCount    = 0
                        totalAssigned  = 0
                        totalAvailable = 0
                        tenants        = [System.Collections.Generic.List[object]]::new()
                    }
                }

                $Entry = $BySku[$Key]
                if ([string]::IsNullOrWhiteSpace($Entry.skuPartNumber) -and $Data.skuPartNumber) { $Entry.skuPartNumber = [string]$Data.skuPartNumber }
                if ([string]::IsNullOrWhiteSpace($Entry.displayName) -and $Data.License) { $Entry.displayName = [string]$Data.License }
                if ((-not $Entry.servicePlans -or $Entry.servicePlans.Count -eq 0) -and $Data.ServicePlans) { $Entry.servicePlans = @($Data.ServicePlans) }

                $Entry.tenantCount++
                $Used = 0; [int]::TryParse([string]$Data.CountUsed, [ref]$Used) | Out-Null
                $Total = 0; [int]::TryParse([string]$Data.TotalLicenses, [ref]$Total) | Out-Null
                $Entry.totalAssigned += $Used
                $Entry.totalAvailable += $Total
                $Entry.tenants.Add([PSCustomObject]@{
                        tenant = [string]$Row.Tenant
                        used   = $Used
                        total  = $Total
                    })
            }

            $Aggregated = $BySku.Values | Sort-Object -Property tenantCount -Descending | Select-Object -First $Limit

            # Shape into the same envelope as other types so the frontend can use match.Data
            $Results = foreach ($Item in $Aggregated) {
                [PSCustomObject]@{
                    Tenant = ''
                    Type   = 'Licenses'
                    RowKey = "Licenses-$($Item.skuId)"
                    Data   = $Item
                }
            }
        }
        default {
            $Results = Search-CIPPDbData -SearchTerms $SearchTerms -Types 'Users' -Limit $Limit -Properties 'id', 'userPrincipalName', 'displayName' -TenantFilter $TenantFilter
        }
    }

    Write-Information "Results: $($Results | ConvertTo-Json -Depth 10)"

    return [HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = @($Results)
    }

}

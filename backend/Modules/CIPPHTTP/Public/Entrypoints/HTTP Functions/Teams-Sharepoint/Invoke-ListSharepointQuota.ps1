Function Invoke-ListSharepointQuota {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Admin.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    # Interact with query parameters or the body of the request.
    $TenantFilter = $Request.Query.tenantFilter

    if ($TenantFilter -eq 'AllTenants') {
        $UsedStoragePercentage = 'Not Supported'
    } else {
        try {
            $SharePointInfo = Get-SharePointAdminLink -Public $false -tenantFilter $TenantFilter
            $extraHeaders = @{
                'Accept' = 'application/json'
            }
            # StorageQuotas returns one row per geo location: on a Multi-Geo tenant this is a
            # collection, on every other tenant a single row. Used storage is therefore the sum
            # across geos, while TenantStorageMB is the shared tenant pool repeated identically
            # on every row and must be taken once rather than summed.
            # Cert-based app-only auth: SPO admin REST 401s delegated client-secret tokens on
            # tenants where the service account lacks SharePoint admin rights, which made this
            # endpoint silently return 'Not available'.
            $SharePointQuota = New-GraphGetRequest -extraHeaders $extraHeaders -scope "$($SharePointInfo.AdminUrl)/.default" -tenantid $TenantFilter -uri "$($SharePointInfo.AdminUrl)/_api/StorageQuotas()?api-version=1.3.2" -asapp $true -UseCertificate
            $GeoUsedStorageMB = ($SharePointQuota.GeoUsedStorageMB | Measure-Object -Sum).Sum
            $TenantStorageMB = $SharePointQuota.TenantStorageMB | Select-Object -First 1

            if ($TenantStorageMB) {
                $UsedStoragePercentage = [int](($GeoUsedStorageMB / $TenantStorageMB) * 100)
            }
        } catch {
            $UsedStoragePercentage = 'Not available'
        }
    }

    $SharePointQuotaDetails = @{
        GeoUsedStorageMB = $GeoUsedStorageMB
        TenantStorageMB  = $TenantStorageMB
        Percentage       = $UsedStoragePercentage
        Dashboard        = "$($UsedStoragePercentage) / 100"
    }

    $StatusCode = [HttpStatusCode]::OK

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $SharePointQuotaDetails
        })

}

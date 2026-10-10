
using namespace System.Net

Function Invoke-DomainAnalyser_List {
    <#
    .FUNCTIONALITY
        Entrypoint,AnyTenant
    .ROLE
        Tenant.DomainAnalyser.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    $DomainTable = Get-CIPPTable -Table 'Domains'

    # Get all the things - always filter by PartitionKey for performance
    if ($Request.Query.tenantFilter -ne 'AllTenants') {
        $DomainTable.Filter = "PartitionKey eq 'TenantDomains' and TenantId eq '{0}'" -f $Request.Query.tenantFilter
    } else {
        $DomainTable.Filter = "PartitionKey eq 'TenantDomains'"
    }

    try {
        # AnyTenant skips the framework's per-tenant check, so scoping is enforced here: narrow the
        # rows to the caller's allowed tenants before extracting results. Rows carry the tenant as
        # TenantGUID (customerId) and TenantId (defaultDomainName), matching Get-CIPPDomainAnalyser.
        $DomainRows = Get-CIPPAzDataTableEntity @DomainTable | Select-CippAllowedTenantData -TenantProperty 'TenantGUID', 'TenantId'
        # Extract json from table results
        $Results = foreach ($DomainAnalyserResult in $DomainRows.DomainAnalyser) {
            try {
                if (![string]::IsNullOrEmpty($DomainAnalyserResult)) {
                    $Object = $DomainAnalyserResult | ConvertFrom-Json -ErrorAction SilentlyContinue
                    $Object
                }
            } catch {}
        }
    } catch {
        $Results = @()
    }


    return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @($Results)
        })
}

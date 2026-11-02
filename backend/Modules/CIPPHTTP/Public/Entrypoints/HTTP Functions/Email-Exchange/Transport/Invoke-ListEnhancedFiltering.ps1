function Invoke-ListEnhancedFiltering {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.Connector.Read
    .DESCRIPTION
        Get Enhanced Filtering settings for an inbound connector (EFSkipIPs, EFSkipLastIP, EFUsers).
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    
    try {
        if ([string]::IsNullOrWhiteSpace($Request.Body.tenantFilter)) { throw 'tenantFilter is required.' }
        if ([string]::IsNullOrWhiteSpace($Request.Body.connectorIdentity)) { throw 'connectorIdentity is required.' }
        
        $TenantFilter = Get-CippNormalizedTenantFilter -TenantFilter $Request.Body.tenantFilter
        $ConnectorIdentity = Get-CippQuarantineInputValue $Request.Body.connectorIdentity

        $CurrentConnector = New-ExoRequest -tenantid $TenantFilter -cmdlet 'Get-InboundConnector' -cmdParams @{ Identity = $ConnectorIdentity } -useSystemMailbox $true | Select-Object -First 1
        if (-not $CurrentConnector) {
            throw "Inbound connector '$ConnectorIdentity' not found"
        }

        $CurrentSettings = @{
            ConnectorIdentity = $ConnectorIdentity
            EFSkipIPs        = $CurrentConnector.EFSkipIPs ?? @()
            EFSkipLastIP     = $CurrentConnector.EFSkipLastIP
            EFUsers          = $CurrentConnector.EFUsers ?? @()
        }
        
        $Result = "Retrieved Enhanced Filtering settings for connector '$ConnectorIdentity'"
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Info'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ 
            Results = $Result
            Settings = $CurrentSettings
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Result = "Failed to get Enhanced Filtering for connector '$ConnectorIdentity' in $TenantFilter`: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Error'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $Result }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}

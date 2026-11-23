function Invoke-ExecEdiscoverySearch {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Security.Ediscovery.ReadWrite
    .DESCRIPTION
        Stats-only Purview eDiscovery search (case/custodian/search/estimate). dryRun defaults true. Counts only.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    return Invoke-CIPPEdiscoverySearchAction -Request $Request
}
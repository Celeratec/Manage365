function Get-CIPPTransportRuleProjection {
    <#
    .SYNOPSIS
        Projects a transport rule down to fields used for Before/After and rollback.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Rule
    )

    if ($null -eq $Rule) { return $null }

    return [pscustomobject]@{
        Name               = [string]$Rule.Name
        Guid               = [string]($Rule.Guid ?? $Rule.Identity ?? $Rule.DistinguishedName)
        Identity           = [string]($Rule.Identity ?? $Rule.Guid ?? $Rule.Name)
        Priority           = $Rule.Priority
        State              = [string]$Rule.State
        Mode               = [string]$Rule.Mode
        RuleErrorAction    = [string]$Rule.RuleErrorAction
        StopRuleProcessing = $Rule.StopRuleProcessing
        BlindCopyTo        = @($Rule.BlindCopyTo)
        CopyTo             = @($Rule.CopyTo)
        ExceptIfSentTo     = @($Rule.ExceptIfSentTo)
        ExceptIfFrom       = @($Rule.ExceptIfFrom)
        Comments           = [string]$Rule.Comments
    }
}

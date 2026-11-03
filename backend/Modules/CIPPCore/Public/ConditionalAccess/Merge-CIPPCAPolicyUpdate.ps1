function Merge-CIPPCAPolicyUpdate {
    <#
    .SYNOPSIS
        Deep-merges a Conditional Access patch onto the policy Graph currently has.
    .DESCRIPTION
        Objects merge property by property. Arrays and scalars from the patch replace the current
        value. An explicit null in the patch replaces the current value too, so an editor can
        still clear a block. Omitted properties stay as they are on the current policy.
    #>
    [CmdletBinding()]
    param(
        $Current,
        $Patch
    )

    $Base = if ($null -eq $Current) {
        [pscustomobject]@{}
    } else {
        $Current | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    }
    if ($null -eq $Patch) { return $Base }
    $Overlay = $Patch | ConvertTo-Json -Depth 30 | ConvertFrom-Json

    function Merge-Node {
        param($Left, $Right)
        if ($null -eq $Right) { return $null }
        $RightIsObject = $Right -is [System.Management.Automation.PSCustomObject]
        $LeftIsObject = $Left -is [System.Management.Automation.PSCustomObject]
        if ($RightIsObject -and $LeftIsObject) {
            foreach ($Prop in $Right.PSObject.Properties) {
                $MergedChild = Merge-Node -Left $Left.$($Prop.Name) -Right $Prop.Value
                $Left | Add-Member -NotePropertyName $Prop.Name -NotePropertyValue $MergedChild -Force
            }
            return $Left
        }
        return $Right
    }

    return Merge-Node -Left $Base -Right $Overlay
}

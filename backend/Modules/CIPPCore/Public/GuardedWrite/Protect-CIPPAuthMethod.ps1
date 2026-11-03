function Protect-CIPPAuthMethod {
    <#
    .SYNOPSIS
        Masks phone numbers and secret material on a Graph authentication method.
    #>
    [CmdletBinding()]
    param($Method)

    if ($null -eq $Method) { return $null }
    $Copy = $Method | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    foreach ($Prop in @($Copy.PSObject.Properties)) {
        $Name = $Prop.Name.ToLowerInvariant()
        if ($Name -match 'secret|password|pin') {
            $Copy | Add-Member -NotePropertyName $Prop.Name -NotePropertyValue '[redacted]' -Force
            continue
        }
        if ($Name -match 'phone' -and $Prop.Value -is [string] -and $Prop.Value.Length -gt 2) {
            $Tail = $Prop.Value.Substring($Prop.Value.Length - 2)
            $Copy | Add-Member -NotePropertyName $Prop.Name -NotePropertyValue ('*' * ($Prop.Value.Length - 2) + $Tail) -Force
        }
    }
    return $Copy
}

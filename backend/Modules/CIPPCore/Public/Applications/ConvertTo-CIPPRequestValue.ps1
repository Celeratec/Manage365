function ConvertTo-CIPPRequestValue {
    <#
    .SYNOPSIS
        A request field as text, or as a list of texts. Label/value objects use value.
    .FUNCTIONALITY
        Internal
    #>
    param(
        $Value,
        [switch]$List
    )
    $Items = @($Value)
    $Texts = foreach ($Item in $Items) {
        if ($null -eq $Item) { continue }
        if ($Item -is [string]) { $Item; continue }
        if ($Item.PSObject.Properties['value'] -and -not [string]::IsNullOrWhiteSpace([string]$Item.value)) {
            [string]$Item.value
            continue
        }
        [string]$Item
    }
    $Texts = @($Texts | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($List) { return $Texts }
    return ($Texts | Select-Object -First 1)
}

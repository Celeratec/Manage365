function ConvertTo-CIPPGuardedWriteRedacted {
    <#
    .SYNOPSIS
        Returns a copy of a value with secret-bearing fields and exact secret strings removed.
    #>
    [CmdletBinding()]
    param(
        $Value,
        [string[]]$SecretValues = @()
    )

    $SecretNames = 'secret', 'password', 'clientsecret', 'token', 'certificatepublickeybase64'
    if ($null -eq $Value) { return $null }
    if ($Value -is [string]) {
        $Text = [string]$Value
        foreach ($Secret in @($SecretValues | Where-Object { $_ })) {
            if ($Secret.Length -ge 6) { $Text = $Text.Replace($Secret, '[redacted]') }
        }
        return $Text
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $Copy = @{}
        foreach ($Key in @($Value.Keys)) {
            if ($SecretNames -contains ([string]$Key).ToLowerInvariant()) {
                $Copy[$Key] = '[redacted]'
            } else {
                $Copy[$Key] = ConvertTo-CIPPGuardedWriteRedacted -Value $Value[$Key] -SecretValues $SecretValues
            }
        }
        return $Copy
    }
    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        $Copy = [pscustomobject]@{}
        foreach ($Prop in $Value.PSObject.Properties) {
            $Child = if ($SecretNames -contains $Prop.Name.ToLowerInvariant()) { '[redacted]' } else { ConvertTo-CIPPGuardedWriteRedacted -Value $Prop.Value -SecretValues $SecretValues }
            $Copy | Add-Member -NotePropertyName $Prop.Name -NotePropertyValue $Child -Force
        }
        return $Copy
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        return @($Value | ForEach-Object { ConvertTo-CIPPGuardedWriteRedacted -Value $_ -SecretValues $SecretValues })
    }
    return $Value
}

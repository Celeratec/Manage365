function Get-CIPPMailFilterCaller {
    <#
    .SYNOPSIS
        Resolves the signed-in caller for a mail-filter write.
    #>
    param($Headers)

    $Name = $Headers.'x-ms-client-principal-name'
    if ([string]::IsNullOrWhiteSpace([string]$Name) -and $Headers.'x-ms-client-principal') {
        try {
            $Parsed = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String([string]$Headers.'x-ms-client-principal')) | ConvertFrom-Json
            $Name = $Parsed.userDetails
        } catch {
            $Name = $null
        }
    }
    if ([string]::IsNullOrWhiteSpace([string]$Name)) { return 'API' }
    return [string]$Name
}

function Get-CIPPEdiscoveryGuardedWriteAuditActor {
    [CmdletBinding()]
    param(
        $Gate
    )

    if ($null -eq $Gate) { return 'API' }
    $Caller = [string]$Gate.Caller
    if ([string]::IsNullOrWhiteSpace($Caller)) { return 'API' }
    return $Caller
}

function New-CIPPEdiscoveryStatsSearchAuditPayload {
    <#
    .SYNOPSIS
        Builds counts-only Request/After payloads for stats search guarded-write audits.
    #>
    [CmdletBinding()]
    param(
        $Gate,
        [Parameter(Mandatory)][int]$TermCount,
        [Parameter(Mandatory)][string]$KqlHash,
        [Parameter(Mandatory)][string]$Status,
        [string]$CaseId,
        [string[]]$SearchIds
    )

    $Payload = [ordered]@{
        ticket    = [string]$Gate.Ticket
        actor     = Get-CIPPEdiscoveryGuardedWriteAuditActor -Gate $Gate
        TermCount = $TermCount
        KqlHash   = $KqlHash
        Status    = $Status
    }

    if (-not [string]::IsNullOrWhiteSpace($CaseId)) {
        $Payload.caseId = $CaseId
    }

    $KnownSearchIds = @($SearchIds | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($KnownSearchIds.Count -gt 0) {
        $Payload.searchIds = $KnownSearchIds
    }

    return [pscustomobject]$Payload
}

function Get-CIPPEdiscoverySensitiveTextHash {
    [CmdletBinding()]
    param(
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }

    $Sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        return ([System.BitConverter]::ToString($Sha256.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant()
    } finally {
        $Sha256.Dispose()
    }
}

function Get-CIPPEdiscoveryEnumerableCount {
    [CmdletBinding()]
    param($Value)

    if ($null -eq $Value) { return 0 }
    if ($Value -is [string]) { return 1 }
    if ($Value -is [System.Collections.IEnumerable]) { return @($Value).Count }
    return 1
}

function ConvertTo-CIPPEdiscoveryCountsOnly {
    <#
    .SYNOPSIS
        Removes eDiscovery content/source detail while preserving ids, counts, and status metadata.
    #>
    [CmdletBinding()]
    param(
        $Value
    )

    if ($null -eq $Value) { return $null }

    $SensitiveKeyPattern = '(?i)subject|sender|preview|snippet|downloadUrl|fileName|content|recipient|body'

    if ($Value -is [System.Collections.IDictionary]) {
        $Copy = [ordered]@{}
        foreach ($Key in @($Value.Keys)) {
            $Name = [string]$Key
            $LowerName = $Name.ToLowerInvariant()
            $Child = $Value[$Key]

            switch ($LowerName) {
                'contentquery' {
                    $Copy.contentQueryPresent = -not [string]::IsNullOrWhiteSpace([string]$Child)
                    $Hash = Get-CIPPEdiscoverySensitiveTextHash -Text ([string]$Child)
                    if ($Hash) { $Copy.contentQueryHash = $Hash }
                    continue
                }
                { $_ -in @('usersources', 'sitesources') } {
                    $Copy["$($Name)Count"] = Get-CIPPEdiscoveryEnumerableCount -Value $Child
                    continue
                }
                { $_ -in @('subject', 'snippet', 'downloadurl', 'downloadurls', 'email', 'siteweburl', 'weburl') } {
                    if ($_ -eq 'downloadurls') {
                        $Copy.downloadUrlsCount = Get-CIPPEdiscoveryEnumerableCount -Value $Child
                    }
                    continue
                }
                { $Name -match $SensitiveKeyPattern } {
                    continue
                }
                default {
                    $Copy[$Name] = ConvertTo-CIPPEdiscoveryCountsOnly -Value $Child
                }
            }
        }
        return $Copy
    }

    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        $AsDictionary = [ordered]@{}
        foreach ($Prop in $Value.PSObject.Properties) {
            $AsDictionary[$Prop.Name] = $Prop.Value
        }
        return [pscustomobject](ConvertTo-CIPPEdiscoveryCountsOnly -Value $AsDictionary)
    }

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        return @($Value | ForEach-Object { ConvertTo-CIPPEdiscoveryCountsOnly -Value $_ })
    }

    return $Value
}

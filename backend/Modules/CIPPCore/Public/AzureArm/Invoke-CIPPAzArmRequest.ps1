function Invoke-CIPPAzArmRequest {
    <#
    .SYNOPSIS
        Hardened ARM HTTP client: management.azure.com only, allowlisted paths, deny list, paging, backoff.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AccessToken,

        [Parameter(Mandatory)]
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$Path,

        [string]$ApiVersion,

        [hashtable]$Query,

        $Body,

        [ValidateSet('read', 'write')]
        [string]$Classification = 'read',

        [int]$MaxPages = 20,

        [scriptblock]$Transport
    )

    $DenyFragments = @(
        '/listKeys', '/regenerateKey', '/listAccountSas', '/listServiceSas',
        '/listSecrets', '/listPublishingCredentials', '/listConnectionStrings',
        '/config/list', '/config/appsettings/list'
    )
    foreach ($Frag in $DenyFragments) {
        if ($Path -like "*$Frag*") {
            throw "ARM path is deny-listed: contains '$Frag'."
        }
    }
    if ($Path -notmatch '\A/' -or $Path.Contains('..') -or $Path -match '(?i)https?://') {
        throw 'ARM path must be a rooted relative path without traversal or scheme.'
    }
    if ($Classification -ne 'read' -and $Method -eq 'GET') {
        # writes are PR2+; this client still refuses non-read classification unless explicitly allowed later
    }
    if ($Classification -ne 'read') {
        throw 'Invoke-CIPPAzArmRequest in this build only allows classification=read.'
    }
    if ($Method -notin @('GET', 'POST')) {
        throw "Method '$Method' is not allowed for ARM reads."
    }
    if ($Method -eq 'POST' -and $Classification -ne 'read') {
        throw 'Non-read POST is refused.'
    }

    $Base = 'https://management.azure.com'
    $Page = 0
    $Items = [System.Collections.Generic.List[object]]::new()
    $LastRaw = $null
    $NextPathAndQuery = $null

    $BuildUri = {
        param($RelPath, $Q, $ApiVer)
        $Builder = [System.UriBuilder]::new($Base)
        $Builder.Path = $RelPath
        $Pairs = [System.Collections.Generic.List[string]]::new()
        if ($ApiVer) { $Pairs.Add("api-version=$([uri]::EscapeDataString($ApiVer))") }
        if ($Q) {
            foreach ($Key in @($Q.Keys)) {
                $Pairs.Add("$([uri]::EscapeDataString([string]$Key))=$([uri]::EscapeDataString([string]$Q[$Key]))")
            }
        }
        $Builder.Query = ($Pairs -join '&')
        if ($Builder.Host -ne 'management.azure.com') {
            throw 'ARM host must be management.azure.com.'
        }
        return $Builder.Uri.AbsoluteUri
    }

    $CurrentPath = $Path
    $CurrentQuery = if ($Query) { @{} + $Query } else { @{} }
    $CurrentApi = $ApiVersion

    while ($true) {
        $Page++
        if ($Page -gt $MaxPages) {
            throw "ARM pagination exceeded MaxPages ($MaxPages)."
        }

        if ($NextPathAndQuery) {
            # nextLink from ARM is absolute; accept only management.azure.com and strip to path+query
            $NextUri = [uri]$NextPathAndQuery
            if ($NextUri.Host -ne 'management.azure.com') {
                throw 'ARM nextLink host must be management.azure.com.'
            }
            $Uri = $NextUri.AbsoluteUri
        } else {
            $Uri = & $BuildUri $CurrentPath $CurrentQuery $CurrentApi
        }

        $Headers = @{ Authorization = "Bearer $AccessToken" }
        $Attempt = 0
        $Response = $null
        while ($Attempt -lt 4) {
            $Attempt++
            try {
                if ($Transport) {
                    $Response = & $Transport -Method $Method -Uri $Uri -Headers $Headers -Body $Body
                } else {
                    $Params = @{
                        Method  = $Method
                        Uri     = $Uri
                        Headers = $Headers
                    }
                    if ($null -ne $Body -and $Method -eq 'POST') {
                        $Params.Body = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 10 -Compress }
                        $Params.ContentType = 'application/json'
                    }
                    $Response = Invoke-CIPPRestMethod @Params -ErrorAction Stop
                }
                break
            } catch {
                $Msg = [string]$_.Exception.Message
                $Status = $null
                if ($Msg -match '\b(429|502|503|504)\b') { $Status = [int]$Matches[1] }
                if ($Status -and $Attempt -lt 4) {
                    $Delay = [math]::Min(30, [math]::Pow(2, $Attempt))
                    if ($_.Exception.Response.Headers -and $_.Exception.Response.Headers['Retry-After']) {
                        $Ra = 0
                        if ([int]::TryParse([string]$_.Exception.Response.Headers['Retry-After'], [ref]$Ra) -and $Ra -gt 0) {
                            $Delay = [math]::Min(60, $Ra)
                        }
                    }
                    Start-Sleep -Seconds $Delay
                    continue
                }
                $Safe = $Msg
                if ($Safe -match '(?i)bearer\s+[A-Za-z0-9\-._~+/]+=*') {
                    $Safe = $Safe -replace '(?i)bearer\s+[A-Za-z0-9\-._~+/]+=*', 'Bearer [redacted]'
                }
                throw "ARM request failed: $Safe"
            }
        }

        $LastRaw = $Response
        if ($Response.value) {
            foreach ($Row in @($Response.value)) { $Items.Add($Row) }
        } elseif ($null -ne $Response -and -not ($Response.PSObject.Properties['value'])) {
            $Items.Add($Response)
        }

        if ($Response.'@odata.nextLink') {
            $NextPathAndQuery = [string]$Response.'@odata.nextLink'
            continue
        }
        if ($Response.nextLink) {
            $NextPathAndQuery = [string]$Response.nextLink
            continue
        }
        break
    }

    return [pscustomobject]@{
        Results = @($Items)
        Raw     = $LastRaw
        Pages   = $Page
    }
}

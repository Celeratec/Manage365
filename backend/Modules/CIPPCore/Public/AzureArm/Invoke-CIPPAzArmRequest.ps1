function Invoke-CIPPAzArmRequest {
    <#
    .SYNOPSIS
        Hardened ARM HTTP client: management.azure.com only, allowlisted paths, deny list, paging, backoff, LRO.
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

        [ValidateSet('read', 'write', 'readSensitive')]
        [string]$Classification = 'read',

        [int]$MaxPages = 20,

        [int]$LroTimeoutSeconds = 300,

        [string]$PermitDenyFragment,

        [scriptblock]$Transport
    )

    $DenyFragments = @(
        '/listKeys', '/regenerateKey', '/listAccountSas', '/listServiceSas',
        '/listSecrets', '/listPublishingCredentials', '/listConnectionStrings',
        '/config/list', '/config/appsettings/list'
    )
    foreach ($Frag in $DenyFragments) {
        if ($Path -like "*$Frag*") {
            if ($Classification -eq 'readSensitive' -and $PermitDenyFragment -and $Frag -eq $PermitDenyFragment) {
                continue
            }
            throw "ARM path is deny-listed: contains '$Frag'."
        }
    }
    if ($Path -notmatch '\A/' -or $Path.Contains('..') -or $Path -match '(?i)https?://') {
        throw 'ARM path must be a rooted relative path without traversal or scheme.'
    }

    switch ($Classification) {
        'read' {
            if ($Method -notin @('GET', 'POST')) {
                throw "Method '$Method' is not allowed for ARM reads."
            }
        }
        'readSensitive' {
            if ($Method -ne 'POST') {
                throw "Method '$Method' is not allowed for readSensitive."
            }
        }
        'write' {
            if ($Method -notin @('PUT', 'PATCH', 'POST', 'DELETE')) {
                throw "Method '$Method' is not allowed for ARM writes."
            }
        }
        default {
            throw "Unknown classification '$Classification'."
        }
    }

    $Base = 'https://management.azure.com'
    $Page = 0
    $Items = [System.Collections.Generic.List[object]]::new()
    $LastRaw = $null
    $NextPathAndQuery = $null
    $OperationUrl = $null

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

    $SendOnce = {
        param($MethodIn, $UriIn, $BodyIn)
        $Headers = @{ Authorization = "Bearer $AccessToken" }
        $Attempt = 0
        while ($Attempt -lt 4) {
            $Attempt++
            try {
                if ($Transport) {
                    return & $Transport -Method $MethodIn -Uri $UriIn -Headers $Headers -Body $BodyIn
                }
                $Params = @{
                    Method  = $MethodIn
                    Uri     = $UriIn
                    Headers = $Headers
                }
                if ($null -ne $BodyIn -and $MethodIn -in @('POST', 'PUT', 'PATCH')) {
                    $Params.Body = if ($BodyIn -is [string]) { $BodyIn } else { $BodyIn | ConvertTo-Json -Depth 12 -Compress }
                    $Params.ContentType = 'application/json'
                }
                return Invoke-CIPPRestMethod @Params -ErrorAction Stop
            } catch {
                $Msg = [string]$_.Exception.Message
                $Status = $null
                if ($Msg -match '\b(429|502|503|504)\b') { $Status = [int]$Matches[1] }
                if ($Status -and $Attempt -lt 4) {
                    $Delay = [math]::Min(30, [math]::Pow(2, $Attempt))
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
        throw 'ARM request failed after retries.'
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
            $NextUri = [uri]$NextPathAndQuery
            if ($NextUri.Host -ne 'management.azure.com') {
                throw 'ARM nextLink host must be management.azure.com.'
            }
            $Uri = $NextUri.AbsoluteUri
        } else {
            $Uri = & $BuildUri $CurrentPath $CurrentQuery $CurrentApi
        }

        $Response = & $SendOnce $Method $Uri $Body
        $LastRaw = $Response

        # LRO: if transport returns StatusCode 202 + Operation-Location / Azure-AsyncOperation in a wrapper
        if ($Classification -eq 'write' -and $Response -is [hashtable] -and $Response.ContainsKey('OperationUrl')) {
            $OperationUrl = [string]$Response.OperationUrl
        } elseif ($Classification -eq 'write' -and $Response.PSObject.Properties['OperationUrl']) {
            $OperationUrl = [string]$Response.OperationUrl
        }

        if ($OperationUrl -and $Classification -eq 'write') {
            $Deadline = [datetime]::UtcNow.AddSeconds($LroTimeoutSeconds)
            while ([datetime]::UtcNow -lt $Deadline) {
                $OpUri = [uri]$OperationUrl
                if ($OpUri.Host -ne 'management.azure.com') {
                    throw 'ARM LRO host must be management.azure.com.'
                }
                Start-Sleep -Seconds 2
                $Op = & $SendOnce 'GET' $OperationUrl $null
                $Status = [string]($Op.status ?? $Op.Status ?? $Op.properties.provisioningState)
                if ($Status -match '(?i)succeeded|complete') {
                    $LastRaw = $Op
                    break
                }
                if ($Status -match '(?i)failed|canceled|cancelled') {
                    throw "ARM long-running operation failed with status '$Status'."
                }
            }
            if ([datetime]::UtcNow -ge $Deadline -and $Status -notmatch '(?i)succeeded|complete') {
                throw "ARM long-running operation timed out after ${LroTimeoutSeconds}s. OperationUrl=$OperationUrl"
            }
        }

        if ($Response.value) {
            foreach ($Row in @($Response.value)) { $Items.Add($Row) }
        } elseif ($null -ne $Response -and -not ($Response.PSObject.Properties['value'])) {
            $Items.Add($Response)
        }

        if ($Classification -eq 'write' -or $Classification -eq 'readSensitive') {
            break
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
        Results      = @($Items)
        Raw          = $LastRaw
        Pages        = $Page
        OperationUrl = $OperationUrl
    }
}

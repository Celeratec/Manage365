function Invoke-CIPPEdiscoveryRequest {
    <#
    .SYNOPSIS
        Hardened Microsoft Graph client for dedicated eDiscovery calls.
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

        $Body,

        [ValidateSet('read', 'write', 'countsOnly')]
        [string]$Classification = 'read',

        [int]$MaxPages = 20,

        [int]$PollTimeoutSeconds = 300,

        [scriptblock]$Transport
    )

    $ContainsDownloadUrl = {
        param($Value)
        if ($null -eq $Value) { return $false }
        if ($Value -is [System.Collections.IDictionary]) {
            foreach ($Key in @($Value.Keys)) {
                if ([string]$Key -match '(?i)(^|\.|@)downloadUrl$') { return $true }
                if (& $ContainsDownloadUrl $Value[$Key]) { return $true }
            }
            return $false
        }
        if ($Value -is [string]) { return $false }
        if ($Value -is [System.Collections.IEnumerable]) {
            foreach ($Item in @($Value)) {
                if (& $ContainsDownloadUrl $Item) { return $true }
            }
            return $false
        }
        foreach ($Prop in @($Value.PSObject.Properties)) {
            if ($Prop.Name -match '(?i)(^|\.|@)downloadUrl$') { return $true }
            if (& $ContainsDownloadUrl $Prop.Value) { return $true }
        }
        return $false
    }

    $Base = 'https://graph.microsoft.com'
    $RequestAccessToken = $AccessToken
    $RequestTransport = $Transport
    $RelativePath = $Path
    if ($Path -match '(?i)^https?://') {
        $Absolute = [uri]$Path
        if ($Absolute.Host -ne 'graph.microsoft.com' -or $Absolute.Scheme -ne 'https') {
            throw 'eDiscovery Graph request host must be graph.microsoft.com.'
        }
        $RelativePath = $Absolute.PathAndQuery
    }
    $DecodedPath = [uri]::UnescapeDataString($RelativePath)
    if ($RelativePath -notmatch '\A/' -or $RelativePath.Contains('..') -or $DecodedPath.Contains('..') -or $RelativePath -match '(?i)https?://') {
        throw 'eDiscovery Graph path must be a rooted relative path without traversal or scheme.'
    }

    if ($Method -eq 'DELETE') {
        throw 'DELETE is not allowed for eDiscovery Graph requests.'
    }

    Test-CIPPEdiscoveryForbiddenAction -RawPath $RelativePath | Out-Null

    switch ($Classification) {
        'read' {
            if ($Method -ne 'GET') {
                throw "Method '$Method' is not allowed for eDiscovery reads."
            }
        }
        'countsOnly' {
            if ($Method -notin @('GET', 'POST')) {
                throw "Method '$Method' is not allowed for counts-only eDiscovery calls."
            }
        }
        'write' {
            if ($Method -notin @('POST', 'PATCH', 'PUT', 'DELETE')) {
                throw "Method '$Method' is not allowed for eDiscovery writes."
            }
        }
        default {
            throw "Unknown classification '$Classification'."
        }
    }

    $BuildUri = {
        param($RelPath)
        $Builder = [System.UriBuilder]::new($Base)
        $Builder.Path = $RelPath.Split('?')[0]
        if ($RelPath.Contains('?')) {
            $Builder.Query = $RelPath.Substring($RelPath.IndexOf('?') + 1)
        }
        if ($Builder.Uri.Host -ne 'graph.microsoft.com') {
            throw 'eDiscovery Graph request host must be graph.microsoft.com.'
        }
        return $Builder.Uri.AbsoluteUri
    }

    $GetHeaderValue = {
        param($HeadersIn, [string]$Name)
        if ($null -eq $HeadersIn) { return $null }
        if ($HeadersIn -is [System.Collections.IDictionary]) {
            foreach ($Key in @($HeadersIn.Keys)) {
                if ([string]$Key -ieq $Name) { return [string]$HeadersIn[$Key] }
            }
            return $null
        }
        foreach ($Prop in @($HeadersIn.PSObject.Properties)) {
            if ($Prop.Name -ieq $Name) { return [string]$Prop.Value }
        }
        return $null
    }

    $NormalizeResponse = {
        param($ResponseIn, $HeadersIn, $StatusCodeIn)

        if ($null -ne $ResponseIn) {
            $HasEnvelopeMember = $false
            if ($ResponseIn -is [System.Collections.IDictionary]) {
                $HasEnvelopeMember = $ResponseIn.Contains('Headers') -or $ResponseIn.Contains('StatusCode')
                if ($HasEnvelopeMember) {
                    return [pscustomobject]@{
                        Body       = $(if ($ResponseIn.Contains('Body')) { $ResponseIn['Body'] } else { $null })
                        Headers    = $(if ($ResponseIn.Contains('Headers')) { $ResponseIn['Headers'] } else { $HeadersIn })
                        StatusCode = $(if ($ResponseIn.Contains('StatusCode')) { $ResponseIn['StatusCode'] } else { $StatusCodeIn })
                    }
                }
            } elseif ($ResponseIn.PSObject.Properties['Headers'] -or $ResponseIn.PSObject.Properties['StatusCode']) {
                return [pscustomobject]@{
                    Body       = $(if ($ResponseIn.PSObject.Properties['Body']) { $ResponseIn.Body } else { $null })
                    Headers    = $(if ($ResponseIn.PSObject.Properties['Headers']) { $ResponseIn.Headers } else { $HeadersIn })
                    StatusCode = $(if ($ResponseIn.PSObject.Properties['StatusCode']) { $ResponseIn.StatusCode } else { $StatusCodeIn })
                }
            }
        }

        return [pscustomobject]@{
            Body       = $ResponseIn
            Headers    = $HeadersIn
            StatusCode = $StatusCodeIn
        }
    }

    $SendOnce = {
        param($MethodIn, $UriIn, $BodyIn)
        $Headers = @{ Authorization = "Bearer $RequestAccessToken" }
        $Attempt = 0
        while ($Attempt -lt 4) {
            $Attempt++
            try {
                if ($RequestTransport) {
                    $TransportResponse = & $RequestTransport -Method $MethodIn -Uri $UriIn -Headers $Headers -Body $BodyIn
                    return & $NormalizeResponse $TransportResponse $null $null
                }
                $Params = @{
                    Method  = $MethodIn
                    Uri     = $UriIn
                    Headers = $Headers
                    ResponseHeadersVariable = 'ResponseHeaders'
                    StatusCodeVariable      = 'StatusCode'
                }
                if ($null -ne $BodyIn -and $MethodIn -in @('POST', 'PUT', 'PATCH')) {
                    $Params.Body = if ($BodyIn -is [string]) { $BodyIn } else { $BodyIn | ConvertTo-Json -Depth 12 -Compress }
                    $Params.ContentType = 'application/json'
                }
                $ResponseHeaders = @{}
                $StatusCode = $null
                $RestResponse = Invoke-CIPPRestMethod @Params -ErrorAction Stop
                return & $NormalizeResponse $RestResponse $ResponseHeaders $StatusCode
            } catch {
                $Msg = [string]$_.Exception.Message
                $Status = $null
                if ($Msg -match '\b(429|502|503|504)\b') { $Status = [int]$Matches[1] }
                $CanRetry = ($Status -eq 429) -or ($MethodIn -eq 'GET' -and $Status -in @(502, 503, 504))
                if ($CanRetry -and $Attempt -lt 4) {
                    $Delay = [math]::Min(30, [math]::Pow(2, $Attempt))
                    Start-Sleep -Seconds $Delay
                    continue
                }
                $Safe = $Msg -replace '(?i)bearer\s+[A-Za-z0-9\-._~+/]+=*', 'Bearer [redacted]'
                throw "eDiscovery Graph request failed: $Safe"
            }
        }
        throw 'eDiscovery Graph request failed after retries.'
    }

    $Page = 0
    $Items = [System.Collections.Generic.List[object]]::new()
    $LastRaw = $null
    $NextPathOrUri = $RelativePath
    $OperationUrl = $null

    while ($true) {
        $Page++
        if ($Page -gt $MaxPages) {
            throw "eDiscovery Graph pagination exceeded MaxPages ($MaxPages)."
        }

        if ($NextPathOrUri -match '(?i)^https://') {
            $NextUri = [uri]$NextPathOrUri
            if ($NextUri.Host -ne 'graph.microsoft.com') {
                throw 'eDiscovery Graph nextLink host must be graph.microsoft.com.'
            }
            $Uri = $NextUri.AbsoluteUri
        } else {
            $Uri = & $BuildUri $NextPathOrUri
        }

        $ResponseEnvelope = & $SendOnce $Method $Uri $Body
        $Response = $ResponseEnvelope.Body
        $LastRaw = $Response
        if ($Classification -eq 'countsOnly' -and (& $ContainsDownloadUrl $Response)) {
            throw 'counts-only eDiscovery response contained downloadUrl.'
        }

        $PollOperationUrl = $null
        $Location = & $GetHeaderValue $ResponseEnvelope.Headers 'Location'
        $ResponseStatusCode = $ResponseEnvelope.StatusCode
        if ($Location) {
            $LocationUri = [uri]$Location
            if ($LocationUri.Scheme -ne 'https' -or $LocationUri.Host -ne 'graph.microsoft.com') {
                throw 'eDiscovery Graph operation host must be graph.microsoft.com.'
            }
            $LocationIsOperation = $LocationUri.AbsolutePath -match '(?i)/operations/'
            if (($ResponseStatusCode -eq 202) -or $LocationIsOperation) {
                $PollOperationUrl = $LocationUri.AbsoluteUri
            }
        } elseif ($Classification -eq 'write' -and $Response -is [hashtable] -and $Response.ContainsKey('OperationUrl')) {
            $PollOperationUrl = [string]$Response.OperationUrl
        } elseif ($Classification -eq 'write' -and $Response.PSObject.Properties['OperationUrl']) {
            $PollOperationUrl = [string]$Response.OperationUrl
        }

        if ($PollOperationUrl -and $Classification -eq 'write') {
            $PollUri = [uri]$PollOperationUrl
            if ($PollUri.Scheme -ne 'https' -or $PollUri.Host -ne 'graph.microsoft.com') {
                throw 'eDiscovery Graph operation host must be graph.microsoft.com.'
            }
            $OperationUrl = $PollOperationUrl
            $Deadline = [datetime]::UtcNow.AddSeconds($PollTimeoutSeconds)
            $Status = $null
            $FirstPoll = $true
            while ([datetime]::UtcNow -lt $Deadline) {
                $OpUri = [uri]$OperationUrl
                if ($OpUri.Scheme -ne 'https' -or $OpUri.Host -ne 'graph.microsoft.com') {
                    throw 'eDiscovery Graph operation host must be graph.microsoft.com.'
                }
                if (-not $FirstPoll) { Start-Sleep -Seconds 2 }
                $FirstPoll = $false
                $OpEnvelope = & $SendOnce 'GET' $OperationUrl $null
                $Op = $OpEnvelope.Body
                if ($Classification -eq 'countsOnly' -and (& $ContainsDownloadUrl $Op)) {
                    throw 'counts-only eDiscovery response contained downloadUrl.'
                }
                $Status = [string]($Op.status ?? $Op.Status ?? $Op.state)
                $OperationComplete = $false
                switch ($Status.ToLowerInvariant()) {
                    'succeeded' {
                        $LastRaw = $Op
                        $Response = $Op
                        $OperationComplete = $true
                    }
                    'partiallysucceeded' {
                        $LastRaw = $Op
                        $Response = $Op
                        $OperationComplete = $true
                    }
                    'failed' {
                        throw "eDiscovery Graph operation failed with status '$Status'."
                    }
                    'canceled' {
                        throw "eDiscovery Graph operation failed with status '$Status'."
                    }
                    'cancelled' {
                        throw "eDiscovery Graph operation failed with status '$Status'."
                    }
                }
                if ($OperationComplete) { break }
            }
            if ([datetime]::UtcNow -ge $Deadline -and $Status -notin @('succeeded', 'partiallySucceeded')) {
                throw "eDiscovery Graph operation timed out after ${PollTimeoutSeconds}s."
            }
        }

        $HasValueCollection = $false
        if ($Response -is [System.Collections.IDictionary]) {
            $HasValueCollection = $Response.Contains('value')
        } elseif ($null -ne $Response) {
            $HasValueCollection = $null -ne $Response.PSObject.Properties['value']
        }

        if ($HasValueCollection) {
            foreach ($Row in @($Response.value)) { $Items.Add($Row) }
        } elseif ($null -ne $Response) {
            $Items.Add($Response)
        }

        if ($Classification -eq 'write') {
            break
        }
        if ($Response.'@odata.nextLink') {
            $NextPathOrUri = [string]$Response.'@odata.nextLink'
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

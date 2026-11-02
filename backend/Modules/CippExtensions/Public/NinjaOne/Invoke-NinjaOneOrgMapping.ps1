function Invoke-NinjaOneOrgMapping {
    <#
    .SYNOPSIS
        Auto-maps CIPP tenants to NinjaOne organizations by exact name, then by matching devices
    .DESCRIPTION
        Unmapped tenants are matched to a NinjaOne organization whose name exactly matches the tenant display name.
        Tenants still unmatched are matched to the organization owning most of their Intune devices (by serial,
        then device name), read from the ManagedDevices report cache. Existing mappings are never overwritten.
        Runs from the mapping page and, with -NameOnly, from the extension timer.
    .PARAMETER NameOnly
        Skip the device match, which downloads every NinjaOne device
    #>
    [CmdletBinding()]
    param(
        [switch]$NameOnly
    )

    $ExcludeSerials = @('0', 'SystemSerialNumber', 'To Be Filled By O.E.M.', 'System Serial Number', '0123456789', '123456789', '............')
    $CIPPMapping = Get-CIPPTable -TableName CippMapping

    $Table = Get-CIPPTable -TableName Extensionsconfig
    $Configuration = ((Get-CIPPAzDataTableEntity @Table).config | ConvertFrom-Json).NinjaOne
    $Token = Get-NinjaOneToken -configuration $Configuration

    $Mappings = @(Get-ExtensionMapping -Extension 'NinjaOne')
    $MappedTenantIds = [System.Collections.Generic.HashSet[string]]::new([string[]]@($Mappings.RowKey), [System.StringComparer]::OrdinalIgnoreCase)
    $MappedOrgIds = [System.Collections.Generic.HashSet[string]]::new([string[]]@($Mappings.IntegrationId))

    # Helper: Parse Retry-After header (seconds or HTTP-date) and cap it
    $ParseRetryAfter = {
        param($Header)
        if (!$Header) { return 60 }
        # Try parsing as integer (seconds)
        $Seconds = 0
        if ([int]::TryParse($Header, [ref]$Seconds)) {
            return [Math]::Min($Seconds, 120)
        }
        # Try parsing as HTTP-date
        $Date = [datetime]::MinValue
        if ([datetime]::TryParse($Header, [ref]$Date)) {
            $WaitSeconds = [Math]::Max(0, ($Date - [datetime]::UtcNow).TotalSeconds)
            return [Math]::Min($WaitSeconds, 120)
        }
        return 60
    }

    $After = 0
    $PageSize = 1000
    $MaxOrgPages = 100
    $OrgPagesFetched = 0
    $NinjaOrgs = do {
        $RetryCount = 0
        $MaxRetries = 3
        $Result = $null
        while ($RetryCount -le $MaxRetries) {
            try {
                $Response = Invoke-WebRequest -Uri "https://$($Configuration.Instance)/api/v2/organizations?pageSize=$PageSize&after=$After" -Method GET -Headers @{Authorization = "Bearer $($Token.access_token)" } -ContentType 'application/json'
                $Result = $Response.content | ConvertFrom-Json -Depth 100
                break
            } catch {
                if ($_.Exception.Response.StatusCode -eq 429 -and $RetryCount -lt $MaxRetries) {
                    $RetryAfter = & $ParseRetryAfter $_.Exception.Response.Headers['Retry-After']
                    Write-Information "NinjaOne rate limit hit on organizations endpoint, waiting $RetryAfter seconds (attempt $($RetryCount + 1)/$MaxRetries)"
                    Start-Sleep -Seconds $RetryAfter
                    $RetryCount++
                } else {
                    throw
                }
            }
        }
        $Result
        $ResultCount = ($Result.id | Measure-Object -Maximum)
        $After = $ResultCount.maximum
        $OrgPagesFetched++
    } while ($ResultCount.count -eq $PageSize -and $OrgPagesFetched -lt $MaxOrgPages)

    if ($OrgPagesFetched -ge $MaxOrgPages -and $ResultCount.count -eq $PageSize) {
        Write-LogMessage -API 'NinjaOneAutoMap' -message "NinjaOne organization fetch hit $MaxOrgPages page cap with more data remaining." -Sev 'Warning'
    }

    $OrgsById = @{}
    $OrgsByName = @{}
    foreach ($Org in $NinjaOrgs) {
        $OrgsById["$($Org.id)"] = $Org
        $Name = "$($Org.name)".Trim()
        if (!$Name) { continue }
        if (!$OrgsByName.ContainsKey($Name)) { $OrgsByName[$Name] = [System.Collections.Generic.List[object]]::new() }
        $OrgsByName[$Name].Add($Org)
    }

    $Matched = 0
    $AddMapping = {
        param($Tenant, $Org, $MatchType)
        $AddObject = @{
            PartitionKey    = 'NinjaOneMapping'
            RowKey          = "$($Tenant.customerId)"
            IntegrationId   = "$($Org.id)"
            IntegrationName = "$($Org.name)"
        }
        Add-CIPPAzDataTableEntity @CIPPMapping -Entity $AddObject -Force
        [void]$MappedOrgIds.Add("$($Org.id)")
        Write-LogMessage -API 'NinjaOneAutoMap' -tenant $Tenant.defaultDomainName -message "Mapped $($Tenant.displayName) to NinjaOne organization $($Org.name) by $MatchType match" -Sev 'Info'
    }

    $Unmatched = foreach ($Tenant in Get-Tenants -IncludeErrors) {
        if ($MappedTenantIds.Contains("$($Tenant.customerId)")) { continue }
        $NameMatches = $OrgsByName["$($Tenant.displayName)".Trim()]
        if ($NameMatches.Count -eq 1 -and !$MappedOrgIds.Contains("$($NameMatches[0].id)")) {
            & $AddMapping $Tenant $NameMatches[0] 'organization name'
            $Matched++
        } else {
            $Tenant
        }
    }

    if ($Unmatched -and !$NameOnly) {
        $After = 0
        $PagesFetched = 0
        $MaxPages = 50  # Cap at 50 pages to prevent runaway fetch
        $LastPageFull = $false
        $NinjaDevices = do {
            $RetryCount = 0
            $MaxRetries = 3
            $Result = $null
            while ($RetryCount -le $MaxRetries) {
                try {
                    $Response = Invoke-WebRequest -Uri "https://$($Configuration.Instance)/api/v2/devices-detailed?pageSize=$PageSize&after=$After" -Method GET -Headers @{Authorization = "Bearer $($Token.access_token)" } -ContentType 'application/json'
                    $Result = $Response.content | ConvertFrom-Json -Depth 100
                    break
                } catch {
                    if ($_.Exception.Response.StatusCode -eq 429 -and $RetryCount -lt $MaxRetries) {
                        # Rate limited - parse Retry-After (seconds or HTTP-date) and cap it
                        $RetryAfter = & $ParseRetryAfter $_.Exception.Response.Headers['Retry-After']
                        Write-Information "NinjaOne rate limit hit on devices endpoint, waiting $RetryAfter seconds (attempt $($RetryCount + 1)/$MaxRetries)"
                        Start-Sleep -Seconds $RetryAfter
                        $RetryCount++
                    } else {
                        throw
                    }
                }
            }
            $Result
            $ResultCount = ($Result.id | Measure-Object -Maximum)
            $After = $ResultCount.maximum
            $PagesFetched++
            $LastPageFull = ($ResultCount.count -eq $PageSize)
        } while ($ResultCount.count -eq $PageSize -and $PagesFetched -lt $MaxPages)

        # If we hit the page cap and the last page was full, partial data - skip device matching
        if ($PagesFetched -ge $MaxPages -and $LastPageFull) {
            Write-LogMessage -API 'NinjaOneAutoMap' -message "NinjaOne device fetch hit $MaxPages page cap with more data remaining. Skipping device matching to avoid partial data." -Sev 'Warning'
            # Don't proceed with device matching - return early
            if ($Matched -gt 0) {
                Write-LogMessage -API 'NinjaOneAutoMap' -message "NinjaOne AutoMap complete: $Matched tenant(s) mapped by name only" -Sev 'Info'
            }
            return "NinjaOne AutoMap complete: $Matched new tenant mapping(s) added (device matching skipped due to page cap)."
        }

        # Key -> org id; a key seen in more than one org maps to $null so it never votes
        # Only count Windows/macOS devices
        $OrgBySerial = @{}
        $OrgByName = @{}
        foreach ($Device in $NinjaDevices) {
            # Only process Windows and macOS devices for matching
            $DeviceClass = "$($Device.nodeClass)".ToLowerInvariant()
            if ($DeviceClass -notin @('windows_workstation', 'windows_server', 'mac')) { continue }
            
            $OrgId = "$($Device.organizationId)"
            foreach ($Serial in @($Device.system.serialNumber, $Device.system.biosSerialNumber)) {
                if (!$Serial -or $Serial -in $ExcludeSerials) { continue }
                $OrgBySerial[$Serial] = if ($OrgBySerial.ContainsKey($Serial) -and $OrgBySerial[$Serial] -ne $OrgId) { $null } else { $OrgId }
            }
            foreach ($DeviceName in @($Device.systemName, $Device.dnsName)) {
                if (!$DeviceName) { continue }
                $OrgByName[$DeviceName] = if ($OrgByName.ContainsKey($DeviceName) -and $OrgByName[$DeviceName] -ne $OrgId) { $null } else { $OrgId }
            }
        }

        foreach ($Tenant in $Unmatched) {
            $Votes = @{}
            $Rows = try { Get-CIPPDbItem -TenantFilter $Tenant.defaultDomainName -Type 'ManagedDevices' } catch { continue }
            $TotalDevices = 0
            foreach ($Row in $Rows) {
                if ($Row.RowKey -like '*-Count') { continue }
                $TotalDevices++
                $IntuneDevice = [CIPP.CippJson]::ConvertFromJson($Row.Data, [string[]]@('deviceName', 'serialNumber'))
                $OrgId = if ($IntuneDevice.serialNumber -and $OrgBySerial[$IntuneDevice.serialNumber]) { $OrgBySerial[$IntuneDevice.serialNumber] } elseif ($IntuneDevice.deviceName) { $OrgByName[$IntuneDevice.deviceName] }
                if ($OrgId) { $Votes[$OrgId] = 1 + $Votes[$OrgId] }
            }
            if ($Votes.Count -eq 0) { continue }
            $Ranked = @($Votes.GetEnumerator() | Sort-Object Value -Descending)
            # Require at least 2 device matches or a majority of devices
            $MinMatches = [Math]::Max(2, [Math]::Ceiling($TotalDevices / 2.0))
            if ($Ranked[0].Value -lt $MinMatches) { continue }
            if ($Ranked.Count -gt 1 -and $Ranked[1].Value -eq $Ranked[0].Value) { continue }
            $Org = $OrgsById[$Ranked[0].Key]
            if (!$Org -or $MappedOrgIds.Contains("$($Org.id)")) { continue }
            & $AddMapping $Tenant $Org 'device'
            $Matched++
        }
    }

    if ($Matched -gt 0) {
        Write-LogMessage -API 'NinjaOneAutoMap' -message "NinjaOne AutoMap complete: $Matched tenant(s) mapped" -Sev 'Info'
    }
    return "NinjaOne AutoMap complete: $Matched new tenant mapping(s) added."
}

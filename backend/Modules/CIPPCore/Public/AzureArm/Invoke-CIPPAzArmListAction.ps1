function Invoke-CIPPAzArmListAction {
    <#
    .SYNOPSIS
        Shared runner for ListAz* entrypoints: config → plan → token → ARM (or local config).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        $Request,

        [scriptblock]$Transport
    )

    $TenantFilter = [string]($Request.Query.tenantFilter ?? $Request.Body.tenantFilter ?? $Request.Body.TenantFilter)
    if ([string]::IsNullOrWhiteSpace($TenantFilter)) {
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'tenantFilter is required.'; Status = 'Failed' }
        }
    }

    $Config = Get-CIPPAzArmTenantConfig -TenantFilter $TenantFilter
    $BodyParams = @{}
    if ($Request.Body) {
        if ($Request.Body -is [hashtable] -or $Request.Body -is [System.Collections.IDictionary]) {
            foreach ($Key in @($Request.Body.Keys)) { $BodyParams[$Key] = $Request.Body[$Key] }
        } else {
            foreach ($Prop in $Request.Body.PSObject.Properties) { $BodyParams[$Prop.Name] = $Prop.Value }
        }
    }
    if ($Request.Query) {
        foreach ($Prop in $Request.Query.PSObject.Properties) {
            if (-not $BodyParams.ContainsKey($Prop.Name)) { $BodyParams[$Prop.Name] = $Prop.Value }
        }
    }

    $Plan = Get-CIPPAzArmReadPlan -Action $Action -Config $Config -Params $BodyParams
    if (-not $Plan.Allowed) {
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = $Plan.Reason; Status = 'Failed' }
        }
    }

    if ($Plan.Special -eq 'listConfig') {
        $Safe = $null
        if ($Config) {
            $Safe = [pscustomobject]@{
                TenantFilter          = $Config.TenantFilter
                Mode                  = $Config.Mode
                SubscriptionId        = $Config.SubscriptionId
                AllowedResourceGroups = $Config.AllowedResourceGroups
                Enabled               = $Config.Enabled
                ChangeWindow          = $Config.ChangeWindow
                Notes                 = $Config.Notes
                ManagingTenantId      = $Config.ManagingTenantId
                ProfileNames          = @($Config.Profiles.Keys)
            }
        }
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{ Results = $Safe; Status = 'Success' }
        }
    }

    try {
        $Token = Get-CIPPAzArmAccessToken -TenantFilter $TenantFilter -Profile $Plan.Profile -Config $Config
    } catch {
        $Msg = [string]$_.Exception.Message
        if ($Msg -match '(?i)bearer\s+[A-Za-z0-9\-._~+/]+=*') {
            $Msg = $Msg -replace '(?i)bearer\s+[A-Za-z0-9\-._~+/]+=*', 'Bearer [redacted]'
        }
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::Forbidden
            Body       = @{ Results = $Msg; Status = 'Failed' }
        }
    }

    if ($Plan.Special -eq 'accessStatus') {
        $Subs = Invoke-CIPPAzArmRequest -AccessToken $Token.AccessToken -Method GET -Path '/subscriptions' -ApiVersion '2022-12-01' -Classification read -Transport $Transport
        $Perms = Invoke-CIPPAzArmRequest -AccessToken $Token.AccessToken -Method GET -Path $Plan.Path -ApiVersion $Plan.ApiVersion -Classification read -Transport $Transport
        $Actions = @($Perms.Results | ForEach-Object { $_.actions })
        $Flat = @($Actions | ForEach-Object { $_ } | Select-Object -Unique)
        $Tripwire = $false
        $Warnings = [System.Collections.Generic.List[string]]::new()
        if ([string]$Config.Mode -eq 'servicePrincipal') {
            # Heuristic: Owner / sub-wide Contributor / User Access Administrator appearing as broad actions
            if ($Flat -contains '*' -or ($Flat -contains 'Microsoft.Authorization/*/write')) {
                $Tripwire = $true
                $Warnings.Add('Principal appears to hold Owner-like or broad authorization write permissions. Writes will be refused until roles are least-privilege.')
            }
            if ($Flat -contains '*/write' -or ($Flat | Where-Object { $_ -eq 'Microsoft.Resources/subscriptions/resourceGroups/write' }).Count -gt 0) {
                # subscription-wide contributor often includes many write actions; flag if no RG constraint in config
                if (@($Config.AllowedResourceGroups).Count -eq 0) {
                    $Tripwire = $true
                    $Warnings.Add('Principal has write-capable permissions with empty allowedResourceGroups (subscription-wide).')
                }
            }
        } else {
            try {
                $Deleg = Invoke-CIPPAzArmRequest -AccessToken $Token.AccessToken -Method GET `
                    -Path "/subscriptions/$($Plan.SubscriptionId)/providers/Microsoft.ManagedServices/registrationAssignments" `
                    -ApiVersion '2022-10-01' -Classification read -Transport $Transport
            } catch {
                $Deleg = [pscustomobject]@{ Results = @(); Error = [string]$_.Exception.Message }
            }
            return [HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
                Body       = @{
                    Results = [pscustomobject]@{
                        Mode              = $Config.Mode
                        Profile           = $Plan.Profile
                        AppId             = $Token.AppId
                        Subscriptions     = $Subs.Results
                        Permissions       = $Perms.Results
                        RegistrationAssignments = $Deleg.Results
                        OverPrivilegeTripwire = $Tripwire
                        Warnings          = @($Warnings)
                    }
                    Status  = 'Success'
                }
            }
        }
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{
                Results = [pscustomobject]@{
                    Mode                  = $Config.Mode
                    Profile               = $Plan.Profile
                    AppId                 = $Token.AppId
                    Subscriptions         = $Subs.Results
                    Permissions           = $Perms.Results
                    OverPrivilegeTripwire = $Tripwire
                    Warnings              = @($Warnings)
                }
                Status  = 'Success'
            }
        }
    }

    if ($Plan.MaxRangeDays -and $Action -eq 'ListAzActivityLog') {
        $Start = [string]($BodyParams.startTime ?? $BodyParams.StartTime)
        $End = [string]($BodyParams.endTime ?? $BodyParams.EndTime)
        if ([string]::IsNullOrWhiteSpace($Start) -or [string]::IsNullOrWhiteSpace($End)) {
            return [HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{ Results = 'startTime and endTime are required (UTC).'; Status = 'Failed' }
            }
        }
        $StartDt = [datetime]::Parse($Start, $null, [System.Globalization.DateTimeStyles]::AdjustToUniversal)
        $EndDt = [datetime]::Parse($End, $null, [System.Globalization.DateTimeStyles]::AdjustToUniversal)
        if (($EndDt - $StartDt).TotalDays -gt $Plan.MaxRangeDays) {
            return [HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{ Results = "Activity log range must be at most $($Plan.MaxRangeDays) days."; Status = 'Failed' }
            }
        }
        $Filter = "eventTimestamp ge '$($StartDt.ToString('o'))' and eventTimestamp le '$($EndDt.ToString('o'))'"
        if ($Plan.ResourceGroupName) {
            $Filter += " and resourceGroupName eq '$($Plan.ResourceGroupName)'"
        }
        $Plan.Query['$filter'] = $Filter
    }

    $ArmBody = $null
    if ($Plan.BodyFromRequest) {
        $ArmBody = $BodyParams.body ?? $BodyParams.Body ?? $BodyParams
        if ($Action -eq 'ListAzCheckName') {
            $Type = [string]($BodyParams.type ?? $BodyParams.Type)
            $CheckName = [string]($BodyParams.name ?? $BodyParams.Name)
            switch ($Type) {
                'storage' { $ArmBody = @{ name = $CheckName; type = 'Microsoft.Storage/storageAccounts' } }
                'keyvault' { $ArmBody = @{ name = $CheckName; type = 'Microsoft.KeyVault/vaults' } }
                'functionapp' { $ArmBody = @{ name = $CheckName; type = 'Microsoft.Web/sites' } }
                default {
                    return [HttpResponseContext]@{
                        StatusCode = [HttpStatusCode]::BadRequest
                        Body       = @{ Results = 'type must be storage, keyvault, or functionapp.'; Status = 'Failed' }
                    }
                }
            }
        }
    }

    try {
        $Primary = Invoke-CIPPAzArmRequest -AccessToken $Token.AccessToken -Method $Plan.Method -Path $Plan.Path `
            -ApiVersion $Plan.ApiVersion -Query $Plan.Query -Body $ArmBody -Classification read -Transport $Transport
        $Combined = [System.Collections.Generic.List[object]]::new()
        foreach ($Row in @($Primary.Results)) { $Combined.Add($Row) }
        foreach ($Also in @($Plan.AlsoPaths)) {
            $Extra = Invoke-CIPPAzArmRequest -AccessToken $Token.AccessToken -Method GET -Path $Also `
                -ApiVersion $Plan.ApiVersion -Classification read -Transport $Transport
            foreach ($Row in @($Extra.Results)) { $Combined.Add($Row) }
        }
        if ($Plan.AlsoFetch -eq 'roleDefinitions') {
            $ScopePath = if ($Plan.ResourceGroupName) {
                "/subscriptions/$($Plan.SubscriptionId)/resourceGroups/$($Plan.ResourceGroupName)/providers/Microsoft.Authorization/roleDefinitions"
            } else {
                "/subscriptions/$($Plan.SubscriptionId)/providers/Microsoft.Authorization/roleDefinitions"
            }
            $Defs = Invoke-CIPPAzArmRequest -AccessToken $Token.AccessToken -Method GET -Path $ScopePath `
                -ApiVersion '2022-04-01' -Classification read -Transport $Transport
            return [HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
                Body       = @{
                    Results         = @($Combined)
                    RoleDefinitions = @($Defs.Results)
                    Status          = 'Success'
                }
            }
        }
        Write-Information "ListAz action=$Action rows=$(@($Combined).Count)"
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{ Results = @($Combined); Status = 'Success' }
        }
    } catch {
        $Msg = [string]$_.Exception.Message
        if ($Msg -match '(?i)bearer\s+[A-Za-z0-9\-._~+/]+=*') {
            $Msg = $Msg -replace '(?i)bearer\s+[A-Za-z0-9\-._~+/]+=*', 'Bearer [redacted]'
        }
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadGateway
            Body       = @{ Results = $Msg; Status = 'Failed' }
        }
    }
}

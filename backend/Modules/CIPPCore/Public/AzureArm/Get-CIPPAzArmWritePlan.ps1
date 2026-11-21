function Get-CIPPAzArmWritePlan {
    <#
    .SYNOPSIS
        Builds an allowlisted ARM write (or readSensitive) plan with secure defaults.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        $Config,

        [hashtable]$Params,

        [string]$TicketNumber,

        $Allowlist
    )

    if (-not $Allowlist) {
        $HelperPath = Join-Path $PSScriptRoot '../../Private/Resolve-CIPPGuardedWriteConfigPath.ps1'
        if (Test-Path -LiteralPath $HelperPath) { . $HelperPath }
        $ConfigPath = Resolve-CIPPGuardedWriteConfigPath -RelativePath 'GuardedWrites/AzureArmAllowlist.json' -PSScriptRoot $PSScriptRoot
        $Allowlist = Get-Content -LiteralPath $ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }

    if (-not $Config -or -not $Config.Enabled) {
        return [pscustomobject]@{ Allowed = $false; Reason = 'Azure ARM access is not enabled for this tenant.' }
    }
    if ($null -eq $Allowlist.actions.PSObject.Properties[$Action]) {
        return [pscustomobject]@{ Allowed = $false; Reason = "Action '$Action' is not on the Azure ARM write allowlist." }
    }
    $Entry = $Allowlist.actions.$Action
    $Sub = [string]$Config.SubscriptionId
    if (-not (Test-CIPPAzArmSegment -Value $Sub -Kind guid)) {
        return [pscustomobject]@{ Allowed = $false; Reason = 'Configured subscriptionId is invalid.' }
    }

    $Rg = [string]($Params.resourceGroupName ?? $Params.ResourceGroupName ?? $Params.resourceGroup)
    if ($Entry.requireResourceGroup) {
        if ([string]::IsNullOrWhiteSpace($Rg)) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'resourceGroupName is required.' }
        }
        if (-not (Test-CIPPAzArmSegment -Value $Rg -Kind resourceGroup)) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'resourceGroupName is invalid.' }
        }
        $Allowed = @($Config.AllowedResourceGroups)
        if ($Allowed.Count -eq 0) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'allowedResourceGroups must be configured for write actions.' }
        }
        if ($Allowed -notcontains $Rg) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'resourceGroupName is not in allowedResourceGroups.' }
        }
    }

    $Name = [string]($Params.name ?? $Params.Name)
    $Location = [string]($Params.location ?? $Params.Location ?? $Params.region)
    if (-not [string]::IsNullOrWhiteSpace($Location)) {
        $LocNorm = $Location.Replace(' ', '').ToLowerInvariant()
        $RegionOk = $false
        foreach ($R in @($Allowlist.regions)) {
            if ($R -eq $LocNorm) { $RegionOk = $true; break }
        }
        if (-not $RegionOk) {
            return [pscustomobject]@{ Allowed = $false; Reason = "location '$Location' is not on the region allowlist." }
        }
        $Location = $LocNorm
    }

    $ManagedTags = @{
        ticket    = [string]$TicketNumber
        managedBy = 'manage365'
    }
    $CallerTags = $Params.tags ?? $Params.Tags
    if ($CallerTags) {
        $TagHash = @{}
        if ($CallerTags -is [hashtable]) { $TagHash = @{} + $CallerTags }
        else { foreach ($P in $CallerTags.PSObject.Properties) { $TagHash[$P.Name] = [string]$P.Value } }
        foreach ($Key in @($TagHash.Keys)) {
            if (@($Allowlist.tagKeys) -notcontains $Key -and $Key -notin @('ticket', 'managedBy')) {
                return [pscustomobject]@{ Allowed = $false; Reason = "tag key '$Key' is not allowlisted." }
            }
            if ($Key -notin @('ticket', 'managedBy')) { $ManagedTags[$Key] = [string]$TagHash[$Key] }
        }
    }

    $AllowUpdate = [bool]($Params.allowUpdate ?? $Params.AllowUpdate)
    $Requests = [System.Collections.Generic.List[object]]::new()
    $GetPath = $null
    $Rollback = $null

    switch ($Action) {
        'ExecAzResourceProvider' {
            $Ns = [string]($Params.namespace ?? $Params.Namespace)
            if (@($Allowlist.providerNamespaces) -notcontains $Ns) {
                return [pscustomobject]@{ Allowed = $false; Reason = "provider namespace '$Ns' is not allowlisted." }
            }
            $Path = "/subscriptions/$Sub/providers/$Ns/register"
            $Requests.Add([pscustomobject]@{ Method = 'POST'; Path = $Path; ApiVersion = $Entry.apiVersion; Body = $null; Classification = 'write' })
            $GetPath = "/subscriptions/$Sub/providers/$Ns"
            $Rollback = @{ Note = 'Provider registration is not automatically undone.'; Namespace = $Ns }
        }
        'ExecAzIdentity' {
            if (-not (Test-CIPPAzArmSegment -Value $Name -Kind resourceName)) {
                return [pscustomobject]@{ Allowed = $false; Reason = 'name is invalid.' }
            }
            if ([string]::IsNullOrWhiteSpace($Location)) {
                return [pscustomobject]@{ Allowed = $false; Reason = 'location is required.' }
            }
            $Path = "/subscriptions/$Sub/resourceGroups/$Rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$Name"
            $Body = @{ location = $Location; tags = $ManagedTags }
            $Requests.Add([pscustomobject]@{ Method = 'PUT'; Path = $Path; ApiVersion = $Entry.apiVersion; Body = $Body; Classification = 'write' })
            $GetPath = $Path
            $Rollback = @{ Action = 'ExecAzDelete'; resourceId = "/subscriptions/$Sub/resourceGroups/$Rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$Name" }
        }
        'ExecAzStorageAccount' {
            if (-not (Test-CIPPAzArmSegment -Value $Name -Kind resourceName) -or $Name.Length -lt 3 -or $Name.Length -gt 24) {
                return [pscustomobject]@{ Allowed = $false; Reason = 'storage account name must be 3-24 characters.' }
            }
            if ([string]::IsNullOrWhiteSpace($Location)) {
                return [pscustomobject]@{ Allowed = $false; Reason = 'location is required.' }
            }
            $Sku = [string]($Params.sku ?? $Params.Sku ?? 'Standard_LRS')
            if (@($Allowlist.storageSkus) -notcontains $Sku) {
                return [pscustomobject]@{ Allowed = $false; Reason = "storage sku '$Sku' is not allowlisted." }
            }
            $AllowSharedKey = [bool]($Params.allowSharedKeyAccess ?? $false)
            if ($AllowSharedKey) {
                return [pscustomobject]@{ Allowed = $false; Reason = 'allowSharedKeyAccess=true is refused; identity-based access is required.' }
            }
            if ([bool]($Params.allowBlobPublicAccess ?? $false)) {
                return [pscustomobject]@{ Allowed = $false; Reason = 'allowBlobPublicAccess=true is refused.' }
            }
            $Path = "/subscriptions/$Sub/resourceGroups/$Rg/providers/Microsoft.Storage/storageAccounts/$Name"
            $Body = @{
                location   = $Location
                tags       = $ManagedTags
                kind       = 'StorageV2'
                sku        = @{ name = $Sku }
                properties = @{
                    minimumTlsVersion        = 'TLS1_2'
                    supportsHttpsTrafficOnly = $true
                    allowBlobPublicAccess    = $false
                    allowSharedKeyAccess     = $false
                }
            }
            $Requests.Add([pscustomobject]@{ Method = 'PUT'; Path = $Path; ApiVersion = $Entry.apiVersion; Body = $Body; Classification = 'write'; Lro = $true })
            $GetPath = $Path
            $Rollback = @{ Action = 'ExecAzDelete'; resourceId = $Path }
        }
        'ExecAzKeyVault' {
            if (-not (Test-CIPPAzArmSegment -Value $Name -Kind resourceName)) {
                return [pscustomobject]@{ Allowed = $false; Reason = 'name is invalid.' }
            }
            if ([string]::IsNullOrWhiteSpace($Location)) {
                return [pscustomobject]@{ Allowed = $false; Reason = 'location is required.' }
            }
            if (-not [bool]($Params.confirmPurgeProtection ?? $Params.ConfirmPurgeProtection)) {
                return [pscustomobject]@{ Allowed = $false; Reason = 'confirmPurgeProtection:true is required (purge protection is irreversible).' }
            }
            if ($null -ne $Params.accessPolicies -or $null -ne $Params.AccessPolicies) {
                return [pscustomobject]@{ Allowed = $false; Reason = 'accessPolicies are refused; RBAC authorization is required.' }
            }
            $Retention = [int]($Params.softDeleteRetentionInDays ?? 90)
            if ($Retention -notin @(7, 90)) {
                return [pscustomobject]@{ Allowed = $false; Reason = 'softDeleteRetentionInDays must be 7 or 90.' }
            }
            $Path = "/subscriptions/$Sub/resourceGroups/$Rg/providers/Microsoft.KeyVault/vaults/$Name"
            $TenantIdForVault = [string]($Params.tenantId ?? $Params.TenantId ?? $Config.ManagingTenantId)
            if ([string]::IsNullOrWhiteSpace($TenantIdForVault) -and $Config.Mode -eq 'servicePrincipal') {
                # Placeholder; real vault tenantId is the customer tenant — callers should pass tenantId
                $TenantIdForVault = [string]$Params.customerTenantId
            }
            if (-not (Test-CIPPAzArmSegment -Value $TenantIdForVault -Kind guid)) {
                return [pscustomobject]@{ Allowed = $false; Reason = 'tenantId (vault Entra tenant) is required as a GUID.' }
            }
            $Body = @{
                location   = $Location
                tags       = $ManagedTags
                properties = @{
                    sku                        = @{ family = 'A'; name = 'standard' }
                    tenantId                   = $TenantIdForVault
                    enableRbacAuthorization    = $true
                    enableSoftDelete           = $true
                    enablePurgeProtection      = $true
                    softDeleteRetentionInDays  = $Retention
                    accessPolicies             = @()
                }
            }
            $Requests.Add([pscustomobject]@{ Method = 'PUT'; Path = $Path; ApiVersion = $Entry.apiVersion; Body = $Body; Classification = 'write'; Lro = $true })
            $GetPath = $Path
            $Rollback = @{ Action = 'ExecAzDelete'; resourceId = $Path; Note = 'Key Vault delete is soft-delete only; name remains reserved while purge protection is on.' }
        }
        'ExecAzFunctionApp' {
            $Operation = [string]($Params.operation ?? $Params.Operation ?? 'create')
            switch ($Operation) {
                'create' {
                    if (-not (Test-CIPPAzArmSegment -Value $Name -Kind resourceName)) {
                        return [pscustomobject]@{ Allowed = $false; Reason = 'name is invalid.' }
                    }
                    if ([string]::IsNullOrWhiteSpace($Location)) {
                        return [pscustomobject]@{ Allowed = $false; Reason = 'location is required.' }
                    }
                    $PlanName = [string]($Params.planName ?? $Params.PlanName ?? "$Name-plan")
                    if (-not (Test-CIPPAzArmSegment -Value $PlanName -Kind resourceName)) {
                        return [pscustomobject]@{ Allowed = $false; Reason = 'planName is invalid.' }
                    }
                    $IdentityId = [string]($Params.userAssignedIdentityId ?? $Params.UserAssignedIdentityId)
                    if ([string]::IsNullOrWhiteSpace($IdentityId) -or $IdentityId -notmatch '^/subscriptions/') {
                        return [pscustomobject]@{ Allowed = $false; Reason = 'userAssignedIdentityId (full resource id) is required.' }
                    }
                    $StorageName = [string]($Params.storageAccountName ?? $Params.StorageAccountName)
                    if (-not (Test-CIPPAzArmSegment -Value $StorageName -Kind resourceName)) {
                        return [pscustomobject]@{ Allowed = $false; Reason = 'storageAccountName is required.' }
                    }
                    $MaxInstances = [int]($Params.maximumInstanceCount ?? 5)
                    if ($MaxInstances -lt 1 -or $MaxInstances -gt 5) {
                        return [pscustomobject]@{ Allowed = $false; Reason = 'maximumInstanceCount must be 1-5.' }
                    }
                    $Mem = [int]($Params.instanceMemoryMB ?? 2048)
                    if ($Mem -notin @(512, 2048, 4096)) {
                        return [pscustomobject]@{ Allowed = $false; Reason = 'instanceMemoryMB must be 512, 2048, or 4096.' }
                    }
                    $Runtime = [string]($Params.runtime ?? 'dotnet-isolated')
                    $RuntimeVersion = [string]($Params.runtimeVersion ?? '8.0')
                    $ClientId = [string]($Params.userAssignedClientId ?? $Params.UserAssignedClientId)
                    if ([string]::IsNullOrWhiteSpace($ClientId)) {
                        return [pscustomobject]@{ Allowed = $false; Reason = 'userAssignedClientId is required for identity-based host storage.' }
                    }
                    $PlanPath = "/subscriptions/$Sub/resourceGroups/$Rg/providers/Microsoft.Web/serverfarms/$PlanName"
                    $SitePath = "/subscriptions/$Sub/resourceGroups/$Rg/providers/Microsoft.Web/sites/$Name"
                    $PlanBody = @{
                        location   = $Location
                        tags       = $ManagedTags
                        kind       = 'functionapp'
                        sku        = @{ tier = 'FlexConsumption'; name = 'FC1' }
                        properties = @{ reserved = $true }
                    }
                    $SiteBody = @{
                        location   = $Location
                        tags       = $ManagedTags
                        kind       = 'functionapp,linux'
                        identity   = @{ type = 'UserAssigned'; userAssignedIdentities = @{ $IdentityId = @{} } }
                        properties = @{
                            serverFarmId = $PlanPath
                            httpsOnly    = $true
                            siteConfig   = @{ minTlsVersion = '1.2' }
                            functionAppConfig = @{
                                deployment         = @{
                                    storage = @{
                                        type           = 'blobContainer'
                                        value          = "https://$StorageName.blob.core.windows.net/app-package-$Name"
                                        authentication = @{
                                            type                       = 'UserAssignedIdentity'
                                            userAssignedIdentityResourceId = $IdentityId
                                        }
                                    }
                                }
                                scaleAndConcurrency = @{
                                    maximumInstanceCount = $MaxInstances
                                    instanceMemoryMB     = $Mem
                                }
                                runtime            = @{ name = $Runtime; version = $RuntimeVersion }
                            }
                        }
                    }
                    $Requests.Add([pscustomobject]@{ Method = 'PUT'; Path = $PlanPath; ApiVersion = $Entry.apiVersion; Body = $PlanBody; Classification = 'write'; Lro = $true })
                    $Requests.Add([pscustomobject]@{ Method = 'PUT'; Path = $SitePath; ApiVersion = $Entry.apiVersion; Body = $SiteBody; Classification = 'write'; Lro = $true })
                    # Identity-based storage settings (no connection string)
                    $SettingsBody = @{
                        AzureWebJobsStorage__accountName = $StorageName
                        AzureWebJobsStorage__credential  = 'managedidentity'
                        AzureWebJobsStorage__clientId    = $ClientId
                    }
                    $Requests.Add([pscustomobject]@{
                            Method = 'PUT'
                            Path = "$SitePath/config/appsettings"
                            ApiVersion = $Entry.apiVersion
                            Body = $SettingsBody
                            Classification = 'write'
                            MergeAppSettings = $true
                        })
                    $GetPath = $SitePath
                    $Rollback = @{
                        Steps = @(
                            @{ Action = 'ExecAzDelete'; resourceId = $SitePath },
                            @{ Action = 'ExecAzDelete'; resourceId = $PlanPath }
                        )
                    }
                }
                'setAppSettings' {
                    if (-not (Test-CIPPAzArmSegment -Value $Name -Kind resourceName)) {
                        return [pscustomobject]@{ Allowed = $false; Reason = 'name is invalid.' }
                    }
                    $Settings = $Params.settings ?? $Params.Settings
                    if (-not $Settings) {
                        return [pscustomobject]@{ Allowed = $false; Reason = 'settings object is required.' }
                    }
                    $SettingsHash = @{}
                    if ($Settings -is [hashtable]) { $SettingsHash = @{} + $Settings }
                    else { foreach ($P in $Settings.PSObject.Properties) { $SettingsHash[$P.Name] = [string]$P.Value } }
                    foreach ($Key in @($SettingsHash.Keys)) {
                        if ($Key -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
                            return [pscustomobject]@{ Allowed = $false; Reason = "app setting name '$Key' is invalid." }
                        }
                        $Val = [string]$SettingsHash[$Key]
                        if ($Key -eq 'AzureWebJobsStorage' -or $Val -match '(?i)AccountKey=|SharedAccessSignature=') {
                            return [pscustomobject]@{ Allowed = $false; Reason = 'connection-string style storage settings are refused.' }
                        }
                        $LooksSecret = $Val -match '(?i)(password|secret|key|token|connection)' -or $Val.Length -gt 80
                        if ($LooksSecret -and $Val -notmatch '^@Microsoft\.KeyVault\(') {
                            return [pscustomobject]@{ Allowed = $false; Reason = "setting '$Key' must be a Key Vault reference." }
                        }
                    }
                    $Path = "/subscriptions/$Sub/resourceGroups/$Rg/providers/Microsoft.Web/sites/$Name/config/appsettings"
                    $Requests.Add([pscustomobject]@{ Method = 'PUT'; Path = $Path; ApiVersion = $Entry.apiVersion; Body = $SettingsHash; Classification = 'write'; MergeAppSettings = $true })
                    $GetPath = "/subscriptions/$Sub/resourceGroups/$Rg/providers/Microsoft.Web/sites/$Name"
                    $Rollback = @{ Note = 'Restore previous app setting names from Before (values never returned).' }
                }
                'setKeyVaultReferenceIdentity' {
                    if (-not (Test-CIPPAzArmSegment -Value $Name -Kind resourceName)) {
                        return [pscustomobject]@{ Allowed = $false; Reason = 'name is invalid.' }
                    }
                    $IdentityId = [string]($Params.userAssignedIdentityId ?? $Params.UserAssignedIdentityId)
                    if ([string]::IsNullOrWhiteSpace($IdentityId)) {
                        return [pscustomobject]@{ Allowed = $false; Reason = 'userAssignedIdentityId is required.' }
                    }
                    $Path = "/subscriptions/$Sub/resourceGroups/$Rg/providers/Microsoft.Web/sites/$Name"
                    $Body = @{ properties = @{ keyVaultReferenceIdentity = $IdentityId } }
                    $Requests.Add([pscustomobject]@{ Method = 'PATCH'; Path = $Path; ApiVersion = $Entry.apiVersion; Body = $Body; Classification = 'write' })
                    $GetPath = $Path
                    $Rollback = @{ Method = 'PATCH'; Path = $Path; Note = 'Restore previous keyVaultReferenceIdentity from Before.' }
                }
                default {
                    return [pscustomobject]@{ Allowed = $false; Reason = "operation '$Operation' is not supported." }
                }
            }
        }
        'ExecAzTags' {
            $ResourceId = [string]($Params.resourceId ?? $Params.ResourceId)
            if ($ResourceId -notmatch "^/subscriptions/$([regex]::Escape($Sub))/resourceGroups/$([regex]::Escape($Rg))/") {
                return [pscustomobject]@{ Allowed = $false; Reason = 'resourceId must be under the pinned subscription and allowed resource group.' }
            }
            if ($ResourceId.Contains('..')) {
                return [pscustomobject]@{ Allowed = $false; Reason = 'resourceId is invalid.' }
            }
            $Path = "$ResourceId/providers/Microsoft.Resources/tags/default"
            $Body = @{ properties = @{ tags = $ManagedTags } }
            $Requests.Add([pscustomobject]@{ Method = 'PATCH'; Path = $Path; ApiVersion = $Entry.apiVersion; Body = $Body; Classification = 'write' })
            $GetPath = $ResourceId
            $Rollback = @{ Note = 'Restore previous tags from Before.' }
        }
        'ExecAzDelete' {
            $ResourceId = [string]($Params.resourceId ?? $Params.ResourceId)
            if ($ResourceId -notmatch "^/subscriptions/$([regex]::Escape($Sub))/resourceGroups/$([regex]::Escape($Rg))/providers/") {
                return [pscustomobject]@{ Allowed = $false; Reason = 'resourceId must be a resource under the allowed resource group (resource groups themselves cannot be deleted).' }
            }
            $TypeOk = $false
            foreach ($T in @($Allowlist.deleteTypes)) {
                if ($ResourceId -match [regex]::Escape("/providers/$T/")) { $TypeOk = $true; break }
            }
            if (-not $TypeOk) {
                return [pscustomobject]@{ Allowed = $false; Reason = 'resource type is not allowlisted for ExecAzDelete.' }
            }
            $Api = '2021-04-01'
            if ($ResourceId -match 'Microsoft\.Web/') { $Api = '2024-04-01' }
            elseif ($ResourceId -match 'Microsoft\.Storage/') { $Api = '2023-05-01' }
            elseif ($ResourceId -match 'Microsoft\.KeyVault/') { $Api = '2023-07-01' }
            elseif ($ResourceId -match 'Microsoft\.ManagedIdentity/') { $Api = '2023-01-31' }
            $Requests.Add([pscustomobject]@{ Method = 'DELETE'; Path = $ResourceId; ApiVersion = $Api; Body = $null; Classification = 'write' })
            $GetPath = $ResourceId
            $Rollback = @{ Note = 'Delete is irreversible for most types; Key Vault is soft-deleted only.' }
        }
        'ListAzWebAppSettingNames' {
            if (-not (Test-CIPPAzArmSegment -Value $Name -Kind resourceName)) {
                return [pscustomobject]@{ Allowed = $false; Reason = 'name is invalid.' }
            }
            $Path = "/subscriptions/$Sub/resourceGroups/$Rg/providers/Microsoft.Web/sites/$Name/config/appsettings/list"
            $Requests.Add([pscustomobject]@{
                    Method             = 'POST'
                    Path               = $Path
                    ApiVersion         = $Entry.apiVersion
                    Body               = $null
                    Classification     = 'readSensitive'
                    PermitDenyFragment = '/config/appsettings/list'
                })
        }
        default {
            return [pscustomobject]@{ Allowed = $false; Reason = "Unhandled action '$Action'." }
        }
    }

    return [pscustomobject]@{
        Allowed      = $true
        Action       = $Action
        Profile      = [string]$Entry.profile
        Role         = [string]$Entry.role
        Requests     = @($Requests)
        GetPath      = $GetPath
        GetApiVersion = if ($GetPath -match 'Microsoft\.Web/') { '2024-04-01' }
        elseif ($GetPath -match 'Microsoft\.Storage/') { '2023-05-01' }
        elseif ($GetPath -match 'Microsoft\.KeyVault/') { '2023-07-01' }
        elseif ($GetPath -match 'Microsoft\.ManagedIdentity/') { '2023-01-31' }
        else { '2021-04-01' }
        CreateOnly   = [bool]$Entry.createOnlyDefault -and -not $AllowUpdate
        AllowUpdate  = $AllowUpdate
        Rollback     = $Rollback
        ResourceGroup = $Rg
        SubscriptionId = $Sub
    }
}

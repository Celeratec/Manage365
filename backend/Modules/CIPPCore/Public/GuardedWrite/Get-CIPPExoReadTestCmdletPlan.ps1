function Get-CIPPExoReadTestCmdletPlan {
    <#
    .SYNOPSIS
        Accepts only allowlisted read-only Exchange Test-* cmdlets with validated parameters.
    .DESCRIPTION
        Used by ListExoRequest so Test-ServicePrincipalAuthorization and
        Test-ApplicationAccessPolicy can run as reads without the guarded-write path.
    #>
    [CmdletBinding()]
    param(
        [string]$Cmdlet,
        $Parameters,
        $Allowlist
    )

    if (-not $Allowlist) {
        $HelperPath = Join-Path $PSScriptRoot '../../Private/Resolve-CIPPGuardedWriteConfigPath.ps1'
        if (Test-Path -LiteralPath $HelperPath) {
            . $HelperPath
        }
        $NameHelperPath = Join-Path $PSScriptRoot '../../Private/Test-CIPPExoParameterName.ps1'
        if (Test-Path -LiteralPath $NameHelperPath) {
            . $NameHelperPath
        }
        $ConfigPath = Resolve-CIPPGuardedWriteConfigPath -RelativePath 'GuardedWrites/ExoReadTestAllowlist.json' -PSScriptRoot $PSScriptRoot
        try {
            $Allowlist = Get-Content -LiteralPath $ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        } catch {
            throw "Failed to load or parse ExoReadTest allowlist from '$ConfigPath': $($_.Exception.Message)"
        }
    } else {
        $NameHelperPath = Join-Path $PSScriptRoot '../../Private/Test-CIPPExoParameterName.ps1'
        if ((Get-Command -Name Test-CIPPExoParameterName -ErrorAction SilentlyContinue) -eq $null -and (Test-Path -LiteralPath $NameHelperPath)) {
            . $NameHelperPath
        }
    }

    if ($null -eq $Allowlist.PSObject.Properties[$Cmdlet]) {
        return [pscustomobject]@{ Allowed = $false; Reason = "Cmdlet '$Cmdlet' is not on the read Test allowlist." }
    }

    $AllowedNames = @($Allowlist.$Cmdlet)
    $Incoming = @{}
    if ($Parameters -is [System.Collections.IDictionary]) {
        foreach ($Key in @($Parameters.Keys)) { $Incoming[$Key] = $Parameters[$Key] }
    } elseif ($null -ne $Parameters) {
        foreach ($Prop in $Parameters.PSObject.Properties) { $Incoming[$Prop.Name] = $Prop.Value }
    }

    $AllowedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($Name in $AllowedNames) { $null = $AllowedSet.Add($Name) }

    $Validated = @{}
    foreach ($Key in @($Incoming.Keys)) {
        $KeyStr = [string]$Key
        if (-not (Test-CIPPExoParameterName -Name $KeyStr)) {
            return [pscustomobject]@{ Allowed = $false; Reason = "Parameter name '$KeyStr' must start with an ASCII letter and contain only ASCII letters and digits." }
        }
        if (-not $AllowedSet.Contains($KeyStr)) {
            return [pscustomobject]@{ Allowed = $false; Reason = "Parameter '$KeyStr' is not allowed on $Cmdlet." }
        }
        $CanonicalName = $AllowedNames | Where-Object { $AllowedSet.Comparer.Equals($_, $KeyStr) } | Select-Object -First 1
        if (-not $CanonicalName) { $CanonicalName = $KeyStr }
        $Validated[$CanonicalName] = $Incoming[$Key]
    }
    $Incoming = $Validated

    function Test-CIPPExoReadGuid {
        param($Value, [string]$FieldName)
        if ($Value -is [array] -or $Value -is [hashtable] -or $null -eq $Value -or ($Value -is [PSCustomObject])) {
            return "Field '$FieldName' must be a scalar GUID string."
        }
        $Raw = [string]$Value
        if ($Raw -match '[\x00-\x1F\x7F]') {
            return "Field '$FieldName' must not contain control characters."
        }
        $Str = $Raw.Trim()
        if ($Raw -ne $Str) {
            return "Field '$FieldName' must not have leading or trailing whitespace."
        }
        if ($Str -notmatch '\A[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}\z') {
            return "Field '$FieldName' must be a GUID."
        }
        return $null
    }

    function Test-CIPPExoReadRecipient {
        param($Value, [string]$FieldName)
        if ($Value -is [array] -or $Value -is [hashtable] -or $null -eq $Value -or ($Value -is [PSCustomObject])) {
            return "Field '$FieldName' must be a scalar string."
        }
        $Raw = [string]$Value
        if ($Raw -match '[\x00-\x1F\x7F]') {
            return "Field '$FieldName' must not contain control characters."
        }
        $Str = $Raw.Trim()
        if ($Raw -ne $Str) {
            return "Field '$FieldName' must not have leading or trailing whitespace."
        }
        if ($Str.Length -eq 0 -or $Str.Length -gt 320) {
            return "Field '$FieldName' must be 1 to 320 characters."
        }
        if ($Str -match '\*') {
            return "Field '$FieldName' must not contain wildcards."
        }
        if ($Str -match '%.*%') {
            return "Field '$FieldName' must not contain variable tokens."
        }
        $IsUPN = $Str -cmatch '\A[A-Za-z0-9!#$%&''*+/=?^_`{|}~-]+(\.[A-Za-z0-9!#$%&''*+/=?^_`{|}~-]+)*@[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+\z'
        $IsSMTP = $Str -cmatch '\A[Ss][Mm][Tt][Pp]:[A-Za-z0-9!#$%&''*+/=?^_`{|}~-]+(\.[A-Za-z0-9!#$%&''*+/=?^_`{|}~-]+)*@[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+\z'
        $IsGUID = $Str -cmatch '\A[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}\z'
        if (-not ($IsUPN -or $IsSMTP -or $IsGUID)) {
            return "Field '$FieldName' must be a valid UPN, SMTP address, or GUID."
        }
        return $null
    }

    if ($Cmdlet -eq 'Test-ServicePrincipalAuthorization') {
        if (-not $Incoming.ContainsKey('Identity')) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'Test-ServicePrincipalAuthorization requires Identity.' }
        }
        if (-not $Incoming.ContainsKey('Resource')) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'Test-ServicePrincipalAuthorization requires Resource. Without Resource every row is Not Run.' }
        }
        $IdErr = Test-CIPPExoReadGuid -Value $Incoming.Identity -FieldName 'Identity'
        if ($IdErr) { return [pscustomobject]@{ Allowed = $false; Reason = $IdErr } }
        $Incoming.Identity = ([string]$Incoming.Identity).Trim()
        $ResErr = Test-CIPPExoReadRecipient -Value $Incoming.Resource -FieldName 'Resource'
        if ($ResErr) { return [pscustomobject]@{ Allowed = $false; Reason = $ResErr } }
        $Incoming.Resource = ([string]$Incoming.Resource).Trim()
    } elseif ($Cmdlet -eq 'Test-ApplicationAccessPolicy') {
        if (-not $Incoming.ContainsKey('Identity')) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'Test-ApplicationAccessPolicy requires Identity.' }
        }
        if (-not $Incoming.ContainsKey('AppId')) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'Test-ApplicationAccessPolicy requires AppId.' }
        }
        $IdErr = Test-CIPPExoReadRecipient -Value $Incoming.Identity -FieldName 'Identity'
        if ($IdErr) { return [pscustomobject]@{ Allowed = $false; Reason = $IdErr } }
        $Incoming.Identity = ([string]$Incoming.Identity).Trim()
        $AppErr = Test-CIPPExoReadGuid -Value $Incoming.AppId -FieldName 'AppId'
        if ($AppErr) { return [pscustomobject]@{ Allowed = $false; Reason = $AppErr } }
        $Incoming.AppId = ([string]$Incoming.AppId).Trim()
    } else {
        return [pscustomobject]@{ Allowed = $false; Reason = "Cmdlet '$Cmdlet' is not on the read Test allowlist." }
    }

    return [pscustomobject]@{
        Allowed    = $true
        Reason     = $null
        Cmdlet     = $Cmdlet
        Parameters = $Incoming
    }
}

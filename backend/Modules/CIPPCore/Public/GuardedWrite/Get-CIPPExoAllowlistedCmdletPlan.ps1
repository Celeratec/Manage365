function Get-CIPPExoAllowlistedCmdletPlan {
    <#
    .SYNOPSIS
        Accepts an Exchange cmdlet only with parameters named on the allowlist.
    .DESCRIPTION
        Set-MailboxJunkEmailConfiguration rejects TrustedSendersToAdd and BlockedSendersToAdd.
        Those parameters fail through the Exchange REST proxy and must not be combined with the
        TrustedSendersAndDomains or BlockedSendersAndDomains lists.
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
        $ConfigPath = Resolve-CIPPGuardedWriteConfigPath -RelativePath 'GuardedWrites/ExoCmdletAllowlist.json' -PSScriptRoot $PSScriptRoot
        try {
            $Allowlist = Get-Content -LiteralPath $ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        } catch {
            throw "Failed to load or parse GuardedWrite allowlist from '$ConfigPath': $($_.Exception.Message)"
        }
    }
    $AllowedNames = @($Allowlist.$Cmdlet)
    if ($null -eq $Allowlist.PSObject.Properties[$Cmdlet]) {
        return [pscustomobject]@{ Allowed = $false; Reason = "Cmdlet '$Cmdlet' is not on the allowlist." }
    }

    $Incoming = @{}
    if ($Parameters -is [System.Collections.IDictionary]) {
        foreach ($Key in @($Parameters.Keys)) { $Incoming[$Key] = $Parameters[$Key] }
    } elseif ($null -ne $Parameters) {
        foreach ($Prop in $Parameters.PSObject.Properties) { $Incoming[$Prop.Name] = $Prop.Value }
    }

    $Unknown = @($Incoming.Keys | Where-Object { $_ -notin $AllowedNames })
    if ($Unknown.Count -gt 0) {
        return [pscustomobject]@{ Allowed = $false; Reason = "Parameter '$($Unknown -join ', ')' is not allowed on $Cmdlet." }
    }
    if ($Cmdlet -eq 'Set-MailboxJunkEmailConfiguration' -and @($Incoming.Keys) -match 'ToAdd$') {
        return [pscustomobject]@{ Allowed = $false; Reason = 'Set-MailboxJunkEmailConfiguration does not accept TrustedSendersToAdd or BlockedSendersToAdd. Send TrustedSendersAndDomains or BlockedSendersAndDomains.' }
    }
    if ($Cmdlet -eq 'New-ManagementScope' -and $Incoming.ContainsKey('RecipientRestrictionFilter')) {
        $Filter = [string]$Incoming.RecipientRestrictionFilter
        if ($Filter.Length -gt 1024) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'RecipientRestrictionFilter must be a string of at most 1024 characters.' }
        }
    }
    if ($Cmdlet -eq 'New-ManagementRoleAssignment') {
        $AllowedRoles = @(
            'Application Mail.Read',
            'Application Calendars.Read',
            'Application Mail.ReadBasic'
        )
        if ([string]$Incoming.Role -notin $AllowedRoles) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'Role must be Application Mail.Read, Application Calendars.Read, or Application Mail.ReadBasic.' }
        }
    }
    if ($Cmdlet -eq 'Set-AdminAuditLogConfig' -and $Incoming.ContainsKey('UnifiedAuditLogIngestionEnabled')) {
        $Flag = [string]$Incoming.UnifiedAuditLogIngestionEnabled
        if ($Flag -notin @('true', 'false', 'True', 'False', '1', '0')) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'UnifiedAuditLogIngestionEnabled must be a boolean.' }
        }
    }
    if ($Cmdlet -eq 'Set-AcceptedDomain') {
        if (-not $Incoming.ContainsKey('Identity')) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'Set-AcceptedDomain requires Identity.' }
        }
        if (-not $Incoming.ContainsKey('DomainType')) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'Set-AcceptedDomain requires DomainType.' }
        }
        $Id = $Incoming.Identity
        if ($Id -is [array] -or $Id -is [hashtable] -or $null -eq $Id -or ($Id -is [PSCustomObject])) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'Identity must be a scalar string.' }
        }
        $IdRaw = [string]$Id
        if ($IdRaw -match '[\x00-\x1F\x7F]') {
            return [pscustomobject]@{ Allowed = $false; Reason = 'Identity must not contain control characters.' }
        }
        $IdStr = $IdRaw.Trim()
        if ($IdRaw -ne $IdStr) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'Identity must not have leading or trailing whitespace.' }
        }
        if ($IdStr.Length -eq 0 -or $IdStr.Length -gt 253) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'Identity must be 1 to 253 characters.' }
        }
        if ($IdStr -match '%.*%' -or $IdStr -match '\*') {
            return [pscustomobject]@{ Allowed = $false; Reason = 'Identity must not contain wildcards or variable tokens.' }
        }
        if ($IdStr -notmatch '\A([a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?\z') {
            return [pscustomobject]@{ Allowed = $false; Reason = 'Identity must be a valid domain name (labels of letters, digits, and hyphens separated by dots).' }
        }
        $Labels = $IdStr -split '\.'
        foreach ($Label in $Labels) {
            if ($Label.Length -gt 63) {
                return [pscustomobject]@{ Allowed = $false; Reason = 'Identity domain name labels must be at most 63 characters each.' }
            }
        }
        $Incoming.Identity = $IdStr
        $Type = $Incoming.DomainType
        if ($Type -is [array] -or $Type -is [hashtable] -or ($Type -is [PSCustomObject])) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'DomainType must be a scalar string.' }
        }
        $TypeStr = [string]$Type
        if ($TypeStr -notin @('Authoritative', 'InternalRelay', 'ExternalRelay')) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'DomainType must be Authoritative, InternalRelay, or ExternalRelay.' }
        }
        $Incoming.DomainType = $TypeStr
    }
    if ($Cmdlet -eq 'Set-DkimSigningConfig') {
        if (-not $Incoming.ContainsKey('Identity')) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'Set-DkimSigningConfig requires Identity.' }
        }
        if (-not $Incoming.ContainsKey('Enabled')) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'Set-DkimSigningConfig requires Enabled.' }
        }
        $Id = $Incoming.Identity
        if ($Id -is [array] -or $Id -is [hashtable] -or $null -eq $Id -or ($Id -is [PSCustomObject])) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'Identity must be a scalar string.' }
        }
        $IdRaw = [string]$Id
        if ($IdRaw -match '[\x00-\x1F\x7F]') {
            return [pscustomobject]@{ Allowed = $false; Reason = 'Identity must not contain control characters.' }
        }
        $IdStr = $IdRaw.Trim()
        if ($IdRaw -ne $IdStr) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'Identity must not have leading or trailing whitespace.' }
        }
        if ($IdStr.Length -eq 0 -or $IdStr.Length -gt 253) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'Identity must be 1 to 253 characters.' }
        }
        if ($IdStr -match '%.*%' -or $IdStr -match '\*') {
            return [pscustomobject]@{ Allowed = $false; Reason = 'Identity must not contain wildcards or variable tokens.' }
        }
        if ($IdStr -notmatch '\A([a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?\z') {
            return [pscustomobject]@{ Allowed = $false; Reason = 'Identity must be a valid domain name (labels of letters, digits, and hyphens separated by dots).' }
        }
        $Labels = $IdStr -split '\.'
        foreach ($Label in $Labels) {
            if ($Label.Length -gt 63) {
                return [pscustomobject]@{ Allowed = $false; Reason = 'Identity domain name labels must be at most 63 characters each.' }
            }
        }
        $Incoming.Identity = $IdStr
        $Flag = $Incoming.Enabled
        if ($Flag -is [array] -or $Flag -is [hashtable] -or ($Flag -is [PSCustomObject])) {
            return [pscustomobject]@{ Allowed = $false; Reason = 'Enabled must be a scalar boolean.' }
        }
        $FlagStr = [string]$Flag
        if ($FlagStr -iin @('true', '1')) {
            $Incoming.Enabled = $true
        } elseif ($FlagStr -iin @('false', '0')) {
            $Incoming.Enabled = $false
        } elseif ($Flag -is [bool]) {
            $Incoming.Enabled = $Flag
        } else {
            return [pscustomobject]@{ Allowed = $false; Reason = 'Enabled must be a boolean.' }
        }
    }

    return [pscustomobject]@{
        Allowed    = $true
        Reason     = $null
        Cmdlet     = $Cmdlet
        Parameters = $Incoming
    }
}

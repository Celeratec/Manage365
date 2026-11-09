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
        $ConfigPath = Join-Path $PSScriptRoot '../../../../Config/GuardedWrites/ExoCmdletAllowlist.json'
        $Allowlist = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
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
        if ($Incoming.ContainsKey('Identity')) {
            $Id = [string]$Incoming.Identity
            if ($Id -eq '' -or $Id -match '[\r\n]') {
                return [pscustomobject]@{ Allowed = $false; Reason = 'Identity must be a non-empty string with no newline characters.' }
            }
        }
        if ($Incoming.ContainsKey('DomainType')) {
            $Type = [string]$Incoming.DomainType
            if ($Type -notin @('Authoritative', 'InternalRelay', 'ExternalRelay')) {
                return [pscustomobject]@{ Allowed = $false; Reason = 'DomainType must be Authoritative, InternalRelay, or ExternalRelay.' }
            }
        }
    }
    if ($Cmdlet -eq 'Set-DkimSigningConfig') {
        if ($Incoming.ContainsKey('Identity')) {
            $Id = [string]$Incoming.Identity
            if ($Id -eq '' -or $Id -match '[\r\n]') {
                return [pscustomobject]@{ Allowed = $false; Reason = 'Identity must be a non-empty string with no newline characters.' }
            }
        }
        if ($Incoming.ContainsKey('Enabled')) {
            $Flag = [string]$Incoming.Enabled
            if ($Flag -notin @('true', 'false', 'True', 'False', '1', '0')) {
                return [pscustomobject]@{ Allowed = $false; Reason = 'Enabled must be a boolean.' }
            }
        }
    }

    return [pscustomobject]@{
        Allowed    = $true
        Reason     = $null
        Cmdlet     = $Cmdlet
        Parameters = $Incoming
    }
}

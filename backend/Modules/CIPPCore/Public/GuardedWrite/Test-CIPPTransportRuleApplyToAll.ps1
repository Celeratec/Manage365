function Test-CIPPTransportRuleApplyToAll {
    <#
    .SYNOPSIS
        Guards condition-less transport rules in guarded mode.
    .DESCRIPTION
        A rule with no non-ExceptIf predicate parameters applies to every message. In guarded
        mode that requires applyToAllMessages:true, and even then DeleteMessage, Quarantine,
        RedirectMessageTo, RouteMessageOutboundConnector, and reject actions are refused.
        BlindCopyTo/CopyTo and header/SCL-style actions are allowed.
    #>
    [CmdletBinding()]
    param(
        [hashtable]$CmdletParams,
        $ApplyToAllMessages
    )

    $ConditionParams = @(
        'From', 'FromScope', 'FromMemberOf', 'SentTo', 'SentToScope', 'SentToMemberOf',
        'SubjectContainsWords', 'SubjectMatchesPatterns', 'SubjectOrBodyContainsWords', 'SubjectOrBodyMatchesPatterns',
        'FromAddressContainsWords', 'FromAddressMatchesPatterns',
        'AttachmentContainsWords', 'AttachmentMatchesPatterns', 'AttachmentNameMatchesPatterns',
        'AttachmentPropertyContainsWords', 'AttachmentExtensionMatchesWords',
        'AttachmentHasExecutableContent', 'AttachmentIsPasswordProtected', 'AttachmentIsUnsupported',
        'AttachmentProcessingLimitExceeded', 'AttachmentSizeOver', 'MessageSizeOver', 'SCLOver',
        'WithImportance', 'MessageTypeMatches', 'SenderDomainIs', 'RecipientDomainIs',
        'RecipientAddressContainsWords', 'RecipientAddressMatchesPatterns',
        'AnyOfRecipientAddressContainsWords', 'AnyOfRecipientAddressMatchesPatterns',
        'AnyOfToHeader', 'AnyOfToHeaderMemberOf', 'AnyOfCcHeader', 'AnyOfCcHeaderMemberOf',
        'AnyOfToCcHeader', 'AnyOfToCcHeaderMemberOf',
        'HeaderContainsMessageHeader', 'HeaderContainsWords', 'HeaderMatchesMessageHeader', 'HeaderMatchesPatterns',
        'SenderIpRanges'
    )

    $HasCondition = $false
    foreach ($Key in $CmdletParams.Keys) {
        if ($Key -like 'ExceptIf*') { continue }
        if ($ConditionParams -contains $Key) {
            $HasCondition = $true
            break
        }
    }

    if ($HasCondition) {
        return [pscustomobject]@{ Ok = $true; HasCondition = $true; Message = $null }
    }

    $FlagTrue = $false
    if ($null -ne $ApplyToAllMessages -and "$ApplyToAllMessages" -ne '') {
        $Raw = if ($ApplyToAllMessages -is [hashtable] -or $ApplyToAllMessages -is [PSCustomObject]) {
            if ($null -ne $ApplyToAllMessages.value) { "$($ApplyToAllMessages.value)" } else { "$ApplyToAllMessages" }
        } else { "$ApplyToAllMessages" }
        $FlagTrue = $Raw -in @('true', 'True', '1')
    }

    if (-not $FlagTrue) {
        return [pscustomobject]@{
            Ok           = $false
            HasCondition = $false
            Message      = 'This rule has no conditions and would apply to every message in the organization. Set applyToAllMessages to true to confirm, or add at least one condition. (Fallback: two rules with FromScope InOrganization and NotInOrganization.)'
        }
    }

    $Forbidden = @(
        'DeleteMessage', 'Quarantine', 'RedirectMessageTo', 'RouteMessageOutboundConnector',
        'RejectMessageReasonText', 'RejectMessageEnhancedStatusCode'
    )
    foreach ($Key in $Forbidden) {
        if (-not $CmdletParams.ContainsKey($Key)) { continue }
        $Value = $CmdletParams[$Key]
        $Present = $false
        if ($Value -is [bool]) { $Present = $Value }
        elseif ($Value -is [array]) { $Present = $Value.Count -gt 0 }
        elseif ($null -ne $Value -and "$Value" -ne '' -and "$Value" -notin @('false', 'False', '0')) { $Present = $true }
        if ($Present) {
            return [pscustomobject]@{
                Ok           = $false
                HasCondition = $false
                Message      = "Unconditional rules cannot use $Key even with applyToAllMessages. Use BlindCopyTo/CopyTo or add a condition."
            }
        }
    }

    return [pscustomobject]@{ Ok = $true; HasCondition = $false; Message = $null }
}

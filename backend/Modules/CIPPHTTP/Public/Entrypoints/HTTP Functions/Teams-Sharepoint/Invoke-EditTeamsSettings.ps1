function Invoke-EditTeamsSettings {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Teams.Group.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Body.tenantFilter

    $Results = [System.Collections.Generic.List[string]]::new()

    try {
        if ([string]::IsNullOrWhiteSpace($TenantFilter)) {
            throw 'Tenant filter is required.'
        }

        $Section = $Request.Body.section

        switch ($Section) {
            'federation' {
                # Helper function to parse and validate domain lists
                function ConvertTo-ValidatedDomainList {
                    param(
                        [object]$RawInput,
                        [string]$FieldName,
                        [bool]$AllowEmpty = $false
                    )
                    
                    # Handle explicit empty array to clear domains
                    if ($RawInput -is [array] -and $RawInput.Count -eq 0) {
                        return @()
                    }
                    
                    $parsed = @()
                    if ($null -ne $RawInput -and $RawInput -ne '') {
                        if ($RawInput -is [string]) {
                            $parsed = $RawInput -split '[,;\s]+' | Where-Object { $_ -ne '' }
                        } elseif ($RawInput -is [array]) {
                            foreach ($item in $RawInput) {
                                if ($item -is [string]) {
                                    $parsed += $item
                                } else {
                                    throw "Invalid domain in $FieldName : non-string element of type $($item.GetType().Name)"
                                }
                            }
                            $parsed = $parsed | Where-Object { $_ -ne '' }
                        } else {
                            throw "Invalid domain list in $FieldName : expected string or array, got $($RawInput.GetType().Name)"
                        }
                    }
                    
                    $validDomains = @()
                    $invalidDomains = @()
                    # Domain regex: require at least one dot (no bare TLDs), use \z instead of $
                    $domainRegex = '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+\z'
                    
                    foreach ($d in $parsed) {
                        if (-not ($d -is [string])) {
                            $invalidDomains += "$d (non-string)"
                            continue
                        }
                        
                        $domainTrimmed = $d.Trim()
                        if ($domainTrimmed.Length -gt 253) {
                            $invalidDomains += "$domainTrimmed (exceeds 253 characters)"
                            continue
                        }
                        
                        $domainLower = $domainTrimmed.ToLower()
                        if ($domainLower -match $domainRegex) {
                            if ($domainLower -notin $validDomains) {
                                $validDomains += $domainLower
                            }
                        } else {
                            $invalidDomains += $domainTrimmed
                        }
                    }
                    
                    if ($invalidDomains.Count -gt 0) {
                        throw "Invalid domains in $FieldName : $($invalidDomains -join ', ')"
                    }
                    
                    return $validDomains
                }

                # Establish Teams session first and get current configuration
                $CurrentConfig = New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Get-CsTenantFederationConfiguration' -CmdParams @{ Identity = 'Global' }

                # Parse and validate federationMode before any mutations
                $FederationMode = $Request.Body.federationMode
                
                # Reject non-string, non-object types immediately
                if ($FederationMode -is [array]) {
                    throw "Invalid federationMode: arrays are not supported"
                }
                if ($FederationMode -is [int] -or $FederationMode -is [double] -or $FederationMode -is [bool]) {
                    throw "Invalid federationMode: numeric and boolean values are not supported"
                }
                
                # Extract .value if object, but validate it has a value property
                if ($FederationMode -is [PSCustomObject] -or $FederationMode -is [hashtable]) {
                    if ($null -eq $FederationMode.value) {
                        throw "Invalid federationMode: object must have a 'value' property"
                    }
                    $FederationMode = $FederationMode.value
                }
                
                # Validate federationMode is one of the 4 valid strings
                $validModes = @('AllowAllExternal', 'BlockAllExternal', 'AllowSpecificExternal', 'BlockSpecificExternal')
                if ([string]::IsNullOrWhiteSpace($FederationMode) -or $FederationMode -notin $validModes) {
                    throw "Invalid federationMode: '$FederationMode'. Must be one of: $($validModes -join ', ')"
                }

                # Build federation configuration parameters (no AllowFederatedUsers default)
                $cmdParams = @{
                    Identity = 'Global'
                }
                
                $AllowedDomainsAsAList = @()
                $ExpectedAllowedDomains = @()
                $ExpectedBlockedDomains = @()
                $ExpectedAllowAllKnownDomains = $false

                # Helper to check if a domain field was meaningfully provided (array or non-blank string)
                function Test-DomainFieldProvided {
                    param([object]$Value)
                    return ($Value -is [array]) -or (($Value -is [string]) -and (-not [string]::IsNullOrWhiteSpace($Value)))
                }

                switch ($FederationMode) {
                    'AllowAllExternal' {
                        $cmdParams['AllowFederatedUsers'] = $true
                        $cmdParams['AllowedDomains'] = New-CsEdgeAllowAllKnownDomains
                        $ExpectedAllowAllKnownDomains = $true
                        
                        # Preserve existing BlockedDomains unless explicitly provided
                        if (Test-DomainFieldProvided -Value $Request.Body.federationBlockedDomains) {
                            $BlockedDomainsList = @(ConvertTo-ValidatedDomainList -RawInput $Request.Body.federationBlockedDomains -FieldName 'federationBlockedDomains' -AllowEmpty $true)
                            $cmdParams['BlockedDomains'] = $BlockedDomainsList
                            $ExpectedBlockedDomains = $BlockedDomainsList
                        } elseif ($CurrentConfig.BlockedDomains) {
                            $cmdParams['BlockedDomains'] = $CurrentConfig.BlockedDomains
                            $ExpectedBlockedDomains = @($CurrentConfig.BlockedDomains)
                        } else {
                            $ExpectedBlockedDomains = @()
                        }
                    }
                    'BlockAllExternal' {
                        $cmdParams['AllowFederatedUsers'] = $false
                        $cmdParams['AllowedDomains'] = New-CsEdgeAllowAllKnownDomains
                        $ExpectedAllowAllKnownDomains = $true
                    }
                    'AllowSpecificExternal' {
                        $cmdParams['AllowFederatedUsers'] = $true
                        
                        # federationAllowedDomains is required and must be provided
                        if (-not (Test-DomainFieldProvided -Value $Request.Body.federationAllowedDomains)) {
                            throw 'AllowSpecificExternal mode requires federationAllowedDomains to be provided as a non-empty string or array.'
                        }
                        
                        $AllowedDomainsAsAList = @(ConvertTo-ValidatedDomainList -RawInput $Request.Body.federationAllowedDomains -FieldName 'federationAllowedDomains')
                        $ExpectedAllowedDomains = $AllowedDomainsAsAList
                        
                        if ($AllowedDomainsAsAList.Count -eq 0) {
                            throw 'AllowSpecificExternal mode requires at least one allowed domain.'
                        }
                        
                        # Preserve existing BlockedDomains unless explicitly provided
                        if (Test-DomainFieldProvided -Value $Request.Body.federationBlockedDomains) {
                            $BlockedDomainsList = @(ConvertTo-ValidatedDomainList -RawInput $Request.Body.federationBlockedDomains -FieldName 'federationBlockedDomains' -AllowEmpty $true)
                            $cmdParams['BlockedDomains'] = $BlockedDomainsList
                            $ExpectedBlockedDomains = $BlockedDomainsList
                        } elseif ($CurrentConfig.BlockedDomains) {
                            $cmdParams['BlockedDomains'] = $CurrentConfig.BlockedDomains
                            $ExpectedBlockedDomains = @($CurrentConfig.BlockedDomains)
                        } else {
                            $ExpectedBlockedDomains = @()
                        }
                    }
                    'BlockSpecificExternal' {
                        $cmdParams['AllowFederatedUsers'] = $true
                        $cmdParams['AllowedDomains'] = New-CsEdgeAllowAllKnownDomains
                        $ExpectedAllowAllKnownDomains = $true
                        
                        # federationBlockedDomains can be provided or omitted; empty array clears
                        if (Test-DomainFieldProvided -Value $Request.Body.federationBlockedDomains) {
                            $BlockedDomainsList = @(ConvertTo-ValidatedDomainList -RawInput $Request.Body.federationBlockedDomains -FieldName 'federationBlockedDomains' -AllowEmpty $true)
                            $ExpectedBlockedDomains = $BlockedDomainsList
                            $cmdParams['BlockedDomains'] = $BlockedDomainsList
                        } elseif ($CurrentConfig.BlockedDomains) {
                            $cmdParams['BlockedDomains'] = $CurrentConfig.BlockedDomains
                            $ExpectedBlockedDomains = @($CurrentConfig.BlockedDomains)
                        } else {
                            $ExpectedBlockedDomains = @()
                        }
                    }
                }

                # Use AllowedDomainsAsAList for specific domain lists
                if ($AllowedDomainsAsAList.Count -gt 0) {
                    $cmdParams.Remove('AllowedDomains')
                    $cmdParams['AllowedDomainsAsAList'] = $AllowedDomainsAsAList
                }

                if ($null -ne $Request.Body.allowTeamsConsumer) {
                    $cmdParams['AllowTeamsConsumer'] = [bool]$Request.Body.allowTeamsConsumer
                }

                # Apply the configuration
                New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Set-CsTenantFederationConfiguration' -CmdParams $cmdParams

                # Verify the configuration was applied correctly
                $VerifyConfig = New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Get-CsTenantFederationConfiguration' -CmdParams @{ Identity = 'Global' }
                
                $verificationFailed = $false
                $verificationErrors = @()

                # Verify AllowFederatedUsers
                if ($VerifyConfig.AllowFederatedUsers -ne $cmdParams.AllowFederatedUsers) {
                    $verificationFailed = $true
                    $verificationErrors += "AllowFederatedUsers: expected $($cmdParams.AllowFederatedUsers), got $($VerifyConfig.AllowFederatedUsers)"
                }

                # Verify AllowAllKnownDomains for modes that use it
                if ($ExpectedAllowAllKnownDomains) {
                    $actualIsAllowAll = $VerifyConfig.AllowedDomains -and $VerifyConfig.AllowedDomains.AllowAllKnownDomains -eq $true
                    if (-not $actualIsAllowAll) {
                        $verificationFailed = $true
                        $verificationErrors += "AllowedDomains: expected AllowAllKnownDomains, got specific domain list or null"
                    }
                }

                # Verify allowed domains for AllowSpecificExternal mode
                if ($FederationMode -eq 'AllowSpecificExternal') {
                    $actualAllowedDomains = @()
                    if ($VerifyConfig.AllowedDomains -and $VerifyConfig.AllowedDomains.Domain) {
                        $actualAllowedDomains = @(@($VerifyConfig.AllowedDomains.Domain) | Sort-Object)
                    }
                    $expectedSorted = @($ExpectedAllowedDomains | Sort-Object)
                    
                    if ($actualAllowedDomains.Count -ne $expectedSorted.Count) {
                        $verificationFailed = $true
                        $verificationErrors += "AllowedDomains count: expected $($expectedSorted.Count), got $($actualAllowedDomains.Count)"
                    } else {
                        for ($i = 0; $i -lt $expectedSorted.Count; $i++) {
                            if ($actualAllowedDomains[$i] -ne $expectedSorted[$i]) {
                                $verificationFailed = $true
                                $verificationErrors += "AllowedDomains mismatch at index $i"
                                break
                            }
                        }
                    }
                }

                # Verify BlockedDomains for all modes that set it
                $actualBlockedDomains = @()
                if ($VerifyConfig.BlockedDomains) {
                    $actualBlockedDomains = @(@($VerifyConfig.BlockedDomains) | Sort-Object)
                }
                $expectedBlockedSorted = @($ExpectedBlockedDomains | Sort-Object)
                
                if ($actualBlockedDomains.Count -ne $expectedBlockedSorted.Count) {
                    $verificationFailed = $true
                    $verificationErrors += "BlockedDomains count: expected $($expectedBlockedSorted.Count), got $($actualBlockedDomains.Count)"
                } else {
                    for ($i = 0; $i -lt $expectedBlockedSorted.Count; $i++) {
                        if ($actualBlockedDomains[$i] -ne $expectedBlockedSorted[$i]) {
                            $verificationFailed = $true
                            $verificationErrors += "BlockedDomains mismatch at index $i"
                            break
                        }
                    }
                }

                # Verify AllowTeamsConsumer if it was set
                if ($null -ne $Request.Body.allowTeamsConsumer) {
                    $expectedTeamsConsumer = [bool]$Request.Body.allowTeamsConsumer
                    if ($VerifyConfig.AllowTeamsConsumer -ne $expectedTeamsConsumer) {
                        $verificationFailed = $true
                        $verificationErrors += "AllowTeamsConsumer: expected $expectedTeamsConsumer, got $($VerifyConfig.AllowTeamsConsumer)"
                    }
                }

                if ($verificationFailed) {
                    Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Federation verification failed: $($verificationErrors -join '; ')" -Sev 'Error'
                    $Body = [PSCustomObject]@{
                        Results = 'Federation change was sent but verification failed; tenant may be partly updated. Re-read before retrying.'
                    }
                    $StatusCode = [HttpStatusCode]::BadGateway
                    return ([HttpResponseContext]@{
                        StatusCode = $StatusCode
                        Body       = $Body
                    })
                }

                $Results.Add('Successfully updated federation configuration.')

                # Update External Access Policy
                $ExternalParams = @{ Identity = 'Global' }
                if ($null -ne $Request.Body.enableFederationAccess) {
                    $ExternalParams['EnableFederationAccess'] = [bool]$Request.Body.enableFederationAccess
                }
                if ($null -ne $Request.Body.enableTeamsConsumerAccess) {
                    $ExternalParams['EnableTeamsConsumerAccess'] = [bool]$Request.Body.enableTeamsConsumerAccess
                }
                if ($ExternalParams.Count -gt 1) {
                    New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Set-CsExternalAccessPolicy' -CmdParams $ExternalParams
                    $Results.Add('Successfully updated external access policy.')
                }
            }

            'client' {
                # Update Client Configuration (guest access, external file sharing)
                $cmdParams = @{ Identity = 'Global' }

                if ($null -ne $Request.Body.allowGuestUser) {
                    $cmdParams['AllowGuestUser'] = [bool]$Request.Body.allowGuestUser
                }
                if ($null -ne $Request.Body.allowGoogleDrive) {
                    $cmdParams['AllowGoogleDrive'] = [bool]$Request.Body.allowGoogleDrive
                }
                if ($null -ne $Request.Body.allowShareFile) {
                    $cmdParams['AllowShareFile'] = [bool]$Request.Body.allowShareFile
                }
                if ($null -ne $Request.Body.allowBox) {
                    $cmdParams['AllowBox'] = [bool]$Request.Body.allowBox
                }
                if ($null -ne $Request.Body.allowDropBox) {
                    $cmdParams['AllowDropBox'] = [bool]$Request.Body.allowDropBox
                }
                if ($null -ne $Request.Body.allowEgnyte) {
                    $cmdParams['AllowEgnyte'] = [bool]$Request.Body.allowEgnyte
                }

                if ($cmdParams.Count -gt 1) {
                    New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Set-CsTeamsClientConfiguration' -CmdParams $cmdParams
                    $Results.Add('Successfully updated client configuration.')
                }
            }

            'meeting' {
                # Update Global Meeting Policy
                $cmdParams = @{ Identity = 'Global' }

                if ($null -ne $Request.Body.allowAnonymousUsersToJoinMeeting) {
                    $cmdParams['AllowAnonymousUsersToJoinMeeting'] = [bool]$Request.Body.allowAnonymousUsersToJoinMeeting
                }
                if ($null -ne $Request.Body.allowAnonymousUsersToStartMeeting) {
                    $cmdParams['AllowAnonymousUsersToStartMeeting'] = [bool]$Request.Body.allowAnonymousUsersToStartMeeting
                }
                if ($null -ne $Request.Body.autoAdmittedUsers) {
                    $cmdParams['AutoAdmittedUsers'] = $Request.Body.autoAdmittedUsers
                }
                if ($null -ne $Request.Body.allowPSTNUsersToBypassLobby) {
                    $cmdParams['AllowPSTNUsersToBypassLobby'] = [bool]$Request.Body.allowPSTNUsersToBypassLobby
                }
                if ($null -ne $Request.Body.meetingChatEnabledType) {
                    $cmdParams['MeetingChatEnabledType'] = $Request.Body.meetingChatEnabledType
                }
                if ($null -ne $Request.Body.designatedPresenterRoleMode) {
                    $cmdParams['DesignatedPresenterRoleMode'] = $Request.Body.designatedPresenterRoleMode
                }
                if ($null -ne $Request.Body.allowExternalParticipantGiveRequestControl) {
                    $cmdParams['AllowExternalParticipantGiveRequestControl'] = [bool]$Request.Body.allowExternalParticipantGiveRequestControl
                }

                if ($cmdParams.Count -gt 1) {
                    New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Set-CsTeamsMeetingPolicy' -CmdParams $cmdParams
                    $Results.Add('Successfully updated meeting policy.')
                }
            }

            'messaging' {
                # Update Global Messaging Policy
                $cmdParams = @{ Identity = 'Global' }

                if ($null -ne $Request.Body.allowOwnerDeleteMessage) {
                    $cmdParams['AllowOwnerDeleteMessage'] = [bool]$Request.Body.allowOwnerDeleteMessage
                }
                if ($null -ne $Request.Body.allowUserDeleteMessage) {
                    $cmdParams['AllowUserDeleteMessage'] = [bool]$Request.Body.allowUserDeleteMessage
                }
                if ($null -ne $Request.Body.allowUserEditMessage) {
                    $cmdParams['AllowUserEditMessage'] = [bool]$Request.Body.allowUserEditMessage
                }
                if ($null -ne $Request.Body.allowUserDeleteChat) {
                    $cmdParams['AllowUserDeleteChat'] = [bool]$Request.Body.allowUserDeleteChat
                }
                if ($null -ne $Request.Body.readReceiptsEnabledType) {
                    $cmdParams['ReadReceiptsEnabledType'] = $Request.Body.readReceiptsEnabledType
                }
                if ($null -ne $Request.Body.createCustomEmojis) {
                    $cmdParams['CreateCustomEmojis'] = [bool]$Request.Body.createCustomEmojis
                }
                if ($null -ne $Request.Body.deleteCustomEmojis) {
                    $cmdParams['DeleteCustomEmojis'] = [bool]$Request.Body.deleteCustomEmojis
                }
                if ($null -ne $Request.Body.allowSecurityEndUserReporting) {
                    $cmdParams['AllowSecurityEndUserReporting'] = [bool]$Request.Body.allowSecurityEndUserReporting
                }
                if ($null -ne $Request.Body.allowCommunicationComplianceEndUserReporting) {
                    $cmdParams['AllowCommunicationComplianceEndUserReporting'] = [bool]$Request.Body.allowCommunicationComplianceEndUserReporting
                }

                if ($cmdParams.Count -gt 1) {
                    New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Set-CsTeamsMessagingPolicy' -CmdParams $cmdParams
                    $Results.Add('Successfully updated messaging policy.')
                }
            }

            'backgrounds' {
                # Update Meeting Branding Policy (background images toggle)
                if ($null -ne $Request.Body.enableMeetingBackgroundImages) {
                    $cmdParams = @{
                        Identity                     = 'Global'
                        EnableMeetingBackgroundImages = [bool]$Request.Body.enableMeetingBackgroundImages
                    }
                    New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Set-CsTeamsMeetingBrandingPolicy' -CmdParams $cmdParams
                    $Results.Add('Successfully updated meeting background settings.')
                }

                # Assign branding policy to a specific user
                if ($Request.Body.assignUser -and $Request.Body.policyName) {
                    $grantParams = @{
                        Identity   = $Request.Body.assignUser
                        PolicyName = $Request.Body.policyName
                    }
                    New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Grant-CsTeamsMeetingBrandingPolicy' -CmdParams $grantParams
                    $Results.Add("Successfully assigned branding policy '$($Request.Body.policyName)' to user '$($Request.Body.assignUser)'.")
                }
            }

            default {
                throw "Invalid section: $Section. Valid values are: federation, client, meeting, messaging, backgrounds."
            }
        }

        if ($Results.Count -eq 0) {
            throw 'No valid settings were provided to update.'
        }

        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message ($Results -join ' ') -Sev 'Info'

        $Body = [PSCustomObject]@{
            Results = ($Results -join ' ')
        }
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message "Failed to update Teams settings: $ErrorMessage" -Sev 'Error'
        $Body = [PSCustomObject]@{
            Results = "Failed to update Teams settings: $ErrorMessage"
        }
        $StatusCode = [HttpStatusCode]::BadRequest
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}

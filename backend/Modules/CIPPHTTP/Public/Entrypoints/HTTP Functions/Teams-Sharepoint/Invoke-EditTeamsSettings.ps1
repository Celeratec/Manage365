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
                # Establish Teams session first and get current configuration
                $CurrentConfig = New-TeamsRequest -TenantFilter $TenantFilter -Cmdlet 'Get-CsTenantFederationConfiguration' -CmdParams @{ Identity = 'Global' }

                # Parse federationMode (can be string or object with label/value)
                $FederationMode = $Request.Body.federationMode
                if ($FederationMode -is [PSCustomObject] -or $FederationMode -is [hashtable]) {
                    $FederationMode = $FederationMode.value
                }

                # Helper function to parse and validate domains
                function ConvertTo-DomainList {
                    param([object]$Input)
                    
                    $domains = @()
                    if ($null -eq $Input -or $Input -eq '') {
                        return $domains
                    }
                    
                    if ($Input -is [string]) {
                        $domains = $Input -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
                    } elseif ($Input -is [array]) {
                        $domains = $Input | ForEach-Object { 
                            if ($_ -is [string]) { $_.Trim() } else { $_ }
                        } | Where-Object { $_ -ne '' }
                    } else {
                        $domains = @($Input)
                    }
                    
                    # Validate domain format and deduplicate
                    $validDomains = @()
                    $domainRegex = '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
                    foreach ($domain in $domains) {
                        $domain = $domain.ToLower()
                        if ($domain -match $domainRegex -and $domain -notin $validDomains) {
                            $validDomains += $domain
                        }
                    }
                    
                    return $validDomains
                }

                # Build federation configuration parameters
                $cmdParams = @{
                    Identity            = 'Global'
                    AllowFederatedUsers = $true
                }
                
                # Preserve existing BlockedDomains unless explicitly changed
                if ($CurrentConfig.BlockedDomains) {
                    $cmdParams['BlockedDomains'] = $CurrentConfig.BlockedDomains
                }

                $AllowedDomainsAsAList = @()
                $ExpectedAllowedDomains = @()

                switch ($FederationMode) {
                    'AllowAllExternal' {
                        $cmdParams['AllowedDomains'] = New-CsEdgeAllowAllKnownDomains
                    }
                    'BlockAllExternal' {
                        $cmdParams['AllowFederatedUsers'] = $false
                        $cmdParams['AllowedDomains'] = New-CsEdgeAllowAllKnownDomains
                    }
                    'AllowSpecificExternal' {
                        $AllowedDomainsAsAList = ConvertTo-DomainList -Input $Request.Body.federationAllowedDomains
                        $ExpectedAllowedDomains = $AllowedDomainsAsAList
                        if ($AllowedDomainsAsAList.Count -eq 0) {
                            throw 'AllowSpecificExternal mode requires at least one allowed domain.'
                        }
                    }
                    'BlockSpecificExternal' {
                        $cmdParams['AllowedDomains'] = New-CsEdgeAllowAllKnownDomains
                        $BlockedDomainsList = ConvertTo-DomainList -Input $Request.Body.federationBlockedDomains
                        if ($BlockedDomainsList.Count -gt 0) {
                            $cmdParams['BlockedDomains'] = $BlockedDomainsList
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

                # Verify allowed domains for AllowSpecificExternal mode
                if ($FederationMode -eq 'AllowSpecificExternal') {
                    $actualAllowedDomains = @()
                    if ($VerifyConfig.AllowedDomains -and $VerifyConfig.AllowedDomains.Domain) {
                        $actualAllowedDomains = @($VerifyConfig.AllowedDomains.Domain) | Sort-Object
                    }
                    $expectedSorted = $ExpectedAllowedDomains | Sort-Object
                    
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

                # Verify AllowTeamsConsumer if it was set
                if ($null -ne $Request.Body.allowTeamsConsumer) {
                    $expectedTeamsConsumer = [bool]$Request.Body.allowTeamsConsumer
                    if ($VerifyConfig.AllowTeamsConsumer -ne $expectedTeamsConsumer) {
                        $verificationFailed = $true
                        $verificationErrors += "AllowTeamsConsumer: expected $expectedTeamsConsumer, got $($VerifyConfig.AllowTeamsConsumer)"
                    }
                }

                if ($verificationFailed) {
                    $errorDetail = $verificationErrors -join '; '
                    throw "Federation configuration verification failed: $errorDetail"
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

# Pester tests for Invoke-EditTeamsSettings
# Tests the federation allowlist bug fix (Freshdesk #3277840):
# - Parses comma-separated domain strings
# - Handles federationMode as string or object
# - Validates domain formats
# - Verifies post-set configuration
# - Returns errors when verification fails

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Teams-Sharepoint/Invoke-EditTeamsSettings.ps1'

    class HttpResponseContext {
        [object]$StatusCode
        [object]$Body
    }

    $Accelerators = [PSObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')
    if (-not ('HttpStatusCode' -as [type])) {
        $Accelerators::Add('HttpStatusCode', [System.Net.HttpStatusCode])
    }

    function Write-LogMessage { param($headers, $API, $tenant, $message, $Sev, $LogData) }
    function Get-NormalizedError { param([string]$Message) $Message }
    
    # Mock New-CsEdgeAllowAllKnownDomains cmdlet
    function New-CsEdgeAllowAllKnownDomains {
        return [PSCustomObject]@{
            AllowAllKnownDomains = $true
        }
    }

    # Track all Teams cmdlet calls
    $script:teamsRequests = @()

    function New-TeamsRequest {
        param($TenantFilter, $Cmdlet, $CmdParams)
        
        $script:teamsRequests += [PSCustomObject]@{
            TenantFilter = $TenantFilter
            Cmdlet       = $Cmdlet
            CmdParams    = $CmdParams
        }

        if ($Cmdlet -eq 'Get-CsTenantFederationConfiguration') {
            # Return current config based on what was set
            $lastSet = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' } | Select-Object -Last 1
            
            if ($lastSet) {
                # Return what was set
                $config = [PSCustomObject]@{
                    Identity            = 'Global'
                    AllowFederatedUsers = if ($null -ne $lastSet.CmdParams.AllowFederatedUsers) { $lastSet.CmdParams.AllowFederatedUsers } else { $true }
                    AllowTeamsConsumer  = if ($null -ne $lastSet.CmdParams.AllowTeamsConsumer) { $lastSet.CmdParams.AllowTeamsConsumer } else { $false }
                    BlockedDomains      = if ($lastSet.CmdParams.BlockedDomains) { $lastSet.CmdParams.BlockedDomains } else { @() }
                }
                
                if ($lastSet.CmdParams.AllowedDomainsAsAList) {
                    $config | Add-Member -NotePropertyName 'AllowedDomains' -NotePropertyValue ([PSCustomObject]@{
                        Domain = @($lastSet.CmdParams.AllowedDomainsAsAList)
                    })
                } elseif ($lastSet.CmdParams.AllowedDomains) {
                    $config | Add-Member -NotePropertyName 'AllowedDomains' -NotePropertyValue $lastSet.CmdParams.AllowedDomains
                } else {
                    $config | Add-Member -NotePropertyName 'AllowedDomains' -NotePropertyValue (New-CsEdgeAllowAllKnownDomains)
                }
                
                return $config
            } else {
                # Return default open federation
                return [PSCustomObject]@{
                    Identity            = 'Global'
                    AllowFederatedUsers = $true
                    AllowedDomains      = New-CsEdgeAllowAllKnownDomains
                    BlockedDomains      = @()
                    AllowTeamsConsumer  = $false
                }
            }
        }
        
        if ($Cmdlet -eq 'Set-CsExternalAccessPolicy') {
            return $null
        }
    }

    function New-EditTeamsRequest {
        param([hashtable]$Extra)
        
        $body = [pscustomobject]@{
            tenantFilter = 'contoso.onmicrosoft.com'
            section      = 'federation'
        }
        
        foreach ($key in $Extra.Keys) {
            $body | Add-Member -NotePropertyName $key -NotePropertyValue $Extra[$key] -Force
        }
        
        [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'EditTeamsSettings' }
            Headers = @{}
            Body    = $body
        }
    }

    . $FunctionPath
}

Describe 'Invoke-EditTeamsSettings Federation Allowlist' {
    BeforeEach {
        $script:teamsRequests = @()
    }

    Context 'Domain Parsing' {
        It 'parses comma-separated domain string' {
            $request = New-EditTeamsRequest -Extra @{
                federationMode           = 'AllowSpecificExternal'
                federationAllowedDomains = 'domain1.com,domain2.com,domain3.com'
                enableFederationAccess   = $true
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 200
            $setCall = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCall.CmdParams.AllowedDomainsAsAList | Should -Contain 'domain1.com'
            $setCall.CmdParams.AllowedDomainsAsAList | Should -Contain 'domain2.com'
            $setCall.CmdParams.AllowedDomainsAsAList | Should -Contain 'domain3.com'
            $setCall.CmdParams.AllowedDomainsAsAList.Count | Should -Be 3
        }

        It 'parses comma-separated domains with whitespace' {
            $request = New-EditTeamsRequest -Extra @{
                federationMode           = 'AllowSpecificExternal'
                federationAllowedDomains = ' domain1.com , domain2.com , domain3.com '
                enableFederationAccess   = $true
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 200
            $setCall = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCall.CmdParams.AllowedDomainsAsAList | Should -Contain 'domain1.com'
            $setCall.CmdParams.AllowedDomainsAsAList | Should -Not -Contain ' domain1.com'
        }

        It 'handles domain array input' {
            $request = New-EditTeamsRequest -Extra @{
                federationMode           = 'AllowSpecificExternal'
                federationAllowedDomains = @('domain1.com', 'domain2.com')
                enableFederationAccess   = $true
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 200
            $setCall = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCall.CmdParams.AllowedDomainsAsAList.Count | Should -Be 2
        }

        It 'deduplicates domains' {
            $request = New-EditTeamsRequest -Extra @{
                federationMode           = 'AllowSpecificExternal'
                federationAllowedDomains = 'domain1.com,domain1.com,domain2.com'
                enableFederationAccess   = $true
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 200
            $setCall = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCall.CmdParams.AllowedDomainsAsAList.Count | Should -Be 2
        }

        It 'validates domain format and rejects invalid domains' {
            $request = New-EditTeamsRequest -Extra @{
                federationMode           = 'AllowSpecificExternal'
                federationAllowedDomains = 'valid.com,invalid..com,also-valid.org,not@valid.com'
                enableFederationAccess   = $true
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 400
            $result.Body.Results | Should -Match 'Invalid domains'
            $result.Body.Results | Should -Match 'invalid\.\.'
            $result.Body.Results | Should -Match 'not@valid'
            $setCalls = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCalls.Count | Should -Be 0
        }

        It 'handles 109-domain comma-separated string' {
            $domains = 1..109 | ForEach-Object { "domain$_.com" }
            $domainString = $domains -join ','

            $request = New-EditTeamsRequest -Extra @{
                federationMode           = 'AllowSpecificExternal'
                federationAllowedDomains = $domainString
                enableFederationAccess   = $true
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 200
            $setCall = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCall.CmdParams.AllowedDomainsAsAList.Count | Should -Be 109
            $setCall.CmdParams.AllowedDomainsAsAList | Should -Contain 'domain1.com'
            $setCall.CmdParams.AllowedDomainsAsAList | Should -Contain 'domain109.com'
        }

        It 'filters empty domain entries' {
            $request = New-EditTeamsRequest -Extra @{
                federationMode           = 'AllowSpecificExternal'
                federationAllowedDomains = 'domain1.com,,domain2.com,,'
                enableFederationAccess   = $true
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 200
            $setCall = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCall.CmdParams.AllowedDomainsAsAList.Count | Should -Be 2
        }
    }

    Context 'FederationMode Parsing' {
        It 'handles federationMode as string' {
            $request = New-EditTeamsRequest -Extra @{
                federationMode           = 'AllowSpecificExternal'
                federationAllowedDomains = 'test.com'
                enableFederationAccess   = $true
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 200
        }

        It 'handles federationMode as object with value property' {
            $request = New-EditTeamsRequest -Extra @{
                federationMode           = @{ label = 'Allow specific external domains'; value = 'AllowSpecificExternal' }
                federationAllowedDomains = 'test.com'
                enableFederationAccess   = $true
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 200
            $setCall = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCall.CmdParams.AllowedDomainsAsAList | Should -Contain 'test.com'
        }

        It 'rejects invalid federationMode string' {
            $request = New-EditTeamsRequest -Extra @{
                federationMode           = 'Bogus'
                federationAllowedDomains = 'test.com'
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 400
            $result.Body.Results | Should -Match 'Invalid federationMode'
            $setCalls = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCalls.Count | Should -Be 0
        }

        It 'rejects null federationMode' {
            $request = New-EditTeamsRequest -Extra @{
                federationMode           = $null
                federationAllowedDomains = 'test.com'
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 400
            $result.Body.Results | Should -Match 'Invalid federationMode'
            $setCalls = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCalls.Count | Should -Be 0
        }

        It 'rejects object with null value' {
            $request = New-EditTeamsRequest -Extra @{
                federationMode           = @{ label = 'Test'; value = $null }
                federationAllowedDomains = 'test.com'
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 400
            $result.Body.Results | Should -Match 'Invalid federationMode'
            $setCalls = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCalls.Count | Should -Be 0
        }

        It 'rejects array federationMode' {
            $request = New-EditTeamsRequest -Extra @{
                federationMode           = @('AllowSpecificExternal')
                federationAllowedDomains = 'test.com'
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 400
            $result.Body.Results | Should -Match 'arrays are not supported'
            $setCalls = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCalls.Count | Should -Be 0
        }

        It 'rejects integer federationMode' {
            $request = New-EditTeamsRequest -Extra @{
                federationMode           = 1
                federationAllowedDomains = 'test.com'
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 400
            $result.Body.Results | Should -Match 'numeric and boolean values are not supported'
            $setCalls = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCalls.Count | Should -Be 0
        }

        It 'rejects object without value property' {
            $request = New-EditTeamsRequest -Extra @{
                federationMode           = @{ label = 'Test' }
                federationAllowedDomains = 'test.com'
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 400
            $result.Body.Results | Should -Match "object must have a 'value' property"
            $setCalls = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCalls.Count | Should -Be 0
        }

        It 'rejects object with array value' {
            $request = New-EditTeamsRequest -Extra @{
                federationMode           = @{ label = 'Test'; value = @('AllowSpecificExternal') }
                federationAllowedDomains = 'test.com'
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 400
            $result.Body.Results | Should -Match 'value property cannot be an array'
            $setCalls = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCalls.Count | Should -Be 0
        }

        It 'rejects non-standard mode string like AllowEverything' {
            $request = New-EditTeamsRequest -Extra @{
                federationMode           = 'AllowEverything'
                federationAllowedDomains = 'test.com'
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 400
            $result.Body.Results | Should -Match 'Invalid federationMode'
            $result.Body.Results | Should -Match 'Must be one of'
            $setCalls = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCalls.Count | Should -Be 0
        }

        It 'requires at least one domain for AllowSpecificExternal' {
            $request = New-EditTeamsRequest -Extra @{
                federationMode           = 'AllowSpecificExternal'
                federationAllowedDomains = ''
                enableFederationAccess   = $true
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 400
            $result.Body.Results | Should -Match 'federationAllowedDomains to be provided'
        }
        
        It 'rejects invalid domains with 400 listing them' {
            $request = New-EditTeamsRequest -Extra @{
                federationMode           = 'AllowSpecificExternal'
                federationAllowedDomains = 'valid.com,invalid..com,also@bad'
                enableFederationAccess   = $true
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 400
            $result.Body.Results | Should -Match 'Invalid domains'
            $result.Body.Results | Should -Match 'invalid\.\.'
            $result.Body.Results | Should -Match 'also@bad'
        }
        
        It 'splits on comma, semicolon, and whitespace' {
            $request = New-EditTeamsRequest -Extra @{
                federationMode           = 'AllowSpecificExternal'
                federationAllowedDomains = 'a.com, b.com; c.com d.com'
                enableFederationAccess   = $true
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 200
            $setCall = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCall.CmdParams.AllowedDomainsAsAList.Count | Should -Be 4
            $setCall.CmdParams.AllowedDomainsAsAList | Should -Contain 'a.com'
            $setCall.CmdParams.AllowedDomainsAsAList | Should -Contain 'b.com'
            $setCall.CmdParams.AllowedDomainsAsAList | Should -Contain 'c.com'
            $setCall.CmdParams.AllowedDomainsAsAList | Should -Contain 'd.com'
        }
        
        It 'handles single domain correctly' {
            $request = New-EditTeamsRequest -Extra @{
                federationMode           = 'AllowSpecificExternal'
                federationAllowedDomains = 'single.com'
                enableFederationAccess   = $true
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 200
            $setCall = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCall.CmdParams.AllowedDomainsAsAList.Count | Should -Be 1
            $setCall.CmdParams.AllowedDomainsAsAList | Should -Contain 'single.com'
        }

        It 'rejects bare TLD without subdomain' {
            $request = New-EditTeamsRequest -Extra @{
                federationMode           = 'AllowSpecificExternal'
                federationAllowedDomains = 'com'
                enableFederationAccess   = $true
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 400
            $result.Body.Results | Should -Match 'Invalid domains'
            $result.Body.Results | Should -Match 'com'
        }

        It 'rejects domain exceeding 253 characters' {
            $longDomain = ('a' * 250) + '.com'
            $request = New-EditTeamsRequest -Extra @{
                federationMode           = 'AllowSpecificExternal'
                federationAllowedDomains = $longDomain
                enableFederationAccess   = $true
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 400
            $result.Body.Results | Should -Match 'exceeds 253 characters'
        }

        It 'rejects non-string element in domain array' {
            $request = New-EditTeamsRequest -Extra @{
                federationMode           = 'AllowSpecificExternal'
                federationAllowedDomains = @('valid.com', 123)
                enableFederationAccess   = $true
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 400
            $result.Body.Results | Should -Match 'non-string element'
        }

        It 'accepts explicit empty array to clear allowlist' {
            $request = New-EditTeamsRequest -Extra @{
                federationMode           = 'AllowAllExternal'
                federationAllowedDomains = @()
                enableFederationAccess   = $true
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 200
        }
    }

    Context 'Post-Set Verification' {
        It 'succeeds when configuration matches request' {
            $request = New-EditTeamsRequest -Extra @{
                federationMode           = 'AllowSpecificExternal'
                federationAllowedDomains = 'domain1.com,domain2.com'
                enableFederationAccess   = $true
                allowTeamsConsumer       = $false
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 200
            $result.Body.Results | Should -Match 'Successfully updated federation configuration'
            
            # Should have: 1st Get (before set), 1 Set, 2nd Get (verification)
            $getCalls = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Get-CsTenantFederationConfiguration' }
            $getCalls.Count | Should -BeGreaterOrEqual 2
        }
    }

    Context 'Error Propagation' {
        It 'returns error when New-TeamsRequest throws on Set' {
            # Override New-TeamsRequest to throw on Set
            Mock New-TeamsRequest {
                param($TenantFilter, $Cmdlet, $CmdParams)
                if ($Cmdlet -eq 'Set-CsTenantFederationConfiguration') {
                    throw 'Simulated API error'
                }
                if ($Cmdlet -eq 'Get-CsTenantFederationConfiguration') {
                    return [PSCustomObject]@{
                        Identity            = 'Global'
                        AllowFederatedUsers = $true
                        AllowedDomains      = New-CsEdgeAllowAllKnownDomains
                        BlockedDomains      = @()
                    }
                }
            }

            $request = New-EditTeamsRequest -Extra @{
                federationMode           = 'AllowSpecificExternal'
                federationAllowedDomains = 'test.com'
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 400
            $result.Body.Results | Should -Match 'Failed to update Teams settings'
        }
    }

    Context 'BlockedDomains Preservation' {
        It 'preserves existing BlockedDomains when not changing them' {
            # Mock to return config with blocked domains
            Mock New-TeamsRequest {
                param($TenantFilter, $Cmdlet, $CmdParams)
                
                $script:teamsRequests += [PSCustomObject]@{
                    TenantFilter = $TenantFilter
                    Cmdlet       = $Cmdlet
                    CmdParams    = $CmdParams
                }
                
                if ($Cmdlet -eq 'Get-CsTenantFederationConfiguration') {
                    $lastSet = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' } | Select-Object -Last 1
                    
                    if ($lastSet) {
                        $config = [PSCustomObject]@{
                            Identity            = 'Global'
                            AllowFederatedUsers = $lastSet.CmdParams.AllowFederatedUsers
                            AllowTeamsConsumer  = $lastSet.CmdParams.AllowTeamsConsumer
                            BlockedDomains      = $lastSet.CmdParams.BlockedDomains
                        }
                        
                        if ($lastSet.CmdParams.AllowedDomainsAsAList) {
                            $config | Add-Member -NotePropertyName 'AllowedDomains' -NotePropertyValue ([PSCustomObject]@{
                                Domain = $lastSet.CmdParams.AllowedDomainsAsAList
                            })
                        }
                        
                        return $config
                    } else {
                        return [PSCustomObject]@{
                            Identity            = 'Global'
                            AllowFederatedUsers = $true
                            AllowedDomains      = New-CsEdgeAllowAllKnownDomains
                            BlockedDomains      = @('spam.com', 'malicious.org')
                            AllowTeamsConsumer  = $false
                        }
                    }
                }
            }

            $request = New-EditTeamsRequest -Extra @{
                federationMode           = 'AllowSpecificExternal'
                federationAllowedDomains = 'trusted.com'
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 200
            $setCall = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCall.CmdParams.BlockedDomains | Should -Contain 'spam.com'
            $setCall.CmdParams.BlockedDomains | Should -Contain 'malicious.org'
        }

        It 'preserves existing BlockedDomains when empty string is sent (UI payload)' {
            Mock New-TeamsRequest {
                param($TenantFilter, $Cmdlet, $CmdParams)
                
                $script:teamsRequests += [PSCustomObject]@{
                    TenantFilter = $TenantFilter
                    Cmdlet       = $Cmdlet
                    CmdParams    = $CmdParams
                }
                
                if ($Cmdlet -eq 'Get-CsTenantFederationConfiguration') {
                    $lastSet = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' } | Select-Object -Last 1
                    
                    if ($lastSet) {
                        $config = [PSCustomObject]@{
                            Identity            = 'Global'
                            AllowFederatedUsers = $lastSet.CmdParams.AllowFederatedUsers
                            AllowTeamsConsumer  = $lastSet.CmdParams.AllowTeamsConsumer
                            BlockedDomains      = $lastSet.CmdParams.BlockedDomains
                        }
                        
                        if ($lastSet.CmdParams.AllowedDomainsAsAList) {
                            $config | Add-Member -NotePropertyName 'AllowedDomains' -NotePropertyValue ([PSCustomObject]@{
                                Domain = $lastSet.CmdParams.AllowedDomainsAsAList
                            })
                        }
                        
                        return $config
                    } else {
                        return [PSCustomObject]@{
                            Identity            = 'Global'
                            AllowFederatedUsers = $true
                            AllowedDomains      = New-CsEdgeAllowAllKnownDomains
                            BlockedDomains      = @('spam.com')
                            AllowTeamsConsumer  = $false
                        }
                    }
                }
            }

            # Exact UI payload: sends empty string for federationBlockedDomains
            $request = New-EditTeamsRequest -Extra @{
                federationMode              = 'AllowSpecificExternal'
                federationAllowedDomains    = 'trusted.com'
                federationBlockedDomains    = ''
                enableFederationAccess      = $true
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 200
            $setCall = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCall.CmdParams.BlockedDomains | Should -Contain 'spam.com'
        }

        It 'handles exact repro payload: 109 domains comma-separated with empty blocked string' {
            $domains = 1..109 | ForEach-Object { "domain$_.com" }
            $domainString = $domains -join ','

            # Exact repro payload from Freshdesk 3277840
            $request = New-EditTeamsRequest -Extra @{
                federationMode              = 'AllowSpecificExternal'
                federationAllowedDomains    = $domainString
                federationBlockedDomains    = ''
                enableFederationAccess      = $true
                allowTeamsConsumer          = $false
                enableTeamsConsumerAccess   = $false
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 200
            $setCall = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCall.CmdParams.AllowedDomainsAsAList.Count | Should -Be 109
        }

        It 'handles federationMode as object (retry payload)' {
            # Retry payload: federationMode as object
            $request = New-EditTeamsRequest -Extra @{
                federationMode              = @{ label = 'Allow specific external domains'; value = 'AllowSpecificExternal' }
                federationAllowedDomains    = 'a.com,b.com,c.com'
                federationBlockedDomains    = ''
                enableFederationAccess      = $true
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 200
            $setCall = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCall.CmdParams.AllowedDomainsAsAList.Count | Should -Be 3
        }

        It 'preserves BlockedDomains when missing field in AllowSpecificExternal' {
            Mock New-TeamsRequest {
                param($TenantFilter, $Cmdlet, $CmdParams)
                
                $script:teamsRequests += [PSCustomObject]@{
                    TenantFilter = $TenantFilter
                    Cmdlet       = $Cmdlet
                    CmdParams    = $CmdParams
                }
                
                if ($Cmdlet -eq 'Get-CsTenantFederationConfiguration') {
                    $lastSet = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' } | Select-Object -Last 1
                    
                    if ($lastSet) {
                        $config = [PSCustomObject]@{
                            Identity            = 'Global'
                            AllowFederatedUsers = $lastSet.CmdParams.AllowFederatedUsers
                            AllowTeamsConsumer  = $false
                            BlockedDomains      = $lastSet.CmdParams.BlockedDomains
                        }
                        
                        if ($lastSet.CmdParams.AllowedDomainsAsAList) {
                            $config | Add-Member -NotePropertyName 'AllowedDomains' -NotePropertyValue ([PSCustomObject]@{
                                Domain = $lastSet.CmdParams.AllowedDomainsAsAList
                            })
                        }
                        
                        return $config
                    } else {
                        return [PSCustomObject]@{
                            Identity            = 'Global'
                            AllowFederatedUsers = $true
                            AllowedDomains      = New-CsEdgeAllowAllKnownDomains
                            BlockedDomains      = @('spam.com')
                            AllowTeamsConsumer  = $false
                        }
                    }
                }
            }

            $request = New-EditTeamsRequest -Extra @{
                federationMode           = 'AllowSpecificExternal'
                federationAllowedDomains = 'trusted.com'
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 200
            $setCall = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCall.CmdParams.BlockedDomains | Should -Contain 'spam.com'
        }

        It 'preserves BlockedDomains when null in AllowSpecificExternal' {
            Mock New-TeamsRequest {
                param($TenantFilter, $Cmdlet, $CmdParams)
                
                $script:teamsRequests += [PSCustomObject]@{
                    TenantFilter = $TenantFilter
                    Cmdlet       = $Cmdlet
                    CmdParams    = $CmdParams
                }
                
                if ($Cmdlet -eq 'Get-CsTenantFederationConfiguration') {
                    $lastSet = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' } | Select-Object -Last 1
                    
                    if ($lastSet) {
                        $config = [PSCustomObject]@{
                            Identity            = 'Global'
                            AllowFederatedUsers = $lastSet.CmdParams.AllowFederatedUsers
                            AllowTeamsConsumer  = $false
                            BlockedDomains      = $lastSet.CmdParams.BlockedDomains
                        }
                        
                        if ($lastSet.CmdParams.AllowedDomainsAsAList) {
                            $config | Add-Member -NotePropertyName 'AllowedDomains' -NotePropertyValue ([PSCustomObject]@{
                                Domain = $lastSet.CmdParams.AllowedDomainsAsAList
                            })
                        }
                        
                        return $config
                    } else {
                        return [PSCustomObject]@{
                            Identity            = 'Global'
                            AllowFederatedUsers = $true
                            AllowedDomains      = New-CsEdgeAllowAllKnownDomains
                            BlockedDomains      = @('spam.com', 'malware.net')
                            AllowTeamsConsumer  = $false
                        }
                    }
                }
            }

            $request = New-EditTeamsRequest -Extra @{
                federationMode              = 'AllowSpecificExternal'
                federationAllowedDomains    = 'trusted.com'
                federationBlockedDomains    = $null
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 200
            $setCall = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCall.CmdParams.BlockedDomains | Should -Contain 'spam.com'
            $setCall.CmdParams.BlockedDomains | Should -Contain 'malware.net'
        }

        It 'preserves BlockedDomains when missing field in BlockSpecificExternal' {
            Mock New-TeamsRequest {
                param($TenantFilter, $Cmdlet, $CmdParams)
                
                $script:teamsRequests += [PSCustomObject]@{
                    TenantFilter = $TenantFilter
                    Cmdlet       = $Cmdlet
                    CmdParams    = $CmdParams
                }
                
                if ($Cmdlet -eq 'Get-CsTenantFederationConfiguration') {
                    $lastSet = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' } | Select-Object -Last 1
                    
                    if ($lastSet) {
                        return [PSCustomObject]@{
                            Identity            = 'Global'
                            AllowFederatedUsers = $lastSet.CmdParams.AllowFederatedUsers
                            AllowedDomains      = New-CsEdgeAllowAllKnownDomains
                            BlockedDomains      = $lastSet.CmdParams.BlockedDomains
                            AllowTeamsConsumer  = $false
                        }
                    } else {
                        return [PSCustomObject]@{
                            Identity            = 'Global'
                            AllowFederatedUsers = $true
                            AllowedDomains      = New-CsEdgeAllowAllKnownDomains
                            BlockedDomains      = @('block1.com', 'block2.org')
                            AllowTeamsConsumer  = $false
                        }
                    }
                }
            }

            $request = New-EditTeamsRequest -Extra @{
                federationMode = 'BlockSpecificExternal'
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 200
            $setCall = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCall.CmdParams.BlockedDomains | Should -Contain 'block1.com'
            $setCall.CmdParams.BlockedDomains | Should -Contain 'block2.org'
        }

        It 'preserves BlockedDomains when null in BlockSpecificExternal' {
            Mock New-TeamsRequest {
                param($TenantFilter, $Cmdlet, $CmdParams)
                
                $script:teamsRequests += [PSCustomObject]@{
                    TenantFilter = $TenantFilter
                    Cmdlet       = $Cmdlet
                    CmdParams    = $CmdParams
                }
                
                if ($Cmdlet -eq 'Get-CsTenantFederationConfiguration') {
                    $lastSet = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' } | Select-Object -Last 1
                    
                    if ($lastSet) {
                        return [PSCustomObject]@{
                            Identity            = 'Global'
                            AllowFederatedUsers = $lastSet.CmdParams.AllowFederatedUsers
                            AllowedDomains      = New-CsEdgeAllowAllKnownDomains
                            BlockedDomains      = $lastSet.CmdParams.BlockedDomains
                            AllowTeamsConsumer  = $false
                        }
                    } else {
                        return [PSCustomObject]@{
                            Identity            = 'Global'
                            AllowFederatedUsers = $true
                            AllowedDomains      = New-CsEdgeAllowAllKnownDomains
                            BlockedDomains      = @('bad.com')
                            AllowTeamsConsumer  = $false
                        }
                    }
                }
            }

            $request = New-EditTeamsRequest -Extra @{
                federationMode              = 'BlockSpecificExternal'
                federationBlockedDomains    = $null
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 200
            $setCall = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCall.CmdParams.BlockedDomains | Should -Contain 'bad.com'
        }

        It 'preserves BlockedDomains when empty string in BlockSpecificExternal' {
            Mock New-TeamsRequest {
                param($TenantFilter, $Cmdlet, $CmdParams)
                
                $script:teamsRequests += [PSCustomObject]@{
                    TenantFilter = $TenantFilter
                    Cmdlet       = $Cmdlet
                    CmdParams    = $CmdParams
                }
                
                if ($Cmdlet -eq 'Get-CsTenantFederationConfiguration') {
                    $lastSet = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' } | Select-Object -Last 1
                    
                    if ($lastSet) {
                        return [PSCustomObject]@{
                            Identity            = 'Global'
                            AllowFederatedUsers = $lastSet.CmdParams.AllowFederatedUsers
                            AllowedDomains      = New-CsEdgeAllowAllKnownDomains
                            BlockedDomains      = $lastSet.CmdParams.BlockedDomains
                            AllowTeamsConsumer  = $false
                        }
                    } else {
                        return [PSCustomObject]@{
                            Identity            = 'Global'
                            AllowFederatedUsers = $true
                            AllowedDomains      = New-CsEdgeAllowAllKnownDomains
                            BlockedDomains      = @('existing-block.com')
                            AllowTeamsConsumer  = $false
                        }
                    }
                }
            }

            $request = New-EditTeamsRequest -Extra @{
                federationMode              = 'BlockSpecificExternal'
                federationBlockedDomains    = ''
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 200
            $setCall = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCall.CmdParams.BlockedDomains | Should -Contain 'existing-block.com'
        }

        It 'clears BlockedDomains when empty array sent explicitly' {
            Mock New-TeamsRequest {
                param($TenantFilter, $Cmdlet, $CmdParams)
                
                $script:teamsRequests += [PSCustomObject]@{
                    TenantFilter = $TenantFilter
                    Cmdlet       = $Cmdlet
                    CmdParams    = $CmdParams
                }
                
                if ($Cmdlet -eq 'Get-CsTenantFederationConfiguration') {
                    $lastSet = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' } | Select-Object -Last 1
                    
                    if ($lastSet) {
                        return [PSCustomObject]@{
                            Identity            = 'Global'
                            AllowFederatedUsers = $lastSet.CmdParams.AllowFederatedUsers
                            AllowedDomains      = if ($lastSet.CmdParams.AllowedDomainsAsAList) {
                                [PSCustomObject]@{ Domain = $lastSet.CmdParams.AllowedDomainsAsAList }
                            } else {
                                New-CsEdgeAllowAllKnownDomains
                            }
                            BlockedDomains      = $lastSet.CmdParams.BlockedDomains
                            AllowTeamsConsumer  = $false
                        }
                    } else {
                        return [PSCustomObject]@{
                            Identity            = 'Global'
                            AllowFederatedUsers = $true
                            AllowedDomains      = New-CsEdgeAllowAllKnownDomains
                            BlockedDomains      = @('should-be-cleared.com')
                            AllowTeamsConsumer  = $false
                        }
                    }
                }
            }

            $request = New-EditTeamsRequest -Extra @{
                federationMode              = 'AllowSpecificExternal'
                federationAllowedDomains    = 'trusted.com'
                federationBlockedDomains    = @()
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 200
            $setCall = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCall.CmdParams.BlockedDomains.Count | Should -Be 0
        }

        It 'handles BlockAllExternal with existing BlockedDomains without false 502' {
            Mock New-TeamsRequest {
                param($TenantFilter, $Cmdlet, $CmdParams)
                
                $script:teamsRequests += [PSCustomObject]@{
                    TenantFilter = $TenantFilter
                    Cmdlet       = $Cmdlet
                    CmdParams    = $CmdParams
                }
                
                if ($Cmdlet -eq 'Get-CsTenantFederationConfiguration') {
                    $lastSet = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' } | Select-Object -Last 1
                    
                    if ($lastSet) {
                        return [PSCustomObject]@{
                            Identity            = 'Global'
                            AllowFederatedUsers = $lastSet.CmdParams.AllowFederatedUsers
                            AllowedDomains      = New-CsEdgeAllowAllKnownDomains
                            BlockedDomains      = $lastSet.CmdParams.BlockedDomains
                            AllowTeamsConsumer  = $false
                        }
                    } else {
                        return [PSCustomObject]@{
                            Identity            = 'Global'
                            AllowFederatedUsers = $true
                            AllowedDomains      = New-CsEdgeAllowAllKnownDomains
                            BlockedDomains      = @('old-block.com')
                            AllowTeamsConsumer  = $false
                        }
                    }
                }
            }

            $request = New-EditTeamsRequest -Extra @{
                federationMode = 'BlockAllExternal'
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 200
            $result.Body.Results | Should -Not -Match 'verification failed'
        }
    }
}

Describe 'Invoke-EditTeamsSettings Verification Failure' {
    BeforeEach {
        $script:teamsRequests = @()
    }

    It 'returns 502 when AllowFederatedUsers verification fails' {
        Mock New-TeamsRequest {
            param($TenantFilter, $Cmdlet, $CmdParams)
            
            $script:teamsRequests += [PSCustomObject]@{
                TenantFilter = $TenantFilter
                Cmdlet       = $Cmdlet
                CmdParams    = $CmdParams
            }
            
            if ($Cmdlet -eq 'Get-CsTenantFederationConfiguration') {
                # First Get returns default, second returns wrong value
                $getCalls = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Get-CsTenantFederationConfiguration' }
                if ($getCalls.Count -le 1) {
                    return [PSCustomObject]@{
                        Identity            = 'Global'
                        AllowFederatedUsers = $true
                        AllowedDomains      = New-CsEdgeAllowAllKnownDomains
                        BlockedDomains      = @()
                    }
                } else {
                    return [PSCustomObject]@{
                        Identity            = 'Global'
                        AllowFederatedUsers = $false
                        AllowedDomains      = New-CsEdgeAllowAllKnownDomains
                        BlockedDomains      = @()
                    }
                }
            }
        }

        $request = New-EditTeamsRequest -Extra @{
            federationMode           = 'AllowSpecificExternal'
            federationAllowedDomains = 'test.com'
        }

        $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

        $result.StatusCode | Should -Be 502
        $result.Body.Results | Should -Match 'verification failed'
    }

    It 'returns 502 when AllowedDomains count verification fails' {
        Mock New-TeamsRequest {
            param($TenantFilter, $Cmdlet, $CmdParams)
            
            $script:teamsRequests += [PSCustomObject]@{
                TenantFilter = $TenantFilter
                Cmdlet       = $Cmdlet
                CmdParams    = $CmdParams
            }
            
            if ($Cmdlet -eq 'Get-CsTenantFederationConfiguration') {
                # First Get returns default, second returns empty allowed domains
                $getCalls = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Get-CsTenantFederationConfiguration' }
                if ($getCalls.Count -le 1) {
                    return [PSCustomObject]@{
                        Identity            = 'Global'
                        AllowFederatedUsers = $true
                        AllowedDomains      = New-CsEdgeAllowAllKnownDomains
                        BlockedDomains      = @()
                    }
                } else {
                    # Return config with wrong domain count (silently didn't apply)
                    return [PSCustomObject]@{
                        Identity            = 'Global'
                        AllowFederatedUsers = $true
                        AllowedDomains      = New-CsEdgeAllowAllKnownDomains
                        BlockedDomains      = @()
                    }
                }
            }
        }

        $request = New-EditTeamsRequest -Extra @{
            federationMode           = 'AllowSpecificExternal'
            federationAllowedDomains = 'domain1.com,domain2.com'
        }

        $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

        $result.StatusCode | Should -Be 502
        $result.Body.Results | Should -Match 'verification failed'
    }

    It 'returns 502 when AllowedDomains have same count but different domains' {
        Mock New-TeamsRequest {
            param($TenantFilter, $Cmdlet, $CmdParams)
            
            $script:teamsRequests += [PSCustomObject]@{
                TenantFilter = $TenantFilter
                Cmdlet       = $Cmdlet
                CmdParams    = $CmdParams
            }
            
            if ($Cmdlet -eq 'Get-CsTenantFederationConfiguration') {
                $getCalls = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Get-CsTenantFederationConfiguration' }
                if ($getCalls.Count -le 1) {
                    return [PSCustomObject]@{
                        Identity            = 'Global'
                        AllowFederatedUsers = $true
                        AllowedDomains      = New-CsEdgeAllowAllKnownDomains
                        BlockedDomains      = @()
                    }
                } else {
                    # Return different domains with same count
                    $config = [PSCustomObject]@{
                        Identity            = 'Global'
                        AllowFederatedUsers = $true
                        BlockedDomains      = @()
                    }
                    $config | Add-Member -NotePropertyName 'AllowedDomains' -NotePropertyValue ([PSCustomObject]@{
                        Domain = @('wrong1.com', 'wrong2.com')
                    })
                    return $config
                }
            }
        }

        $request = New-EditTeamsRequest -Extra @{
            federationMode           = 'AllowSpecificExternal'
            federationAllowedDomains = 'right1.com,right2.com'
        }

        $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

        $result.StatusCode | Should -Be 502
        $result.Body.Results | Should -Match 'verification failed'
    }

    It 'returns 502 when AllowTeamsConsumer verification fails' {
        Mock New-TeamsRequest {
            param($TenantFilter, $Cmdlet, $CmdParams)
            
            $script:teamsRequests += [PSCustomObject]@{
                TenantFilter = $TenantFilter
                Cmdlet       = $Cmdlet
                CmdParams    = $CmdParams
            }
            
            if ($Cmdlet -eq 'Get-CsTenantFederationConfiguration') {
                $getCalls = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Get-CsTenantFederationConfiguration' }
                if ($getCalls.Count -le 1) {
                    return [PSCustomObject]@{
                        Identity            = 'Global'
                        AllowFederatedUsers = $true
                        AllowedDomains      = New-CsEdgeAllowAllKnownDomains
                        BlockedDomains      = @()
                        AllowTeamsConsumer  = $true
                    }
                } else {
                    # Return wrong AllowTeamsConsumer value
                    $config = [PSCustomObject]@{
                        Identity            = 'Global'
                        AllowFederatedUsers = $true
                        AllowTeamsConsumer  = $true
                        BlockedDomains      = @()
                    }
                    $config | Add-Member -NotePropertyName 'AllowedDomains' -NotePropertyValue ([PSCustomObject]@{
                        Domain = @('test.com')
                    })
                    return $config
                }
            }
        }

        $request = New-EditTeamsRequest -Extra @{
            federationMode           = 'AllowSpecificExternal'
            federationAllowedDomains = 'test.com'
            allowTeamsConsumer       = $false
        }

        $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

        $result.StatusCode | Should -Be 502
        $result.Body.Results | Should -Match 'verification failed'
    }
}

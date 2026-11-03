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
                    AllowFederatedUsers = $lastSet.CmdParams.AllowFederatedUsers
                    AllowTeamsConsumer  = $lastSet.CmdParams.AllowTeamsConsumer
                    BlockedDomains      = $lastSet.CmdParams.BlockedDomains
                }
                
                if ($lastSet.CmdParams.AllowedDomainsAsAList) {
                    $config | Add-Member -NotePropertyName 'AllowedDomains' -NotePropertyValue ([PSCustomObject]@{
                        Domain = $lastSet.CmdParams.AllowedDomainsAsAList
                    })
                } else {
                    $config | Add-Member -NotePropertyName 'AllowedDomains' -NotePropertyValue $lastSet.CmdParams.AllowedDomains
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

            $result.StatusCode | Should -Be 200
            $setCall = $script:teamsRequests | Where-Object { $_.Cmdlet -eq 'Set-CsTenantFederationConfiguration' }
            $setCall.CmdParams.AllowedDomainsAsAList | Should -Contain 'valid.com'
            $setCall.CmdParams.AllowedDomainsAsAList | Should -Contain 'also-valid.org'
            $setCall.CmdParams.AllowedDomainsAsAList | Should -Not -Contain 'invalid..com'
            $setCall.CmdParams.AllowedDomainsAsAList | Should -Not -Contain 'not@valid.com'
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

        It 'requires at least one domain for AllowSpecificExternal' {
            $request = New-EditTeamsRequest -Extra @{
                federationMode           = 'AllowSpecificExternal'
                federationAllowedDomains = ''
                enableFederationAccess   = $true
            }

            $result = Invoke-EditTeamsSettings -Request $request -TriggerMetadata $null

            $result.StatusCode | Should -Be 400
            $result.Body.Results | Should -Match 'requires at least one allowed domain'
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
    }
}

Describe 'Invoke-EditTeamsSettings Verification Failure' {
    BeforeEach {
        $script:teamsRequests = @()
    }

    It 'returns error when AllowFederatedUsers verification fails' {
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

        $result.StatusCode | Should -Be 400
        $result.Body.Results | Should -Match 'verification failed'
        $result.Body.Results | Should -Match 'AllowFederatedUsers'
    }

    It 'returns error when AllowedDomains count verification fails' {
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

        $result.StatusCode | Should -Be 400
        $result.Body.Results | Should -Match 'verification failed'
        $result.Body.Results | Should -Match 'AllowedDomains count'
    }

    It 'returns error when AllowTeamsConsumer verification fails' {
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

        $result.StatusCode | Should -Be 400
        $result.Body.Results | Should -Match 'verification failed'
        $result.Body.Results | Should -Match 'AllowTeamsConsumer'
    }
}

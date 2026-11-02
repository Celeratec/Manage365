BeforeAll {
    # Load cipp-roles.json to verify editor and readonly roles exclude Exchange.SecurityPolicy.ReadWrite
    $RolesConfigPath = Join-Path $PSScriptRoot '../..' 'Config/cipp-roles.json'
    $RolesConfig = Get-Content $RolesConfigPath -Raw | ConvertFrom-Json
    
    # Endpoints that should have Exchange.SecurityPolicy.ReadWrite
    $SecurityPolicyEndpoints = @(
        'backend/Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Transport/Invoke-ExecEnhancedFiltering.ps1'
        'backend/Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-ExecRemoveAntiSpamPolicy.ps1'
        'backend/Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-ExecRemoveAntiPhishPolicy.ps1'
        'backend/Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-ExecRemoveAntiMalwarePolicy.ps1'
        'backend/Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-ExecDisableDefenderPresetPolicy.ps1'
        'backend/Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-ExecRescopeDefenderPresetPolicy.ps1'
    )
}

Describe 'SecurityPolicy Endpoint RBAC Tests' {
    Context 'Role Configuration (cipp-roles.json)' {
        It 'editor role should exclude Exchange.SecurityPolicy.ReadWrite (via wildcard or explicit)' {
            $EditorRole = $RolesConfig.editor
            $EditorRole | Should -Not -BeNullOrEmpty
            # Check if excluded directly or via wildcard pattern
            $Excluded = $false
            if ($EditorRole.exclude -contains 'Exchange.SecurityPolicy.ReadWrite') {
                $Excluded = $true
            } else {
                foreach ($Pattern in $EditorRole.exclude) {
                    # Convert glob-style wildcard to regex
                    $RegexPattern = '^' + [regex]::Escape($Pattern).Replace('\*', '.*').Replace('\?', '.') + '$'
                    if ('Exchange.SecurityPolicy.ReadWrite' -match $RegexPattern) {
                        $Excluded = $true
                        break
                    }
                }
            }
            $Excluded | Should -Be $true -Because "editor role must exclude Exchange.SecurityPolicy.ReadWrite"
        }
        
        It 'readonly role should deny Exchange.SecurityPolicy.ReadWrite (not included)' {
            $ReadonlyRole = $RolesConfig.readonly
            $ReadonlyRole | Should -Not -BeNullOrEmpty
            # Check include - readonly only has *.Read which should NOT match *.ReadWrite
            $Included = $false
            foreach ($Pattern in $ReadonlyRole.include) {
                $RegexPattern = '^' + [regex]::Escape($Pattern).Replace('\*', '.*').Replace('\?', '.') + '$'
                if ('Exchange.SecurityPolicy.ReadWrite' -match $RegexPattern) {
                    $Included = $true
                    break
                }
            }
            $Included | Should -Be $false -Because "readonly role must deny Exchange.SecurityPolicy.ReadWrite (not in includes)"
        }
        
        It 'editor role should deny Exchange.SecurityPolicy.ReadWrite (exclude overrides include)' {
            $EditorRole = $RolesConfig.editor
            # Check include first
            $Included = $false
            foreach ($Pattern in $EditorRole.include) {
                $RegexPattern = '^' + [regex]::Escape($Pattern).Replace('\*', '.*').Replace('\?', '.') + '$'
                if ('Exchange.SecurityPolicy.ReadWrite' -match $RegexPattern) {
                    $Included = $true
                    break
                }
            }
            # Then check exclude (overrides include)
            $Excluded = $false
            foreach ($Pattern in $EditorRole.exclude) {
                $RegexPattern = '^' + [regex]::Escape($Pattern).Replace('\*', '.*').Replace('\?', '.') + '$'
                if ('Exchange.SecurityPolicy.ReadWrite' -match $RegexPattern) {
                    $Excluded = $true
                    break
                }
            }
            # Final result: if excluded, access is denied even if included
            $FinalAllowed = $Included -and (-not $Excluded)
            $FinalAllowed | Should -Be $false -Because "editor role must deny Exchange.SecurityPolicy.ReadWrite (exclude wins)"
        }
        
        It 'readonly role should not include Exchange.SecurityPolicy.ReadWrite (via wildcard or explicit)' {
            $ReadonlyRole = $RolesConfig.readonly
            $Included = $false
            if ($ReadonlyRole.include -contains 'Exchange.SecurityPolicy.ReadWrite') {
                $Included = $true
            } else {
                foreach ($Pattern in $ReadonlyRole.include) {
                    # Convert glob-style wildcard to regex
                    $RegexPattern = '^' + [regex]::Escape($Pattern).Replace('\*', '.*').Replace('\?', '.') + '$'
                    if ('Exchange.SecurityPolicy.ReadWrite' -match $RegexPattern) {
                        $Included = $true
                        break
                    }
                }
            }
            $Included | Should -Be $false -Because "readonly role must not include Exchange.SecurityPolicy.ReadWrite"
        }
    }
    
    Context 'Endpoint .ROLE Directives' {
        It '<EndpointFile> should have .ROLE Exchange.SecurityPolicy.ReadWrite' -TestCases @(
            @{ EndpointFile = 'Invoke-ExecEnhancedFiltering.ps1' }
            @{ EndpointFile = 'Invoke-ExecRemoveAntiSpamPolicy.ps1' }
            @{ EndpointFile = 'Invoke-ExecRemoveAntiPhishPolicy.ps1' }
            @{ EndpointFile = 'Invoke-ExecRemoveAntiMalwarePolicy.ps1' }
            @{ EndpointFile = 'Invoke-ExecDisableDefenderPresetPolicy.ps1' }
            @{ EndpointFile = 'Invoke-ExecRescopeDefenderPresetPolicy.ps1' }
        ) {
            param($EndpointFile)
            
            $FullPath = $SecurityPolicyEndpoints | Where-Object { $_ -match $EndpointFile } | Select-Object -First 1
            $FullPath | Should -Not -BeNullOrEmpty
            
            $ResolvedPath = Join-Path $PSScriptRoot '../..' $FullPath.Replace('backend/', '')
            Test-Path $ResolvedPath | Should -Be $true -Because "Endpoint file should exist: $ResolvedPath"
            
            $Content = Get-Content $ResolvedPath -Raw
            $Content | Should -Match '\.ROLE\s+Exchange\.SecurityPolicy\.ReadWrite' -Because "$EndpointFile should declare Exchange.SecurityPolicy.ReadWrite role"
        }
    }
    
    Context 'SpamFilter.ReadWrite Endpoints' {
        It '<EndpointFile> should have .ROLE Exchange.SpamFilter.ReadWrite' -TestCases @(
            @{ EndpointFile = 'Invoke-ExecAntiSpamPolicy.ps1' }
            @{ EndpointFile = 'Invoke-ExecAntiPhishPolicy.ps1' }
            @{ EndpointFile = 'Invoke-ExecAntiMalwarePolicy.ps1' }
            @{ EndpointFile = 'Invoke-ExecDefenderPresetPolicy.ps1' }
        ) {
            param($EndpointFile)
            
            $FullPath = Join-Path $PSScriptRoot '../../Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter' $EndpointFile
            Test-Path $FullPath | Should -Be $true -Because "Endpoint file should exist: $FullPath"
            
            $Content = Get-Content $FullPath -Raw
            $Content | Should -Match '\.ROLE\s+Exchange\.SpamFilter\.ReadWrite' -Because "$EndpointFile should declare Exchange.SpamFilter.ReadWrite role"
        }
        
        It 'editor role should include Exchange.SpamFilter.ReadWrite (via wildcard or explicit)' {
            $EditorRole = $RolesConfig.editor
            $EditorRole | Should -Not -BeNullOrEmpty
            # Check if included directly or via wildcard
            $Included = $false
            if ($EditorRole.include -contains 'Exchange.SpamFilter.ReadWrite') {
                $Included = $true
            } else {
                foreach ($Pattern in $EditorRole.include) {
                    # Convert glob-style wildcard to regex
                    $RegexPattern = '^' + [regex]::Escape($Pattern).Replace('\*', '.*').Replace('\?', '.') + '$'
                    if ('Exchange.SpamFilter.ReadWrite' -match $RegexPattern) {
                        $Included = $true
                        break
                    }
                }
            }
            $Included | Should -Be $true -Because "editor role should grant SpamFilter.ReadWrite"
        }
    }

    Context 'Real Test-CIPPAccess Integration' {
        BeforeAll {
            # Set up environment for Test-CIPPAccess
            $env:CIPPRootPath = Join-Path $PSScriptRoot '../..'
            
            # Load the REAL Test-CIPPAccess function
            $TestCIPPAccessPath = Join-Path $PSScriptRoot '../../Modules/CIPPCore/Public/Authentication/Test-CIPPAccess.ps1'
            . $TestCIPPAccessPath
            
            # Load endpoint functions so Get-Help can read their .ROLE directives
            $ExecEnhancedFilteringPath = Join-Path $PSScriptRoot '../../Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Transport/Invoke-ExecEnhancedFiltering.ps1'
            $ExecRemoveAntiSpamPath = Join-Path $PSScriptRoot '../../Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Spamfilter/Invoke-ExecRemoveAntiSpamPolicy.ps1'
            . $ExecEnhancedFilteringPath
            . $ExecRemoveAntiSpamPath
        }

        It 'editor role is denied access to ExecEnhancedFiltering (SecurityPolicy endpoint)' {
            $Request = [pscustomobject]@{
                Headers = @{
                    Roles = 'editor'
                    'x-ms-client-principal-idp' = 'aad'
                    'x-ms-client-principal-name' = 'test@example.com'
                }
                Params = @{
                    CIPPEndpoint = 'ExecEnhancedFiltering'
                }
            }
            
            $Result = Test-CIPPAccess -Request $Request
            $Result | Should -Be $false -Because "editor role must not have Exchange.SecurityPolicy.ReadWrite access"
        }

        It 'readonly role is denied access to ExecRemoveAntiSpamPolicy (SecurityPolicy endpoint)' {
            $Request = [pscustomobject]@{
                Headers = @{
                    Roles = 'readonly'
                    'x-ms-client-principal-idp' = 'aad'
                    'x-ms-client-principal-name' = 'test@example.com'
                }
                Params = @{
                    CIPPEndpoint = 'ExecRemoveAntiSpamPolicy'
                }
            }
            
            $Result = Test-CIPPAccess -Request $Request
            $Result | Should -Be $false -Because "readonly role must not have Exchange.SecurityPolicy.ReadWrite access"
        }

        It 'admin role is allowed access to ExecEnhancedFiltering (SecurityPolicy endpoint)' {
            $Request = [pscustomobject]@{
                Headers = @{
                    Roles = 'admin'
                    'x-ms-client-principal-idp' = 'aad'
                    'x-ms-client-principal-name' = 'test@example.com'
                }
                Params = @{
                    CIPPEndpoint = 'ExecEnhancedFiltering'
                }
            }
            
            $Result = Test-CIPPAccess -Request $Request
            $Result | Should -Be $true -Because "admin role should have full access including SecurityPolicy"
        }
    }
}

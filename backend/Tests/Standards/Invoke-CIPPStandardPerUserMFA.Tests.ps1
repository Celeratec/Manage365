BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    
    Import-Module (Join-Path $RepoRoot 'Modules/CIPPStandards/CIPPStandards.psd1') -Force
    Import-Module (Join-Path $RepoRoot 'Modules/CIPPCore/CIPPCore.psd1') -Force
    
    Mock Write-LogMessage { } -ModuleName CIPPCore
    Mock Write-LogMessage { } -ModuleName CIPPStandards
    Mock Get-NormalizedError { return "Mocked error" }
    Mock Add-CIPPAzDataTableEntity { } -ModuleName CIPPCore
    Mock Get-CIPPTable { return @{} } -ModuleName CIPPCore
}

Describe 'Invoke-CIPPStandardPerUserMFA' {
    It 'passes object IDs (GUIDs) to Set-CIPPPerUserMFA instead of UPNs' {
        # Mock New-GraphGetRequest to return users with both id and userPrincipalName
        Mock New-GraphGetRequest {
            @(
                [PSCustomObject]@{
                    id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                    userPrincipalName = 'user1@contoso.com'
                    displayName = 'User 1'
                    accountEnabled = $true
                    perUserMfaState = 'disabled'
                }
                [PSCustomObject]@{
                    id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
                    userPrincipalName = 'user2@contoso.com'
                    displayName = 'User 2'
                    accountEnabled = $true
                    perUserMfaState = 'disabled'
                }
            )
        }
        
        # Mock Set-CIPPPerUserMFA and verify it receives GUIDs
        Mock Set-CIPPPerUserMFA {
            # Verify that userId contains GUIDs, not UPNs
            $userId | Should -Not -BeNullOrEmpty
            $userId.Count | Should -Be 2
            foreach ($id in $userId) {
                $id | Should -Not -BeLike '*@*'
                $parsedGuid = [guid]::Empty
                [guid]::TryParse($id, [ref]$parsedGuid) | Should -Be $true
            }
            
            @(
                [PSCustomObject]@{ UserId = $userId[0]; Success = $true; Message = 'Success' }
                [PSCustomObject]@{ UserId = $userId[1]; Success = $true; Message = 'Success' }
            )
        } -ModuleName CIPPStandards
        
        $Settings = @{
            remediate = $true
            report = $false
        }
        
        Invoke-CIPPStandardPerUserMFA -Tenant 'contoso.onmicrosoft.com' -Settings $Settings
        
        Should -Invoke Set-CIPPPerUserMFA -Times 1 -ModuleName CIPPStandards
    }
    
    It 'includes id in Select-Object to preserve it for Set-CIPPPerUserMFA' {
        # Mock New-GraphGetRequest
        Mock New-GraphGetRequest {
            @(
                [PSCustomObject]@{
                    id = 'test-guid'
                    userPrincipalName = 'user@contoso.com'
                    displayName = 'Test User'
                    accountEnabled = $true
                    perUserMfaState = 'disabled'
                }
            )
        }
        
        Mock Set-CIPPPerUserMFA {
            @([PSCustomObject]@{ UserId = 'test-guid'; Success = $true; Message = 'Success' })
        } -ModuleName CIPPStandards
        
        $Settings = @{
            remediate = $true
            report = $false
        }
        
        # Should not throw - id should be available
        { Invoke-CIPPStandardPerUserMFA -Tenant 'contoso.onmicrosoft.com' -Settings $Settings } | Should -Not -Throw
    }
}

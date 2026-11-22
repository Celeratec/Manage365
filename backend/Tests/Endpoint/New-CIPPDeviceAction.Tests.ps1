# Pester tests for the primary-user branches of New-CIPPDeviceAction.
# Removing the primary user is a DELETE on the managed device's users/$ref (what the Intune portal sends).

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Join-Path $RepoRoot 'Modules/CIPPCore/Public/New-CIPPDeviceAction.ps1'

    function New-GraphPOSTRequest { param($uri, $type, $tenantid, $body) }
    function Write-LogMessage { param($headers, $API, $tenant, $message, $Sev, $LogData) }
    function Get-CippException { param($Exception) }
    function Invoke-CIPPMDEOffboard { param($AzureADDeviceId, $TenantFilter) }
    function Test-IsGuid { param([string]$String) return [guid]::TryParse($String, [ref][guid]::Empty) }

    . $FunctionPath
}

Describe 'New-CIPPDeviceAction - removePrimaryUser' {
    BeforeEach {
        Mock -CommandName Write-LogMessage -MockWith { }
        Mock -CommandName New-GraphPOSTRequest -MockWith { }
    }

    It 'sends a DELETE to users/$ref on the managed device' {
        $Result = New-CIPPDeviceAction -Action 'removePrimaryUser' -ActionBody '{"Action":"removePrimaryUser"}' -DeviceFilter 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' -TenantFilter 'contoso.com'

        $Result | Should -Be 'Removed primary user from device aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
        Should -Invoke New-GraphPOSTRequest -Times 1 -Exactly -ParameterFilter {
            $uri -eq "https://graph.microsoft.com/beta/deviceManagement/managedDevices('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee')/users/`$ref" -and
            $type -eq 'DELETE' -and
            $tenantid -eq 'contoso.com'
        }
    }

    It 'throws a failure message when Graph rejects the call' {
        Mock -CommandName New-GraphPOSTRequest -MockWith { throw 'boom' }
        Mock -CommandName Get-CippException -MockWith { [pscustomobject]@{ NormalizedError = 'No primary user' } }

        { New-CIPPDeviceAction -Action 'removePrimaryUser' -DeviceFilter 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' -TenantFilter 'contoso.com' } |
            Should -Throw '*removePrimaryUser*No primary user*'
    }
}

Describe 'New-CIPPDeviceAction - action names' {
    BeforeEach {
        Mock -CommandName Write-LogMessage -MockWith { }
        Mock -CommandName New-GraphPOSTRequest -MockWith { }
        Mock -CommandName Get-CippException -MockWith { [pscustomobject]@{ NormalizedError = "$($Exception.Exception.Message)" } }
    }

    It 'refuses <_> without calling Graph' -ForEach @('deviceCompliancePolicyStates', 'users/$ref', 'logCollectionRequests', 'notARealAction', '') {
        { New-CIPPDeviceAction -Action $_ -DeviceFilter 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' -TenantFilter 'contoso.com' } | Should -Throw
        Should -Invoke New-GraphPOSTRequest -Times 0 -Exactly
    }

    It 'refuses a non-GUID device id without calling Graph' {
        { New-CIPPDeviceAction -Action 'wipe' -DeviceFilter '../users' -TenantFilter 'contoso.com' } | Should -Throw '*GUID*'
        Should -Invoke New-GraphPOSTRequest -Times 0 -Exactly
    }

    It 'queues <_>' -ForEach @(
        'syncDevice', 'rebootNow', 'locateDevice', 'remoteLock', 'setDeviceName', 'RotateLocalAdminPassword', 'WindowsDefenderScan',
        'windowsDefenderUpdateSignatures', 'cleanWindowsDevice', 'wipe', 'retire', 'createDeviceLogCollectionRequest',
        'initiateOnDemandProactiveRemediation'
    ) {
        New-CIPPDeviceAction -Action $_ -DeviceFilter 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' -TenantFilter 'contoso.com' | Should -Be "Queued $_ on aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
        Should -Invoke New-GraphPOSTRequest -Times 1 -Exactly -ParameterFilter {
            $uri -eq "https://graph.microsoft.com/beta/deviceManagement/managedDevices('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee')/$_" -and $type -eq 'POST'
        }
    }
}

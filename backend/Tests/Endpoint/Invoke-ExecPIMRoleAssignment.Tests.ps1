# Pester tests for Invoke-ExecPIMRoleAssignment.
#
# The endpoint is the API/MCP-facing gate for PIM assignment changes. These tests pin its input
# contract: every change needs a justification, any schedule-creating action needs an expiration,
# and a request that spells out permanence ('noExpiration', 'permanent', ...) is refused before
# Invoke-CIPPPIMAssignmentAction is ever called.

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Identity/Administration/Roles/Invoke-ExecPIMRoleAssignment.ps1'
    if (-not (Test-Path $FunctionPath)) { throw "Could not locate Invoke-ExecPIMRoleAssignment.ps1 at $FunctionPath" }

    class HttpResponseContext {
        [object]$StatusCode
        [object]$Body
    }
    $Accelerators = [PSObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')
    if (-not ('HttpStatusCode' -as [type])) {
        $Accelerators::Add('HttpStatusCode', [System.Net.HttpStatusCode])
    }

    function Invoke-CIPPPIMAssignmentAction { param($TenantFilter, $Action, $PrincipalId, $RoleDefinitionId, $DirectoryScopeId, $AssignmentType, $Duration, $EndDateTime, $StartDateTime, $Justification, $TimeZone, $Headers, $APIName) }
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/PIM/Get-CIPPMaxRoleAssignmentDuration.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/GraphHelper/Get-CIPPGraphErrorMessage.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/PIM/New-CIPPPIMScheduleRequest.ps1')
    function Write-LogMessage { param($headers, $API, $tenant, $message, $Sev, $LogData) }
    function Get-CippException { param($Exception) @{ NormalizedError = "$Exception" } }

    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/Get-CippErrorStatusCode.ps1')
    . $FunctionPath

    function New-PimRequest {
        param([hashtable]$Body = @{})
        $RequestBody = [pscustomobject]@{
            tenantFilter     = 'contoso.onmicrosoft.com'
            Action           = 'GrantActive'
            PrincipalId      = 'user-guid'
            RoleDefinitionId = '62e90394-69f5-4237-9190-012177145e10'
            DirectoryScopeId = '/'
            AssignmentType   = 'Eligible'
            Duration         = 'PT4H'
            Justification    = 'Ticket 42'
        }
        foreach ($Key in $Body.Keys) {
            if ($null -eq $Body[$Key]) { $RequestBody.PSObject.Properties.Remove($Key) }
            else { $RequestBody | Add-Member -NotePropertyName $Key -NotePropertyValue $Body[$Key] -Force }
        }
        [pscustomobject]@{
            Body    = $RequestBody
            Headers = @{}
            Params  = @{ CIPPEndpoint = 'ExecPIMRoleAssignment' }
        }
    }
}

Describe 'Invoke-ExecPIMRoleAssignment' {
    BeforeEach {
        Mock Invoke-CIPPPIMAssignmentAction { [pscustomobject]@{ resultText = 'done'; state = 'success' } }
        Mock Write-LogMessage {}
    }

    Context 'time zone for the result wording' {
        It 'passes the browser time zone through, and leaves it out when the request has none' {
            $null = Invoke-ExecPIMRoleAssignment -Request (New-PimRequest -Body @{ TimeZone = 'Australia/Perth' }) -TriggerMetadata $null
            Should -Invoke Invoke-CIPPPIMAssignmentAction -Times 1 -Exactly -ParameterFilter { $TimeZone -eq 'Australia/Perth' -and $Duration -eq 'PT4H' }
            $null = Invoke-ExecPIMRoleAssignment -Request (New-PimRequest) -TriggerMetadata $null
            Should -Invoke Invoke-CIPPPIMAssignmentAction -Times 1 -Exactly -ParameterFilter { [string]::IsNullOrEmpty($TimeZone) }
        }
    }

    Context 'input validation (nothing reaches PIM)' {
        It 'returns 400 when required fields are missing' {
            $Response = Invoke-ExecPIMRoleAssignment -Request (New-PimRequest @{ PrincipalId = $null })
            $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
            $Response.Body.Results[0].resultText | Should -Match 'required'
            Should -Invoke Invoke-CIPPPIMAssignmentAction -Times 0 -Exactly
        }

        It 'returns 400 for an unknown action' {
            $Response = Invoke-ExecPIMRoleAssignment -Request (New-PimRequest @{ Action = 'MakePermanent' })
            $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
            $Response.Body.Results[0].resultText | Should -Match 'not supported'
            Should -Invoke Invoke-CIPPPIMAssignmentAction -Times 0 -Exactly
        }

        It 'returns 400 without a justification' {
            $Response = Invoke-ExecPIMRoleAssignment -Request (New-PimRequest @{ Justification = '' })
            $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
            $Response.Body.Results[0].resultText | Should -Match 'justification'
            Should -Invoke Invoke-CIPPPIMAssignmentAction -Times 0 -Exactly
        }

        It 'refuses a duration that asks for permanence: <_>' -ForEach @('noExpiration', 'permanent', 'never', 'unlimited') {
            $Response = Invoke-ExecPIMRoleAssignment -Request (New-PimRequest @{ Duration = $_ })
            $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
            $Response.Body.Results[0].resultText | Should -Match 'Permanent \(no-expiration\) assignments cannot be created'
            Should -Invoke Invoke-CIPPPIMAssignmentAction -Times 0 -Exactly
        }

        It 'refuses an end date that asks for permanence' {
            $Response = Invoke-ExecPIMRoleAssignment -Request (New-PimRequest @{ Duration = $null; EndDateTime = 'noExpiration' })
            $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
            Should -Invoke Invoke-CIPPPIMAssignmentAction -Times 0 -Exactly
        }

        It 'requires an expiration for <_>' -ForEach @('GrantActive', 'Extend', 'Renew') {
            $Response = Invoke-ExecPIMRoleAssignment -Request (New-PimRequest @{ Action = $_; Duration = $null })
            $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
            $Response.Body.Results[0].resultText | Should -Match 'requires a Duration or an EndDateTime'
            Should -Invoke Invoke-CIPPPIMAssignmentAction -Times 0 -Exactly
        }

        It 'rejects Duration and EndDateTime together' {
            $Response = Invoke-ExecPIMRoleAssignment -Request (New-PimRequest @{ EndDateTime = '2099-01-01T00:00:00Z' })
            $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
            $Response.Body.Results[0].resultText | Should -Match 'not both'
        }

        It 'rejects an unparseable end date' {
            $Response = Invoke-ExecPIMRoleAssignment -Request (New-PimRequest @{ Duration = $null; EndDateTime = 'next tuesday' })
            $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
            $Response.Body.Results[0].resultText | Should -Match 'not a valid date'
        }
    }

    Context 'forwarding to Invoke-CIPPPIMAssignmentAction' {
        It 'passes the duration, scope, type and justification through' {
            $Response = Invoke-ExecPIMRoleAssignment -Request (New-PimRequest)
            $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
            $Response.Body.Results[0].state | Should -Be 'success'
            Should -Invoke Invoke-CIPPPIMAssignmentAction -Times 1 -Exactly -ParameterFilter {
                $Action -eq 'GrantActive' -and $Duration -eq 'PT4H' -and $DirectoryScopeId -eq '/' -and $AssignmentType -eq 'Eligible' -and $Justification -eq 'Ticket 42' -and $null -eq $EndDateTime
            }
        }

        It 'converts a unix-seconds end date to a UTC datetime' {
            $Unix = [System.DateTimeOffset]::UtcNow.AddHours(6).ToUnixTimeSeconds()
            $null = Invoke-ExecPIMRoleAssignment -Request (New-PimRequest @{ Duration = $null; EndDateTime = $Unix })
            Should -Invoke Invoke-CIPPPIMAssignmentAction -Times 1 -Exactly -ParameterFilter {
                $EndDateTime -is [datetime] -and [math]::Abs(($EndDateTime - [datetime]::UtcNow).TotalHours - 6) -lt 0.1
            }
        }

        It 'unwraps label/value objects from the dialog' {
            $Request = New-PimRequest @{
                Action   = [pscustomobject]@{ label = 'Convert to eligible'; value = 'ConvertToEligible' }
                Duration = [pscustomobject]@{ label = '1 year'; value = 'P365D' }
            }
            $null = Invoke-ExecPIMRoleAssignment -Request $Request
            Should -Invoke Invoke-CIPPPIMAssignmentAction -Times 1 -Exactly -ParameterFilter { $Action -eq 'ConvertToEligible' -and $Duration -eq 'P365D' }
        }

        It 'lets Remove through without an expiration' {
            $Response = Invoke-ExecPIMRoleAssignment -Request (New-PimRequest @{ Action = 'Remove'; Duration = $null })
            $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
            Should -Invoke Invoke-CIPPPIMAssignmentAction -Times 1 -Exactly -ParameterFilter { $Action -eq 'Remove' }
        }

        It 'returns 400 with the refusal message when the action refuses' {
            Mock Invoke-CIPPPIMAssignmentAction { throw [System.ArgumentException]::new('Refusing: last active Global Administrator') }
            $Response = Invoke-ExecPIMRoleAssignment -Request (New-PimRequest @{ Action = 'Remove'; Duration = $null })
            $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
            $Response.Body.Results[0].state | Should -Be 'error'
            $Response.Body.Results[0].resultText | Should -Match 'last active Global Administrator'
        }

        It 'returns 500 when the Graph call fails' {
            Mock Invoke-CIPPPIMAssignmentAction { throw 'Graph: InternalServerError' }
            $Response = Invoke-ExecPIMRoleAssignment -Request (New-PimRequest @{ Action = 'Remove'; Duration = $null })
            $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::InternalServerError)
            $Response.Body.Results[0].state | Should -Be 'error'
        }

        It 'forwards <_> for GrantActive' -ForEach @('PT1H', 'P30D', 'P90D', 'P180D', 'P365D') {
            $ExpectedDuration = $_
            $Response = Invoke-ExecPIMRoleAssignment -Request (New-PimRequest @{ Duration = $ExpectedDuration })
            $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
            Should -Invoke Invoke-CIPPPIMAssignmentAction -Times 1 -Exactly -ParameterFilter { $Duration -eq $ExpectedDuration }
        }

        It 'accepts GrantEligible and forwards the duration' {
            $Response = Invoke-ExecPIMRoleAssignment -Request (New-PimRequest @{ Action = 'GrantEligible'; Duration = 'P90D' })
            $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
            Should -Invoke Invoke-CIPPPIMAssignmentAction -Times 1 -Exactly -ParameterFilter { $Action -eq 'GrantEligible' -and $Duration -eq 'P90D' }
        }

        It 'forwards an explicit StartDateTime and EndDateTime pair' {
            $Start = [datetime]::UtcNow.AddHours(1).ToString('o')
            $End = [datetime]::UtcNow.AddDays(30).ToString('o')
            $null = Invoke-ExecPIMRoleAssignment -Request (New-PimRequest @{ Duration = $null; StartDateTime = $Start; EndDateTime = $End })
            Should -Invoke Invoke-CIPPPIMAssignmentAction -Times 1 -Exactly -ParameterFilter {
                $null -eq $Duration -and $null -ne $StartDateTime -and $null -ne $EndDateTime -and ($EndDateTime - $StartDateTime).TotalDays -gt 29
            }
        }

        It 'returns 400 for a duration over 365 days and does not call PIM' {
            $Response = Invoke-ExecPIMRoleAssignment -Request (New-PimRequest @{ Duration = 'P366D' })
            $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
            $Response.Body.Results[0].resultText | Should -Match 'P365D'
            Should -Invoke Invoke-CIPPPIMAssignmentAction -Times 0 -Exactly
        }

        It 'returns 400 for an end date in the past and does not call PIM' {
            $Past = [datetime]::UtcNow.AddHours(-2).ToString('o')
            $Response = Invoke-ExecPIMRoleAssignment -Request (New-PimRequest @{ Duration = $null; EndDateTime = $Past })
            $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
            $Response.Body.Results[0].resultText | Should -Match 'not in the future|in the past'
            Should -Invoke Invoke-CIPPPIMAssignmentAction -Times 0 -Exactly
        }

        It 'returns the Graph policy error instead of a generic token failure' {
            Mock Invoke-CIPPPIMAssignmentAction {
                $Ex = [System.Exception]::new('Response status code does not indicate success: 400 (Bad Request).')
                $Ex.Data['RawErrorBody'] = '{"error":{"code":"RoleAssignmentRequestPolicyValidationFailed","message":"The following policy rules failed: Expiration_Admin_Assignment"}}'
                throw $Ex
            }
            $Response = Invoke-ExecPIMRoleAssignment -Request (New-PimRequest @{ Duration = 'P365D' })
            $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
            $Response.Body.Results[0].resultText | Should -Match 'Expiration_Admin_Assignment'
            $Response.Body.Results[0].resultText | Should -Not -Match 'token configuration'
        }
    }
}

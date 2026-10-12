# The Exchange card and user actions post a short protocol name plus enable.
# The mailbox CAS report posts Set-CASMailbox parameter names. Both must reach Set-CASMailbox.

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $FunctionPath = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Email-Exchange/Administration/Invoke-ExecSetCASMailbox.ps1'

    class HttpResponseContext {
        [object]$StatusCode
        [object]$Body
    }

    $Accelerators = [psobject].Assembly.GetType('System.Management.Automation.TypeAccelerators')
    if (-not $Accelerators::Get.ContainsKey('HttpStatusCode')) {
        $Accelerators::Add('HttpStatusCode', [System.Net.HttpStatusCode])
    }

    function Write-LogMessage { param($headers, $API, $tenant, $message, $Sev, $LogData) }
    function New-ExoRequest { param($tenantid, $cmdlet, $cmdParams) }

    . $FunctionPath
}

Describe 'Invoke-ExecSetCASMailbox' {
    BeforeEach {
        Mock Write-LogMessage {}
        Mock New-ExoRequest {}
    }

    It 'enables ActiveSync from the short name the Exchange card sends' {
        $Request = [pscustomobject]@{
            Params  = [pscustomobject]@{ CIPPEndpoint = 'ExecSetCASMailbox' }
            Headers = @{}
            Body    = [pscustomobject]@{
                user         = 'ada@contoso.com'
                tenantFilter = 'contoso.com'
                protocol     = 'ActiveSync'
                enable       = $true
            }
        }

        $Response = Invoke-ExecSetCASMailbox -Request $Request

        $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        Should -Invoke New-ExoRequest -Times 1 -Exactly -ParameterFilter {
            $cmdlet -eq 'Set-CASMailbox' -and
            $cmdParams.Identity -eq 'ada@contoso.com' -and
            $cmdParams.ActiveSyncEnabled -eq $true
        }
    }

    It 'disables several short names sent together' {
        $Request = [pscustomobject]@{
            Params  = [pscustomobject]@{ CIPPEndpoint = 'ExecSetCASMailbox' }
            Headers = @{}
            Body    = [pscustomobject]@{
                user         = 'ada@contoso.com'
                tenantFilter = 'contoso.com'
                protocols    = '!IMAP,POP'
                enable       = $false
            }
        }

        $Response = Invoke-ExecSetCASMailbox -Request $Request

        $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        Should -Invoke New-ExoRequest -Times 1 -Exactly -ParameterFilter {
            $cmdParams.IMAPEnabled -eq $false -and $cmdParams.POPEnabled -eq $false
        }
    }

    It 'still accepts the Set-CASMailbox parameter names' {
        $Request = [pscustomobject]@{
            Params  = [pscustomobject]@{ CIPPEndpoint = 'ExecSetCASMailbox' }
            Headers = @{}
            Body    = [pscustomobject]@{
                Identity     = 'mailbox-guid'
                tenantFilter = 'contoso.com'
                ActiveSyncEnabled = $false
            }
        }

        $Response = Invoke-ExecSetCASMailbox -Request $Request

        $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::OK)
        Should -Invoke New-ExoRequest -Times 1 -Exactly -ParameterFilter {
            $cmdParams.Identity -eq 'mailbox-guid' -and $cmdParams.ActiveSyncEnabled -eq $false
        }
    }

    It 'returns 400 when no protocol was supplied' {
        $Request = [pscustomobject]@{
            Params  = [pscustomobject]@{ CIPPEndpoint = 'ExecSetCASMailbox' }
            Headers = @{}
            Body    = [pscustomobject]@{
                user         = 'ada@contoso.com'
                tenantFilter = 'contoso.com'
            }
        }

        $Response = Invoke-ExecSetCASMailbox -Request $Request

        $Response.StatusCode | Should -Be ([System.Net.HttpStatusCode]::BadRequest)
        Should -Invoke New-ExoRequest -Times 0 -Exactly
    }
}

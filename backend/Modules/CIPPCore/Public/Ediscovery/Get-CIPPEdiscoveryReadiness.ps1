function Get-CIPPEdiscoveryReadiness {
    <#
    .SYNOPSIS
        Checks whether a tenant's dedicated eDiscovery app config is ready for Graph use.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TenantFilter,

        [scriptblock]$Transport
    )

    $Remediation = [System.Collections.Generic.List[string]]::new()
    $Result = [ordered]@{
        ConfigPresent = $false
        Enabled       = $false
        TokenOk       = $false
        CasesListOk   = $false
        Status        = 'Error'
        Remediation   = @()
    }

    $MissingConfigSteps = @(
        'Create a dedicated Entra app registration for Purview eDiscovery.',
        'Grant and admin-consent Microsoft Graph eDiscovery.ReadWrite.All application permission.',
        'Store the certificate Key Vault secret name in the eDiscovery tenant config.',
        'Run New-ServicePrincipal in Purview for the dedicated app.',
        'Add the dedicated app service principal to the eDiscoveryManager role group.'
    )

    try {
        $Config = Get-CIPPEdiscoveryTenantConfig -TenantFilter $TenantFilter
        if (-not $Config) {
            foreach ($Step in $MissingConfigSteps) { $Remediation.Add($Step) }
            $Result.Status = 'MissingConfig'
            $Result.Remediation = @($Remediation)
            return [pscustomobject]$Result
        }

        $Result.ConfigPresent = $true
        $Result.Enabled = [bool]$Config.Enabled
        if (-not $Result.Enabled) {
            $Remediation.Add('Enable the eDiscovery tenant config after confirming the dedicated app and Purview role assignment.')
            $Result.Status = 'Disabled'
            $Result.Remediation = @($Remediation)
            return [pscustomobject]$Result
        }

        try {
            $Token = Get-CIPPEdiscoveryAccessToken -TenantFilter $TenantFilter -Config $Config
            if (-not $Token -or [string]::IsNullOrWhiteSpace([string]$Token.AccessToken)) {
                throw 'eDiscovery token response did not include AccessToken.'
            }
            $Result.TokenOk = $true
        } catch {
            $Remediation.Add('Verify the app id, certificate Key Vault secret, tenant id resolution, and Graph admin consent.')
            $Result.Status = 'TokenFailed'
            $Result.Remediation = @($Remediation)
            return [pscustomobject]$Result
        }

        try {
            $RequestParams = @{
                AccessToken    = [string]$Token.AccessToken
                Method         = 'GET'
                Path           = '/v1.0/security/cases/ediscoveryCases'
                Classification = 'read'
            }
            if ($Transport) { $RequestParams.Transport = $Transport }
            $null = Invoke-CIPPEdiscoveryRequest @RequestParams
            $Result.CasesListOk = $true
            $Result.Status = 'Ready'
        } catch {
            $Message = [string]$_.Exception.Message
            if ($Message -match '\b403\b|Forbidden') {
                $Remediation.Add('Confirm the dedicated app service principal is a Purview eDiscoveryManager and has Graph eDiscovery consent.')
                $Result.Status = 'Forbidden'
            } else {
                $Remediation.Add('Retry the readiness check and review the Graph eDiscovery request error.')
                $Result.Status = 'Error'
            }
        }

        $Result.Remediation = @($Remediation)
        return [pscustomobject]$Result
    } catch {
        $Remediation.Add('Review eDiscovery tenant config storage and retry readiness.')
        $Result.Status = 'Error'
        $Result.Remediation = @($Remediation)
        return [pscustomobject]$Result
    }
}

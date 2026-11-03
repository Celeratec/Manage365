function Invoke-ExecAppRegistration {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.AppGovernance.ReadWrite
    .DESCRIPTION
        Creates a single-tenant application, its service principal, and one credential. A secret is stored in Key Vault and is never returned or logged. SecretDelivery names GetAppRegistrationSecret, which returns that secret once within 24 hours. Certificate is the preferred credential and uses CertificatePublicKeyBase64. Requires tenantFilter, ticketNumber (6 to 8 digits), and dryRun.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Graph returns the new client secret as a string and Key Vault accepts only a SecureString.')]
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Gate = Test-CIPPGuardedWriteRequest -Request $Request -IsWrite
    if (-not $Gate.Ok) {
        $Headers = @{}
        if ($Gate.StatusCode -eq 429) { $Headers['Retry-After'] = [string]$Gate.RetryAfter }
        return [HttpResponseContext]@{ StatusCode = $Gate.StatusCode; Headers = $Headers; Body = @{ Results = $Gate.Message; Status = 'Failed' } }
    }

    $DisplayName = [string]$Request.Body.DisplayName
    $Audience = [string]$Request.Body.SignInAudience
    $Credential = $Request.Body.Credential
    $ExpiryMonths = 0
    [int]::TryParse([string]$Credential.ExpiryMonths, [ref]$ExpiryMonths) | Out-Null
    if ([string]::IsNullOrWhiteSpace($DisplayName)) {
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'DisplayName is required.'; Status = 'Failed' } }
    }
    if ($Audience -ne 'AzureADMyOrg') {
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'SignInAudience must be AzureADMyOrg.'; Status = 'Failed' } }
    }
    if ([string]$Credential.Type -notin @('Secret', 'Certificate') -or $ExpiryMonths -lt 1 -or $ExpiryMonths -gt 24) {
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'Credential.Type must be Secret or Certificate and ExpiryMonths must be 1 to 24.'; Status = 'Failed' } }
    }
    if ("$($Request.Body.GrantAdminConsent)" -in @('true', 'True', '1')) {
        $Permissions = @(Get-CippRequestAllowedPermissions)
        if ($Permissions -notcontains 'Tenant.AppGovernance.AllPrincipals') {
            return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::Forbidden; Body = @{ Results = 'GrantAdminConsent requires Tenant.AppGovernance.AllPrincipals.'; Status = 'Failed' } }
        }
    }

    $Plan = [pscustomobject]@{
        DisplayName    = $DisplayName
        SignInAudience = $Audience
        CredentialType = [string]$Credential.Type
        ExpiryMonths   = $ExpiryMonths
    }
    if ($Gate.WhatIf) {
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -DryRun $true -Result 'DryRun'
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{ Results = "Would create application $DisplayName."; Status = 'DryRun'; AuditId = $AuditId; WhatIfPlan = @($Plan) }
        }
    }

    $AppBody = @{
        displayName            = $DisplayName
        signInAudience         = 'AzureADMyOrg'
        requiredResourceAccess = @($Request.Body.RequiredResourceAccess)
    } | ConvertTo-Json -Depth 12 -Compress
    $App = New-GraphPOSTRequest -uri 'https://graph.microsoft.com/v1.0/applications' -tenantid $Gate.Tenant -type POST -body $AppBody -asApp $true
    $Sp = New-GraphPOSTRequest -uri 'https://graph.microsoft.com/v1.0/servicePrincipals' -tenantid $Gate.Tenant -type POST -body (@{ appId = $App.appId } | ConvertTo-Json -Compress) -asApp $true
    $End = [datetime]::UtcNow.AddMonths($ExpiryMonths).ToString('o')
    $KeyId = $null
    $Delivery = $null
    if ($Credential.Type -eq 'Certificate') {
        $KeyBody = @{
            keyCredential      = @{
                type  = 'AsymmetricX509Cert'
                usage = 'Verify'
                key   = [string]$Credential.CertificatePublicKeyBase64
                endDateTime = $End
            }
            passwordCredential = $null
            proof              = $null
        } | ConvertTo-Json -Depth 6 -Compress
        $Added = New-GraphPOSTRequest -uri "https://graph.microsoft.com/v1.0/applications/$($App.id)/addKey" -tenantid $Gate.Tenant -type POST -body $KeyBody -asApp $true
        $KeyId = [string]$Added.keyId
        $Delivery = @{ Type = 'KeyVaultReference'; SecretUri = $null; ExpiresAt = $End }
    } else {
        $Added = New-GraphPOSTRequest -uri "https://graph.microsoft.com/v1.0/applications/$($App.id)/addPassword" -tenantid $Gate.Tenant -type POST -body (@{ passwordCredential = @{ displayName = $DisplayName; endDateTime = $End } } | ConvertTo-Json -Depth 5 -Compress) -asApp $true
        $KeyId = [string]$Added.keyId
        $Generated = [string]$Added.secretText
        $VaultName = Get-CippKeyVaultName
        $SecretName = "appreg-$($App.appId)-$KeyId"
        $Secure = ConvertTo-SecureString -String $Generated -AsPlainText -Force
        try {
            Set-CippKeyVaultSecret -VaultName $VaultName -Name $SecretName -SecretValue $Secure
        } finally {
            if ($Secure) { $Secure.Dispose() }
            $Secure = $null
            $Generated = $null
            $Added = $null
        }
        $Delivery = @{
            Type               = 'KeyVaultReference'
            SecretUri          = "https://$VaultName.vault.azure.net/secrets/$SecretName"
            RetrievalEndpoint  = 'GetAppRegistrationSecret'
            RetrievalExpiresAt = [datetime]::UtcNow.AddHours(24).ToString('o')
            ExpiresAt          = $End
        }
    }

    $After = [pscustomobject]@{
        AppId              = [string]$App.appId
        ObjectId           = [string]$App.id
        ServicePrincipalId = [string]$Sp.id
        CredentialKeyId    = $KeyId
        SecretDelivery     = $Delivery
    }
    $Warning = $null
    if ("$($Request.Body.GrantAdminConsent)" -in @('true', 'True', '1')) {
        $Warning = 'The application was created. Admin consent is a separate ExecGraphWrite call.'
    }
    $Summary = "Created application $DisplayName ($($App.appId))."
    Write-LogMessage -headers $Request.Headers -API $APIName -tenant $Gate.Tenant -message $Summary -Sev 'Info'
    $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -After $After -DryRun $false -Result 'Success'
    return [HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = @{
            Results            = $Summary
            Status             = 'Success'
            AuditId            = $AuditId
            AppId              = $After.AppId
            ObjectId           = $After.ObjectId
            ServicePrincipalId = $After.ServicePrincipalId
            CredentialKeyId    = $KeyId
            SecretDelivery     = $Delivery
            Warning            = $Warning
            WhatIfPlan         = @()
        }
    }
}

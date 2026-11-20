function Invoke-ExecAppRegistration {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.AppGovernance.ReadWrite
    .DESCRIPTION
        Creates a single-tenant application, its service principal, and one credential.
        Certificate (CertificatePublicKeyBase64, public key only) is preferred; secrets are
        stored in Key Vault and never returned. Optional Notes, Description, and Owners.
        dryRun/preview defaults to true for this endpoint. Requires tenantFilter, ticketNumber
        (6 to 8 digits), and reason.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Graph returns the new client secret as a string and Key Vault accepts only a SecureString.')]
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Gate = Test-CIPPGuardedWriteRequest -Request $Request -IsWrite -DefaultDryRun
    if (-not $Gate.Ok) {
        $Headers = @{}
        if ($Gate.StatusCode -eq 429) { $Headers['Retry-After'] = [string]$Gate.RetryAfter }
        return [HttpResponseContext]@{ StatusCode = $Gate.StatusCode; Headers = $Headers; Body = @{ Results = $Gate.Message; Status = 'Failed' } }
    }

    $DisplayName = [string]$Request.Body.DisplayName
    $Audience = [string]$Request.Body.SignInAudience
    $Credential = $Request.Body.Credential
    $CredType = [string]$Credential.Type
    $ExpiryMonths = 0
    $ExpiryProvided = $null -ne $Credential.ExpiryMonths -and "$($Credential.ExpiryMonths)" -ne ''
    if ($ExpiryProvided) {
        [int]::TryParse([string]$Credential.ExpiryMonths, [ref]$ExpiryMonths) | Out-Null
    }

    if ([string]::IsNullOrWhiteSpace($DisplayName)) {
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'DisplayName is required.'; Status = 'Failed' } }
    }
    if ($Audience -ne 'AzureADMyOrg') {
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'SignInAudience must be AzureADMyOrg.'; Status = 'Failed' } }
    }
    if ($CredType -notin @('Secret', 'Certificate')) {
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'Credential.Type must be Secret or Certificate.'; Status = 'Failed' } }
    }
    if ($CredType -eq 'Secret' -and ($ExpiryMonths -lt 1 -or $ExpiryMonths -gt 24)) {
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'Credential.ExpiryMonths must be 1 to 24 for Secret credentials.'; Status = 'Failed' } }
    }
    if ($CredType -eq 'Certificate' -and $ExpiryProvided -and ($ExpiryMonths -lt 1 -or $ExpiryMonths -gt 24)) {
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'Credential.ExpiryMonths must be 1 to 24 when provided.'; Status = 'Failed' } }
    }
    if ("$($Request.Body.GrantAdminConsent)" -in @('true', 'True', '1')) {
        $Permissions = @(Get-CippRequestAllowedPermissions)
        if ($Permissions -notcontains 'Tenant.AppGovernance.AllPrincipals') {
            return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::Forbidden; Body = @{ Results = 'GrantAdminConsent requires Tenant.AppGovernance.AllPrincipals.'; Status = 'Failed' } }
        }
    }

    $Notes = [string]$Request.Body.Notes
    $Description = [string]$Request.Body.Description
    if ($Notes.Length -gt 1024) {
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'Notes must be at most 1024 characters.'; Status = 'Failed' } }
    }
    if ($Description.Length -gt 1024) {
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'Description must be at most 1024 characters.'; Status = 'Failed' } }
    }

    $OwnerIds = @()
    if ($null -ne $Request.Body.Owners) {
        $OwnerIds = @($Request.Body.Owners)
        if ($OwnerIds.Count -gt 5) {
            return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'Owners may list at most 5 user object IDs.'; Status = 'Failed' } }
        }
        foreach ($OwnerId in $OwnerIds) {
            $Oid = [string]$OwnerId
            if ($Oid -notmatch '\A[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}\z') {
                return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'Each Owners entry must be a user object GUID.'; Status = 'Failed' } }
            }
        }
    }

    $RequiredResourceAccess = @()
    if ($null -ne $Request.Body.RequiredResourceAccess -and "$($Request.Body.RequiredResourceAccess)" -ne '') {
        $RequiredResourceAccess = @($Request.Body.RequiredResourceAccess | Where-Object { $null -ne $_ })
    }

    $Cert = $null
    $CertThumbprint = $null
    $CertEnd = $null
    $PublicKeyB64 = $null
    if ($CredType -eq 'Certificate') {
        $PublicKeyB64 = [string]$Credential.CertificatePublicKeyBase64
        if ([string]::IsNullOrWhiteSpace($PublicKeyB64)) {
            return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'Credential.CertificatePublicKeyBase64 is required for Certificate.'; Status = 'Failed' } }
        }
        if ($PublicKeyB64.Length -gt 20000) {
            return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'CertificatePublicKeyBase64 exceeds the allowed size.'; Status = 'Failed' } }
        }
        try {
            $Raw = $PublicKeyB64.Trim() -replace '-----BEGIN CERTIFICATE-----', '' -replace '-----END CERTIFICATE-----', '' -replace '\s', ''
            $Bytes = [Convert]::FromBase64String($Raw)
            # PKCS#12 / PFX often starts with 0x30 and contains private key bags; refuse any blob Graph would treat as PFX by trying X509 first then checking HasPrivateKey.
            $Cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($Bytes)
        } catch {
            $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -DryRun $Gate.WhatIf -Result 'Failed'
            return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'CertificatePublicKeyBase64 must be a public X.509 certificate (DER/base64 or PEM). PFX/private key material is refused.'; Status = 'Failed'; AuditId = $AuditId } }
        }
        if ($Cert.HasPrivateKey) {
            $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -DryRun $Gate.WhatIf -Result 'Failed'
            return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'CertificatePublicKeyBase64 must not include a private key.'; Status = 'Failed'; AuditId = $AuditId } }
        }
        $Now = [datetime]::UtcNow
        if ($Cert.NotAfter.ToUniversalTime() -le $Now) {
            return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'Certificate is expired.'; Status = 'Failed' } }
        }
        if ($Cert.NotBefore.ToUniversalTime() -gt $Now) {
            return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'Certificate is not yet valid.'; Status = 'Failed' } }
        }
        $CertEnd = $Cert.NotAfter.ToUniversalTime()
        if ($ExpiryProvided) {
            $RequestedEnd = [datetime]::UtcNow.AddMonths($ExpiryMonths)
            if ($RequestedEnd -gt $CertEnd) {
                return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = "ExpiryMonths extends past the certificate NotAfter ($($CertEnd.ToString('o')))."; Status = 'Failed' } }
            }
            $CertEnd = $RequestedEnd
        }
        $CertThumbprint = $Cert.Thumbprint
        $PublicKeyB64 = [Convert]::ToBase64String($Cert.RawData)
    }

    $End = if ($CredType -eq 'Certificate') { $CertEnd.ToString('o') } else { [datetime]::UtcNow.AddMonths($ExpiryMonths).ToString('o') }

    $Plan = [pscustomobject]@{
        DisplayName             = $DisplayName
        SignInAudience          = $Audience
        CredentialType          = $CredType
        ExpiryMonths            = $(if ($ExpiryProvided) { $ExpiryMonths } else { $null })
        CredentialEndDateTime   = $End
        CredentialThumbprint    = $CertThumbprint
        NotesLength             = $Notes.Length
        DescriptionLength       = $Description.Length
        Owners                  = $OwnerIds
        RequiredResourceAccess  = $RequiredResourceAccess
    }

    # Name collision (create-only), including dryRun
    $EscapedName = $DisplayName.Replace("'", "''")
    $Existing = @(New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/applications?`$filter=displayName eq '$EscapedName'&`$select=id,appId,displayName" -tenantid $Gate.Tenant -asApp $true)
    if ($Existing.Count -gt 0) {
        $Hit = $Existing | Select-Object -First 1
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before $Hit -DryRun $Gate.WhatIf -Result 'Failed'
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::Conflict
            Body       = @{
                Results        = "An application named '$DisplayName' already exists."
                Status         = 'Failed'
                AuditId        = $AuditId
                ExistingObjectId = [string]$Hit.id
                ExistingAppId  = [string]$Hit.appId
                Before         = $Hit
            }
        }
    }

    if ($Gate.WhatIf) {
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -Before @{ Existing = @() } -DryRun $true -Result 'DryRun'
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = @{
                Results    = "Would create application $DisplayName."
                Status     = 'DryRun'
                AuditId    = $AuditId
                Before     = @{ Existing = @() }
                WhatIfPlan = @($Plan)
            }
        }
    }

    $App = $null
    $Sp = $null
    try {
        $AppPayload = @{
            displayName            = $DisplayName
            signInAudience         = 'AzureADMyOrg'
            requiredResourceAccess = @($RequiredResourceAccess)
        }
        if (-not [string]::IsNullOrWhiteSpace($Notes)) { $AppPayload.notes = $Notes }
        if (-not [string]::IsNullOrWhiteSpace($Description)) { $AppPayload.description = $Description }
        if ($CredType -eq 'Certificate') {
            $AppPayload.keyCredentials = @(
                @{
                    type        = 'AsymmetricX509Cert'
                    usage       = 'Verify'
                    key         = $PublicKeyB64
                    endDateTime = $End
                }
            )
        }
        $AppBody = $AppPayload | ConvertTo-Json -Depth 12 -Compress
        $App = New-GraphPOSTRequest -uri 'https://graph.microsoft.com/v1.0/applications' -tenantid $Gate.Tenant -type POST -body $AppBody -asApp $true
        $Sp = New-GraphPOSTRequest -uri 'https://graph.microsoft.com/v1.0/servicePrincipals' -tenantid $Gate.Tenant -type POST -body (@{ appId = $App.appId } | ConvertTo-Json -Compress) -asApp $true

        # Prove permissions stayed empty when none were requested
        if ($RequiredResourceAccess.Count -eq 0) {
            $ReadBack = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/applications/$($App.id)?`$select=requiredResourceAccess" -tenantid $Gate.Tenant -asApp $true
            $ReadAccess = @($ReadBack.requiredResourceAccess)
            if ($ReadAccess.Count -gt 0) {
                throw "Application was created with unexpected requiredResourceAccess ($($ReadAccess.Count) entries)."
            }
        }

        $KeyId = $null
        $Delivery = $null
        if ($CredType -eq 'Certificate') {
            $KeyId = [string](@($App.keyCredentials) | Select-Object -First 1).keyId
            if ([string]::IsNullOrWhiteSpace($KeyId)) {
                # Graph may omit keyCredentials on create response; re-read
                $AppKeys = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/applications/$($App.id)?`$select=keyCredentials" -tenantid $Gate.Tenant -asApp $true
                $KeyId = [string](@($AppKeys.keyCredentials) | Select-Object -First 1).keyId
            }
            $Delivery = $null
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

        foreach ($OwnerId in $OwnerIds) {
            $User = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users/$OwnerId`?`$select=id" -tenantid $Gate.Tenant -asApp $true
            if (-not $User -or [string]$User.id -ne $OwnerId) {
                throw "Owner '$OwnerId' is not a user in this tenant."
            }
            $OwnerBody = @{ '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$OwnerId" } | ConvertTo-Json -Compress
            $null = New-GraphPOSTRequest -uri "https://graph.microsoft.com/v1.0/applications/$($App.id)/owners/`$ref" -tenantid $Gate.Tenant -type POST -body $OwnerBody -asApp $true
        }

        $After = [pscustomobject]@{
            AppId                   = [string]$App.appId
            ObjectId                = [string]$App.id
            ServicePrincipalId      = [string]$Sp.id
            CredentialKeyId         = $KeyId
            CredentialThumbprint    = $CertThumbprint
            CredentialEndDateTime   = $End
            SecretDelivery          = $Delivery
        }
        $Warning = $null
        if ("$($Request.Body.GrantAdminConsent)" -in @('true', 'True', '1')) {
            $Warning = 'The application was created. Admin consent is a separate ExecGraphWrite call.'
        }
        $Summary = "Created application $DisplayName ($($App.appId))."
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $Gate.Tenant -message $Summary -Sev 'Info'
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -After $After -DryRun $false -Result 'Success'
        $Body = @{
            Results                 = $Summary
            Status                  = 'Success'
            AuditId                 = $AuditId
            AppId                   = $After.AppId
            ObjectId                = $After.ObjectId
            ServicePrincipalId      = $After.ServicePrincipalId
            CredentialKeyId         = $KeyId
            CredentialThumbprint    = $CertThumbprint
            CredentialEndDateTime   = $End
            Warning                 = $Warning
            WhatIfPlan              = @()
        }
        if ($null -ne $Delivery) { $Body.SecretDelivery = $Delivery }
        return [HttpResponseContext]@{ StatusCode = [HttpStatusCode]::OK; Body = $Body }
    } catch {
        $Rollback = $null
        if ($App -and $App.id) {
            try {
                if ($Sp -and $Sp.id) {
                    $null = New-GraphPOSTRequest -uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($Sp.id)" -tenantid $Gate.Tenant -type DELETE -asApp $true
                }
                $null = New-GraphPOSTRequest -uri "https://graph.microsoft.com/v1.0/applications/$($App.id)" -tenantid $Gate.Tenant -type DELETE -asApp $true
                $Rollback = @{ DeletedApplicationId = [string]$App.id; DeletedServicePrincipalId = [string]$Sp.id; Note = 'Rolled back create after failure.' }
            } catch {
                $Rollback = @{
                    DeletedApplicationId       = [string]$App.id
                    DeletedServicePrincipalId  = [string]$Sp.id
                    Note                       = "Create failed; automatic rollback also failed: $($_.Exception.Message). Delete via ExecGraphWrite."
                }
            }
        }
        $Msg = [string]$_.Exception.Message
        $AuditId = Add-CIPPGuardedWriteAudit -Endpoint $APIName -Tenant $Gate.Tenant -Ticket $Gate.Ticket -Caller $Gate.Caller -Request $Request.Body -After @{ Error = $Msg; AppId = [string]$App.appId; ObjectId = [string]$App.id; ServicePrincipalId = [string]$Sp.id } -DryRun $false -Result 'Failed'
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{
                Results  = $Msg
                Status   = 'Failed'
                AuditId  = $AuditId
                AppId    = [string]$App.appId
                ObjectId = [string]$App.id
                ServicePrincipalId = [string]$Sp.id
                Rollback = $Rollback
            }
        }
    }
}

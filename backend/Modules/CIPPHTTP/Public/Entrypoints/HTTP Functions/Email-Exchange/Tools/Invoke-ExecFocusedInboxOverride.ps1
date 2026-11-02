function Invoke-ExecFocusedInboxOverride {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Exchange.Mailbox.ReadWrite
    .DESCRIPTION
        Add or remove Focused Inbox sender overrides for a mailbox using Graph API inferenceClassification.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $UserPrincipalName = Get-CippQuarantineInputValue $Request.Body.userPrincipalName
    $Action = $Request.Body.action  # Add, Remove, or List
    $SenderEmailAddress = Get-CippQuarantineInputValue $Request.Body.senderEmailAddress
    $ClassifyAs = $Request.Body.classifyAs  # focused or other

    try {
        # Normalize tenantFilter inside try block
        $TenantFilter = Get-CippNormalizedTenantFilter -TenantFilter $Request.Body.tenantFilter
        # Input validation
        if ([string]::IsNullOrWhiteSpace($TenantFilter)) { throw 'tenantFilter is required.' }
        if ([string]::IsNullOrWhiteSpace($UserPrincipalName)) { throw 'userPrincipalName is required.' }
        if ([string]::IsNullOrWhiteSpace($Action)) { throw 'action is required.' }
        if ($Action -notin @('Add', 'Remove', 'List')) { throw 'action must be Add, Remove, or List.' }
        
        # Validate UPN (email or GUID)
        $Validation = Test-CippExchangeInputValidation -UserPrincipalName $UserPrincipalName
        if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }
        
        # URL-encode the UPN to prevent path injection
        $EncodedUPN = [uri]::EscapeDataString($UserPrincipalName)
        
        if ($Action -eq 'Add') {
            if ([string]::IsNullOrWhiteSpace($SenderEmailAddress)) { throw 'senderEmailAddress is required for Add action.' }
            if ([string]::IsNullOrWhiteSpace($ClassifyAs)) { throw 'classifyAs is required for Add action.' }
            if ($ClassifyAs -notin @('focused', 'other')) { throw 'classifyAs must be focused or other.' }
            
            # Validate sender email address
            $Validation = Test-CippExchangeInputValidation -EmailAddress $SenderEmailAddress
            if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }

            # Add override via Graph API (requires Mail.ReadWrite permission)
            $Body = @{
                senderEmailAddress = @{
                    name    = $SenderEmailAddress
                    address = $SenderEmailAddress
                }
                classifyAs         = $ClassifyAs
            } | ConvertTo-Json -Compress

            $GraphRequest = New-GraphPOSTRequest -uri "https://graph.microsoft.com/v1.0/users/$EncodedUPN/inferenceClassification/overrides" -tenantid $TenantFilter -body $Body -type POST

            $Result = "Added Focused Inbox override: $SenderEmailAddress will be classified as '$ClassifyAs' for $UserPrincipalName"
            Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Info'
            $StatusCode = [HttpStatusCode]::OK
            $Body = @{ Results = $Result; Override = $GraphRequest }
        } elseif ($Action -eq 'Remove') {
            if ([string]::IsNullOrWhiteSpace($SenderEmailAddress)) { throw 'senderEmailAddress is required for Remove action.' }
            
            # Validate sender email address
            $Validation = Test-CippExchangeInputValidation -EmailAddress $SenderEmailAddress
            if (-not $Validation.IsValid) { throw ($Validation.Errors -join '; ') }

            # List overrides to find the ID
            $Overrides = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users/$EncodedUPN/inferenceClassification/overrides" -tenantid $TenantFilter

            $OverrideToRemove = $Overrides | Where-Object { $_.senderEmailAddress.address -eq $SenderEmailAddress } | Select-Object -First 1

            if ($null -eq $OverrideToRemove) {
                throw "No Focused Inbox override found for sender $SenderEmailAddress"
            }

            # Remove override
            $null = New-GraphPOSTRequest -uri "https://graph.microsoft.com/v1.0/users/$EncodedUPN/inferenceClassification/overrides/$($OverrideToRemove.id)" -tenantid $TenantFilter -type DELETE

            $Result = "Removed Focused Inbox override for $SenderEmailAddress from $UserPrincipalName"
            Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Info'
            $StatusCode = [HttpStatusCode]::OK
            $Body = @{ Results = $Result }
        } else {
            # List overrides
            $Overrides = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/users/$EncodedUPN/inferenceClassification/overrides" -tenantid $TenantFilter

            $Result = "Retrieved $($Overrides.Count) Focused Inbox override(s) for $UserPrincipalName"
            Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Info'
            $StatusCode = [HttpStatusCode]::OK
            $Body = $Overrides
        }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Result = "Failed to $Action Focused Inbox override for $UserPrincipalName in $TenantFilter`: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Request.Headers -API $APIName -tenant $TenantFilter -message $Result -Sev 'Error'
        $StatusCode = [HttpStatusCode]::OK
        $Body = @{ Results = $Result }
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}

function Invoke-ExecEditCAPolicyFull {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.ConditionalAccess.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    # Graph's beta GET returns annotations and read-only fields the policy schema rejects on PATCH
    # (1007). @odata.type stays: externalTenants is polymorphic and the schema requires it.
    function Remove-CIPPCAPolicyServerFields {
        param($Node, [bool]$PolicyRoot = $false)
        if ($null -eq $Node -or $Node -is [string] -or $Node -is [ValueType]) { return }
        if ($Node -isnot [System.Management.Automation.PSCustomObject]) {
            foreach ($Item in @($Node)) { Remove-CIPPCAPolicyServerFields -Node $Item }
            return
        }

        $ReadOnly = if ($PolicyRoot) {
            @('id', 'createdDateTime', 'modifiedDateTime', 'deletedDateTime', 'templateId', 'partialEnablementStrategy')
        } else {
            @('createdDateTime', 'modifiedDateTime', 'deletedDateTime')
        }
        foreach ($Name in @($Node.PSObject.Properties.Name)) {
            $Annotation = $Name -like '*@odata*' -and $Name -ne '@odata.type'
            if ($Annotation -or $Name -in $ReadOnly) {
                $Node.PSObject.Properties.Remove($Name)
            }
        }
        foreach ($Prop in @($Node.PSObject.Properties)) {
            # A GET expands authenticationStrength into the full policy. PATCH accepts { id } or null.
            if ($Prop.Name -eq 'authenticationStrength' -and $null -ne $Prop.Value -and $Prop.Value -is [System.Management.Automation.PSCustomObject]) {
                $StrengthId = [string]$Prop.Value.id
                $Node.authenticationStrength = if ([string]::IsNullOrWhiteSpace($StrengthId)) {
                    $null
                } else {
                    [pscustomobject]@{ id = $StrengthId }
                }
                continue
            }
            Remove-CIPPCAPolicyServerFields -Node $Prop.Value
        }
    }

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Query.tenantFilter ?? $Request.Body.tenantFilter

    if ([string]::IsNullOrWhiteSpace($TenantFilter)) {
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'Error: tenantFilter is required' }
        }
    }

    $PolicyId = $Request.Query.PolicyId ?? $Request.Body.PolicyId
    if ([string]::IsNullOrWhiteSpace($PolicyId)) {
        return [HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = @{ Results = 'Error: PolicyId is required' }
        }
    }

    try {
        $PolicyBody = $Request.Body.PolicyBody
        if ($null -eq $PolicyBody) {
            return [HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{ Results = 'Error: PolicyBody is required' }
            }
        }

        # Start from the live policy so a partial body cannot silently drop grant controls,
        # session controls, conditions, or excluded users and groups. Strip server fields
        # before the merge so they are not copied onto the PATCH.
        $Current = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/identity/conditionalAccess/policies/$PolicyId" -tenantid $TenantFilter -asApp $true -noPagination $true
        $CleanBody = $PolicyBody | ConvertTo-Json -Depth 30 | ConvertFrom-Json
        $CurrentClean = $Current | ConvertTo-Json -Depth 30 | ConvertFrom-Json
        Remove-CIPPCAPolicyServerFields -Node $CleanBody -PolicyRoot $true
        Remove-CIPPCAPolicyServerFields -Node $CurrentClean -PolicyRoot $true
        $PolicyObject = Merge-CIPPCAPolicyUpdate -Current $CurrentClean -Patch $CleanBody
        Format-CIPPCAPolicy -Policy $PolicyObject
        $ConfirmRemoval = @($Request.Body.ConfirmRemoval | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        $Dropped = @(Test-CIPPCAPolicyRemoval -Current $Current -Proposed $PolicyObject -ConfirmRemoval $ConfirmRemoval)
        if ($Dropped.Count -gt 0) {
            $Result = "Refusing to drop $($Dropped -join ', ') from CA policy $PolicyId. Set ConfirmRemoval to those field names to confirm."
            Write-LogMessage -API $APIName -tenant $TenantFilter -headers $Headers -message $Result -sev Warning
            return [HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{ Results = $Result; ConfirmRemoval = $Dropped }
            }
        }
        $RawJSON = ConvertTo-Json -InputObject $PolicyObject -Depth 20 -Compress

        $null = New-GraphPOSTRequest `
            -uri "https://graph.microsoft.com/beta/identity/conditionalAccess/policies/$PolicyId" `
            -tenantid $TenantFilter `
            -type PATCH `
            -body $RawJSON `
            -asApp $true

        $DisplayName = $PolicyBody.displayName ?? $PolicyId
        $Result = "Successfully updated CA policy '$DisplayName' for $TenantFilter"
        Write-LogMessage -API $APIName -tenant $TenantFilter -headers $Headers -message $Result -sev Info
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Result = "Failed to update CA policy $PolicyId for ${TenantFilter}: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -API $APIName -tenant $TenantFilter -headers $Headers -message $Result -sev Error -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
    }

    return [HttpResponseContext]@{
        StatusCode = $StatusCode ?? [HttpStatusCode]::OK
        Body       = @{ Results = $Result }
    }
}

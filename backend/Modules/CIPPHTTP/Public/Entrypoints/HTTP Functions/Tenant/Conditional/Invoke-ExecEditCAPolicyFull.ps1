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

    # ConvertFrom-Json and the Functions worker can turn a one-item array into a string and an
    # empty array into null. Graph rejects both with 1007. These names are arrays in the policy schema.
    function ConvertTo-CIPPCAPolicyArray {
        param($Value)
        $List = [System.Collections.Generic.List[string]]::new()
        if ($null -ne $Value) {
            $Items = if ($Value -is [string] -or $Value -is [ValueType]) { ,$Value } else { @($Value) }
            foreach ($Item in $Items) {
                if ($null -eq $Item -or ($Item -isnot [string] -and $Item -isnot [ValueType])) { continue }
                $Text = [string]$Item
                if ([string]::IsNullOrWhiteSpace($Text)) { continue }
                [void]$List.Add($Text)
            }
        }
        Write-Output -NoEnumerate $List
    }

    function Set-CIPPCAPolicyArrays {
        param($Node)
        if ($null -eq $Node -or $Node -is [string] -or $Node -is [ValueType]) { return }
        if ($Node -isnot [System.Management.Automation.PSCustomObject]) {
            foreach ($Item in @($Node)) { Set-CIPPCAPolicyArrays -Node $Item }
            return
        }
        $ArrayProperties = @{
            includeUsers = $true; excludeUsers = $true; includeGroups = $true; excludeGroups = $true
            includeRoles = $true; excludeRoles = $true; includeApplications = $true; excludeApplications = $true
            includeUserActions = $true; includeAuthenticationContextClassReferences = $true
            clientAppTypes = $true; signInRiskLevels = $true; userRiskLevels = $true; servicePrincipalRiskLevels = $true
            includePlatforms = $true; excludePlatforms = $true; includeLocations = $true; excludeLocations = $true
            includeDevices = $true; excludeDevices = $true; includeServicePrincipals = $true; excludeServicePrincipals = $true
            builtInControls = $true; customAuthenticationFactors = $true; termsOfUse = $true; members = $true
        }
        foreach ($Prop in @($Node.PSObject.Properties)) {
            if ($ArrayProperties.ContainsKey($Prop.Name)) {
                $Node.$($Prop.Name) = ConvertTo-CIPPCAPolicyArray -Value $Prop.Value
                continue
            }
            Set-CIPPCAPolicyArrays -Node $Prop.Value
        }
    }

    function Test-CIPPCAPolicyNode {
        param($Node, [string]$Name)
        return ($null -ne $Node -and $Node -is [System.Management.Automation.PSCustomObject] -and $Node.PSObject.Properties.Name -contains $Name)
    }

    function Test-CIPPCAPolicyEmptyObject {
        param($Value)
        if ($Value -isnot [System.Management.Automation.PSCustomObject]) { return $false }
        foreach ($Prop in @($Value.PSObject.Properties)) {
            if ($Prop.Name -like '*@odata*') { continue }
            if ($null -eq $Prop.Value) { continue }
            if ($Prop.Value -is [string] -and [string]::IsNullOrWhiteSpace([string]$Prop.Value)) { continue }
            if ($Prop.Value -is [System.Management.Automation.PSCustomObject] -and (Test-CIPPCAPolicyEmptyObject -Value $Prop.Value)) { continue }
            return $false
        }
        return $true
    }

    # Format-CIPPCAPolicy turns a half-populated block into null. That null clears a block the
    # caller never mentioned. Drop it instead, so the PATCH leaves the live value alone.
    # An explicit null in the request is a clear and stays null.
    function Remove-CIPPCAPolicyUnrequestedNull {
        param($Proposed, $Live, $Patch)
        $Paths = @(
            @('conditions', 'platforms'),
            @('conditions', 'locations'),
            @('conditions', 'devices'),
            @('conditions', 'clientApplications'),
            @('conditions', 'authenticationFlows'),
            @('conditions', 'users', 'includeGuestsOrExternalUsers'),
            @('conditions', 'users', 'excludeGuestsOrExternalUsers'),
            @('conditions', 'applications', 'applicationFilter'),
            @('conditions', 'devices', 'deviceFilter'),
            @('conditions', 'clientApplications', 'servicePrincipalFilter'),
            @('grantControls', 'authenticationStrength'),
            @('sessionControls'),
            @('sessionControls', 'applicationEnforcedRestrictions'),
            @('sessionControls', 'cloudAppSecurity'),
            @('sessionControls', 'signInFrequency'),
            @('sessionControls', 'persistentBrowser')
        )
        foreach ($Path in $Paths) {
            $ProposedParent = $Proposed
            $LiveParent = $Live
            $PatchParent = $Patch
            $MissingParent = $false
            for ($Index = 0; $Index -lt ($Path.Count - 1); $Index++) {
                $Step = $Path[$Index]
                if (-not (Test-CIPPCAPolicyNode -Node $ProposedParent -Name $Step)) { $MissingParent = $true; break }
                $ProposedParent = $ProposedParent.$Step
                $LiveParent = if (Test-CIPPCAPolicyNode -Node $LiveParent -Name $Step) { $LiveParent.$Step } else { $null }
                $PatchParent = if (Test-CIPPCAPolicyNode -Node $PatchParent -Name $Step) { $PatchParent.$Step } else { $null }
            }
            if ($MissingParent) { continue }
            $Name = $Path[-1]
            if (-not (Test-CIPPCAPolicyNode -Node $ProposedParent -Name $Name)) { continue }
            if (Test-CIPPCAPolicyEmptyObject -Value $ProposedParent.$Name) { $ProposedParent.$Name = $null }
            if ($null -ne $ProposedParent.$Name) { continue }
            $LiveHasValue = (Test-CIPPCAPolicyNode -Node $LiveParent -Name $Name) -and $null -ne $LiveParent.$Name
            # Any value in the request, including null or an empty block, is the caller speaking.
            # Only a block the request left out is unsafe to send back as null.
            $CallerAddressed = Test-CIPPCAPolicyNode -Node $PatchParent -Name $Name
            if ($LiveHasValue -and -not $CallerAddressed) {
                $ProposedParent.PSObject.Properties.Remove($Name)
            }
        }
    }

    function ConvertTo-CIPPCAPolicyLogBody {
        param([string]$Json)
        if ([string]::IsNullOrEmpty($Json)) { return $Json }
        return [regex]::Replace($Json, '(?i)Bearer\s+[A-Za-z0-9\-._~+/=]+', 'Bearer [redacted]')
    }

    function Get-CIPPCAPolicyGraphFailure {
        param($ErrorRecord)
        $Message = Get-CIPPGraphErrorMessage -ErrorRecord $ErrorRecord
        $Code = $null
        $Raw = $null
        if ($ErrorRecord -is [System.Management.Automation.ErrorRecord] -and $ErrorRecord.ErrorDetails) {
            $Raw = [string]$ErrorRecord.ErrorDetails.Message
        }
        if ($Raw -and $Raw.TrimStart().StartsWith('{')) {
            try {
                $Parsed = $Raw | ConvertFrom-Json
                $Code = [string]$Parsed.error.code
            } catch {
                Write-Information "Could not read the Graph error code: $($_.Exception.Message)"
            }
        }
        if ([string]::IsNullOrWhiteSpace($Message)) { $Message = [string]$ErrorRecord.Exception.Message }
        if (-not [string]::IsNullOrWhiteSpace($Code) -and $Message -notmatch "(^|\s)$([regex]::Escape($Code))(:|\s)") {
            return "${Code}: $Message"
        }
        return $Message
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

    $RawJSON = $null
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
        Remove-CIPPCAPolicyUnrequestedNull -Proposed $PolicyObject -Live $CurrentClean -Patch $CleanBody
        Set-CIPPCAPolicyArrays -Node $PolicyObject
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
        $GraphFailure = Get-CIPPCAPolicyGraphFailure -ErrorRecord $_
        $Result = "Failed to update CA policy $PolicyId for ${TenantFilter}: $GraphFailure"
        $LoggedBody = ConvertTo-CIPPCAPolicyLogBody -Json $RawJSON
        $LogMessage = if ([string]::IsNullOrWhiteSpace($LoggedBody)) { $Result } else { "$Result Outgoing body: $LoggedBody" }
        Write-LogMessage -API $APIName -tenant $TenantFilter -headers $Headers -message $LogMessage -sev Error -LogData $ErrorMessage
        $StatusCode = [HttpStatusCode]::InternalServerError
    }

    return [HttpResponseContext]@{
        StatusCode = $StatusCode ?? [HttpStatusCode]::OK
        Body       = @{ Results = $Result }
    }
}

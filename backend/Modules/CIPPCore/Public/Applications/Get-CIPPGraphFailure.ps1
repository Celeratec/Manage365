function Get-CIPPGraphFailure {
    <#
    .SYNOPSIS
        Graph's own message and HTTP status from a failed request.
    .FUNCTIONALITY
        Internal
    #>
    param($ErrorRecord)
    $Message = $null
    $Status = $null
    $Node = $ErrorRecord
    for ($Guard = 0; $Node -and $Guard -lt 8; $Guard++) {
        if ($Node.Data -and $Node.Data.Contains('StatusCode') -and $Node.Data['StatusCode']) {
            $Status = [int]$Node.Data['StatusCode']
        }
        if ($Node -is [System.Management.Automation.ErrorRecord]) {
            if (-not $Message -and $Node.Exception.Message) { $Message = [string]$Node.Exception.Message }
            $Node = $Node.Exception
            continue
        }
        if (-not $Message -and $Node.Message) { $Message = [string]$Node.Message }
        $Node = $Node.InnerException
    }
    if (Get-Command Get-CIPPGraphErrorMessage -ErrorAction SilentlyContinue) {
        $GraphMessage = Get-CIPPGraphErrorMessage -ErrorRecord $ErrorRecord
        if (-not [string]::IsNullOrWhiteSpace($GraphMessage)) { $Message = $GraphMessage }
    }
    if (-not $Status -and $Message -match '\((\d{3})\)') { $Status = [int]$Matches[1] }
    if (-not $Status) { $Status = 500 }
    if ([string]::IsNullOrWhiteSpace($Message)) { $Message = [string]$ErrorRecord }
    [pscustomobject]@{ Message = $Message; StatusCode = $Status }
}

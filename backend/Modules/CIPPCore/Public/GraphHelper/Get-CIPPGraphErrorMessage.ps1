function Get-CIPPGraphErrorMessage {
    <#
    .SYNOPSIS
        User-facing text from a Graph failure, preferring the JSON error body.
    .DESCRIPTION
        Graph policy failures (for example Expiration_Admin_Assignment) arrive as a JSON error
        body. A bare "400 Bad Request" status line is rewritten elsewhere into a generic token
        message, which hides the policy rule Entra actually rejected. This walks the error record
        and returns error.message plus any inner error instead of that generic line.
    #>
    [CmdletBinding()]
    param($ErrorRecord)

    $Raw = $null
    $Text = $null
    $Node = $ErrorRecord
    for ($Guard = 0; $Node -and $Guard -lt 8; $Guard++) {
        if ($Node -is [System.Management.Automation.ErrorRecord]) {
            if (-not $Raw -and $Node.ErrorDetails -and $Node.ErrorDetails.Message) {
                $Raw = [string]$Node.ErrorDetails.Message
            }
            $Node = $Node.Exception
            continue
        }
        if ($Node.Data -and $Node.Data.Contains('RawErrorBody') -and $Node.Data['RawErrorBody']) {
            $Raw = [string]$Node.Data['RawErrorBody']
        }
        if (-not $Text -and $Node.Message) { $Text = [string]$Node.Message }
        $Node = $Node.InnerException
    }

    if ($Raw -and $Raw.TrimStart().StartsWith('{')) {
        try {
            $Json = $Raw | ConvertFrom-Json
            $Parts = [System.Collections.Generic.List[string]]::new()
            foreach ($Part in @($Json.error.message, $Json.error.innererror.message, $Json.error.innerError.message)) {
                $PartText = [string]$Part
                if (-not [string]::IsNullOrWhiteSpace($PartText) -and -not $Parts.Contains($PartText)) {
                    $Parts.Add($PartText)
                }
            }
            if ($Parts.Count -gt 0) { return ($Parts -join ' ') }
        } catch {
            Write-Information "Could not parse a Graph error body: $($_.Exception.Message)"
        }
    }

    if ($Text -match 'token configuration|Response status code does not indicate success' -and $Raw) {
        return $Raw
    }
    if ($Text) { return $Text }
    return [string]$ErrorRecord
}

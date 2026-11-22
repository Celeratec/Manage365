# Storage Report PDF forwards the caller's branding preset (other fixed-report PDFs on this fork
# still resolve tenant naming without BrandingPresetId; covered when those endpoints are upgraded).
BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))

    class HttpResponseContext {
        [object]$StatusCode
        [object]$Body
        [object]$ContentType
        [object]$Headers
    }

    $Accelerators = [psobject].Assembly.GetType('System.Management.Automation.TypeAccelerators')
    if (-not $Accelerators::Get.ContainsKey('HttpStatusCode')) {
        $Accelerators::Add('HttpStatusCode', [System.Net.HttpStatusCode])
    }

    . (Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Teams-Sharepoint/Invoke-ExecGetStorageReportPdf.ps1')

    function Get-CippReportTenantName { param($TenantFilter, $BrandingPresetId) }
    function ConvertTo-CippReportPdf { param($Blocks, $Variables, $TenantName, $TenantFilter, $ReportName, $BrandingPresetId) }
    function Get-CIPPSharePointSiteUsageReport { [CmdletBinding()] param($TenantFilter) throw 'No SharePoint site listing data found' }
    function Get-CIPPOneDriveUsageReport { [CmdletBinding()] param($TenantFilter) @() }
    function New-CIPPDbRequest { param($TenantFilter, $Type, $TableName) @() }
    function Build-CippStorageReportTree { param($Data) @{ Blocks = @(); Variables = @{} } }
    function Get-CippException { param($Exception) @{ NormalizedError = [string]$Exception } }
    function Write-LogMessage {}
}

Describe 'Report PDF branding preset' {
    BeforeEach {
        Mock Get-CippReportTenantName { 'Contoso' }
        Mock ConvertTo-CippReportPdf { [byte[]]@(37, 80, 68, 70, 45) }
    }

    It 'Invoke-ExecGetStorageReportPdf forwards brandingPresetId from the query' {
        $Request = @{
            Query  = @{ tenantFilter = 'contoso.onmicrosoft.com'; brandingPresetId = 'p1' }
            Body   = @{}
            Headers = @{}
        }

        $Response = Invoke-ExecGetStorageReportPdf -Request $Request -TriggerMetadata @{ FunctionName = 'Invoke-ExecGetStorageReportPdf' }

        $Response.StatusCode | Should -Be ([HttpStatusCode]::OK)
        Should -Invoke Get-CippReportTenantName -Times 1 -Exactly -ParameterFilter { $BrandingPresetId -eq 'p1' }
        Should -Invoke ConvertTo-CippReportPdf -Times 1 -Exactly -ParameterFilter { $BrandingPresetId -eq 'p1' }
    }
}

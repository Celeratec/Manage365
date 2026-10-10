function Invoke-ListIntuneTemplates {
    <#
    .FUNCTIONALITY
        Entrypoint,AnyTenant
    .ROLE
        Endpoint.MEM.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    $Table = Get-CippTable -tablename 'templates'
    $Imported = Get-CIPPAzDataTableEntity @Table -Filter "PartitionKey eq 'settings'"
    if ($Imported.IntuneTemplate -ne $true) {
        $Templates = Get-ChildItem (Join-Path $env:CIPPRootPath 'Config\*.IntuneTemplate.json') | ForEach-Object {
            $Entity = @{
                JSON         = "$(Get-Content $_)"
                RowKey       = "$($_.name)"
                PartitionKey = 'IntuneTemplate'
                GUID         = "$($_.name)"
            }
            Add-CIPPAzDataTableEntity @Table -Entity $Entity -Force
        }
        Add-CIPPAzDataTableEntity @Table -Entity @{
            IntuneTemplate = $true
            RowKey         = 'IntuneTemplate'
            PartitionKey   = 'settings'
        } -Force
    }
    #List new policies
    $Table = Get-CippTable -tablename 'templates'
    $Filter = "PartitionKey eq 'IntuneTemplate'"
    $RawTemplates = (Get-CIPPAzDataTableEntity @Table -Filter $Filter)
    if ($Request.query.View) {
        $Templates = $RawTemplates | ForEach-Object {
            try {
                $JSONData = $Row.JSON | ConvertFrom-Json -Depth 100 -ErrorAction SilentlyContinue
                $data = $JSONData.RAWJson | ConvertFrom-Json -Depth 100 -ErrorAction SilentlyContinue
                if ($null -eq $data) { throw 'RAWJson is empty or not valid JSON' }
                $data | Add-Member -NotePropertyMembers ([ordered]@{
                        displayName      = $JSONData.Displayname
                        description      = $JSONData.Description
                        Type             = $JSONData.Type
                        GUID             = $Row.RowKey
                        package          = $Row.Package
                        isSynced         = (![string]::IsNullOrEmpty($Row.SHA))
                        source           = $Row.Source
                        reusableSettings = $JSONData.ReusableSettings
                    }) -Force
                $data
            } catch {

            }

        } | Sort-Object -Property displayName
    } else {
        if ($Request.query.mode -eq 'Tag') {
            #when the mode is tag, show all the potential tags, return the object with: label: tag, value: tag, count: number of templates with that tag, unique only
            $Templates = @($RawTemplates | Where-Object { $_.Package } | Group-Object -Property Package | ForEach-Object {
                    $package = $_.Name
                    $packageTemplates = @($_.Group)
                    $templateCount = $packageTemplates.Count
                    [pscustomobject]@{
                        label         = "$($package) ($templateCount Templates)"
                        value         = $package
                        type          = 'tag'
                        templateCount = $templateCount
                        templates     = @($packageTemplates | ForEach-Object {
                                try {
                                    $JSONData = $_.JSON | ConvertFrom-Json -Depth 100 -ErrorAction SilentlyContinue
                                    $data = $JSONData.RAWJson | ConvertFrom-Json -Depth 100 -ErrorAction SilentlyContinue
                                    $data | Add-Member -NotePropertyMembers ([ordered]@{
                                            displayName      = $JSONData.Displayname
                                            description      = $JSONData.Description
                                            Type             = $JSONData.Type
                                            GUID             = $_.RowKey
                                            package          = $_.Package
                                            source           = $_.Source
                                            isSynced         = (![string]::IsNullOrEmpty($_.SHA))
                                            reusableSettings = $JSONData.ReusableSettings
                                        }) -Force
                                    $data
                                } catch {

                            }
                        })
                }
            } | Sort-Object -Property label)
        } else {
            $Templates = $RawTemplates.JSON | ForEach-Object { try { ConvertFrom-Json -InputObject $_ -Depth 20 -ErrorAction SilentlyContinue } catch {} }

        }
    }

    if ($Request.query.ID) { $Templates = $Templates | Where-Object -Property guid -EQ $Request.query.id }

    # Sort all output regardless of view condition
    $Templates = $Templates | Sort-Object -Property displayName

    return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = ConvertTo-Json -Depth 20 -InputObject @($Templates)
        })

}

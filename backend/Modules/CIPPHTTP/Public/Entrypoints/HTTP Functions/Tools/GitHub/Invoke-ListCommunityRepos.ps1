function Invoke-ListCommunityRepos {
    <#
    .SYNOPSIS
        List community repositories in Table Storage
    .DESCRIPTION
        This function lists community repositories in Table Storage
    .FUNCTIONALITY
        Entrypoint,AnyTenant
    .ROLE
        CIPP.Core.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $Table = Get-CIPPTable -TableName CommunityRepos

    if ($Request.Query.WriteAccess -eq 'true') {
        $Filter = "PartitionKey eq 'CommunityRepos' and WriteAccess eq true"
    } else {
        $Filter = "PartitionKey eq 'CommunityRepos'"
    }

    $Repos = Get-CIPPAzDataTableEntity @Table -Filter $Filter

    if (!$Request.Query.WriteAccess) {
        $CommunityRepos = Join-Path $env:CIPPRootPath 'Config\CommunityRepos.json'
        $DefaultCommunityRepos = [System.IO.File]::ReadAllText($CommunityRepos) | ConvertFrom-Json

        $DefaultsMissing = $false
        foreach ($Repo in $DefaultCommunityRepos) {
            if ($Repos.Url -notcontains $Repo.Url -or $Repos.Buitin -notcontains $Repo.BuiltIn) {
                $Entity = [PSCustomObject]@{
                    PartitionKey  = 'CommunityRepos'
                    RowKey        = $Repo.Id
                    BuiltIn       = $Repo.BuiltIn
                    Name          = $Repo.Name
                    Description   = $Repo.Description
                    URL           = $Repo.URL
                    FullName      = $Repo.FullName
                    Owner         = $Repo.Owner
                    Visibility    = $Repo.Visibility
                    WriteAccess   = $Repo.WriteAccess
                    DefaultBranch = $Repo.DefaultBranch
                    UploadBranch  = $Repo.DefaultBranch
                    Permissions   = [string]($Repo.RepoPermissions | ConvertTo-Json -ErrorAction SilentlyContinue -Compress)
                }
                Add-CIPPAzDataTableEntity @Table -Entity $Entity -Force
                $DefaultsChanged = $true
            } elseif ($Existing.TemplateTypes -ne $TemplateTypesJson -or $Existing.BuiltIn -ne $Repo.BuiltIn -or $Existing.Description -ne $Repo.Description -or $Existing.Name -ne $Repo.Name) {
                # Upgrade path: sync built-in metadata onto rows seeded by older versions
                $Existing | Add-Member -NotePropertyMembers ([ordered]@{
                        TemplateTypes = $TemplateTypesJson
                        BuiltIn       = $Repo.BuiltIn
                        Description   = $Repo.Description
                        Name          = $Repo.Name
                    }) -Force
                Add-CIPPAzDataTableEntity @Table -Entity $Existing -Force
                $DefaultsChanged = $true
            }
        }
        if ($DefaultsMissing) {
            $Repos = Get-CIPPAzDataTableEntity @Table -Filter "PartitionKey eq 'CommunityRepos'"
        }
    }

    $Repos = $Repos | ForEach-Object {
        [pscustomobject]@{
            Id              = $_.RowKey
            BuiltIn         = $_.BuiltIn
            Name            = $_.Name
            Description     = $_.Description
            URL             = $_.URL
            FullName        = $_.FullName
            Owner           = $_.Owner
            Visibility      = $_.Visibility
            WriteAccess     = $_.WriteAccess
            DefaultBranch   = $_.DefaultBranch
            UploadBranch    = $_.UploadBranch ?? $_.DefaultBranch
            RepoPermissions = ($_.Permissions | ConvertFrom-Json -ErrorAction SilentlyContinue) ?? @{}
        }
    }

    $Body = @{
        Results = @($Repos | Sort-Object -Property FullName)
    }

    return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = $Body
        })
}

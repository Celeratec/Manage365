function Invoke-ExecCippReplacemap {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.Config.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers

    $Table = Get-CippTable -tablename 'CippReplacemap'
    $Action = $Request.Query.Action ?? $Request.Body.Action
    $TenantId = $Request.Query.tenantId ?? $Request.Body.tenantId
    if ($TenantId -eq 'AllTenants') {
        $customerId = $TenantId
    } else {
        # ensure we use a consistent id for the table storage
        $Tenant = Get-Tenants -TenantFilter $TenantId
        $customerId = $Tenant.customerId
    }

    if (!$customerId) {
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = 'customerId is required'
            })
        return
    }

    switch ($Action) {
        'List' {
            $Variables = Get-CIPPAzDataTableEntity @Table -Filter "PartitionKey eq '$customerId'"
            if (!$Variables) {
                $Variables = @()
            }
            $Body = @{ Results = @($Variables) }
        }
        'AddEdit' {
            $VariableName = $Request.Body.RowKey
            $VariableValue = $Request.Body.Value
            $VariableDescription = $Request.Body.Description

            $VariableEntity = @{
                PartitionKey = $customerId
                RowKey       = $VariableName
                Value        = $VariableValue
                Description  = $VariableDescription
            }

            Add-CIPPAzDataTableEntity @Table -Entity $VariableEntity -Force
            $Result = "Variable '$VariableName' saved successfully"
            Write-LogMessage -headers $Headers -API $APIName -tenant $customerId -message $Result -Sev 'Info'
            $Body = @{ Results = $Result }
        }
        'Delete' {
            $VariableName = $Request.Body.RowKey

            $VariableEntity = Get-CIPPAzDataTableEntity @Table -Filter "PartitionKey eq '$customerId' and RowKey eq '$VariableName'"
            if ($VariableEntity) {
                Remove-CIPPAzDataTableEntity @Table -Entity $VariableEntity -Force
                $Result = "Variable '$VariableName' deleted successfully"
                Write-LogMessage -headers $Headers -API $APIName -tenant $customerId -message $Result -Sev 'Info'
                $Body = @{ Results = $Result }
            } else {
                $Body = @{ Results = "Variable '$VariableName' not found" }
            }
        }
        default {
            $Body = @{ Results = 'Invalid action' }
        }
    }

    return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = $Body
        })
}

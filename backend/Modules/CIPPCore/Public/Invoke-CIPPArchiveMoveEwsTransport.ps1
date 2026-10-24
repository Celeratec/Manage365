function Invoke-CIPPArchiveMoveEwsTransport {
    <#
    .SYNOPSIS
        EWS fallback for archive-to-primary moves when Graph import/export is unavailable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName,

        [Parameter(Mandatory = $true)]
        [hashtable]$JobEntity,

        [string]$TargetFolder,
        [string]$SourceFolder,
        [int]$MaxItemsPerRun = 40
    )

    $Headers = Get-GraphToken -tenantid $TenantFilter -scope 'https://outlook.office365.com/.default' -AsApp $true
    if (-not $Headers.Authorization) { throw 'Could not obtain EWS app token (outlook.office365.com scope).' }

    $EwsUrl = 'https://outlook.office365.com/EWS/Exchange.asmx'
    $SoapNs = 'http://schemas.xmlsoap.org/soap/envelope/'
    $TypesNs = 'http://schemas.microsoft.com/exchange/services/2006/types'
    $MessagesNs = 'http://schemas.microsoft.com/exchange/services/2006/messages'

    function Invoke-CIPPEwsSoap {
        param([string]$BodyInner)
        $Envelope = @"
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="$SoapNs" xmlns:t="$TypesNs" xmlns:m="$MessagesNs">
  <soap:Header>
    <t:RequestServerVersion Version="Exchange2016"/>
    <t:ExchangeImpersonation>
      <t:ConnectingSID>
        <t:PrimarySmtpAddress>$([System.Security.SecurityElement]::Escape($UserPrincipalName))</t:PrimarySmtpAddress>
      </t:ConnectingSID>
    </t:ExchangeImpersonation>
  </soap:Header>
  <soap:Body>
    $BodyInner
  </soap:Body>
</soap:Envelope>
"@
        $Raw = Invoke-WebRequest -Uri $EwsUrl -Method POST -Body $Envelope -Headers @{
            Authorization  = $Headers.Authorization
            'Content-Type' = 'text/xml; charset=utf-8'
        } -UseBasicParsing
        return [xml]$Raw.Content
    }

    $FindBody = @"
<m:FindItem Traversal="Shallow" xmlns:m="$MessagesNs">
  <m:ItemShape>
    <t:BaseShape>IdOnly</t:BaseShape>
    <t:AdditionalProperties>
      <t:FieldURI FieldURI="item:Size"/>
    </t:AdditionalProperties>
  </m:ItemShape>
  <m:IndexedPageItemView MaxEntriesReturned="$MaxItemsPerRun" Offset="0" BasePoint="Beginning"/>
  <m:ParentFolderIds>
    <t:DistinguishedFolderId Id="archivemsgfolderroot"/>
  </m:ParentFolderIds>
</m:FindItem>
"@

    $FindXml = Invoke-CIPPEwsSoap -BodyInner $FindBody
    $Items = @($FindXml.Envelope.Body.FindItemResponse.ResponseMessages.FindItemResponseMessage.RootFolder.Items.Item)
    if ($Items.Count -eq 0) {
        return [PSCustomObject]@{
            Complete       = $true
            MovedThisRun   = 0
            CheckpointJson = $JobEntity.CheckpointJson
            Transport      = 'EWS'
        }
    }

    $RestoreName = if ($TargetFolder) { $TargetFolder } else { 'Restored from Archive' }
    $Moved = 0
    foreach ($Item in $Items) {
        $ItemId = $Item.ItemId.Id
        $ChangeKey = $Item.ItemId.ChangeKey
        $Size = [long]$Item.Size

        $CopyBody = @"
<m:CopyItem xmlns:m="$MessagesNs">
  <m:ToFolderId>
    <t:DistinguishedFolderId Id="inbox"/>
  </m:ToFolderId>
  <m:ItemIds>
    <t:ItemId Id="$([System.Security.SecurityElement]::Escape($ItemId))" ChangeKey="$([System.Security.SecurityElement]::Escape($ChangeKey))"/>
  </m:ItemIds>
</m:CopyItem>
"@
        $CopyXml = Invoke-CIPPEwsSoap -BodyInner $CopyBody
        $CopyResp = $CopyXml.Envelope.Body.CopyItemResponse.ResponseMessages.CopyItemResponseMessage
        if ($CopyResp.ResponseClass -ne 'Success') {
            throw "EWS CopyItem failed: $($CopyResp.MessageText)"
        }
        $NewId = $CopyResp.Items.Item.ItemId.Id
        $NewSize = [long]$CopyResp.Items.Item.Size
        if ($NewSize -ne $Size) {
            throw "EWS verification failed (size $Size vs $NewSize) for item $ItemId."
        }

        $DeleteBody = @"
<m:DeleteItem DeleteType="MoveToDeletedItems" xmlns:m="$MessagesNs">
  <m:ItemIds>
    <t:ItemId Id="$([System.Security.SecurityElement]::Escape($ItemId))" ChangeKey="$([System.Security.SecurityElement]::Escape($ChangeKey))"/>
  </m:ItemIds>
</m:DeleteItem>
"@
        $DelXml = Invoke-CIPPEwsSoap -BodyInner $DeleteBody
        $DelResp = $DelXml.Envelope.Body.DeleteItemResponse.ResponseMessages.DeleteItemResponseMessage
        if ($DelResp.ResponseClass -ne 'Success') {
            throw "EWS delete source failed after copy for $ItemId : $($DelResp.MessageText)"
        }
        $Moved++
    }

    $More = $Items.Count -ge $MaxItemsPerRun
    return [PSCustomObject]@{
        Complete         = -not $More
        MovedThisRun     = $Moved
        CheckpointJson   = $JobEntity.CheckpointJson
        Transport        = 'EWS'
        PrimaryMailboxId = $null
        ArchiveMailboxId = $null
        Note             = "EWS fallback: ArchiveMsgFolderRoot -> Inbox (flat). Target folder name '$RestoreName' is not mirrored on EWS path."
    }
}

# Files

This tab lists the files Safe Attachments has quarantined from SharePoint, OneDrive, and Microsoft Teams for the selected tenant, so a file blocked in a document library can be reviewed and released without going into the Defender portal.

Quarantined files are a Microsoft Defender for Office 365 feature, so this tab stays empty for a tenant that is not protected by it. The message-level investigation actions offered for email do not apply to files, so this tab offers release and deletion only.

## Filters

| Filter       | Shows                                                                                  |
| ------------ | ---------------------------------------------------------------------------------------- |
| Not Released | Files still sitting in quarantine with no request against them.                        |
| Released     | Files that have already been released.                                                 |
| Requested    | Files a user has asked to have released, which are the ones waiting on your decision.  |

## Table Details

The properties returned are for the Exchange Online PowerShell command `Get-QuarantineMessage`. For more information on the command please see the [Microsoft documentation](https://learn.microsoft.com/powershell/module/exchangepowershell/get-quarantinemessage).

Files are listed newest first. Choosing AllTenants starts a background job to gather quarantined items from every tenant, so the table reports that it is still loading until that job finishes.

## Item Details

**More Info** opens a flyout with the quarantine record for the file: when it was quarantined and when it expires, the reason it was caught, the policy that caught it, its release history, and the identifiers Microsoft holds against it. Fields with no value are left out rather than shown empty. The actions offered in the table are repeated at the foot of the flyout.

The threat analysis shown for email messages does not apply here, so the flyout carries the quarantine record only.

## Table Actions

{% hint style="info" %}
Under AllTenants, each action runs against the tenant the file belongs to rather than against the tenant selected at the top of CIPP.
{% endhint %}

<table><thead><tr><th>Action</th><th>Description</th><th data-type="checkbox">Bulk Action Available</th></tr></thead><tbody><tr><td>Release</td><td>Releases the file back to the library it was quarantined from. Greyed out on a file that has already been released.</td><td>true</td></tr><tr><td>Delete from Quarantine</td><td>Permanently deletes the file from quarantine. Greyed out on a file that has already been released.</td><td>true</td></tr><tr><td>More Info</td><td>Opens the Extended Info flyout with the full details for the selected row.</td><td>false</td></tr></tbody></table>

{% hint style="danger" %}
**Delete from Quarantine** removes the file outright. There is no recovery afterwards.
{% endhint %}

{% include "../../../../../.gitbook/includes/feature-request.md" %}

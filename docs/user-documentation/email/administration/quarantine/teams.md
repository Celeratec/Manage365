# Teams Messages

This tab lists the Microsoft Teams messages that have been quarantined for the selected tenant, so a chat or channel message pulled out of a conversation can be reviewed and released without going into the Defender portal.

Teams message quarantine is a Microsoft Defender for Office 365 feature, so this tab stays empty for a tenant that is not protected by it. The mail-specific investigation actions offered for email do not apply to Teams messages, so this tab offers release and deletion only.

## Filters

| Filter       | Shows                                                                                       |
| ------------ | ----------------------------------------------------------------------------------------------- |
| Not Released | Messages still sitting in quarantine with no request against them.                          |
| Released     | Messages that have already been released.                                                   |
| Requested    | Messages a user has asked to have released, which are the ones waiting on your decision.    |

## Table Details

The properties returned are for the Exchange Online PowerShell command `Get-QuarantineMessage`. For more information on the command please see the [Microsoft documentation](https://learn.microsoft.com/powershell/module/exchangepowershell/get-quarantinemessage).

Messages are listed newest first. Choosing AllTenants starts a background job to gather quarantined items from every tenant, so the table reports that it is still loading until that job finishes.

## Item Details

**More Info** opens a flyout with the quarantine record for the message: when it was quarantined and when it expires, the reason it was caught, the policy that caught it, its release history, the recipients, and the type of conversation it came from. Fields with no value are left out rather than shown empty. The actions offered in the table are repeated at the foot of the flyout.

The threat analysis shown for email messages does not apply here, so the flyout carries the quarantine record only.

## Table Actions

{% hint style="info" %}
Under AllTenants, each action runs against the tenant the message belongs to rather than against the tenant selected at the top of CIPP.
{% endhint %}

<table><thead><tr><th>Action</th><th>Description</th><th data-type="checkbox">Bulk Action Available</th></tr></thead><tbody><tr><td>Release</td><td>Releases the message back into the conversation it was quarantined from. Greyed out on a message that has already been released.</td><td>true</td></tr><tr><td>Delete from Quarantine</td><td>Permanently deletes the message from quarantine. Greyed out on a message that has already been released.</td><td>true</td></tr><tr><td>More Info</td><td>Opens the Extended Info flyout with the full details for the selected row.</td><td>false</td></tr></tbody></table>

{% hint style="danger" %}
**Delete from Quarantine** removes the message outright. There is no recovery afterwards.
{% endhint %}

{% include "../../../../../.gitbook/includes/feature-request.md" %}

# Room Lists

This page lists the room lists in the selected tenant. Room lists group room mailboxes together so users can browse them in the room finder, for example all rooms in one building or all rooms on one floor. A room list is a distribution group flagged as a room list, so adding and removing rooms is a membership change rather than a change to the rooms themselves.

## Action Buttons

<details>

<summary>Add Room List</summary>

Creates a new room list in the selected tenant.

| Field          | Description                                                                                                 |
| -------------- | ----------------------------------------------------------------------------------------------------------- |
| Display Name   | The name shown in the address list and in the room finder. Required.                                        |
| Username       | The part before the @ symbol. Required, and limited to letters, numbers, hyphens, underscores, and periods. |
| Primary Domain | The domain used after the @ symbol, chosen from the tenant's verified domains. Required.                    |

**Create Room List** submits the form. The list is created empty, so add rooms to it afterwards on the [edit.md](edit.md "mention") page. Once a list has been created the button changes to **Create Another**, so the drawer can be reused without closing it.

</details>

## Table Details

The properties returned are for the Exchange Online PowerShell command `Get-DistributionGroup` with a filter for `RoomList`. For more information on the command please see the [Microsoft documentation](https://learn.microsoft.com/en-us/powershell/module/exchange/get-distributiongroup?view=exchange-ps).

**More Info** opens the Extended Info flyout, which shows the room list's display name, address, identity, phone, notes, and GUID.

## Table Actions

<table><thead><tr><th>Action</th><th>Description</th><th data-type="checkbox">Bulk Action Available</th></tr></thead><tbody><tr><td>Edit Room List</td><td>Opens the <a data-mention href="edit.md">edit.md</a> page with the selected row's room list pre-populated.</td><td>false</td></tr><tr><td>Delete Room List</td><td>Deletes the selected room list. The rooms it contained are left in place. Asks for confirmation first.</td><td>true</td></tr><tr><td>More Info</td><td>Opens the Extended Info flyout with the full details for the selected row.</td><td>false</td></tr></tbody></table>

{% include "../../../../../../.gitbook/includes/feature-request.md" %}

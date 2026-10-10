---
description: View OneDrive information for users in your Microsoft 365 tenants.
---

# OneDrive

This page lists every user's OneDrive in the selected tenant, with the storage it is consuming, the number of files it holds, and when it was last used. Use it to check how well a rollout is going, find accounts that are sitting idle, and spot users approaching their storage allocation. You can also grant another user access to someone's OneDrive from here.

{% hint style="warning" %}
The activity, file count and storage figures come from Microsoft's usage reporting, aggregated over a seven day window rather than showing the position at this moment. Microsoft refreshes that reporting once a day, so a change made today will not appear straight away. The **Report Refresh Date** column tells you how current the figures are.
{% endhint %}

## Table Details

| Column                        | Description                                                                                      |
| ----------------------------- | ------------------------------------------------------------------------------------------------ |
| Display Name                  | The name of the user's OneDrive.                                                                 |
| Created Date Time             | When the OneDrive was created.                                                                   |
| Owner Principal Name          | The user the OneDrive belongs to.                                                                |
| Last Activity Date            | The last date any activity was recorded on the OneDrive. Blank when there has been none.         |
| File Count                    | The number of files stored in the OneDrive.                                                      |
| Storage Used In Gigabytes     | How much storage the OneDrive is using, rounded to two decimal places.                           |
| Storage Allocated In Gigabytes | The storage quota allocated to the OneDrive, rounded to two decimal places.                      |
| Report Refresh Date           | The date Microsoft last refreshed the usage figures behind this report.                          |
| Web Url                       | The address of the OneDrive.                                                                     |

## Table Actions

<table><thead><tr><th>Action</th><th>Description</th><th data-type="checkbox">Bulk Action Available</th></tr></thead><tbody><tr><td>Add permissions to OneDrive</td><td>Grants another user access to the selected user's OneDrive. You pick the user to grant access to from a list of everyone in the tenant.</td><td>true</td></tr><tr><td>Remove permissions from OneDrive</td><td>Removes another user's access to the selected user's OneDrive. You pick the user to remove from a list of everyone in the tenant.</td><td>true</td></tr><tr><td>Edit OneDrive Site</td><td>Edits the OneDrive site's properties, prefilled with the current values: the storage quota and warning level, sharing settings, lock state, and file version policy. Selecting multiple rows applies the same values to each OneDrive. Greyed out unless you have SharePoint site write access.</td><td>true</td></tr><tr><td>Reactivate Archived OneDrive</td><td>Reactivates an archived OneDrive so it can be used again. Reactivation is asynchronous and can take up to 24 hours, may incur Microsoft 365 Archive charges, and needs Unlicensed OneDrive billing enabled on the tenant. The account stays active for 30 days before it is archived again. Greyed out unless you have SharePoint site write access.</td><td>true</td></tr></tbody></table>

{% include "../../../.gitbook/includes/feature-request.md" %}

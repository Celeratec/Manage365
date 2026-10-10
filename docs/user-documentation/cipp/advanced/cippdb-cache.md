# CIPPDB Cache

CIPPDB Cache lets SuperAdmins browse CIPP reporting cache collections in `CippReportingDB`, delete individual records, empty an entire cache type for a tenant, or queue a fresh sync from Microsoft. Prefer this page over Table Maintenance when you need to inspect or clear typed CIPPDB data.

{% hint style="danger" %}
This is advanced SuperAdmin functionality. Deletes take effect immediately and cannot be undone. Emptied or removed rows only return after the next nightly CIPPDB run or a manual **Sync Cache** from this page (or Refresh CIPPDB Cache from Settings → Tenants).
{% endhint %}

## Selecting a Cache Type

The panel on the left lists every cache type from the CIPPDB catalogue. Selecting a type loads its rows for the tenant currently chosen in the CIPP header.

| Control         | Description                                                                                                                   |
| --------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Search box      | Filters the type list as you type. Matches friendly name, type key, and description (case-insensitive).                       |
| Category filter | Restricts the type list to one category (Identity, Exchange, Intune, and so on), or **All**.                                  |

## Tenant Scope

This page uses the global tenant picker in the CIPP header. There is no separate tenant selector on the page. Changing the header tenant clears the grid and reloads the selected type for the new tenant when one is already selected.

**AllTenants** is allowed and performs a cross-partition read for that type. Prefer a single tenant for large collections.

## Cache Contents

Rows are decoded cache objects. Columns are derived from the returned data. Storage keys used for deletes (`CIPPPartitionKey`, `CIPPRowKey`, `CIPPETag`) are kept on each row but hidden from the default column set. When the tenant is **AllTenants**, a **Tenant** column is added from each row's partition key.

| Button      | Description                                                                                                                                                                                                 |
| ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Sync Cache  | Queues a re-collection of the selected type from Microsoft for the current tenant (or every tenant when AllTenants is selected). Runs in the background; the grid refreshes when the queue finishes. Some listing types are filled by another collector and cannot be synced on their own. |
| Empty Cache | Deletes every data row of the selected type for the selected tenant and resets that type's count metadata to zero, after confirmation. When the tenant is AllTenants, every partition for that type is cleared. |
| Refresh     | Reloads the current type for the current header tenant (table toolbar).                                                                                                                                     |

{% hint style="warning" %}
Emptying a cache for AllTenants is a cross-tenant wipe of that collection. Confirm carefully.
{% endhint %}

{% hint style="info" %}
A **Mailboxes** sync from this page collects mailbox rows only. Mailbox permissions, calendar permissions, and rules are separate cache types and must be synced on their own.
{% endhint %}

## Row Actions

| Action | Description                                                                  | Bulk |
| ------ | ---------------------------------------------------------------------------- | ---- |
| Delete | Removes the selected cache record(s) and decrements the type count metadata. | Yes  |

{% hint style="info" %}
Large collections (Users, Devices, Mailboxes, SharePoint permissions, and similar) can take time to load. Prefer a single tenant unless you need an estate-wide view.
{% endhint %}

{% include "../../../../.gitbook/includes/feature-request.md" %}

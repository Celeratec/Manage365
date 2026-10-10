---
description: View captured Audit Logs from the Alerts Wizard.
---

# Audit Logs

CIPP stores a copy of any audit log entry that matches an Audit Log Alert rule, so you keep a durable record even after the entry ages out of the tenant. This page lists those saved entries and lets you open any of them in full. Entries are only captured going forward from the point an alert rule exists, so nothing appears here for a rule that has not yet matched.

## Search Options

The Search Options panel controls the time window the table covers. It defaults to the last 7 days.

| Field            | Description                                                                                               |
| ---------------- | --------------------------------------------------------------------------------------------------------- |
| Date Filter Type | Choose `Relative` to look back a set amount of time from now or `Start / End` to specify an exact window. |
| Last             | Shown for a relative filter. The number of hours or days to look back.                                    |
| Interval         | Shown for a relative filter. Whether the number above counts Hours or Days.                               |
| Start Date       | Shown for a start and end filter. The beginning of the window.                                            |
| End Date         | Shown for a start and end filter. The end of the window.                                                  |

Select **Apply Filters** to reload the table for the chosen window. Use the table's own filter and search to narrow the results further.

## Table Details

| Column    | Description                                                                                                         |
| --------- | ------------------------------------------------------------------------------------------------------------------- |
| Timestamp | When the original event occurred in the tenant, taken from the raw audit record rather than the time CIPP saved it. |
| Tenant    | The tenant the entry was captured from.                                                                             |
| Title     | A short summary of what the alert matched, generated when the entry was processed.                                  |

{% hint style="info" %}
The table respects the tenant selected at the top of CIPP. Choose All Tenants to see captured entries from every tenant in one list.
{% endhint %}

## Table Actions

<table><thead><tr><th>Action</th><th>Description</th><th data-type="checkbox">Bulk Action Available</th></tr></thead><tbody><tr><td>View Log</td><td>Opens the full structured view of the selected entry, including the raw audit record, any actions CIPP took, and geolocation for the originating IP address where one is available.</td><td>false</td></tr><tr><td>More Info</td><td>Opens the Extended Info flyout with the full details for the selected row.</td><td>false</td></tr></tbody></table>

{% include "../../../../../.gitbook/includes/feature-request.md" %}

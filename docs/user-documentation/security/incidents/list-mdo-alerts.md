# Defender Alerts

Alerts raised by Microsoft Defender for Office 365 and Microsoft Defender for Endpoint in the selected tenant, narrowed to those two products so mail, collaboration, and endpoint threats are not buried among identity and other alerts. Use the **Service Source** column to tell which product raised each alert. Take an alert, move it through its statuses, and open it in the Defender portal when you need the full picture.

## Table Details

The properties returned are for the Graph resource type `alert`, filtered to `serviceSource eq 'microsoftDefenderForOffice365' or serviceSource eq 'microsoftDefenderForEndpoint'`. For more information on the properties please see the [Graph documentation](https://learn.microsoft.com/en-us/graph/api/resources/security-alert?view=graph-rest-beta#properties).

The Extended Info flyout goes considerably further than the table, adding the alert description and recommended actions, the evidence and affected resources behind it, the MITRE techniques matched, any named threat or actor, the detection source, and the first and last activity times.

{% hint style="info" %}
Selecting All Tenants queues a background job that collects alerts from every tenant, and the page tells you it is still loading. Come back in a few minutes for a complete list.
{% endhint %}

## Table Actions

<table><thead><tr><th>Action</th><th>Description</th><th data-type="checkbox">Bulk Action Available</th></tr></thead><tbody><tr><td>Assign to self</td><td>Puts your name on the alert as its owner.</td><td>true</td></tr><tr><td>Set status to active</td><td>Moves the alert back into the active queue.</td><td>true</td></tr><tr><td>Set status to in progress</td><td>Marks the alert as being worked on.</td><td>true</td></tr><tr><td>Set status to resolved</td><td>Closes the alert.</td><td>true</td></tr><tr><td>More Info</td><td>Opens the Extended Info flyout with the full details for the selected row.</td><td>false</td></tr></tbody></table>

{% include "../../../../.gitbook/includes/feature-request.md" %}

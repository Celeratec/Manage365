# Non-Compliant Devices

Non-Compliant Devices shows every failing compliance setting on every non-compliant device, from Intune's NoncompliantDevicesAndSettings report via the CIPP report-export cache. Use it when you need the per-setting reason a device is non-compliant, not only the device's overall compliance state.

{% hint style="info" %}
The data comes from the Intune report-export cache (`IntuneNonCompliantSettings`). If the table is empty, confirm the tenant's Intune report exports have run and that the NoncompliantDevicesAndSettings export completed.
{% endhint %}

## Overview

Chart segments summarise failing settings by policy. Selecting a segment filters the table to that policy. Intune's built-in **Default Device Compliance Policy** is flagged when it appears, because the export does not carry a policy id for it.

## Table Details

| Column       | Description                                                                                         |
| ------------ | --------------------------------------------------------------------------------------------------- |
| Device       | The managed device name, with drill-down to View Device and Sync Device where available.            |
| Policy       | The compliance policy that reported the failing setting.                                            |
| Setting      | The setting name that failed.                                                                       |
| Error code   | Intune's signed error code, shown as hex (for example `0x87D1FDE8`) with the decimal in parentheses.|

## Table Actions

Device actions available from the row match the subset of Intune device actions offered for View and Sync. Open the device page for the full action set.

{% include "../../../../.gitbook/includes/feature-request.md" %}

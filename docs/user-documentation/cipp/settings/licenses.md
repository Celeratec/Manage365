# Licenses

Excluded licences are SKUs that CIPP leaves out of its licence counts and reporting. The list is seeded with a set of defaults covering free and trial SKUs that would otherwise inflate reports, and you can add or remove entries to suit your own reporting. Exclusions apply across the whole instance rather than per tenant.

## Exclusion Types

An exclusion works in one of two ways, shown in the Exclusion Type column.

| Type                      | Description                                                                                                                                                                              |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Excluded Everywhere       | The licence is left out of licence reporting, alerts, and the data sent to integrations such as Gradient. This is the default for a newly added exclusion.                               |
| Excluded from Alerts Only | The licence still appears in licence reports and integration data, but is ignored when alerts are evaluated. Use this for SKUs you want visibility of without being notified about them. |

Separately from the exclusion type, each entry carries a flag controlling whether the licence still appears in CIPP's licence pickers.

{% hint style="info" %}
Excluding a licence hides it from reporting, but it does not stop the licence existing in the tenant or being assignable in Microsoft 365. A licence stays visible in CIPP's own licence pickers by default even while excluded, so you can still assign it from within CIPP; use **Hide from License Dropdowns** if you also want it out of the pickers.
{% endhint %}

## Page Actions

| Button                                                              | Description                                                          |
| ------------------------------------------------------------------- | -------------------------------------------------------------------- |
| [#add-excluded-license](licenses.md#add-excluded-license "mention") | Adds a licence to the exclusion list.                                |
| [#restore-defaults](licenses.md#restore-defaults "mention")         | Re-applies CIPP's default exclusions from its bundled configuration. |

### Add Excluded License

The dialog offers two ways of identifying the licence.

| Field          | Description                                                                                                                                                                                                |
| -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Advanced Mode  | Switches from picking a known licence to entering the details by hand. Leave off unless the licence you want is not in the list.                                                                           |
| Select License | The licence to exclude, chosen from CIPP's built-in list of Microsoft 365 SKUs. Where two products share a display name, the GUID is appended so you can tell them apart. Shown when Advanced Mode is off. |
| GUID           | The SKU identifier of the licence, for example `f30db892-07e9-47e9-837c-80727f46fd3d`. Shown when Advanced Mode is on.                                                                                     |
| SKU Name       | The display name to record against the GUID, for example `MICROSOFT FLOW FREE`. Shown when Advanced Mode is on.                                                                                            |

{% hint style="info" %}
Microsoft publish the full list of product names, SKU identifiers and service plans in their [licensing service plan reference](https://learn.microsoft.com/entra/identity/users/licensing-service-plan-reference), which is the place to look up a GUID for Advanced Mode.
{% endhint %}

A licence added this way is set to Excluded Everywhere. Change it afterwards with the **Only Exclude from Alerts** row action if you want the narrower behaviour.

### Restore Defaults

| Field                                                        | Description                                                                                                                                                                     |
| ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Full Reset (clear all entries including manually added ones) | Clears the entire list before restoring the defaults. Leave this off to add any missing defaults while keeping your own entries and any changes you have made to existing ones. |

{% hint style="danger" %}
A full reset deletes every entry in the list, including licences you added yourself and any exclusions you switched to alerts only. There is no undo, so leave the switch off unless you genuinely want to start again.
{% endhint %}

## Table Details

| Column                   | Description                                                                         |
| ------------------------ | ----------------------------------------------------------------------------------- |
| Product Display Name     | The name of the excluded licence.                                                   |
| GUID                     | The SKU identifier of the licence.                                                  |
| Exclusion Type           | Whether the licence is excluded everywhere or only from alerts.                     |
| Show In License Dropdown | Whether the licence still appears in CIPP's licence pickers despite being excluded. |

## Table Actions

<table><thead><tr><th>Action</th><th>Description</th><th data-type="checkbox">Bulk Action Available</th></tr></thead><tbody><tr><td>Only Exclude from Alerts</td><td>Narrows the exclusion so the licence is ignored by alerts but still appears in reports and integration data.</td><td>true</td></tr><tr><td>Show in License Dropdowns</td><td>Makes the licence selectable in CIPP's licence pickers again. Only offered for licences currently hidden from them.</td><td>true</td></tr><tr><td>Hide from License Dropdowns</td><td>Removes the licence from CIPP's licence pickers. Only offered for licences currently shown in them.</td><td>true</td></tr><tr><td>Delete Exclusion</td><td>Removes the licence from the exclusion list, so it is counted and reported on again.</td><td>true</td></tr><tr><td>More Info</td><td>Opens the Extended Info flyout with the full details for the selected row.</td><td>false</td></tr></tbody></table>

{% include "../../../../.gitbook/includes/feature-request.md" %}

# Named Locations

Named locations are the reusable IP ranges and country groupings that Conditional Access policies reference in their location conditions. This page lists the named locations configured in the selected tenant and lets you maintain them without leaving CIPP.

There are two kinds, and they behave differently: **IP** locations hold CIDR ranges and can be marked trusted, while **country** locations hold a list of countries or regions. Which actions are offered on a row depends on which kind it is.

## Action Buttons

{% content-ref url="add.md" %}
[add.md](add.md)
{% endcontent-ref %}

## Table Details

| Column                                | Description                                                                                                            |
| ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Display Name                          | The name of the named location, as referenced by policies.                                                             |
| Include Unknown Countries And Regions | For country locations, whether addresses that cannot be mapped to a country are included.                              |
| Is Trusted                            | For IP locations, whether the location is marked as trusted.                                                           |
| Range Or Location                     | A summary of the location's contents: the CIDR ranges for an IP location, or the country codes for a country location. |
| Modified Date Time                    | When the named location was last changed.                                                                              |

{% hint style="info" %}
Range Or Location is composed by CIPP rather than returned by Graph, so it shows whichever of the two lists applies to that row. For the remaining properties, see the Graph documentation for the [namedLocation](https://learn.microsoft.com/en-us/graph/api/resources/namedlocation?view=graph-rest-beta) resource type and its `ipNamedLocation` and `countryNamedLocation` subtypes.
{% endhint %}

## Table Actions

<table><thead><tr><th>Action</th><th>Description</th><th data-type="checkbox">Bulk Action Available</th></tr></thead><tbody><tr><td>Rename named location</td><td>Changes the display name. Policies referencing the location by name follow the rename.</td><td>true</td></tr><tr><td>Mark as Trusted</td><td>Marks the location as trusted. Only shown on IP locations that are not already trusted.</td><td>true</td></tr><tr><td>Mark as Untrusted</td><td>Removes the trusted flag. Only shown on IP locations that are currently trusted.</td><td>true</td></tr><tr><td>Add location to named location</td><td>Adds a country to the location. Countries already present are not offered. Only shown on country locations.</td><td>true</td></tr><tr><td>Remove location from named location</td><td>Removes one or more countries. At least one country must remain, so this is only shown on country locations holding more than one.</td><td>true</td></tr><tr><td>Add IP to named location</td><td>Adds a CIDR range. Only shown on IP locations.</td><td>true</td></tr><tr><td>Remove IP from named location</td><td>Removes one or more CIDR ranges. At least one range must remain, so this is only shown on IP locations holding more than one.</td><td>true</td></tr><tr><td>Delete named location</td><td>Deletes the named location. This cannot be undone.</td><td>true</td></tr></tbody></table>

{% hint style="warning" %}
A named location that a Conditional Access template deploys is rewritten to the template's stored values every time that template is applied through a standard, so edits made here are undone on the next run. Change the ranges on the template instead, as described on [create-ca-template.md](../list-template/create-ca-template.md "mention").
{% endhint %}

{% hint style="warning" %}
Deleting a named location does not update the Conditional Access policies that reference it. Check which policies use a location before removing it, or you may leave a policy with a condition that no longer resolves.
{% endhint %}

### IP Address Format

**Add IP to named location** requires CIDR notation and validates it before submitting.

| Type | Format          | Prefix range |
| ---- | --------------- | ------------ |
| IPv4 | `1.1.1.1/32`    | /9 to /32    |
| IPv6 | `2001:db8::/32` | /9 to /128   |

{% include "../../../../../.gitbook/includes/feature-request.md" %}

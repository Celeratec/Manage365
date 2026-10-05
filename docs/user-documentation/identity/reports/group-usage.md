# Group Usage Report

This report lists every group in the selected tenant together with where it is actually used: Conditional Access policies, Intune assignments, Entra role assignments, enterprise application assignments, group-based licensing, Microsoft Teams, nested group membership and Exchange transport rules. Groups nothing references are marked as unused, which makes this the quickest way to find groups that can be cleaned up, and to check what would break before removing one.

## Filters

| Filter                     | Shows                                                                    |
| -------------------------- | ------------------------------------------------------------------------ |
| Unused groups              | Groups that nothing currently references, so are candidates for cleanup. |
| Used in Conditional Access | Groups referenced by at least one Conditional Access policy.             |
| Used in Intune             | Groups referenced by at least one Intune assignment.                     |
| Used for licensing         | Groups used to assign licences through group-based licensing.            |

## Table Details

| Column         | Description                                                                                                                                                    |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Display Name   | The name of the group.                                                                                                                                        |
| Group Type     | The kind of group, worked out by CIPP from the group's underlying flags: Microsoft 365, Mail-Enabled Security, Security or Distribution List.                |
| Mail           | The group's email address, where it has one.                                                                                                                  |
| Used Locations | The categories of place that reference the group: Conditional Access, Intune, Entra Roles, Enterprise Applications, Licensing, Teams, Exchange or Group Nesting (membership of another group). Blank when the group is unused. |
| Used In        | The specific policy, assignment or rule behind each reference, one entry per match.                                                                           |
| Usage Count    | How many references **Used In** lists.                                                                                                                        |
| Is Used        | Whether the group has any references at all. No when **Usage Count** is zero.                                                                                 |

{% hint style="info" %}
This report joins several independently cached data sources: groups, Conditional Access, Intune, roles, applications, licences and transport rules. The **Sync** button here refreshes all of them together, which can take a few minutes for larger tenants.
{% endhint %}

{% include "../../../../.gitbook/includes/feature-request.md" %}

# Map an existing group (Advanced)

This page maps a GDAP role to a security group that already exists in your partner tenant, rather than creating one. Use it when your groups do not follow the `M365 GDAP RoleName` naming convention, for example when bringing an existing GDAP setup into CIPP. For everything else, build a [role template](../ "mention") - it creates and maps the groups for you.

Select a group and a role, then use the add button to build up the list of mappings. Each pairing appears in the Role Mappings table below, where it can be removed again before you submit.

| Field            | Description                                        |
| ---------------- | -------------------------------------------------- |
| Select Group     | An existing security group in your partner tenant. |
| Select GDAP Role | The role to assign through that group.             |

{% hint style="warning" %}
This is an advanced page. Use extreme caution. The following limitations apply:

* Reserved groups and roles are unavailable for mapping, to prevent misconfigurations due to permission overlap.
* Only one role can be mapped per group. If your current configuration maps more than one, use the **Reset Role Mapping** action on the relationship.
* Certain roles may not be compatible with GDAP. See the [Microsoft documentation](https://learn.microsoft.com/en-us/partner-center/customers/gdap-least-privileged-roles-by-task) on GDAP role guidance.
{% endhint %}

{% include "../../../../../../.gitbook/includes/feature-request.md" %}

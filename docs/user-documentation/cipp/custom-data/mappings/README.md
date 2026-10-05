# Mappings

Custom data mappings connect a source of information to a custom data attribute on a directory object, for one or more tenants. A mapping either populates the attribute automatically from CIPP's reporting database on a daily schedule, or exposes it as a field your technicians complete on the user forms.

You need at least one directory extension or schema extension before a mapping can be created, because the mapping needs somewhere to write the value.

{% hint style="warning" %}
Creating, editing and deleting mappings requires a role with unrestricted tenant access, meaning **Allowed Tenants** left as `AllTenants` with nothing in **Blocked Tenants**. A role scoped to particular tenants or tenant groups is refused these actions, and the list it sees is narrowed to the mappings that target tenants within its scope. See [roles.md](../../../../setup/setting-up-cipp/roles.md "mention").
{% endhint %}

## Action Buttons

{% content-ref url="add.md" %}
[add.md](add.md)
{% endcontent-ref %}

## Table Details

| Column                | Description                                                                                                                                                   |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Tenant                | The tenants the mapping applies to. All Tenants applies the mapping everywhere.                                                                               |
| Source Type           | Where the value comes from: Reporting DB for automatic synchronisation, or Manual Entry for a technician-completed field.                                     |
| Dataset               | For Reporting DB mappings, the cached dataset the value is read from. Shows N/A for Manual Entry mappings.                                                    |
| Sync Property         | The property within the dataset that is copied. For array datasets this lists the fields captured in each entry instead. Shows N/A for Manual Entry mappings. |
| Directory Object      | The directory object type the value is written to.                                                                                                            |
| Custom Data Attribute | The directory extension or schema extension property the value is written to.                                                                                 |

## Table Actions

<table><thead><tr><th>Action</th><th>Description</th><th data-type="checkbox">Bulk Action Available</th></tr></thead><tbody><tr><td>Edit Mapping</td><td>Opens the page to change the mapping's tenants, source, or destination.</td><td>false</td></tr><tr><td>Delete Mapping</td><td>Removes the mapping after confirmation. Values already written to directory objects are left in place.</td><td>true</td></tr></tbody></table>

{% hint style="info" %}
Adding or deleting a Reporting DB mapping re-registers the scheduled synchronisation tasks, so no further action is needed to start or stop the daily sync.
{% endhint %}

{% include "../../../../../.gitbook/includes/feature-request.md" %}

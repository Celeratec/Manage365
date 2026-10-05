# CIPP Roles

A page for super admins to manage the custom roles deployed to their CIPP instance. Please see the User Roles in CIPP page on [#custom-roles](../../../../../setup/setting-up-cipp/roles.md#custom-roles "mention") for instructions and notes/limitations.

## Table Details

| Column          | Description                              |
| --------------- | ---------------------------------------- |
| Role Name       | The name given to the role               |
| Type            | The type of role: Built-In or Custom     |
| Entra Group     | The Entra group name, if one is assigned |
| Allowed Tenants | The list of allowed tenants              |
| Blocked Tenants | The list of blocked tenants              |

## Table Actions

<table><thead><tr><th>Action</th><th>Description</th><th data-type="checkbox">Bulk Action Available</th></tr></thead><tbody><tr><td>Impersonate Role</td><td>Reloads CIPP as though you hold only this role, so you can see what it can reach. Shown to super admins only, and not offered on the <code>superadmin</code> role.</td><td>false</td></tr><tr><td>Edit</td><td>Allows you to edit the custom role.</td><td>false</td></tr><tr><td>Clone</td><td>Allows you to use an existing custom role to use as a starting point for a new role</td><td>true</td></tr><tr><td>Delete</td><td>Deletes the selected role(s)</td><td>true</td></tr><tr><td>More Info</td><td>Opens the Extended Info flyout with the full details for the selected row.</td><td>false</td></tr></tbody></table>

## Reading a Role's Permissions

**More Info** lists a role's **Permission Rules** where it has them, showing include patterns in green and exclude patterns in red. The permission list beneath is labelled **Effective Permissions (at last save)**, because a role built from patterns is expanded against the current permission list each time it is evaluated, and the stored list only records what those patterns matched when the role was saved.

## Impersonating a Role

Super admins can check a role by working in it for a moment rather than reading its permission list. **Impersonate Role** reloads CIPP with only that role's permissions and tenant scope in force, and a banner across the top of every page names the role until **Exit impersonation** is selected.

Access is enforced by the API for the duration, so anything the role cannot do fails exactly as it would for a real user. Impersonation can only reduce what you reach: the `superadmin` role cannot be impersonated, and the action itself disappears while impersonating, so one role cannot be nested inside another.

{% hint style="warning" %}
This shows a single role on its own. Real users often hold a base role alongside one or more custom roles, where the custom roles narrow the base role rather than adding to it, so their access can differ from what you see here. IP restrictions are not simulated. See [how-cipp-evaluates-roles.md](../../../../../setup/resources/how-cipp-evaluates-roles.md "mention") for how roles combine.
{% endhint %}

{% include "../../../../../../.gitbook/includes/feature-request.md" %}

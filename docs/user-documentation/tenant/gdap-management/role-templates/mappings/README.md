# Group Mappings

This page lists the GDAP roles that have been mapped to security groups in your partner tenant. Each mapping tells CIPP which group to assign a role through when it sets up a relationship, so a technician gains delegated access by being a member of the mapped group.

You do not normally need this page: building a [role template](../ "mention") creates and maps the groups for you. Use it to review what exists, to see which templates depend on a mapping, and to check that every mapping still points at a real security group. Mapping a group by hand is an advanced option, reached from **Map an existing group (Advanced)** ([add.md](add.md "mention")), for groups that already exist and do not follow the `M365 GDAP RoleName` naming.

Each mapping is checked against the partner tenant when the page loads:

* **Valid** - the mapping points at an existing security group.
* **Stale** - the group exists under the expected name, but the stored group id is out of date.
* **Missing** - no group with that name exists any more.
* **Unknown** - the partner tenant groups could not be read; the mappings themselves are unaffected.

If anything is Stale or Missing, use **Repair mappings**. The button opens a dialog before anything is changed, listing:

* **What will change** - every stale or missing mapping, the group it uses today, and what repair will do: re-link it to the existing group of that name, or recreate the group. Mappings that are already valid are summarised as a count.
* **Next steps** - what to do once the repair has run.

{% hint style="warning" %}
A recreated group is a **new, empty security group**. Your technicians are not carried over, so re-add them before they regain access.
{% endhint %}

After repairing:

* Every role template is updated automatically with the corrected group ids.
* Relationships that already had assignments against a missing group need the **Reset Role Mapping** action on the [relationship](../../relationships/ "mention"), or a re-run of onboarding.
* Re-run the GDAP check on the [overview](../../ "mention") to confirm the result.

The button is disabled when every mapping is valid. If the check could not run, the dialog says so and repair still attempts the fix. Open a row for the full status message.

## Table Details

| Column            | Description                                                                                       |
| ----------------- | ------------------------------------------------------------------------------------------------- |
| Role Name         | The name of the GDAP role associated with the mapping.                                            |
| Group Name        | The name of the Entra ID security group in your partner tenant that the role is assigned through. |
| Group Status      | Whether the mapped security group still exists: Valid, Stale, Missing or Unknown.                 |
| Used In Templates | The role templates that include this mapping.                                                     |

## Table Actions

<table><thead><tr><th>Action</th><th>Description</th><th data-type="checkbox">Bulk Action Available</th></tr></thead><tbody><tr><td>Delete Mapping</td><td>Removes the mapping from CIPP. Any role template that uses it loses that role. The security group itself is not deleted and existing GDAP relationships are not changed.</td><td>true</td></tr></tbody></table>

{% include "../../../../../../.gitbook/includes/feature-request.md" %}

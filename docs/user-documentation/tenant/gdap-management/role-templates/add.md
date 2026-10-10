# Add Template

This page creates a new GDAP role template: a named set of admin roles that invites and onboardings are built from.

Pick the roles your technicians need. Each role targets the group `M365 GDAP RoleName`, or `M365 GDAP RoleName - Suffix` when a custom suffix is set. Roles whose target group already exists are listed under **Mapped to a group**, with the group name shown beneath the role; the rest are listed under **Not mapped yet** and CIPP creates their group when you save. Changing the suffix re-groups the list, so it always reflects what will actually happen.

Groups that do not follow the naming convention appear as their own entries, marked as a custom group. Those stay pinned to that group whatever the suffix is set to.

| Field         | Description                                                                                               |
| ------------- | ----------------------------------------------------------------------------------------------------------- |
| Template Name | The name for the template. This is the value shown when selecting a template elsewhere in CIPP. Required. |
| Admin Roles   | The roles the template grants. At least one role is required.                                             |

Click **Add CIPP Default Roles** to select the 15 recommended roles from the recommended-roles.md page. Once roles are selected, the **Group mappings** list shows the group each role resolves to, and whether that group already exists or will be created.

## Advanced

| Field                    | Description                                                                                                                                                                        |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Custom Suffix (optional) | Changes which group every selected role uses, to `M365 GDAP RoleName - Suffix`. A group with that name is reused if it exists, otherwise it is created. Use this to keep separate groups per team or department. Roles pinned to a specific group (see below) are unaffected. |

{% hint style="danger" %}
Certain roles may not be compatible with GDAP. See the [Microsoft documentation](https://learn.microsoft.com/en-us/partner-center/customers/gdap-least-privileged-roles-by-task) on GDAP role guidance. Unsupported roles are not available in CIPP to prevent random errors due to these roles being added to relationships.
{% endhint %}

{% hint style="danger" %}
The Global Administrator role is a highly privileged role that should be used with caution. GDAP Relationships with this role will not be eligible for auto-extend.
{% endhint %}

{% include "../../../../../.gitbook/includes/feature-request.md" %}

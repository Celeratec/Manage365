# Edit Template

Editing a role template updates the set of roles that future invites and onboardings are built from. The form is the same one used to create a template, prefilled with the current name and role selection.

## Editing a Template

{% stepper %}
{% step %}
### Open the template

Selecting **Edit Template** loads the template by name and preselects its current roles. If every group in the template shares one suffix, that suffix is restored into the Advanced section so saving reproduces the same groups. Anything a suffix cannot reproduce - a custom group name, a second suffix, an unsuffixed group sitting alongside a suffixed one - is pinned to the group it already uses, and the editor says so.
{% endstep %}

{% step %}
### Adjust the name or roles

Change **Template Name** to rename the template, or add and remove entries under **Admin Roles**. Adding a role whose target group does not exist creates it when you save; removing a role leaves its group and mapping in place. Changing the Custom Suffix re-targets every role that is not pinned to a specific group.
{% endstep %}

{% step %}
### Save

Submitting creates any missing groups and writes the changes back. A renamed template keeps its roles and history, as CIPP tracks the original name behind the scenes rather than creating a second template.
{% endstep %}
{% endstepper %}

{% hint style="warning" %}
Editing a template does not change GDAP relationships that were created from it. To bring an existing relationship in line with an updated template, use the **Reset Role Mapping** action on the relationships page.
{% endhint %}

{% hint style="info" %}
Renaming the template named `CIPP Defaults` causes CIPP to prompt you to recreate it, since it checks for that exact name.
{% endhint %}

{% include "../../../../../.gitbook/includes/feature-request.md" %}

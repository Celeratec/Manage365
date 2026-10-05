# Purview Retention Policies

Microsoft Purview retention policies control how long content is kept and what happens when that period ends. A policy sets the scope of workloads it applies to, and the retention rules attached to it carry the duration and the end of period action. This page lists the retention policies in the selected tenant, shows how many rules each one carries, and lets you enable, disable, delete or capture them as reusable templates.

## Action Buttons

<details>

<summary>Deploy Retention Policy</summary>

Opens a drawer that creates a retention policy in one or more tenants from a template or from parameters you supply yourself.

| Field | Description |
| ----- | ----------- |
| Select Tenants | The tenants to create the policy in. At least one is required, and you can pick several to deploy the same policy across a group of customers in one go. |
| Select a template (optional) | Picks a saved retention policy template. Choosing one fills **Parameters (JSON)** with that template's stored settings, which you can then edit before deploying. |
| Parameters (JSON) | The policy settings as JSON. Required. A worked example is shown in the field until you type into it, covering the policy name, workload locations and a nested `RuleParams` block holding the retention duration and action. |

</details>

## Table Details

| Column | Description |
| ---------------------- | ------------------------------------------------------------------------------------------------------- |
| Name                   | The policy name.                                                                                        |
| Enabled                | Whether the policy is currently switched on.                                                            |
| Scoped Locations       | The Microsoft 365 locations the policy actually covers: Exchange, SharePoint, OneDrive, Microsoft 365 Groups, Teams Chats, Teams Channels, Skype, Public Folders or Adaptive Scope. |
| Rule Count             | How many retention rules belong to this policy.                                                         |
| Retention Action       | What happens to content when the retention period ends, taken from the first rule attached to the policy. |
| Retention Duration     | How long content is retained before that action applies, taken from the same rule. Shows **Unlimited** when the rule has no duration set. |
| Restrictive Retention  | Whether Preservation Lock is set on the policy.                                                          |
| Created By             | The account that created the policy.                                                                    |
| When Changed UTC       | When the policy was last modified, in UTC.                                                              |

The Extended Info flyout also breaks **Scoped Locations** out into its individual location fields, and adds the policy's comment and creation date.

{% hint style="danger" %}
Preservation Lock cannot be undone. Once it is set on a policy, nobody, including a Global Administrator, can disable or delete that policy, remove locations from it, or shorten its retention period. Locations can still be added and the retention period extended, but nothing can be taken back. **Disable Policy** and **Delete Policy** will fail against a locked policy.

Microsoft does not offer this setting in the Purview portal at all, specifically to guard against it being applied by accident. In CIPP it is reachable through the deploy drawer, and a template carrying it applies it to every tenant you deploy to without a confirmation step. Check what a template sets before deploying it. See [Preservation Lock](https://learn.microsoft.com/purview/retention-preservation-lock) for Microsoft's guidance.
{% endhint %}

{% hint style="info" %}
**Scoped Locations** is worked out from which location fields the policy actually returns populated, rather than from Microsoft's own **Workload** field: Workload is a fixed list of every location a retention policy can ever target, not what this particular policy covers. **Create template based on policy** captures the policy's current locations when it builds the template, so the result stays deployable.
{% endhint %}

## Table Actions

<table><thead><tr><th>Action</th><th>Description</th><th data-type="checkbox">Bulk Action Available</th></tr></thead><tbody><tr><td>Create template based on policy</td><td>Saves the selected policy, and the first retention rule attached to it, as a retention policy template so it can be redeployed to other tenants.</td><td>false</td></tr><tr><td>Enable Policy</td><td>Switches the selected policy on. Greyed out when the policy is already enabled.</td><td>true</td></tr><tr><td>Disable Policy</td><td>Switches the selected policy off, leaving it in place but not retaining. Greyed out when the policy is already disabled.</td><td>true</td></tr><tr><td>Delete Policy</td><td>Permanently removes the selected policy and the rules belonging to it.</td><td>true</td></tr><tr><td>More Info</td><td>Opens the Extended Info flyout with the full details for the selected row.</td><td>false</td></tr></tbody></table>

{% include "../../../../.gitbook/includes/feature-request.md" %}

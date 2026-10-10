# Transport Rules

This page lists the mail flow rules (transport rules) configured in Exchange Online for the selected tenant. You can build a rule from scratch, edit an existing one, enable or disable rules, save a rule as a reusable template, and deploy templates out to other tenants. Viewing the list requires the `Exchange.TransportRule.Read` permission, and the action buttons and row actions require `Exchange.TransportRule.ReadWrite`.

{% hint style="info" %}
Selecting All Tenants starts a background collection across every tenant. While it runs, the page shows a message asking you to check back in a few minutes rather than the rule list.
{% endhint %}

## Action Buttons

<details>

<summary>Deploy Template</summary>

Opens a drawer that deploys a transport rule to one or more tenants. Select the target tenants, then either pick a saved template to fill in the **New-TransportRule parameters (JSON)** box or type the JSON in yourself, and click **Deploy Transport Rule**. If a rule of the same name already exists in a target tenant, that rule is updated to match the template instead of a second copy being added.

</details>

<details>

<summary>New Transport Rule</summary>

Opens a guided editor that builds a rule in the selected tenant without you writing any JSON. **Basic Information** covers the rule name, priority, comments, rule mode (Enforce, Test with Policy Tips, or Test without Policy Tips), audit severity, and whether the rule is enabled. You then choose conditions under **Apply this rule if...** (or switch on **Apply to all messages**), one or more actions under **Do the following...**, and optional exceptions under **Except if...**. **Advanced Settings** covers where the sender address is matched, whether rule processing stops after this rule, and optional activation and expiry dates. Most condition, action, and exception types reveal further fields once you select them. **Priority** is pre-filled with the next free value for the tenant, and the rule is created when you click **Create Rule**.

</details>

## Filters

Preset filters are available from the **Filters** button for **Enabled Rules** and **Disabled Rules** rows.

## Table Details

The properties returned are for the Exchange Online PowerShell command `Get-TransportRule`. For more information on the command please see the [Microsoft documentation](https://learn.microsoft.com/powershell/module/exchangepowershell/get-transportrule).

## Table Actions

<table><thead><tr><th>Action</th><th>Description</th><th data-type="checkbox">Bulk Action Available</th></tr></thead><tbody><tr><td>Create template based on rule</td><td>Saves the selected rule as a transport rule template on the <a data-mention href="list-templates.md">list-templates.md</a> page, so it can be redeployed to other tenants. Offered one rule at a time, because a bulk selection does not carry each rule's settings through to the template.</td><td>false</td></tr><tr><td>Enable Rule</td><td>Sets the rule's <strong>State</strong> to <code>Enabled</code> so it starts acting on mail. Greyed out for a rule that is already enabled, and for a bulk selection unless every selected rule is disabled.</td><td>true</td></tr><tr><td>Edit Rule</td><td>Opens the same guided editor as <strong>New Transport Rule</strong>, pre-filled with the selected rule's conditions, actions, exceptions, and advanced settings. Save your changes with <strong>Update Rule</strong>.</td><td>true</td></tr><tr><td>Disable Rule</td><td>Sets the rule's <strong>State</strong> to <code>Disabled</code>, which leaves the rule in place but stops it acting on mail. Greyed out for a rule that is already disabled, and for a bulk selection unless every selected rule is enabled.</td><td>true</td></tr><tr><td>Delete Rule</td><td>Permanently removes the rule from the tenant. Consider using <strong>Create template based on rule</strong> first if you might need to recreate it.</td><td>true</td></tr><tr><td>More Info</td><td>Opens the Extended Info flyout with the full details for the selected row.</td><td>false</td></tr></tbody></table>

{% include "../../../../.gitbook/includes/feature-request.md" %}

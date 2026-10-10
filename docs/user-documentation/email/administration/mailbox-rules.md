# Mailbox Rules

This report lists the inbox rules configured on every mailbox in the selected tenant. Rules that forward, redirect, or quietly file mail are a common sign of a compromised account, so this is usually the first page to check during an investigation, and the one to sweep periodically across a whole estate.

## Table Details

| Column              | Description                                                                   |
| ------------------- | ----------------------------------------------------------------------------- |
| User Principal Name | The user principal name of the user's mailbox that the rule has been set for. |
| Name                | The name of the mailbox rule.                                                 |
| Priority            | The priority order of the rule. Rules run in this order, lowest first.        |
| Enabled             | A Boolean field indicating if the rule is currently enabled.                  |
| From                | The sender's information the rule applies to, if set.                         |

The row flyout shows the rule's full definition, which is where its actual conditions and actions are, including any forwarding or redirect target, the folder mail is moved to, and whether the rule stops further rules from running.

## Table Actions

<table><thead><tr><th>Action</th><th>Description</th><th data-type="checkbox">Bulk Action Available</th></tr></thead><tbody><tr><td>Enable Mailbox Rule</td><td>Enables the mailbox rule so it starts acting on mail again. Greyed out on a rule that is already enabled.</td><td>true</td></tr><tr><td>Disable Mailbox Rule</td><td>Stops the mailbox rule acting on mail while leaving it in place, so it can be turned back on later. Greyed out on a rule that is already disabled.</td><td>true</td></tr><tr><td>Remove Mailbox Rule</td><td>Deletes the mailbox rule. This cannot be undone, so disable a rule first if you may need to reinstate it.</td><td>true</td></tr><tr><td>More Info</td><td>Opens the Extended Info flyout with the full details for the selected row.</td><td>false</td></tr></tbody></table>

{% include "../../../../.gitbook/includes/feature-request.md" %}

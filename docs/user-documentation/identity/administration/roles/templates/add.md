---
description: Create a PIM role settings template
---

# Add PIM Template

## Template

| Field         | Description                                                                                                    |
| ------------- | -------------------------------------------------------------------------------------------------------------- |
| Template name | The name shown in the template list and in the PIM Role Settings Template standard.                           |
| Description   | Optional free text.                                                                                            |

## Roles

| Field    | Description                                                                                                                                                        |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Apply to | **Privileged roles** applies the template to CIPP's privileged-roles list (Global, Security, Exchange, SharePoint, User, Conditional Access, Application, ... administrators). **All directory roles** applies it to every role that has a PIM policy. **Custom selection** lets you pick roles. |
| Roles    | The roles for a custom selection.                                                                                                                                  |

## Activation

| Field                                | Description                                                                                                                                                    |
| ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Maximum activation duration          | How long an activated role stays active. 8 hours is the recommended maximum; 12 and 24 hours are allowed and logged as an override.                            |
| Activation requires                  | **Multi-factor authentication**, or a **Conditional Access authentication context** (then enter the context id, for example `c1`). Entra allows only one of the two. |
| Require a ticket number on activation | Adds the ticketing requirement to activation.                                                                                                                 |
| Require approval to activate         | Adds an approval stage. Name the approvers as group display names or user principal names, comma separated; they are resolved in each tenant.                 |

Justification on activation is always required by the secure floor and is not configurable.

## Assignments

| Field                                        | Description                                                                                   |
| -------------------------------------------- | --------------------------------------------------------------------------------------------- |
| Maximum eligible assignment duration         | How long an administrator may make someone eligible for; at most one year.                   |
| Maximum active assignment duration           | How long an administrator may assign the role actively for; at most one year. Permanent active assignments become impossible in the portal. |
| Require MFA when creating an active assignment | Adds the MFA requirement to the admin assignment enablement rule. Justification is always required. |

## Notifications

| Field                                  | Description                                                                                            |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Additional admin notification recipients | E-mail addresses that receive the admin notifications for eligibility, assignment and activation events, in addition to Entra's default recipients. |
| Notification level                     | **All** or **Critical** for the added recipients.                                                       |

{% hint style="warning" %}
Saving a template below the secure floor fails with the list of problems. Fix the settings and save again; CIPP does not adjust them for you.
{% endhint %}

{% include "../../../../../../.gitbook/includes/feature-request.md" %}

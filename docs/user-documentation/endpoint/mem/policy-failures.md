# Policy Failures

Policy Failures lists Intune configuration policies that currently have devices in an **error** or **conflict** state. Use it to find policies that are not applying cleanly, then open a policy's drawer for the devices and settings that failed.

## Table Details

| Column           | Description                                                                 |
| ---------------- | --------------------------------------------------------------------------- |
| Display Name     | The name of the configuration policy.                                       |
| Policy Type Name | The policy family CIPP maps the Intune type to.                             |
| Platform         | The platform the policy targets, where Intune reports one.                  |
| Error Devices    | How many devices are in an error state for this policy.                     |
| Conflict Devices | How many devices are in a conflict state for this policy.                   |

Only policies with at least one error or conflict device appear. Policies that are applying cleanly are omitted.

## Table Actions

| Action      | Description                                                                                          |
| ----------- | ---------------------------------------------------------------------------------------------------- |
| Open Intune | Opens the Intune admin centre for the selected tenant in a new tab.                                  |
| More Info   | Opens the drawer with the failing devices and settings for the selected policy.                      |

The drawer lists devices in error or conflict and the settings that failed, including conflicting policies where Intune reports them.

{% include "../../../../.gitbook/includes/feature-request.md" %}

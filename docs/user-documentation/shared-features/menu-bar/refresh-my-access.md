# Refresh My Access

Where your CIPP role comes from membership of an Entra group, CIPP does not notice a change to that membership straight away. **Refresh my access** re-checks your group membership on demand and applies whatever roles it finds, so a role you have just picked up, typically by activating a group through Privileged Identity Management, takes effect without you having to wait or sign in again.

It only ever refreshes your own access. It cannot be used to change anyone else's.

{% hint style="info" %}
This is for a change to your own group membership. Changes made in CIPP itself apply straight away and need no refresh: assigning a different Entra group to a role, removing a role's group, or deleting a role that had one all reach everyone in the affected group immediately. Changing only a role's permissions does not alter who holds the role, so nothing needs to be refreshed there either.
{% endhint %}

## Refreshing from the Menu Bar

**Refresh my access** sits in the account menu, reached from your avatar at the right of the menu bar, directly above **Log out**.

Selecting it asks you to confirm, then reports the outcome in the same dialog. The rest of CIPP picks up the new roles in place, so pages and actions that were previously unavailable become available without a reload.

## Refreshing from the Access Denied Page

The Access Denied page carries the same **Refresh my access** button, below the card. This is the more common route: an account with a standing read-only role that elevates to an admin role through PIM lands on Access Denied when it opens a page the standing role cannot reach.

A refresh that grants the role you were missing takes you into the page you were trying to reach, with no second sign-in.

## What the Result Tells You

| Result | Meaning |
| ------ | ------- |
| Access refreshed, with your roles listed | Your group memberships were re-checked and the roles listed are now in force. |
| Access refreshed, but no group maps to a role | Your memberships were re-checked and none of the groups you belong to is mapped to a CIPP role. If you activated a group moments ago, the activation may not have reached Microsoft yet, so wait a moment and try again. |
| A warning message | The refresh did not complete. The message explains why. |

{% hint style="info" %}
A refresh can only be run once every 30 seconds. Running it again sooner reports how long is left to wait rather than re-checking.
{% endhint %}

Only roles that come from Entra group membership are affected. A role assigned to you directly on [cipp-users.md](../../cipp/advanced/authentication/cipp-users.md "mention") is already in force and needs no refresh, and refreshing never removes it. If a refresh reports roles you did not expect, or none where you expected some, check which group each role is mapped to on [cipp-roles](../../cipp/advanced/authentication/cipp-roles/ "mention"), and see [how-cipp-evaluates-roles.md](../../../setup/resources/how-cipp-evaluates-roles.md "mention") for how several roles combine.

{% include "../../../../.gitbook/includes/feature-request.md" %}

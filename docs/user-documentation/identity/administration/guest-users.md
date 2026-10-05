# Guest Users

Every guest account in the tenant is listed here with a lifecycle status worked out from its invitation state and its sign-in activity, so guests who never accepted their invitation, or who stopped using the tenant long ago, can be found and dealt with in one place.

A guest is classified as follows, with the first match winning:

| Status             | Meaning                                                                    |
| ------------------ | -------------------------------------------------------------------------- |
| Disabled           | The account is blocked from signing in.                                    |
| Pending Acceptance | The invitation was sent but has not been redeemed.                         |
| Never Signed In    | The guest has accepted, but no sign-in has ever been recorded.             |
| Stale              | The last recorded sign-in was 90 or more days ago.                         |
| Active             | The guest has signed in within the last 90 days.                           |
| Unknown            | Sign-in activity could not be read, so staleness cannot be worked out.     |

A disabled guest is reported as Disabled whether or not it ever accepted the invitation.

## Guest Status Summary

A row of cards above the table shows how many guests fall into each status, alongside a total. Clicking a status card filters the table to that status and outlines the card, clicking it again clears the filter, and clicking **Total Guests** clears it as well.

Guests with a status of Unknown are counted in **Total Guests** but have no card of their own.

## Filters

| Filter                       | Shows                                                       |
| ---------------------------- | ----------------------------------------------------------- |
| Active guests                | Guests who have signed in within the last 90 days.          |
| Stale guests                 | Guests whose last sign-in was 90 or more days ago.          |
| Pending Acceptance guests    | Guests who have not yet redeemed their invitation.          |
| Never Signed In guests       | Guests who accepted but have never signed in.               |
| Disabled guests              | Guest accounts that are blocked from signing in.            |

## Table Details

| Column               | Description                                                                                                             |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Display Name         | The name the guest appears under in the directory.                                                                      |
| Mail                 | The external email address the invitation was sent to.                                                                  |
| Source Domain        | The domain part of that address, which groups guests by the organisation they come from.                                |
| Status               | The lifecycle status described above.                                                                                   |
| Account Enabled      | Whether the account is allowed to sign in.                                                                              |
| Created Date Time    | When the guest account was created in the tenant.                                                                       |
| Last Sign In Date Time | The most recent sign-in recorded for the guest, taking the latest of its interactive, non-interactive and successful sign-in times. |
| Days Since Sign In   | How many days have passed since that sign-in. Empty where no sign-in has been recorded.                                 |

The flyout adds the user principal name, the object ID, the raw invitation state and when it last changed, each of the three sign-in times separately, and any sponsors recorded against the guest.

## Table Actions

<table><thead><tr><th>Action</th><th>Description</th><th data-type="checkbox">Bulk Action Available</th></tr></thead><tbody><tr><td>View User</td><td>Opens the <a data-mention href="users/user/">user</a> page for the selected guest.</td><td>false</td></tr><tr><td>Re-invite Guest</td><td>Sends the guest invitation email again, pointing the guest at the My Apps portal. Greyed out for guests with no email address, and for any status other than <strong>Pending Acceptance</strong> or <strong>Stale</strong>.</td><td>true</td></tr><tr><td>More Info</td><td>Opens the Extended Info flyout with the full details for the selected row.</td><td>false</td></tr></tbody></table>

{% hint style="warning" %}
Reading sign-in activity needs an Entra ID P1 licence in the tenant. Without it, only Disabled and Pending Acceptance can be determined and every other guest is reported as Unknown, so an Unknown-heavy table means the licensing is missing rather than that the guests are inactive.
{% endhint %}

{% hint style="info" %}
This page supports syncing under AllTenants, which queues a background refresh for every tenant rather than just the selected one.
{% endhint %}

{% include "../../../../.gitbook/includes/feature-request.md" %}

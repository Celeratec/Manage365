# JIT Admin

JIT Admin creates administrative accounts that expire on their own, so temporary elevation does not turn into a permanent standing privilege. Each account is created with a chosen set of roles and an expiry, and CIPP removes the roles or disables the account when the window closes. This page lists the accounts CIPP is tracking, whether they are currently active, and what they were created for.

## Action Buttons

{% content-ref url="add.md" %}
[add.md](add.md)
{% endcontent-ref %}

## Filters

| Filter            | Shows                                                       |
| ----------------- | ----------------------------------------------------------- |
| Active JIT Admins | Accounts whose JIT elevation is currently in force.         |
| Expired/Disabled  | Accounts whose elevation has ended or has not been enabled. |

## Table Details

| Column               | Description                                                                                      |
| -------------------- | ------------------------------------------------------------------------------------------------ |
| User Principal Name  | The sign-in name of the account.                                                                 |
| Display Name         | The name of the account.                                                                         |
| Account Enabled      | Whether the account itself can sign in, separate from whether its elevation is active.           |
| Jit Admin Enabled    | Whether the JIT elevation is currently in force.                                                 |
| Jit Admin Start Date | When the elevation was scheduled to begin.                                                       |
| Jit Admin Expiration | When the elevation ends, at which point CIPP acts on the account.                                |
| Jit Admin Reason     | The reason recorded when the account was created, which is what makes the list reviewable later. |
| Jit Admin Created By | Who set the elevation up.                                                                        |
| Member Of            | The directory roles the account currently holds.                                                 |

{% hint style="info" %}
The JIT columns are not standard Entra ID properties. CIPP stores them in a schema extension on the user object, which is how the elevation details survive between sessions and how the expiry job knows which accounts to act on. An account elevated outside CIPP will not appear here.
{% endhint %}

{% hint style="info" %}
This table has no per-row actions. Elevation is granted from the Add JIT Admin page, and ends automatically at the expiry, so there is nothing to act on from the list itself.
{% endhint %}

{% hint style="warning" %}
Under All Tenants the list is served from a cache rather than queried live. The first time it is opened, CIPP queues a background job to collect the data from every tenant and reports that it is still loading, so come back after a few minutes. Once built, the cache is reused for an hour before a fresh collection runs. Single-tenant views are always live.
{% endhint %}

{% hint style="info" %}
If your CIPP role has a [JIT Role Template](../jit-role-templates/README.md "mention") assigned, this list is filtered to JIT Admins whose roles fall entirely within that template. An account holding any role outside your allow-list is left off the list rather than shown with roles hidden.
{% endhint %}

{% include "../../../../../.gitbook/includes/feature-request.md" %}

# Permissions

The Permissions page verifies that CIPP has the access it needs to manage your tenants. It runs three checks: one covering CIPP's own application registration, one covering your GDAP relationships, and one that tests access to each tenant individually. The results can be exported as a diagnostic report for troubleshooting or support. Where your tenants are added directly rather than through Microsoft Partner Center relationships, the GDAP check does not apply and access is confirmed per tenant by the Tenants check instead.

## Diagnostic Report

The buttons at the top of the page export the current check results, or load a report that was exported elsewhere. This is intended for troubleshooting and for sharing results with support.

| Action                | Description                                                                                                                                                                       |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Export Report         | Exports the current permissions, GDAP, and tenant results as a JSON file. A Redact Customer Data option is offered, which removes identifying tenant information from the export. |
| Import Report         | Loads a previously exported JSON report from a file so its results can be reviewed on this page.                                                                                  |
| Import from Clipboard | Loads a previously exported report directly from the clipboard rather than from a file.                                                                                           |
| Close report          | Clears the imported report and returns the page to live results.                                                                                                                  |

While an imported report is being viewed, each affected check is marked with an "Imported" label and its Refresh button is disabled, since the results come from the file rather than from your environment.

## Permissions Check

Checks the permissions granted to CIPP's application registration and reports anything missing. Select **Refresh** to run the check again without using cached results, or **Details** to open a flyout with the full breakdown. The time of the last run is shown beside the buttons.

The check also confirms that the secret CIPP authenticates with as its own application is still valid. CIPP renews that secret automatically ahead of its expiry date, so a problem is only reported where the stored secret has already expired, or is within a few weeks of expiring and has not been renewed. Both are reported on the card with the expiry date, and both need attention, because CIPP uses that secret to obtain access to your tenants.

Shortly after a renewal, the check can report that the secret CIPP is currently using does not match the one that is stored. That resolves itself once the new value is picked up, which takes up to thirty minutes. Where the secret cannot be checked at all, the card reports that rather than treating it as a failure.

{% hint style="info" %}
When this check flags missing permissions or required CPV refreshes, the Details flyout provides buttons to handle these tasks easily.
{% endhint %}

## GDAP Check

Checks your Granular Delegated Admin Privileges relationships and the roles they grant. As with the Permissions check, **Refresh** re-runs it and **Details** opens the full breakdown.

This check is only shown where it applies. In an environment whose tenants are added directly instead of through Partner Center relationships, the card is replaced with a note explaining that GDAP checks do not apply and that access is verified per tenant by the Tenants check below. The check also remains visible when an imported report contains GDAP results.

## Tenants Check

Tests access to each tenant in turn and reports what CIPP can reach. Select **Refresh** to re-run the check for every tenant.

### Table Details

| Column          | Description                                                                                                                                                                                              |
| --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Tenant Name     | The name of the tenant.                                                                                                                                                                                  |
| Tenant Type     | How CIPP connects to the tenant: Direct for a tenant added with its own service account, or GDAP for one reached through a Partner Center relationship.                                                  |
| Service Account | For a direct tenant, the account CIPP authenticated as. Blank for GDAP tenants, which use the partner relationship rather than an account in the tenant.                                                 |
| Last Run        | When the access check last ran for this tenant.                                                                                                                                                          |
| Graph Status    | Whether CIPP could successfully reach Microsoft Graph in the tenant.                                                                                                                                     |
| Exchange Status | Whether CIPP could successfully reach Exchange Online in the tenant.                                                                                                                                     |
| Missing Roles   | Any required roles CIPP does not currently hold in the tenant.                                                                                                                                           |
| Assigned Roles  | The roles CIPP holds in the tenant. For a direct tenant these are the roles held by the service account; where that account is a Global Administrator, the roles it grants implicitly are noted as such. |

Selecting a row opens a flyout with further detail, including the tenant ID, default domain name, when the service account last authenticated, and the full results of the Graph and Exchange tests.

### Table Actions

<table><thead><tr><th>Action</th><th>Description</th><th data-type="checkbox">Bulk Action Available</th></tr></thead><tbody><tr><td>Check Tenant</td><td>Re-runs the access check for the selected tenant.</td><td>true</td></tr><tr><td>Repair Exchange Roles</td><td>Restores the Exchange roles CIPP requires in the selected tenant. Available only where the check has found that a repair is needed.</td><td>true</td></tr><tr><td>More Info</td><td>Opens the Extended Info flyout with the full details for the selected row.</td><td>false</td></tr></tbody></table>

{% include "../../../../.gitbook/includes/feature-request.md" %}

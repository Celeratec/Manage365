# GDAP Management

The GDAP Management overview is the starting point for managing Granular Delegated Admin Privileges between your partner tenant and your customer tenants. It summarises the current state of your GDAP configuration and guides you through the steps needed to get set up correctly.

## Overview

A summary bar showing high-level counts for your GDAP configuration.

| Statistic          | Description                                                                                       |
| ------------------ | ------------------------------------------------------------------------------------------------- |
| GDAP Relationships | The total number of delegated admin relationships between your partner tenant and your customers. |
| Mapped Admin Roles | The number of GDAP roles that have been mapped to security groups in your partner tenant.         |
| Role Templates     | The number of role templates available for creating invites and onboarding tenants.               |
| Pending Invites    | The number of generated invites that have not yet been used.                                      |

## Add a Tenant

Opens the [sam-setup-wizard.md](../../cipp/sam-setup-wizard.md "mention") with the **Add a tenant** option already selected, so you can bring a new tenant into an existing CIPP deployment.

## GDAP Setup

A guided checklist covering the three stages of a working GDAP configuration. CIPP works out how far you have progressed by inspecting your role templates and invites, so the highlighted step reflects your current configuration rather than anything you set by hand.

| Step                    | Description                                                                                                              |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Create a role template  | Pick the admin roles your technicians need. CIPP maps each one to a security group in your partner tenant.               |
| Create invites          | Create invites based on your role templates.                                                                             |
| Setup complete          | You are ready to start adding your tenants using CIPP.                                                                   |

## GDAP Check

Runs a set of diagnostic checks against your GDAP configuration and reports the problems it finds, such as missing security groups or relationships that have not been mapped correctly. Use it when an onboarding has failed, or when delegated access is not behaving as expected.

{% hint style="info" %}
The **GDAP Setup** and **GDAP Check** cards are only shown to users who hold the `CIPP.AppSettings.Read` permission. The statistics bar and the **Add a Tenant** button are visible to everyone who can reach the page.
{% endhint %}

{% include "../../../../.gitbook/includes/feature-request.md" %}

# Message Encryption

Microsoft Purview Message Encryption lets users send protected email to any recipient, including Gmail and Outlook.com. This page shows the Information Rights Management (IRM) configuration for the selected tenant, lets you turn message encryption on, and verifies that it actually works.

{% hint style="info" %}
The only prerequisite for Purview Message Encryption is that Azure Rights Management is active for the tenant. For most eligible plans it is activated automatically. See [Set up Message Encryption](https://learn.microsoft.com/en-us/purview/set-up-new-message-encryption-capabilities).
{% endhint %}

## Current Configuration

| Field                                | Description                                                                                                                                                                                               |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Purview Message Encryption           | Whether the tenant can connect directly to Azure Rights Management. This is the switch that makes message encryption available.                                                                           |
| Internal Licensing Enabled           | Whether IRM features are enabled for messages sent to internal recipients. In Exchange Online this setting covers external recipients as well, and is on by default.                                      |
| External Licensing Enabled           | Whether Exchange tries to acquire licences from clusters other than the one it is configured to use. This applies to on-premises Exchange only, so it carries no meaning for a cloud-only tenant.          |
| Encrypt Button in Outlook            | Whether the **Encrypt** button is offered when composing mail in Outlook on the web and the new Outlook. Defaults to disabled, which leaves users no way to reach message encryption.                                                                                                                          |
| Transport Decryption                 | How protected mail is treated in transit. Disabled leaves it encrypted, Optional decrypts it where possible and delivers either way, and Mandatory rejects anything it cannot decrypt. Optional is the default. |
| Journal Report Decryption            | Whether a decrypted copy of a protected message is attached to the journal report.                                                                                                                       |
| Licensing Location                   | The RMS licensing URLs for the tenant. Used to work out whether the tenant is on Azure RMS or still on on-premises AD RMS.                                                                                |

The card itself is read-only. Purview Message Encryption and the Encrypt button are the two settings you can change from this page, using the switches below the card.

## AD RMS Migration Warning

Purview Message Encryption is **not compatible with Active Directory Rights Management Services (AD RMS)**. When the licensing location points at something other than an Azure RMS URL, the page shows a warning: that tenant is still using an on-premises AD RMS cluster and has to be [migrated to Azure RMS](https://learn.microsoft.com/en-us/azure/information-protection/migrate-from-ad-rms-to-azure-rms) before message encryption can be used.

The warning does not block the toggle, so you can still act on a tenant you know has already been migrated. The **Enable Purview Message Encryption** standard is stricter: it skips remediation entirely for these tenants and logs a warning instead, because it runs unattended.

## Actions

| Action                                                        | Description                                                                                                                                                                                                 |
| ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Enable Purview Message Encryption (Azure RMS licensing)       | Turns Azure RMS licensing on or off for the tenant.                                                                                             |
| Show the Encrypt button in Outlook (simplified client access) | Shows or hides the **Encrypt** button when composing mail in Outlook on the web and the new Outlook. Turning encryption on without this leaves the feature enabled but out of users' reach.                  |
| Run Test                                                      | Checks that RMS templates can be acquired and that encryption and decryption both work. Pick any mailbox in the tenant for **Sender** and for **Recipient**. The button is greyed out until both are chosen. |

**Submit** applies both switches together. Switching tenants clears them and both test addresses, so a value set for one tenant is never submitted against another.

## Rolling This Out Across Tenants

This page configures one tenant at a time. To deploy message encryption to many tenants and keep it that way, use the **Enable Purview Message Encryption** standard under Exchange Standards, which sets the Azure RMS licensing and the Encrypt button together. In report mode it records the licensing state per tenant, including whether the Encrypt button is on and whether AD RMS was detected, which gives you the same pre-check across the whole estate without changing anything. A tenant with encryption enabled but the Encrypt button still off is reported as not aligned.

Encrypted message branding, one-time passcodes, and social ID sign-in are configured separately, through the **Configure Encrypted Message Branding (OME)** standard.

{% include "../../../../.gitbook/includes/feature-request.md" %}

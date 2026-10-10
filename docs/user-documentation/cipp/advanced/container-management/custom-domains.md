# Custom Domains

{% hint style="info" %}
## CyberDrain Hosted

On a CyberDrain-hosted instance this page is read-only: it lists the domains bound to your instance, but adding, fixing and removing them happens in the [management portal](https://management.cipp.app/). The instance's own identity has no permission on the shared App Service plan, so it cannot bind domains or issue certificates itself. This also covers re-adding a domain after the next-generation migration.
{% endhint %}

The Custom Domains page maps custom domains onto the Azure App Service that hosts this CIPP instance, so you can reach CIPP on your own hostname instead of the default `*.azurewebsites.net` address. Setting up a domain involves a DNS alias record, a hostname binding on the App Service, and an optional free managed TLS certificate. A wizard walks through all three and can be reopened at any time to finish or fix a domain. The default `*.azurewebsites.net` hostname always remains available.

{% hint style="warning" %}
Point the domain directly at the App Service. A proxy or CDN in front of CIPP (such as a Cloudflare proxied record) hides the domain from Azure and blocks certificate issuance and renewal, so use a DNS-only record.
{% endhint %}

## App Service Details

The App Service card shows the read-only details you need when creating DNS records for a custom domain.

| Field                  | Description                                                                                             |
| ---------------------- | ------------------------------------------------------------------------------------------------------- |
| Site name              | The name of the App Service hosting this CIPP instance.                                                 |
| Default hostname       | The App Service's default hostname. Use this as the CNAME target when adding a subdomain.               |
| Inbound IP (A record)  | The App Service's inbound IP address. Use this as the A record value when adding an apex (root) domain. |

## Table Details

The Custom Domains table lists every hostname bound to the App Service. Selecting a row opens a details flyout showing the hostname, its SSL state, the binding type and, where a certificate is present, its thumbprint and expiry date.

| Column   | Description                                                                                                                                                                                             |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Hostname | The domain bound to the App Service.                                                                                                                                                                    |
| Status   | The security state of the binding: Default (Azure-managed) for the built-in hostname, Secured (SNI SSL) or Secured (IP SSL) when a certificate is bound, Provisioning certificate (attempt N of 4) while CIPP is still issuing one in the background, Certificate not issued (see details) once those attempts ran out (the flyout shows the last error), or Not secured when no certificate has been requested. |

## Table Actions

<table><thead><tr><th>Action</th><th>Description</th><th data-type="checkbox">Bulk Action Available</th></tr></thead><tbody><tr><td>Manage / Fix</td><td>Reopens the setup wizard for the selected domain so you can finish or repair its configuration. Available for custom domains only.</td><td>true</td></tr><tr><td>Remove domain</td><td>Removes the custom domain from the CIPP App Service, along with any managed certificate for it. The default hostname is unaffected. Available for custom domains only.</td><td>true</td></tr><tr><td>More Info</td><td>Opens the Extended Info flyout with the full details for the selected row.</td><td>false</td></tr></tbody></table>

## Adding or Fixing a Domain

Select **Add Custom Domain** to start the wizard, or use **Manage / Fix** on an existing domain to resume where it left off. The wizard has three steps.

{% stepper %}
{% step %}
### Configure DNS record

Enter the fully qualified domain CIPP should answer on. This can be a subdomain (for example `portal.contoso.com`), an apex domain (`contoso.com`), or a wildcard (`*.contoso.com`). The wizard then shows the DNS record to create at your DNS provider:

* An **Alias** record: a CNAME pointing to the App Service default hostname for a subdomain, or an A record pointing to the inbound IP for an apex domain.

Create the record, then select **Check DNS** to verify it. Once verified you can continue. A wildcard alias can't be resolved directly, so it passes this check and is validated by Azure when the binding is created. The record must point directly at the App Service: a proxied record is invisible to the check and to Azure's own validation.

{% hint style="warning" %}
CIPP no longer uses domain-verification TXT records. If an `asuid.<domain>` TXT record exists from a previous setup, **remove it**: the wizard flags it when the DNS check finds one, and a leftover record blocks Azure's validation even when the alias record is correct.
{% endhint %}
{% endstep %}

{% step %}
### Create hostname binding

The wizard creates the hostname binding on the App Service. Azure validates ownership through the alias record the DNS check found (CNAME or A) as part of this step. If Azure keeps rejecting the binding, the wizard links to the App Service's **Custom domains** page in the Azure portal, where you can add the domain by hand and then reopen it in CIPP to provision the certificate.
{% endstep %}

{% step %}
### Enable HTTPS certificate

The wizard provisions a free App Service Managed Certificate for the domain and enables the SNI SSL binding. Issuance usually takes a minute or two. If the certificate is not issued by the time the step returns, CIPP keeps trying in the background: a hidden scheduled task retries every 15 minutes, up to four attempts in total, then stops. The table shows the attempt in progress and, once the retries are exhausted, the last error in the details flyout. Correct the DNS record and use **Manage / Fix** to start again.

Wildcard domains are the exception: App Service Managed Certificates do not support them, so you will need to upload your own certificate and binding from the Azure Portal to secure a wildcard domain.
{% endstep %}
{% endstepper %}

{% include "../../../../../.gitbook/includes/feature-request.md" %}

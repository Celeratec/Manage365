# Application Templates

Application Templates holds reusable bundles of application deployments. A template can contain one application or many, each with its configuration and assignment already set, so the same set of software can be pushed to any tenant without rebuilding it each time. Templates are stored in CIPP rather than in a tenant, so the list is the same whichever tenant is selected.

{% hint style="info" %}
Templates cover the six types offered in the drawer: MSP Vendor App, Store App, Chocolatey App, Microsoft Office, Microsoft Edge and Custom Application. Each of these is rebuilt from its package or script at deployment, so a Win32 application uploaded to Intune as an `.intunewin` package cannot be templated. Its installer content stays inside Intune, and it has to be rebuilt here as a Custom Application whose install script fetches the installer.
{% endhint %}

## Action Buttons

<details>

<summary>Create Template</summary>

Opens a drawer for building a template. Give it a **Template Name** and an optional **Description**, then add applications to it one at a time.

For each application, choose a type under **Select Application Type** and complete the same fields the Application Deployment drawer asks for, described on [list.md](list.md "mention"). Set the assignment for that application, then select **Add App to Template**. The application appears in the list at the top of the drawer, where it can be edited or removed, and the type selector resets so the next one can be added. The save button is disabled until at least one application has been added, and shows how many the template currently holds.

There are two differences from the deployment drawer worth knowing:

* MSP Vendor App entries ask for the vendor's keys, URLs and IDs directly rather than once per tenant. Enter a literal value where it is the same everywhere, or reference a CIPP custom variable such as `%DattoSiteID%` where it differs. Typing `%` opens a browser of the available variables. Variables are resolved per tenant at deployment, so the value only needs defining once per tenant.
* The assignment is saved into the template itself, and can be overridden per deployment later.

After saving, the drawer stays open so a variation can be adjusted and saved as a second template.

</details>

## Table Details

| Column       | Description                                                                                                                                                                                                                                                                         |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Display Name | The name given to the template when it was created or last edited.                                                                                                                                                                                                                  |
| Description  | The description given to the template, where one was supplied.                                                                                                                                                                                                                      |
| App Count    | How many applications the template bundles.                                                                                                                                                                                                                                         |
| App Types    | The application types the template contains, listed once each. These appear as their internal values: `mspApp`, `StoreApp`, `chocolateyApp`, `officeApp`, `edgeApp` and `win32ScriptApp`, corresponding to MSP Vendor App, Store App, Chocolatey App, Microsoft Office, Microsoft Edge and Custom Application. |
| App Names    | The names of the applications in the template.                                                                                                                                                                                                                                      |

## Table Actions

<table><thead><tr><th>Action</th><th>Description</th><th data-type="checkbox">Bulk Action Available</th></tr></thead><tbody><tr><td>Edit Template</td><td>Reopens the template in the drawer so its details, applications and assignments can be changed. Selecting several rows opens the drawer for one of them rather than editing them together.</td><td>true</td></tr><tr><td>Save to GitHub</td><td>Uploads the template to one of your GitHub repositories, prompting for the repository and a commit message. Only repositories you have write access to are offered, from those configured in community-repos. Hidden unless the GitHub integration is enabled.</td><td>true</td></tr><tr><td>Deploy Template</td><td>Deploys every application in the template to the tenants you select, optionally overriding the assignment saved in the template. The deployments are added to the queue rather than created immediately.</td><td>true</td></tr><tr><td>Delete Template</td><td>Permanently deletes the template from CIPP. Applications already deployed from it are unaffected.</td><td>true</td></tr><tr><td>More Info</td><td>Opens the Extended Info flyout with the full details for the selected row.</td><td>false</td></tr></tbody></table>

{% hint style="info" %}
**Deploy Template** offers an **Override Assignment (optional)** choice. Leaving it on **Keep template assignment** uses whatever each application was given when the template was built. Choosing anything else applies that assignment to every application in the template for this deployment only and does not change the template.
{% endhint %}

{% hint style="warning" %}
Deployed templates go into the queue alongside anything added from the Applications page, so nothing reaches Intune until the queue is processed. Use **Run Queue now** on the [queue.md](queue.md "mention") page if you would rather not wait for the scheduled run.
{% endhint %}

{% include "../../../../.gitbook/includes/feature-request.md" %}

# SAM App Permissions

This page controls the permission set requested for the CIPP-SAM application when consent is granted on customer tenants through CPV. It is where additional Graph or other API permissions are added when a CIPP feature, custom script, or integration needs access beyond what CIPP ships with.

{% hint style="danger" %}
This is an advanced configuration of CIPP currently in beta. Please proceed with caution. Removing permissions from the CIPP-SAM app is not advised.
{% endhint %}

## How Permissions Are Applied

CIPP's own default permissions are always applied and cannot be removed. Anything you configure here is layered on top of them, so this page adds permissions rather than replacing the set.

The defaults include `Application.ReadWrite.All`, `AppRoleAssignment.ReadWrite.All`, and `DelegatedPermissionGrant.ReadWrite.All`, which the user-scoped app consent endpoints use. `ConsentRequest.ReadWrite.All` is also part of the defaults, so a permissions repair and a CPV refresh are required on an instance that was consented before that permission was added. Application Administrator remains the GDAP directory role for these calls. See [user-app-consent](../../../tools/tenant-tools/user-app-consent.md "mention").

Saving stores the permission set. It does not grant anything on its own. To apply the change you need to run a permissions repair from [permissions.md](../../settings/permissions.md "mention"), then complete a CPV refresh so that consent is updated in each customer tenant.

{% hint style="warning" %}
Permissions added here are requested in every tenant CIPP manages, not just the one you need them for. Add only what is genuinely required, and be prepared to justify the resulting consent scope to your customers.
{% endhint %}

## Editing Permissions

Permissions are grouped by the API they belong to, each shown as a service principal card with its display name, application ID, and a count of the application and delegated permissions currently assigned.

Expanding a card reveals two tabs.

| Tab         | Description                                                                                                |
| ----------- | ---------------------------------------------------------------------------------------------------------- |
| Application | Permissions the CIPP-SAM application holds in its own right, used when CIPP acts without a signed-in user. |
| Delegated   | Permissions exercised on behalf of the signed-in service account.                                          |

On each tab, choose a permission from the picker and select the add button to include it. Existing permissions are listed below with the option to remove them.

{% hint style="info" %}
Saving happens in two stages. **Save Changes** within a service principal card commits your edits to that API's permission set on screen. **Save** at the bottom of the page submits the whole set to CIPP. Changes are not stored until you use the second one.
{% endhint %}

## Toolbar Actions

| Control                            | Description                                                                                                                                                                                |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Add a Service Principal (optional) | Adds an API not already listed, so its permissions can be configured. Choose from the available service principals, or enter an application ID directly if the one you need is not listed. |
| Reset to Current Defaults          | Discards unsaved changes and returns the builder to the currently saved permission set. This affects the screen only, not what is stored.                                                  |
| Download Manifest                  | Exports the current permission set as an application manifest, which is useful for review or for reproducing the configuration elsewhere.                                                  |
| Import Manifest                    | Loads a permission set from a manifest rather than building it by hand.                                                                                                                    |

{% hint style="info" %}
Not every permission can be represented in an application manifest. Where the export encounters any that cannot, you are offered a separate `AdditionalPermissions.json` download containing them, so nothing is silently lost.
{% endhint %}

Individual service principals can be removed from the list, with confirmation. Removing one drops the additional permissions configured against it, but has no effect on CIPP's defaults for that API.

## Reset to CIPP Defaults

**Reset to CIPP Defaults** removes every additional permission layered on top of the defaults and returns the saved permission set to the built-in CIPP manifest. The default permissions themselves are unaffected.

As with any other change here, the reset only alters what CIPP stores. Run a permissions repair followed by a CPV refresh to apply it to your tenants.

{% hint style="warning" %}
Consent already granted in a customer tenant is not withdrawn by resetting here. Permissions the CIPP-SAM application has already been consented to remain in place until they are removed in the tenant.
{% endhint %}

Directory role assignments for the same application are configured separately on [sam-app-roles.md](sam-app-roles.md "mention").

{% include "../../../../../.gitbook/includes/feature-request.md" %}

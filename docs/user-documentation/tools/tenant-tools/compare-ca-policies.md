# Compare CA Policies

Compare CA Policies diffs two Conditional Access sources side by side: a CIPP template against a live tenant policy, or two tenant policies (including across tenants). Use it when checking whether a deployed policy still matches its template, or when reviewing drift between environments.

## Sources

Each side of the comparison has:

| Field | Description |
| ----- | ----------- |
| Source type | **CIPP Template** or **Tenant Policy**. |
| Tenant | Required for tenant policies; used to resolve policy GUIDs in that tenant's directory. |
| Policy / template | The template or Conditional Access policy to load. |

Select **Compare** to run the diff. Policy GUIDs that appear as members of include/exclude lists are resolved to display names in each source's own tenant so cross-tenant comparisons stay readable.

## Results

Differences are shown in a policy diff table covering conditions, grant controls, session controls and related settings. Unchanged sections can be collapsed so only the drift is visible.

{% include "../../../../.gitbook/includes/feature-request.md" %}

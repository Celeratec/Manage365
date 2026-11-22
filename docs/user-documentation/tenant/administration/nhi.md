# NHI Compromise

NHI Compromise investigates non-human identities (enterprise apps and service principals) for signs of compromise. Start a case from an app's **Investigate compromise** action or from this list, then review score, activity, and containment options on the case page.

## Cases list

| Column | Description |
| ------ | ----------- |
| App / service principal | The enterprise app under investigation. |
| Tenant | The tenant the case belongs to. |
| Status | Whether a run is queued, running, completed, or stalled. |
| Score | The latest NHI risk score for the case. |

Start a new investigation by selecting an enterprise application. Cases poll for run status while an investigation is in progress.

## Case page

The case page shows the investigation report, IP verdicts, containment history, and evidence export. From containment you can reverse lockouts with **Release** where an action supports it, or keep attacker cleanup in place.

{% hint style="info" %}
Directory audit reads for a busy app are capped so a long history cannot stall the run. Heuristics live in `NhiHeuristics.json` and score ownership, credentials, grants, and directory roles.
{% endhint %}

{% include "../../../../.gitbook/includes/feature-request.md" %}

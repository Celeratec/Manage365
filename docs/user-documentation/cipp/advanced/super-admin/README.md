# Super Admin

This is a menu option that is limited to the highest level of admins.

{% hint style="danger" %}
As of version 8.0, users only need the \`superadmin\` role in order to access these menus and take actions. The value should be `superadmin` for self-hosted clients. Needing admin in addition to superadmin is no longer valid. Using both you will see errors. CyberDrain hosted clients should select both roles for the user on [https://management.cipp.app/](https://management.cipp.app/)
{% endhint %}

{% hint style="warning" %}
Note that it may take some time for the role change to take effect.
{% endhint %}

{% hint style="info" %}
Not every superadmin capability lives in this menu. Role impersonation, which reloads CIPP as though you hold only a chosen role so you can see what that role can reach, is offered against each role on the [cipp-roles](../authentication/cipp-roles/ "mention") page.
{% endhint %}

{% include "../../../../../.gitbook/includes/feature-request.md" %}

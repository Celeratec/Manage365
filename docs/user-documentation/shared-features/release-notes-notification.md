# Release Notes Notification

After CIPP is updated, the release notes for the new version open automatically the first time you load the application, so you can see what has changed.

You can also open them at any time from **View release notes** in the account menu, reached from your avatar at the right of the menu bar.

## Reading the Notes

The dialog opens on the notes for the most recent feature release, the one whose version ends in `.0`. Hotfix and maintenance releases list only what changed since that feature release, so leading with the feature notes gives you the fuller picture of what is new.

A **Release** dropdown at the top lets you select any other release and read its notes instead, including the hotfixes, and the heading updates to show which release you are viewing.

**Expand** widens the dialog to fill more of the screen, which helps with longer release notes. **Shrink** returns it to its normal size.

{% hint style="info" %}
The list of releases is fetched from GitHub and cached. If GitHub cannot be reached, the last list that was fetched successfully is shown instead, so the notes stay readable even when the newest release is missing from the dropdown.
{% endhint %}

## Dismissing the Notification

Four options sit at the foot of the dialog.

| Option                        | Description                                                            |
| ----------------------------- | ---------------------------------------------------------------------- |
| View release notes on GitHub  | Opens the selected release on GitHub in a new tab.                     |
| Don't show again              | Suppresses the notification permanently, including for future updates. |
| Remind me next time           | Closes the dialog for now. It opens again the next time you load CIPP. |
| Don't show until next release | Suppresses the notification until CIPP is updated to a newer release.  |

{% hint style="info" %}
These choices are stored in the browser you are using, so they apply to that browser only. Opening CIPP elsewhere, or clearing your browser data, brings the notification back.

Choosing **Remind me next time** or **Don't show until next release** also clears a previous **Don't show again**, so the notification is easy to reinstate without hunting through browser settings.
{% endhint %}

## On a Phone

The dialog fills the screen on a phone, so there is no **Expand** control. The heading doubles as the release picker: select it to open the list of releases and choose the one you want to read.

**Don't show until next release** stays at the foot of the dialog, and **View release notes on GitHub** and **Don't show again** move behind the **More options** button beside it. Closing the dialog with the close icon, the back gesture, or by selecting outside it, does the same as **Remind me next time**.

{% include "../../../.gitbook/includes/feature-request.md" %}

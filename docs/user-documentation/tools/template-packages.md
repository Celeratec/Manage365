# Template Package Manager

CA Templates and Policy (Intune) Templates can be grouped into a package - a shared tag that lets a single Standards Template pull in every template carrying that tag, instead of listing each template's GUID individually. The Template Package Manager is where those packages are viewed, renamed, and deleted, and where their members are managed, for both template types.

{% hint style="info" %}
A package is just a tag shared by its member templates. Deleting a package removes the tag from its members - the templates themselves are not deleted.
{% endhint %}

## Switching Template Type

Use the toggle at the top of the page to switch between Conditional Access Templates and Policy Templates. Each package list is specific to the selected type.

## Managing a Package

Each package is shown with its member count. Expand a package to:

| Action                        | Effect                                                                                     |
| ------------------------------ | -------------------------------------------------------------------------------------------- |
| Add an existing template       | Select any template of the current type that isn't already in this package and add it.       |
| Remove a member                | Removes the tag from that template only. The template itself is unaffected.                  |
| Rename package                 | Re-tags every current member with the new name. Renaming to an existing package's name merges the two. |
| Delete package                 | Removes the tag from every current member. No templates are deleted.                          |

{% hint style="warning" %}
Renaming or deleting a package affects every one of its member templates at once.
{% endhint %}

## Adding a Template to a Package from the Template List

The "Add to package" action on the CA Templates and Policy Templates lists now offers a dropdown of existing packages, in addition to typing a new package name. Picking an existing package from the list avoids mismatches from typing the name by hand.

{% include "../../../.gitbook/includes/feature-request.md" %}

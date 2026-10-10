# JIT Role Templates

This page allows you to manage the JIT Role Templates on your CIPP instance.

A JIT Role Template is a named allow-list of Entra ID directory roles. When a template is assigned to a [CIPP custom role](../../../cipp/advanced/super-admin/custom-roles/README.md), members of that role can only grant the roles contained in the template when creating a JIT Admin, and can only see JIT Admins whose roles fall entirely within the template.

{% hint style="info" %}
Restriction combines the same way CIPP handles multiple custom roles elsewhere - restrictively, not additively. A custom role with no template assigned does not restrict anything on its own, but as soon as a user holds **any** role that has a template they are restricted, and their allowed roles are the **intersection** of every template they hold. An untemplated role therefore cannot be used to bypass a template assigned alongside it. `admin`/`superadmin` users are unaffected, and if no template is assigned anywhere nothing changes - so existing configurations are not disturbed until you explicitly assign one.
{% endhint %}

## Page Actions

<details>

<summary>Add JIT Role Template</summary>

Links to [add-jit-role-template.md](add-jit-role-template.md "mention")

</details>

## Table Data

| Column        | Description                                                         |
| ------------- | ------------------------------------------------------------------ |
| Template Name | The name of the template given at creation or last edit            |
| Roles         | The directory roles included in this allow-list                    |
| Created By    | The user that created the template                                 |
| Created Date  | The date the template was created                                  |

## Table Actions

<table><thead><tr><th>Action</th><th>Description</th><th data-type="checkbox">Bulk Action Available</th></tr></thead><tbody><tr><td>Edit Template</td><td>Allows you to edit the template's name and roles</td><td>false</td></tr><tr><td>Delete Template</td><td>Deletes the selected template</td><td>false</td></tr></tbody></table>

***

{% include "../../../../.gitbook/includes/feature-request.md" %}

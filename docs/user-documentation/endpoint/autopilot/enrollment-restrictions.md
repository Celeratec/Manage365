# Enrollment Restrictions

Enrollment Restrictions lists the device platform restriction policies that control which platforms and OS versions can enrol into Intune. Restrictions are split by platform tabs (Windows, Apple, Android). The default restriction for each platform appears last and is read-only.

## Platforms

| Tab     | Description                                                                 |
| ------- | --------------------------------------------------------------------------- |
| Windows | Windows platform restrictions, including OS version examples where relevant.|
| Apple   | iOS, iPadOS, macOS and related Apple platform restrictions.                 |
| Android | Android work profile and device administrator restriction objects as one row.|

## Table Actions

| Action | Description                                                                                          |
| ------ | ---------------------------------------------------------------------------------------------------- |
| Add    | Creates a new restriction for the current platform tab.                                              |
| Edit   | Updates an existing restriction. The default restriction cannot be edited.                           |
| Delete | Removes the restriction objects behind the row. The default restriction cannot be deleted.           |
| Save as template | Saves the restriction as an enrollment restriction template for later deploy.                 |

Priority controls where a restriction sits relative to others on the same platform. Assignments can target all users, specific groups, or no assignment.

{% include "../../../../.gitbook/includes/feature-request.md" %}

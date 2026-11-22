# Enrollment Restriction Templates

Enrollment Restriction Templates stores reusable enrollment restriction configurations that can be deployed to one or more tenants. Templates are scoped globally; create and edit them here, then deploy from the template drawer.

## Table Details

| Column      | Description                                      |
| ----------- | ------------------------------------------------ |
| Name        | The template display name.                       |
| Platform    | The platform family the template applies to.     |
| Description | Optional notes recorded against the template.    |

## Table Actions

| Action | Description                                                                 |
| ------ | --------------------------------------------------------------------------- |
| Add    | Creates a new enrollment restriction template.                              |
| Edit   | Updates an existing template.                                               |
| Deploy | Opens the deploy drawer to push the template to selected tenants.           |
| Delete | Removes the saved template. Does not delete restrictions already deployed.  |

Deploy follows the same group-handling patterns as other Intune template deploys: existing groups can be picked by id, and named groups can be created when missing.

{% include "../../../../.gitbook/includes/feature-request.md" %}

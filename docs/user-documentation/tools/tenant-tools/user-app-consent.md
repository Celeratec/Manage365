# User-scoped app consent

These endpoints consent an application for named users. They do not grant tenant-wide admin consent. The Application Approval wizard still does that, through an AllPrincipals grant. Use these when the application should be available only to the users or groups you name.

Every call requires `tenantFilter` and runs in that customer tenant with the CIPP-SAM delegated token. Each call is written to the logbook with the tenant, caller, application, users, scopes, and the object ids involved. A Graph rejection is returned with Graph's message and status. CIPP does not report success when Graph refused the call.

## ExecServicePrincipals

`Action=Create` posts the service principal (`POST /servicePrincipals` with `appId`) and stops. It grants no roles and no delegated scopes. Pass `tenantFilter` to create it in the customer tenant. A request that omits `tenantFilter` still creates it in the partner tenant, which is the previous behavior.

`Action=Update` requires `tenantFilter` and sets `appRoleAssignmentRequired`. `true` means only assigned users and groups can sign in to the application.

List and Get are unchanged and still read the partner tenant.

## ExecAppRoleAssignment

`Action=Add` assigns one user or group to the service principal. `appRoleId` defaults to `00000000-0000-0000-0000-000000000000`. `Action=Remove` deletes the assignment by id. An assignment that already exists is reused.

## ExecOAuth2PermissionGrant

`Action=Add` creates a delegated grant with `consentType` `Principal` for one user, against Microsoft Graph unless you pass another `resourceId`. `scope` is a space-separated list. Each name must be one of the scopes that resource publishes. An unknown scope is rejected with 400 and nothing is written.

`Action=Update` replaces the scope list on an existing grant. `Action=Remove` deletes a grant by id.

`consentType` `AllPrincipals` is rejected with 400. This endpoint cannot grant the application to every user in the tenant.

## ExecAppConsentRequest

`Action=Approve` or `Action=Deny` records the decision on one user consent request. The stage is read with `GET .../approval?$expand=stages`. v1.0 is tried first. If that response has no stages, the same read is repeated on beta. The decision is `PATCH .../approval/stages/{stageId}` with `reviewResult` `Approve` or `Deny`. This endpoint does not create an `oauth2PermissionGrant` and does not call the admin consent URL.

`GET .../approval/stages` is not a Graph resource. That URL returns "No HTTP resource was found", which is why the stage is read from the approval object instead.

When the stage has `assignedToMe` false, CIPP is not a reviewer and Graph rejects the decision with `UnknownError` and an empty message. Approving after adding CIPP as a reviewer would let Graph grant admin consent, so this path does not approve. It reads `GET /me`, then `PUT /policies/adminConsentRequestPolicy` with the current settings and one added reviewer, the calling SAM user (`/users/{id}`). A service principal is not a valid reviewer, and this policy does not support PATCH. The stage is then denied with the justification `Handled via per-user grant`. The original policy, including the previous reviewer list, is written back afterwards. Grant the user with `ExecGrantAppToUsers` instead. `Policy.ReadWrite.ConsentRequest` is already on the CIPP-SAM manifest.

## ExecGrantAppToUsers

One call runs the three steps in order: create the service principal if it is missing, require assignment (the default), then assign each user and add or merge a Principal grant. It is safe to run again. An existing service principal, assignment, or grant is reused, and scopes are merged rather than replaced with a shorter list.

Scopes are checked before anything is written. `Metadata.Created` lists only the ids this call created (`servicePrincipalId`, `appRoleAssignmentIds`, `grantIds`). Remove those ids with `ExecAppRoleAssignment` and `ExecOAuth2PermissionGrant` to roll the change back. Ids that were already there are not included, so a second run does not delete the original grant.

## Permissions

CIPP-SAM already requested `Application.ReadWrite.All`, `AppRoleAssignment.ReadWrite.All`, and `DelegatedPermissionGrant.ReadWrite.All`. This release adds `ConsentRequest.ReadWrite.All` (delegated and application) and the application-permission forms of `DelegatedPermissionGrant.ReadWrite.All` and `AppRoleAssignment.ReadWrite.All` to `backend/Config/SAMManifest.json`.

The directory role that can perform these Graph calls is Application Administrator, which is already on the GDAP invite list. Adding the manifest entries does not consent them. Run a permissions repair, then a CPV refresh, so each customer tenant picks up `ConsentRequest.ReadWrite.All`. Until that refresh, approving a consent request can fail with Graph's permission error, which is returned as Graph reported it.

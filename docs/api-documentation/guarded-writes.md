# Guarded tenant writes

These endpoints are off until an administrator enables the **Guarded tenant writes** feature flag. A read-only API client receives 403 from the role check. The MCP catalog only publishes roles ending in `.Read`, so these write operations are not offered as MCP tools.

Every guarded write takes `tenantFilter`, `ticketNumber` (6 to 8 digits), `dryRun`, and `reason`. `TicketNumber` and `WhatIf` are accepted as the same fields. `dryRun: true` validates and returns `Before` without calling Graph or Exchange. The response includes `Results`, `Status` (`Success`, `DryRun`, or `Failed`), and `AuditId`. An unknown cmdlet, parameter, or Graph path returns 403 and is audited.

The admin role already includes every permission the API publishes. That list is cached by CIPP version, and the Manage365 image keeps that version at the CIPP baseline, so a new role was invisible until the cache key also included the image commit. `ListMyApiRoles` returns the permissions the caller has after that resolution. It uses `CIPP.Core.Read`.

| Endpoint | Role |
| --- | --- |
| `ExecGraphWrite` | `Tenant.AppGovernance.ReadWrite` |
| `ExecExoAllowlistedCmdlet` | `Exchange.Security.ReadWrite` |
| `ExecSecurityDefaults` | `Tenant.AppGovernance.ReadWrite` |
| `ExecTeamsAppUpload` | `Teams.AppCatalog.ReadWrite` |
| `ExecPermissionGrantPreApproval` | `Tenant.AppGovernance.ReadWrite` |
| `ExecAppRegistration` | `Tenant.AppGovernance.ReadWrite` |
| `GetAppRegistrationSecret` | `Tenant.AppGovernance.ReadWrite` |
| `ExecSetMailboxCustomAttributes` | `Exchange.Mailbox.ReadWrite` |
| `ListMyApiRoles` | `CIPP.Core.Read` |
| `ListPermissionGrantPreApproval` | `Tenant.AppGovernance.Read` |
| `ListSecurityDefaults` | `Tenant.AppGovernance.Read` |
| `ListUserAuthMethods` | `Identity.User.Read` |

`ExecGraphWrite` only accepts the method, path, and API version pairs in `backend/Config/GuardedWrites/GraphAllowlist.json`, on `v1.0` and `beta`. That list is also in the OpenAPI description. It covers app role assignment create and delete, `oauth2PermissionGrants` with `consentType` `Principal` only, security defaults, chat installed apps, and delete of a Teams catalog app, an application, or a service principal.

`ExecExoAllowlistedCmdlet` only accepts the cmdlets and parameters in `backend/Config/GuardedWrites/ExoCmdletAllowlist.json`. `New-ManagementRoleAssignment` accepts `Role` of exactly `Application Mail.Read`, `Application Calendars.Read`, or `Application Mail.ReadBasic`. `Set-MailboxJunkEmailConfiguration` accepts `TrustedSendersAndDomains` and `BlockedSendersAndDomains`, not the `*ToAdd` parameters. `Remove-ServicePrincipal` and `Remove-ManagementScope` take `Identity`.

`ExecAppRegistration` prefers a certificate (`Certificate` plus `CertificatePublicKeyBase64`). A secret is stored in Key Vault under `appreg-{appId}-{keyId}` and the response carries `SecretUri`, `RetrievalEndpoint`, and `RetrievalExpiresAt` (24 hours). It never returns the secret. `GetAppRegistrationSecret` returns it once and then deletes it. The same caller needs `Tenant.AppGovernance.ReadWrite`.

`ExecSetMailboxCustomAttributes` accepts `AttributeNumber` 1–15 and `Value` up to 1024 characters. An empty value clears the attribute. The response includes the old and new values. The mailbox editor can still send `CustomAttribute1`–`CustomAttribute15` without a ticket.

`ExecCustomMailFilterPolicy`, `ExecPresetSecurityPolicy`, `ExecInboundConnectorEnhancedFiltering`, `ExecMailboxJunkConfiguration`, and `ExecFocusedInbox` are on the same flag. They already require `ticketNumber`. The flag's stored on/off choice is kept; the endpoint names are read from `FeatureFlags.json` on each request. The repo default remains off.

`ListMailQuarantine` accepts `StartReceivedDate`, `EndReceivedDate`, `SenderAddress`, `RecipientAddress`, and `QuarantineTypes` in addition to the existing names. A range longer than 30 days is rejected. Omitting the dates still searches the last 7 days.

`ExecEditCAPolicyFull` reads the current policy, merges the supplied fields, and refuses the PATCH when it would drop `grantControls`, `sessionControls`, `conditions`, `excludeUsers`, or `excludeGroups` unless `ConfirmRemoval` names those fields.

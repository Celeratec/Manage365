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
| `ExecSoftDeleteMailboxFolder` | `Exchange.Mailbox.ReadWrite` |
| `ExecRestoreMailboxFolder` | `Exchange.Mailbox.ReadWrite` |
| `ListMyApiRoles` | `CIPP.Core.Read` |
| `ListPermissionGrantPreApproval` | `Tenant.AppGovernance.Read` |
| `ListSecurityDefaults` | `Tenant.AppGovernance.Read` |
| `ListUserAuthMethods` | `Identity.User.Read` |

`ExecGraphWrite` only accepts the method, path, and API version pairs in `backend/Config/GuardedWrites/GraphAllowlist.json`, on `v1.0` and `beta`. That list is also in the OpenAPI description. It covers app role assignment create and delete, `oauth2PermissionGrants` with `consentType` `Principal` only, security defaults, chat installed apps, and delete of a Teams catalog app, an application, or a service principal.

`ExecExoAllowlistedCmdlet` only accepts the cmdlets and parameters in `backend/Config/GuardedWrites/ExoCmdletAllowlist.json`. Transport-rule cmdlets `Set-TransportRule` (Identity plus Mode and/or Priority), `Enable-TransportRule`, and `Disable-TransportRule` also require `Exchange.TransportRule.ReadWrite` and default `dryRun` to true when omitted (other allowlisted cmdlets still default to execute when `dryRun` is omitted). `Mode` is Audit, AuditAndNotify, or Enforce; `Priority` is an integer ≥ 0 within 0..N-1. Priority changes return the whole ordered rule list as `Before`/`After` and a `Rollback` payload `{ Cmdlet, Parameters }`. `New-ManagementRoleAssignment` accepts `Role` of exactly `Application Mail.Read`, `Application Calendars.Read`, or `Application Mail.ReadBasic`. `Set-MailboxJunkEmailConfiguration` accepts `TrustedSendersAndDomains` and `BlockedSendersAndDomains`, not the `*ToAdd` parameters. `Remove-ServicePrincipal` and `Remove-ManagementScope` take `Identity`. `Set-AcceptedDomain` accepts `Identity` (domain name, 1-253 characters total, each label ≤63 characters, no leading or trailing whitespace, no control characters) and `DomainType` (Authoritative, InternalRelay, or ExternalRelay). `Set-DkimSigningConfig` accepts `Identity` (domain name, same constraints) and `Enabled` (boolean: true/false/1/0, coerced to a real bool). `Disable-Mailbox` accepts `Identity` (1-320 characters, UPN/SMTP/GUID only, no wildcards or tokens, requires at least one dot in domain), `Archive` (must be true), and `Confirm` (must be false); only archive disable is allowed and full mailbox disable is rejected. **The allowlisted `Disable-Mailbox` route has NO item-count guard.** Use `ExecDisableArchive` for archives with items; it requires `Force` and `Reason` when the archive contains items. Parameter names must start with an ASCII letter and contain only ASCII letters and digits (e.g. `CustomAttribute1`). For domain Identity validation, trailing-dot FQDNs, underscores, and non-ASCII characters are rejected; use the `xn--` punycode form for internationalized domain names. Archive preflight checks `ArchiveGuid` (must parse as a valid non-zero GUID) and requires `ArchiveStatus` eq 'Active' OR a non-null `ArchiveDatabase`; the preflight runs on `dryRun` too. When `dryRun: true`, the endpoint calls the corresponding `Get-*` cmdlet (`Get-Mailbox` for `Disable-Mailbox`) against Exchange Online to retrieve the current state and returns it as `Before`; it does not execute the `Set-*` or `Disable-*` cmdlet. On real execution, `Before` is read first, then the change is applied, then `After` is read (`Get-Mailbox` again for `Disable-Mailbox`).

`ExecAppRegistration` prefers a certificate (`Certificate` plus `CertificatePublicKeyBase64`). A secret is stored in Key Vault under `appreg-{appId}-{keyId}` and the response carries `SecretUri`, `RetrievalEndpoint`, and `RetrievalExpiresAt` (24 hours). It never returns the secret. `GetAppRegistrationSecret` returns it once and then deletes it. The same caller needs `Tenant.AppGovernance.ReadWrite`.

`ExecSetMailboxCustomAttributes` accepts `AttributeNumber` 1–15 and `Value` up to 1024 characters. An empty value clears the attribute. The response includes the old and new values. The mailbox editor can still send `CustomAttribute1`–`CustomAttribute15` without a ticket.

`ExecSoftDeleteMailboxFolder` and `ExecRestoreMailboxFolder` move a single mailbox folder to or from **Deleted Items** via Microsoft Graph only. Permanent delete is prohibited. Well-known/default folders, shared/linked/delegated calendars, folders already in Deleted Items, and search folders are refused. `preview` / `dryRun` defaults to true; ticket, reason, `tenantFilter`, `userId`, and `folderId` or `folderPath` are required. Expect the service principal (SAM) application to hold Graph application permissions **Mail.ReadWrite** and, for calendar folder trees, possibly **Calendars.ReadWrite** — confirm against the SAM app registration after test-mailbox verification.

`ExecCustomMailFilterPolicy`, `ExecPresetSecurityPolicy`, `ExecInboundConnectorEnhancedFiltering`, `ExecMailboxJunkConfiguration`, `ExecFocusedInbox`, `ExecSoftDeleteMailboxFolder`, and `ExecRestoreMailboxFolder` are on the same flag. They already require `ticketNumber`. The flag's stored on/off choice is kept; the endpoint names are read from `FeatureFlags.json` on each request. The repo default remains off.

`ListMailQuarantine` accepts `StartReceivedDate`, `EndReceivedDate`, `SenderAddress`, `RecipientAddress`, and `QuarantineTypes` in addition to the existing names. A range longer than 30 days is rejected. Omitting the dates still searches the last 7 days.

`ExecEditCAPolicyFull` reads the current policy, merges the supplied fields, and refuses the PATCH when it would drop `grantControls`, `sessionControls`, `conditions`, `excludeUsers`, or `excludeGroups` unless `ConfirmRemoval` names those fields.

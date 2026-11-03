# Guarded tenant writes

These endpoints are off until an administrator enables the **Guarded tenant writes** feature flag. A read-only API client receives 403 from the role check. The MCP catalog only publishes roles ending in `.Read`, so these write operations are not offered as MCP tools.

Every write takes `tenantFilter`, a numeric `TicketNumber` of 6 to 8 digits, `WhatIf`, and `Reason`. `WhatIf: true` validates and returns `WhatIfPlan` and `Before` without calling Graph or Exchange. The response includes `Results`, `Status` (`Success`, `DryRun`, or `Failed`), and `AuditId`. Secret values are stored in Key Vault and are not returned.

| Endpoint | Role |
| --- | --- |
| `ExecGraphWrite` | `Tenant.AppGovernance.ReadWrite` |
| `ExecExoAllowlistedCmdlet` | `Exchange.Security.ReadWrite` |
| `ExecSecurityDefaults` | `Tenant.AppGovernance.ReadWrite` |
| `ExecTeamsAppUpload` | `Teams.AppCatalog.ReadWrite` |
| `ExecPermissionGrantPreApproval` | `Tenant.AppGovernance.ReadWrite` |
| `ExecAppRegistration` | `Tenant.AppGovernance.ReadWrite` |
| `ListPermissionGrantPreApproval` | `Tenant.AppGovernance.Read` |
| `ListSecurityDefaults` | `Tenant.AppGovernance.Read` |
| `ListUserAuthMethods` | `Identity.User.Read` |

`ExecGraphWrite` only accepts the method, path, and API version pairs in `backend/Config/GuardedWrites/GraphAllowlist.json`. `consentType` defaults to `Principal`. `AllPrincipals` also requires `Tenant.AppGovernance.AllPrincipals`.

`ExecExoAllowlistedCmdlet` only accepts the cmdlets and parameters in `backend/Config/GuardedWrites/ExoCmdletAllowlist.json`. `Set-MailboxJunkEmailConfiguration` accepts `TrustedSendersAndDomains` and `BlockedSendersAndDomains`, not the `*ToAdd` parameters.

`ListMailQuarantine` accepts `StartReceivedDate`, `EndReceivedDate`, `SenderAddress`, `RecipientAddress`, and `QuarantineTypes` in addition to the existing names. A range longer than 30 days is rejected. Omitting the dates still searches the last 7 days.

`ExecEditCAPolicyFull` reads the current policy, merges the supplied fields, and refuses the PATCH when it would drop `grantControls`, `sessionControls`, `conditions`, `excludeUsers`, or `excludeGroups` unless `ConfirmRemoval` names those fields.

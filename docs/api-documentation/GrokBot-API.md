# Manage365 API reference for GrokBot

Instance: Manage365 production, release 6.1.9, CIPP baseline 11.0.2.
This client is **GrokBot API**. It is enabled, role **admin**, IP allow list **Any**.
Do not use the other app, **GrokBot** (`4ecfb394-0cff-47d5-9243-906b0b01bfd4`). That one is the MCP connector and can only read.

The field-level source of truth is the live OpenAPI document. Fetch it with no token:

https://manage365.celeratec.cloud/openapi.json

Paths below are generated from that spec. A `*` marks a required field. `{label, value}` means send an object; the server reads `value` and ignores a bare string.

## Authentication

Token URL:

`POST https://login.microsoftonline.com/d8aa5d80-662b-49b9-932a-43030b269e85/oauth2/v2.0/token`

Form body:

```
client_id=c25d9256-9aa0-48df-b693-1d66b0e7f967
client_secret=<the GrokBot API secret; not included here>
grant_type=client_credentials
scope=api://c25d9256-9aa0-48df-b693-1d66b0e7f967/.default
```

These audiences are accepted:

- `api://c25d9256-9aa0-48df-b693-1d66b0e7f967`
- `https://cippbefno.azurewebsites.net`

The bare application id, with no `api://` prefix, is rejected with 401. `https://manage365.celeratec.cloud` is not a token audience.

Send the access token on every API call:

```
Authorization: Bearer <access_token>
Accept-Encoding: br, gzip
Content-Type: application/json
```

Base URL for calls: `https://manage365.celeratec.cloud`
`https://cippbefno.azurewebsites.net` is the same site. Prefer the manage365 host.

## How to call

- The path is case-sensitive. `GET` or `POST https://manage365.celeratec.cloud/api/<EndpointName>`.
- Query string for GET. JSON body for POST. The server also accepts some fields from either place; send them where this reference lists them.
- `tenantFilter` is the customer tenant's default domain (for example `contoso.onmicrosoft.com`), its tenant id, or `AllTenants`. It is not a display name.
- `AllTenants` on a list that supports `UseReportDB=true` reads the cache. Without that flag it queries every tenant live and is slow.
- `UseReportDB=true` returns the overnight cache, up to about 24 hours old. Omit it when the change has to be live.
- Encode guest UPNs in query strings. A `#` in `#EXT#` truncates the query.
- List tenants first with `GET /api/ListTenants` and use each row's `defaultDomainName` as `tenantFilter`.
- Rate limit: 100 requests per 10 second window for this client. Over the limit is HTTP 429 with `Retry-After`. Wait and retry. Do not burst.
- A single call may run up to 10 minutes.
- Success bodies are often a JSON array, or `{ "Results": "..." }`. Errors may be `{ "Results": "..." }` or a plain string.
- HTTP 401: token missing, expired, or the audience is not one of the two above.
- HTTP 403: this client is not allowed to call that endpoint. Super-admin endpoints are in that set for this client.
- HTTP 503 with `This feature has been disabled`: the endpoint is switched off on this container. Do not retry.

## What this client can and cannot do

Role `admin` includes every permission except `CIPP.SuperAdmin.*`. Endpoints marked FORBIDDEN below will return 403. Do not try to work around that.

Do not call setup or authentication-repair endpoints (`ExecSAMSetup`, `ExecUpdateRefreshToken`, `ExecTokenExchange`, SSO setup, or anything that recreates CIPP-SAM). Production is already set up.

App registration display names that must stay as they are: CIPP-SAM, CIPP-SSO, CIPP-MCP, CIPP-API. The product name in user-facing text is Manage365.

Baselines are on for this instance. Classic Standards and Drift scheduled runs do not run beside them. Read baseline state before deploying classic standards.

These endpoints return 503 on this container:

- `POST /api/ExecAppInsightsQuery`
- `POST /api/ExecOffloadFunctions`

## MCP

MCP is a different connection and it cannot make changes. Connector URL for the **GrokBot** client (not GrokBot API):

`https://manage365.celeratec.cloud/api/ExecMcp?client=4ecfb394-0cff-47d5-9243-906b0b01bfd4`

MCP only publishes tools whose role ends in `.Read`, and it drops names that look like a change (Add, Set, Remove, Edit, and similar). `ExecTool` cannot run an endpoint that is not in that catalog. `ListGraphRequest` is a Graph GET. To change anything, use this API with the GrokBot API token.

## Endpoint index

816 operations.


### CIPP > Core

- `POST /api/ExecAddAlert` — `CIPP.Alert.ReadWrite`
  body: sendEmailNow, sendPsaNow, sendWebhookNow, tenantFilter, text, writeLog
- `POST /api/ExecAppInsightsQuery` — `CIPP.SuperAdmin.Read` — FORBIDDEN for this client (super admin only); returns 503 on this container (App Insights is off)
  Runs a Kusto (KQL) query against the CIPP instance's own Application Insights telemetry and returns the result rows. The query is echoed back in Metadata. query: query body: query*
- `POST /api/ExecAzBobbyTables` — `CIPP.SuperAdmin.ReadWrite` — FORBIDDEN for this client (super admin only)
  This function is used to interact with Azure Tables. This is advanced functionality used for external integrations or SuperAdmin functionality. body: FunctionName, Parameters, TableName
- `POST /api/ExecCIPPDBCache` — `CIPP.Core.ReadWrite`
  query: Name*, tenantFilter*, Types
- `POST /api/ExecCIPPDBCacheAdmin` — `CIPP.SuperAdmin.ReadWrite` — FORBIDDEN for this client (super admin only)
  Typed alternative to Table Maintenance for the reporting cache. List returns decoded cache objects stamped with CIPPPartitionKey / CIPPRowKey / CIPPETag so the UI can delete by storage key. Empty clears an entire type... body: Action, Rows, TenantFilter*, Type
- `POST /api/ExecCPVRefresh` — `CIPP.Core.ReadWrite`
- `POST /api/ExecCippFunction` — `CIPP.SuperAdmin.ReadWrite` — FORBIDDEN for this client (super admin only)
  This function is used to execute a CIPPCore function from an HTTP request. This is advanced functionality used for external integrations or SuperAdmin functionality. body: FunctionName, Parameters
- `POST /api/ExecCippLogsSas` — `CIPP.AppSettings.ReadWrite`
  Creates a long-lived, read-only SAS URL for the CippLogs Azure Storage table. query: Days body: Days
- `POST /api/ExecCloneTemplate` — `CIPP.Core.ReadWrite`
  query: GUID, Type body: GUID, Type
- `POST /api/ExecDiagnosticsPresets` — `CIPP.SuperAdmin.ReadWrite` — FORBIDDEN for this client (super admin only)
  body: action, GUID*, name, query
- `POST /api/ExecDurableFunctions` — `CIPP.AppSettings.ReadWrite`
  query: Action, PartitionKey
- `POST /api/ExecEditTemplate` — `CIPP.Core.ReadWrite`
  query: Type body: description, displayName, GUID, id, name, parsedRAWJson, Type
- `POST /api/ExecFeatureFlag` — `CIPP.AppSettings.ReadWrite`
  body: Action, Enabled*, Id*
- `POST /api/ExecGeoIPLookup` — `CIPP.Core.Read`
  Resolves a single IP address to its geographic location using CIPP's bundled GeoIP database. query: IP body: IP
- `GET /api/ExecGraphRequestProfile` — `CIPP.Core.Read`
  Profiles a Graph request for troubleshooting, timing the call and reporting what it returned. Passing Mode=Diagnostics instead returns a point-in-time snapshot of the CIPPSharp REST client and token cache counters wit... query: Endpoint, manualPagination, Mode, Reset, tenantFilter*, Version
- `POST /api/ExecLicenseSearch` — `CIPP.Core.Read`
  Resolves licence SKU ids to display names from the licence name table, falling back to the given tenant's cached licence overview. Takes an array of skuIds in the body. body: skuIds [string], tenantFilter
- `GET /api/ExecListBackup` — `CIPP.Backup.Read`
  query: BackupName, NameOnly, tenantFilter*, Type
- `POST /api/ExecPartnerWebhook` — `CIPP.AppSettings.ReadWrite`
  query: Action, CorrelationId body: enabled, EventType {label, value}, standardsExcludeAllTenants
- `POST /api/ExecRemoveSnooze` — `CIPP.AlertSnooze.ReadWrite`
  query: PartitionKey, RowKey body: PartitionKey, RowKey
- `POST /api/ExecSAMCertificate` — `CIPP.AppSettings.ReadWrite`
  Returns status information about the SAM app certificate (thumbprint, validity, registration state) or forces a renewal via Update-CIPPSAMCertificate. Never returns private key material. query: Action body: Action
- `POST /api/ExecServicePrincipals` — `Tenant.Application.ReadWrite`
  query: Action, AppId, Id, Select
- `POST /api/ExecSetCIPPAutoBackup` — `CIPP.Backup.ReadWrite`
  body: Enabled
- `POST /api/ExecSetPackageTag` — `CIPP.Core.ReadWrite`
- `POST /api/ExecSnoozeAlert` — `CIPP.AlertSnooze.ReadWrite`
  Snoozes one alert item so it stops notifying. Body: CmdletName, TenantFilter, AlertItem, and either Duration (7, 14, 30 or 90 days) or UntilResolved=true, which keeps the snooze until the alert stops reporting the ite... body: AlertItem, CmdletName, Duration, KeepVisible, Reason, TenantFilter, UntilResolved
- `GET /api/ExecUniversalSearch` — `CIPP.Core.Read`
  Searches every tenant for a user by display name or user principal name, using a cross-tenant Graph query. Superseded by ExecUniversalSearchV2, which searches the cached data and covers groups, applications and licenc... query: name
- `GET /api/ExecUniversalSearchV2` — `CIPP.Core.Read`
  Searches cached report data the caller can access and returns matches with the tenant each belongs to. type selects what is searched: Users (the default), Groups, Applications or Licenses. An explicit tenantFilter is... query: limit, searchTerms, tenantFilter, type
- `GET /api/GetCippAlerts` — `CIPP.Core.Read`
  Returns the CIPP dashboard banner notifications: any hosted maintenance notice, a legacy infrastructure warning for instances still on Function Apps, today's most recent entries from the alert log, and warnings for an... query: localversion
- `GET /api/GetVersion` — `CIPP.Core.Read`
  Compares the caller's reported CIPP version against the latest published release and reports whether the frontend or the API is out of date, alongside the hosting shape (hosting type, App Service SKU, runtime stack) a... query: CleanupStale, LocalVersion
- `GET /api/ListAdminPortalLicenses` — `CIPP.Core.Read`
  Retrieves license information from the Microsoft 365 Admin Portal for a tenant, including low-friction trial allotments. query: tenantFilter*
- `GET /api/ListAlertResults` — `CIPP.Alert.Read`
  Lists the tracked alert items for a tenant from the AlertLifecycle table, which Write-AlertTrace maintains: one row per alert item with its Status (Open, Snoozed or Resolved), when it was first and last seen, when it... query: Days, IncludeResolved, tenantFilter*
- `GET /api/ListApiTest` — `CIPP.Core.Read`
  Returns debug information about the current API request, trigger metadata, and environment variables. Used for CIPP platform diagnostics.
- `GET /api/ListCippDocs` — `CIPP.Core.Read`
  Searches the GitBook documentation shipped with this build and returns matching sections, each with an excerpt and links back to docs.cipp.app and to the file on GitHub. Pages under user-documentation also report the... query: full, limit, path*, query
- `GET /api/ListCippQueue` — `CIPP.Core.Read`
  Lists active and recent CIPP background processing queue items and their status.
- `GET /api/ListCippQueues` — `CIPP.Core.Read`
  Lists several CIPP background queues at once and rolls them up into a single progress figure. ListCippQueue reports one queue; this exists for the actions that start several at a time - syncing a report that is compil... query: QueueIds
- `GET /api/ListCustomDataMappings` — `CIPP.Core.Read`
  Lists custom data mappings that define how external data sources map to CIPP directory objects, filterable by source type, directory object, and tenant. query: directoryObject, sourceType, tenantFilter*
- `GET /api/ListDBCache` — `CIPP.Core.Read`
  Retrieves cached tenant data from the CIPP reporting database (CippReportingDB). This is the fastest and most efficient way to query tenant data across single or multiple tenants. The database is populated nightly by... query: countsOnly, dateField, groupBy, latestOnly, select, tenantFilter*, top, type
- `GET /api/ListDiagnosticsPresets` — `CIPP.SuperAdmin.Read` — FORBIDDEN for this client (super admin only)
  Lists saved diagnostics presets used for troubleshooting CIPP configuration. Requires SuperAdmin access.
- `POST /api/ListDirectoryObjects` — `CIPP.Core.Read`
  Resolves Entra ID directory objects by their IDs using the directoryObjects/getByIds batch endpoint. Accepts an array of object IDs in the request body. body: $select, asApp, ids, partnerLookup, tenantFilter
- `GET /api/ListEmptyResults` — `CIPP.Core.Read`
  Returns an empty results array. Used as a placeholder endpoint.
- `GET /api/ListExtensionCacheData` — `CIPP.Core.Read`
  This function is used to list the extension cache data. query: dataTypes, tenantFilter*
- `GET /api/ListFeatureFlags` — `CIPP.Core.Read`
  Lists CIPP feature flags and their enabled/disabled state, including environment-driven overrides.
- `GET /api/ListFunctionStats` — `CIPP.Core.Read`
  Lists execution statistics for CIPP functions, including timing and performance metrics, filterable by function type and time range. query: FunctionType, Interval, tenantFilter*, Time
- `GET /api/ListGenericTestFunction` — `CIPP.Core.Read`
  Returns the original request URL for debugging purposes. Used for CIPP platform diagnostics.
- `POST /api/ListGraphBulkRequest` — `CIPP.Core.Read`
  Executes multiple Microsoft Graph API requests in a single batch call for a given tenant. Accepts an array of request objects in the body. body: asApp, noPaginateIds, requests [object], tenantFilter*
- `GET /api/ListGraphRequest` — `CIPP.Core.Read`
  Proxies an arbitrary Microsoft Graph API GET request for a tenant. Supports custom endpoints, filters, pagination, and field selection via query parameters. If a request returns a permission error, retry with AsApp se... query: $count, $expand, $filter, $format, $orderby, $search, $select, $top, AsApp, CountOnly, Endpoint, expand, graphFilter, IgnoreErrors, ListProperties, manualPagination, maxPageBytes, nextLink, NoPagination, QueueId, QueueNameOverride, ReverseTenantLookup, ReverseTenantLookupProperty, SkipCache, Sort, tenantFilter*, Version
- `GET /api/ListGraphSchema` — `CIPP.Core.Read`
  Describes what a Microsoft Graph endpoint returns without calling it: the entity type behind the path, every property with its type, and the navigation properties that can be expanded or traversed. Use it to check whe... query: Endpoint*, Version
- `GET /api/ListKnownIPDb` — `CIPP.IPDatabase.Read`
  Lists known IP address entries from the CIPP IP database, optionally filtered by tenant.
- `GET /api/ListLogs` — `CIPP.Logs.Read`
  Lists CIPP platform audit logs with filtering by severity, date range, tenant, and user. Supports listing available log categories, fetching a single entry, and server-side pagination via manualPagination/nextLink. Pa... query: API, BaselineRunId, countsOnly, DateFilter, Days, EndDate, Filter, ListLogs, logentryid, manualPagination, nextLink, PageSize, ScheduledTaskId, Search, Severity, StandardTemplateId, StartDate, summaryOnly, Tenant, User
- `GET /api/ListPartnerTenantInfo` — `CIPP.Core.Read`
  Reports whether the CIPP host tenant is a Microsoft Partner tenant, so the frontend can decide whether partner-only flows (GDAP onboarding, reseller invites, GDAP permission checks) apply to this instance.  Marked Any...
- `GET /api/ListSnoozedAlerts` — `CIPP.AlertSnooze.Read`
  Lists alerts that have been snoozed (temporarily suppressed), filterable by cmdlet name. Returns the snooze duration, whether it runs until the item resolves, whether the item stays visible on the dashboard, and who s... query: CmdletName
- `POST /api/PublicPhishingCheck` — `Public`
  body: AlertMessage, Cloned, reason, score, source, TenantId, threshold, type, url, userDisplayName, userEmail
- `GET /api/PublicPing` — `Public`
- `POST /api/RemoveCippQueue` — `CIPP.Core.ReadWrite`

### CIPP > Extensions

- `POST /api/ExecExtensionClearHIBPKey` — `CIPP.Extension.ReadWrite`
- `POST /api/ExecExtensionMapping` — `CIPP.Extension.ReadWrite`
  query: AddMapping, AutoMapping, List, TicketType
- `POST /api/ExecExtensionNinjaOneQueue` — `CIPP.Extension.ReadWrite`
- `POST /api/ExecExtensionSync` — `CIPP.Extension.ReadWrite`
  query: Extension, tenantFilter*, TenantID
- `GET /api/ExecExtensionTest` — `CIPP.Extension.Read`
  query: extensionName
- `POST /api/ExecExtensionsConfig` — `CIPP.Extension.ReadWrite`
- `POST /api/ExecHaloPSATestTicket` — `CIPP.Extension.ReadWrite`
- `GET /api/ListExtensionSync` — `CIPP.Extension.Read`
  Lists extension synchronization tasks and their status, including last sync results for configured third-party integrations (Hudu, Halo, NinjaOne, etc.).
- `GET /api/ListExtensionsConfig` — `CIPP.Extension.Read`
  Lists the current CIPP extension configuration, including settings for HaloPSA, NinjaOne, Hudu, and other integrations.
- `GET /api/ListHaloClients` — `CIPP.Extension.Read`
  Lists client records from the configured HaloPSA instance for tenant mapping purposes.

### CIPP > MCP

- `POST /api/ExecMcp` — `CIPP.Core.Read`
  A Streamable-HTTP MCP server running in JSON response mode (no SSE). It exposes CIPP's read-only API surface as MCP tools, projected at runtime from openapi.json.  Every 'tools/call' is re-dispatched through New-CippC... body: id, method*, params
- `POST /api/PublicMcpRegister` — `Public`
  Entra ID offers no registration endpoint, but MCP clients (Claude, ChatGPT, VS Code) attempt dynamic client registration as the first step of connecting with only a URL. This endpoint closes that gap without any token... query: client body: client_name, redirect_uris

### CIPP > Scheduler

- `POST /api/AddScheduledItem` — `CIPP.Scheduler.ReadWrite`
  query: DisallowDuplicateName, hidden body: DesiredStartTime, DisallowDuplicateName, RowKey, RunNow
- `POST /api/ExecSchedulerBillingRun` — `Scheduler.Billing.ReadWrite`
- `GET /api/ListAsyncDeployment` — `CIPP.Scheduler.Read`
  Returns the status rows of a background job that reports progress while it runs, such as a user offboarding started from the wizard: one row per target (the user) with its overall status and the status and message of... query: DeploymentId*
- `GET /api/ListFunctionParameters` — `CIPP.Core.Read`
  Lists the CIPP PowerShell functions that can be run from the scheduler, with each one's parameters and help text. Filter with Module or Function. Internal and entrypoint functions are excluded, so this is the set of c... query: Compliance, Function, Module
- `GET /api/ListScheduledItemDetails` — `CIPP.Scheduler.Read`
  query: RowKey*
- `GET /api/ListScheduledItems` — `CIPP.Scheduler.Read`
  Lists scheduled tasks in CIPP, filterable by tenant or task ID. Returns task name, command, schedule, and last execution status. query: Id, Name, SearchTitle, ShowHidden, tenantFilter, Type
- `POST /api/RemoveScheduledItem` — `CIPP.Scheduler.ReadWrite`
  Removes a scheduled item from CIPP's scheduler. query: id body: id

### CIPP > Settings

- `GET /api/ExecAPIPermissionList` — `CIPP.SuperAdmin.Read` — FORBIDDEN for this client (super admin only)
  Lists every CIPP API endpoint grouped by the role that gates it. Backs the permission picker in the custom role editor.
- `POST /api/ExecAccessChecks` — `CIPP.AppSettings.Read`
  Runs the CIPP deployment's self-diagnostics and returns the result. Type selects the check: 'Permissions' verifies the SAM application's Graph permissions, 'Tenants' tests access to each tenant, and 'GDAP' inspects th... query: SkipCache, TenantId, Type body: SkipCache, TenantId, Type
- `POST /api/ExecAddTrustedIP` — `CIPP.AppSettings.ReadWrite`
  Sets each IP address or CIDR range (IPv4 or IPv6) to Trusted, Blocked or NotTrusted (neutral) for one tenant, or for every tenant with tenantfilter=AllTenants. A tenant entry overrides an AllTenants entry for the same... query: tenantFilter* body: IP [string], Note, State
- `POST /api/ExecApiClient` — `CIPP.Extension.ReadWrite`
  query: Action body: Action, AppName, CIPPAPI, ClientId, Enabled, IpRange {label, value}, MCPAllowed, PublicRedirectUris, RedirectUris, RemoveAppReg, Role {label, value}, WebRedirectUris
- `POST /api/ExecAppServiceDomains` — `CIPP.SuperAdmin.ReadWrite` — FORBIDDEN for this client (super admin only)
  Drives the super-admin "Custom Domains" page. All actions operate on the App Service that hosts this CIPP instance (Microsoft.Web/sites/$env:WEBSITE_SITE_NAME) using the managed identity via New-CIPPAzRestRequest — th... query: Action, Hostname body: Action, DnsRecordType, Hostname*
- `POST /api/ExecBECRemediationDefaults` — `CIPP.AppSettings.ReadWrite`
  GET with List=true returns the containment catalog (Id, Label, Description, Impact, DefaultSelected) with the instance-wide defaults applied. POST with DefaultActions saves the action ids that start selected in the BE... query: List body: DefaultActions [{label, value}]
- `GET /api/ExecBackendURLs` — `CIPP.AppSettings.Read`
  Returns Azure portal deep links for the CIPP deployment's own infrastructure (resource group, key vault, the function app or web app, its App Service plan, static web app) plus its subscription, SKU and timezone. Whet...
- `POST /api/ExecBackupReplicationConfig` — `CIPP.AppSettings.ReadWrite`
  query: List body: BackupType, Enabled, SASUrl
- `POST /api/ExecBackupRetentionConfig` — `CIPP.AppSettings.ReadWrite`
  query: List body: RetentionDays
- `POST /api/ExecBrandingSettings` — `CIPP.AppSettings.ReadWrite`
  query: Action body: Action, colour, coverFooterText, coverImageId, coverImageIds, coverStock, data, footerText, id, kind, logoImageId, logoImageIds, name, reportDefaults, roleColours, secondaryColour, showFooter, showPageNumbers, tenantLabel, watermarkEnabled, watermarkText
- `POST /api/ExecCIPPUsers` — `CIPP.SuperAdmin.ReadWrite` — FORBIDDEN for this client (super admin only)
  query: Action body: Action, Roles, UPN*
- `POST /api/ExecCPVPermissions` — `CIPP.AppSettings.ReadWrite`
  query: ResetSP body: tenantFilter*
- `POST /api/ExecCippReplacemap` — `Tenant.Config.ReadWrite`
  query: Action, includeGlobal, tenantId body: Action, Description, includeGlobal, RowKey, tenantId, Value, VariableType {label, value}
- `POST /api/ExecContainerManagement` — `CIPP.SuperAdmin.ReadWrite` — FORBIDDEN for this client (super admin only)
  query: Action body: Action, AutoUpdate, Channel*, CheckInterval, CheckTime
- `POST /api/ExecCreateDefaultGroups` — `Tenant.Groups.ReadWrite`
  This function creates a set of default tenant groups that are commonly used
- `POST /api/ExecCustomData` — `CIPP.AppSettings.ReadWrite`
  query: Action, id, targetObject body: Action, dataType, id, isMultiValued, Mapping, name, schemaExtension, status, targetObjects, type
- `POST /api/ExecCustomRole` — `CIPP.SuperAdmin.ReadWrite` — FORBIDDEN for this client (super admin only)
  query: Action body: Action, AllowedRolesTemplate, AllowedTenants, BlockedEndpoints, BlockedTenants, EntraGroup {label, value}, IpRange, NewRoleName, PermissionRules, Permissions, RoleName
- `POST /api/ExecDnsConfig` — `Tenant.Domains.ReadWrite`
  query: Action, Domain, Resolver, Selector body: Action, Domain, Resolver, Selector
- `POST /api/ExecExchangeRoleRepair` — `CIPP.AppSettings.ReadWrite`
  query: tenantId body: tenantId
- `POST /api/ExecExcludeLicenses` — `CIPP.AppSettings.ReadWrite`
  body: Action, FullReset, GUID, ShowInDropdown, SKUName
- `POST /api/ExecExcludeTenant` — `CIPP.AppSettings.ReadWrite`
  query: AddExclusion, List, ListAll, RemoveExclusion, tenantFilter* body: value [string]
- `GET /api/ExecGDAPTrace` — `CIPP.AppSettings.Read`
  GDAP Access Path Testing: 1. Validates input parameters (TenantFilter and UPN) 2. Retrieves customer tenant information 3. Gets all active GDAP relationships for the customer tenant 4. Locates the UPN in the partner t... query: tenantFilter*, UPN*
- `POST /api/ExecJITAdminSettings` — `CIPP.AppSettings.ReadWrite`
  query: Action body: Action, MaxDuration {label, value}
- `POST /api/ExecLogRetentionConfig` — `CIPP.AppSettings.ReadWrite`
  query: List body: RetentionDays
- `GET /api/ExecMaintenanceScripts` — `CIPP.AppSettings.Read`
  Returns the maintenance scripts shipped with CIPP. Called without ScriptFile it lists the available scripts; with one it returns that script with the deployment's own tenant, subscription and resource details substitu... query: MakeLink, ScriptFile
- `POST /api/ExecNotificationConfig` — `CIPP.AppSettings.ReadWrite`
  body: email, logsToInclude, onePerTenant, sendtoIntegration, Severity, UseStandardizedSchema, webhook, webhookAuthHeaderName, webhookAuthHeaders, webhookAuthHeaderValue, webhookAuthPassword, webhookAuthToken, webhookAuthType {label, value}, webhookAuthUsername
- `POST /api/ExecOffloadFunctions` — `CIPP.SuperAdmin.ReadWrite` — FORBIDDEN for this client (super admin only); returns 503 on this container (function offloading is off)
  query: Action body: OffloadFunctions
- `POST /api/ExecPartnerMode` — `CIPP.SuperAdmin.ReadWrite` — FORBIDDEN for this client (super admin only)
  query: action body: TenantMode
- `POST /api/ExecPasswordConfig` — `CIPP.AppSettings.ReadWrite`
  query: List body: appendNumber, appendSpecialChar, capitalizeWords, charCount, includeDigits, includeLowercase, includeSpecialChars, includeUppercase, passwordType, separator, specialCharSet, wordCount
- `POST /api/ExecPermissionRepair` — `CIPP.AppSettings.ReadWrite`
  Merges new permissions from the SAM manifest into the AppPermissions entry for CIPP-SAM.
- `POST /api/ExecPreviewBrandingReportPdf` — `CIPP.AppSettings.Read`
  Renders a sample report against a branding configuration - normally the unsaved state of the branding editor - and returns it as application/pdf bytes, so a colour, logo, cover, footer or watermark can be judged on ev... body: branding, reportType, tenantFilter
- `POST /api/ExecPushSubscription` — `CIPP.Core.ReadWrite`
  Registers, removes or tests a Web Push subscription for the signed-in user's device. Subscriptions are per user: the row belongs to the principal that sent it and only that principal can remove it. Refused while imper... body: Action, DeviceName, RowKey, Subscription
- `GET /api/ExecRefreshMyAccess` — `Public`
  Clears the caller's cached role resolution and re-checks Entra group membership, so a just-activated PIM group grants its mapped CIPP role without waiting out the role cache. Only ever refreshes the calling user's own...
- `POST /api/ExecRemoveTenant` — `Tenant.Administration.ReadWrite`
  body: TenantID
- `POST /api/ExecReportAttachmentRetentionConfig` — `CIPP.AppSettings.ReadWrite`
  query: List body: RetentionDays
- `POST /api/ExecRestoreBackup` — `CIPP.AppSettings.ReadWrite`
- `POST /api/ExecRunBackup` — `CIPP.AppSettings.ReadWrite`
- `POST /api/ExecRunTenantGroupRule` — `Tenant.Groups.ReadWrite`
  This function executes dynamic tenant group rules for immediate membership updates query: groupId body: groupId
- `POST /api/ExecSAMAppPermissions` — `CIPP.SuperAdmin.ReadWrite` — FORBIDDEN for this client (super admin only)
  query: Action body: Permissions
- `POST /api/ExecSAMRoles` — `CIPP.SuperAdmin.ReadWrite` — FORBIDDEN for this client (super admin only)
  query: Action body: Roles, Tenants
- `POST /api/ExecTenantGroup` — `Tenant.Groups.ReadWrite`
  This function is used to manage tenant groups in CIPP body: Action, dynamicRules [object], groupDescription, groupId, groupName, groupType, members [{label, value}], ruleLogic
- `POST /api/ExecTimeSettings` — `CIPP.SuperAdmin.ReadWrite` — FORBIDDEN for this client (super admin only)
  body: Timezone {label, value}
- `POST /api/ExecUserBookmarks` — `CIPP.Core.ReadWrite`
  body: currentSettings, user
- `POST /api/ExecUserSettings` — `CIPP.Core.ReadWrite`
  body: currentSettings, user
- `POST /api/ExecWebhookSubscriptions` — `Tenant.Alert.ReadWrite`
  query: Action, WebhookID
- `GET /api/ListApiEgress` — `CIPP.SuperAdmin.Read` — FORBIDDEN for this client (super admin only)
  Per-API-client egress usage for this instance against the daily cap. Reads the CraftEgressAccounting table that the Craft runtime mirrors its egress accounting into (the same storage account, so this reads it directly... query: Hours
- `GET /api/ListBrandingSettings` — `Identity.User.Read`
  Returns the report branding: colours, logo and cover images, footer and watermark text.  Branding was previously returned by ListUserSettings, which put every uploaded cover inline on every page load and ran the legac... query: includeGallery
- `GET /api/ListCIPPUsers` — `CIPP.SuperAdmin.Read` — FORBIDDEN for this client (super admin only)
  Lists CIPP platform users and their role assignments from the allowedUsers table. Requires SuperAdmin access.
- `GET /api/ListContainerLogs` — `CIPP.SuperAdmin.Read` — FORBIDDEN for this client (super admin only)
  Retrieves container logs for the CIPP backend process. Requires SuperAdmin access. Supports ReadLog, ListFiles, and snapshot actions. query: Action, Exclude, File, From, Level, Query*, Regex, Search, SortDesc, Tail, To
- `GET /api/ListCustomRole` — `CIPP.Core.Read`
- `GET /api/ListCustomVariables` — `CIPP.Core.Read`
  Lists custom variables configured in CIPP for use in templates and automation. query: allTenants, excludeGlobalReserved, includeSystem, tenantFilter*
- `GET /api/ListExcludedLicenses` — `CIPP.AppSettings.Read`
- `GET /api/ListIPWhitelist` — `CIPP.IPDatabase.Read`
  Lists CIPP's IP allow/block list: every tenant or AllTenants entry with its address or CIDR range (Range) and state (Trusted, Blocked or NotTrusted).
- `GET /api/ListInstanceDiagnostics` — `CIPP.SuperAdmin.Read` — FORBIDDEN for this client (super admin only)
  Self diagnostics for this instance. Checks turns the recorded InstanceHealth samples into a pass/warn/fail list with a suggested fix per finding; Timeline returns the raw buckets plus the restart and out-of-memory eve... query: Action, Hours
- `GET /api/ListNotificationConfig` — `CIPP.AppSettings.Read`
  Retrieves the CIPP notification configuration, including alert channels, severity filters, and notification targets.
- `GET /api/ListPushSubscriptions` — `CIPP.Core.Read`
  Lists the signed-in user's registered push notification devices and the instance's VAPID public key.
- `GET /api/ListTenantGroups` — `CIPP.Core.Read`
  Lists tenant groups (logical groupings of managed tenants) and optionally includes usage data. query: groupId, includeUsage
- `GET /api/ListWorkerHealth` — `CIPP.SuperAdmin.Read` — FORBIDDEN for this client (super admin only)
  Retrieves health status and diagnostics for CIPP background worker processes. Requires SuperAdmin access. query: Action, JobId*, Limit, MaxPoints, Minutes, PoolType, Priority, RunName*, Status

### CIPP > Setup

- `POST /api/ExecAddTenant` — `CIPP.AppSettings.ReadWrite`
  body: accessToken, defaultDomainName, tenantId, username
- `POST /api/ExecCombinedSetup` — `CIPP.AppSettings.ReadWrite`
  body: applicationId, ApplicationSecret, baselineOption, certificateAuth, email, RefreshToken, selectedBaselines [{label, value}], selectedOption, tenantId, webhook
- `POST /api/ExecCreateSAMApp` — `CIPP.AppSettings.ReadWrite`
  body: access_token, certificateOnly
- `POST /api/ExecDeviceCodeLogon` — `CIPP.AppSettings.ReadWrite`
  query: clientId, deviceCode, operation, scope, tenantId
- `POST /api/ExecListAppId` — `CIPP.Core.ReadWrite`
- `POST /api/ExecSSOSetup` — `CIPP.AppSettings.ReadWrite`
  query: Action body: Action, appId, appSecret*, multiTenant, targetUrl
- `POST /api/ExecSamSecretStatus` — `CIPP.AppSettings.ReadWrite`
  The setup wizard creates a client secret on one step and uses it on the next, but Entra can take several minutes to replicate a newly created secret. Until it has, every token request fails with AADSTS7000215 even tho...
- `POST /api/ExecTokenExchange` — `CIPP.AppSettings.ReadWrite`
  body: tenantId, tokenRequest, tokenUrl
- `POST /api/ExecUpdateRefreshToken` — `CIPP.AppSettings.ReadWrite`
  body: refreshtoken, tenantId

### Dynamics

- `GET /api/ListDynamicsBusinessUnits` — `Dynamics.BusinessUnit.Read`
  query: DynamicsUrl*, tenantFilter*
- `GET /api/ListDynamicsEnvironments` — `Dynamics.Environment.Read`
  query: tenantFilter*
- `GET /api/ListDynamicsSecurityRoles` — `Dynamics.SecurityRole.Read`
  query: DynamicsUrl*, tenantFilter*
- `GET /api/ListDynamicsSolutions` — `Dynamics.Solution.Read`
  query: DynamicsUrl*, tenantFilter*
- `GET /api/ListDynamicsUsers` — `Dynamics.User.Read`
  query: DynamicsUrl*, tenantFilter*

### Email-Exchange > Administration

- `POST /api/AddSharedMailbox` — `Exchange.Mailbox.ReadWrite`
  body: addedAliases, displayName, domain, tenantID, username
- `POST /api/ExecConvertMailbox` — `Exchange.Mailbox.ReadWrite`
  body: ID, MailboxType, tenantFilter*
- `POST /api/ExecCopyForSent` — `Exchange.Mailbox.ReadWrite`
  query: ID, messageCopyState, tenantFilter* body: ID, messageCopyState, tenantFilter*
- `POST /api/ExecEditCalendarPermissions` — `Exchange.Mailbox.ReadWrite`
  query: CanViewPrivateItems, FolderName, Permissions, RemoveAccess, tenantFilter*, userid, UserToGetPermissions body: CanViewPrivateItems, FolderName, Permissions {label, value}, RemoveAccess {label, value}, tenantFilter*, userid, UserToGetPermissions {label, value}
- `POST /api/ExecEditMailboxPermissions` — `Exchange.Mailbox.ReadWrite`
  body: tenantfilter*, userID
- `POST /api/ExecEmailForward` — `Exchange.Mailbox.ReadWrite`
  body: ForwardExternal, ForwardInternal {label, value}, forwardOption, KeepCopy, tenantFilter*, userID
- `POST /api/ExecEnableArchive` — `Exchange.Mailbox.ReadWrite`
  query: id, tenantFilter*, username body: id, tenantFilter*, username
- `POST /api/ExecEnableAutoExpandingArchive` — `Exchange.Mailbox.ReadWrite`
  body: ID, tenantFilter*, username
- `POST /api/ExecGroupsDelete` — `Exchange.Mailbox.ReadWrite`
  query: displayName, GroupType, id, tenantFilter* body: displayName, GroupType, id, tenantFilter*
- `POST /api/ExecGroupsDeliveryManagement` — `Exchange.Group.ReadWrite`
  query: GroupType, ID, OnlyAllowInternal, tenantFilter* body: GroupType, ID, OnlyAllowInternal, tenantFilter*
- `POST /api/ExecGroupsHideFromGAL` — `Exchange.Group.ReadWrite`
  query: GroupType, HideFromGAL, ID, tenantFilter* body: GroupType, HideFromGAL, ID, tenantFilter*
- `POST /api/ExecHVEUser` — `Exchange.Mailbox.ReadWrite`
  body: Action, BillingPolicyId {label, value}, DisplayName, domain {label, value}, Identity*, password, PrimarySmtpAddress, ReplyTo, TenantFilter*, username
- `POST /api/ExecHideFromGAL` — `Exchange.Mailbox.ReadWrite`
  query: HideFromGAL, ID, tenantFilter* body: HideFromGAL, ID, tenantFilter*
- `POST /api/ExecMailboxMobileDevices` — `Exchange.Mailbox.ReadWrite`
  query: Delete, deviceid, guid, Quarantine, tenantFilter*, Userid body: Delete, deviceid, guid, Quarantine, tenantFilter*, Userid
- `POST /api/ExecModifyCalPerms` — `Exchange.Mailbox.ReadWrite`
  body: permissions [object], tenantFilter*, userID*
- `POST /api/ExecModifyContactPerms` — `Exchange.Mailbox.ReadWrite`
  body: permissions [object], tenantFilter*, userID*
- `POST /api/ExecModifyMBPerms` — `Exchange.Mailbox.ReadWrite`
- `POST /api/ExecRemoveMailboxRule` — `Exchange.Mailbox.ReadWrite`
  query: ruleId, ruleName, tenantFilter*, userPrincipalName body: ruleId, ruleName, TenantFilter*, userPrincipalName
- `POST /api/ExecRemoveRestrictedUser` — `Exchange.Mailbox.ReadWrite`
  Removes a user from the restricted senders list in Exchange Online. body: SenderAddress*, tenantFilter*
- `POST /api/ExecScheduleForwardingVacation` — `Exchange.Mailbox.ReadWrite`
  body: endDate, ForwardExternal*, ForwardInternal {label, value}, forwardOption, KeepCopy, postExecution, reference, startDate, tenantFilter*, Users
- `POST /api/ExecScheduleMailboxVacation` — `Exchange.Mailbox.ReadWrite`
  body: autoMap, calendarPermission {label, value}, canViewPrivateItems, delegates, endDate, includeCalendar, mailboxOwners, permissionTypes, postExecution, reference, startDate, tenantFilter*
- `POST /api/ExecScheduleOOOVacation` — `Exchange.Mailbox.ReadWrite`
  body: AutoDeclineFutureRequestsWhenOOF, CreateOOFEvent, DeclineEventsForScheduledOOF, DeclineMeetingMessage, endDate, externalMessage, internalMessage, OOFEventSubject, postExecution, reference, startDate, tenantFilter*, Users
- `POST /api/ExecSetCASMailbox` — `Exchange.Mailbox.ReadWrite`
  body: DisplayName, Identity, tenantFilter*
- `POST /api/ExecSetCalendarProcessing` — `Exchange.Mailbox.ReadWrite`
  body: additionalResponse, addOrganizerToSubject, allowConflicts, allowRecurringMeetings, automaticallyAccept, automaticallyProcess, bookingWindowInDays, deleteComments, deleteSubject, maxConflicts, maximumDurationInMinutes, minimumDurationInMinutes, processExternalMeetingMessages, removeCanceledMeetings, removeOldMeetingMessages, removePrivateProperty, scheduleOnlyDuringWorkHours, tenantFilter*, UPN
- `POST /api/ExecSetLitigationHold` — `Exchange.Mailbox.ReadWrite`
  body: days, disable, Identity, tenantFilter*, UPN
- `POST /api/ExecSetMailboxEmailSize` — `Exchange.Mailbox.ReadWrite`
  body: id, maxReceiveSize, maxSendSize, tenantFilter*, UPN
- `POST /api/ExecSetMailboxLocale` — `Exchange.Mailbox.ReadWrite`
  body: locale, tenantFilter*, user
- `POST /api/ExecSetMailboxQuota` — `Exchange.Mailbox.ReadWrite`
  body: IssueWarningQuota, ProhibitSendQuota, ProhibitSendReceiveQuota, quota, tenantfilter*, user
- `POST /api/ExecSetMailboxRestriction` — `Exchange.Mailbox.ReadWrite`
  body: Direction, Enable, tenantFilter*, UserId
- `POST /api/ExecSetMailboxRule` — `Exchange.Mailbox.ReadWrite`
  body: Disable, Enable, ruleId, ruleName, TenantFilter*, userPrincipalName
- `POST /api/ExecSetOoO` — `Exchange.Mailbox.ReadWrite`
  body: AutoDeclineFutureRequestsWhenOOF, AutoReplyState {label, value}, CreateOOFEvent, DeclineEventsForScheduledOOF, DeclineMeetingMessage, EndTime, ExternalMessage, input, InternalMessage, OOFEventSubject, StartTime, tenantFilter*, timezone, userId
- `POST /api/ExecSetRecipientLimits` — `Exchange.Mailbox.ReadWrite`
  body: Identity, recipientLimit, tenantFilter*, userid
- `POST /api/ExecSetRetentionHold` — `Exchange.Mailbox.ReadWrite`
  body: disable, Identity, tenantFilter*, UPN
- `POST /api/ExecStartManagedFolderAssistant` — `Exchange.Mailbox.ReadWrite`
  query: Id, tenantFilter* body: Id, tenantFilter*, UserPrincipalName
- `GET /api/ListCASMailboxes` — `Exchange.Mailbox.Read`
  query: tenantFilter*
- `GET /api/ListCalendarPermissions` — `Exchange.Mailbox.Read`
  query: ByUser, tenantFilter*, UseReportDB, UserID
- `GET /api/ListContactPermissions` — `Exchange.Mailbox.Read`
  query: tenantFilter*, UserID
- `GET /api/ListHVEAccounts` — `Exchange.Mailbox.Read`
  Lists High Volume Email (HVE) accounts and billing policies for a tenant. Supports UseReportDB=true query parameter to retrieve cached data from the reporting database for significantly better performance, especially... query: Identity, ListBillingPolicies, tenantFilter*, UseReportDB
- `GET /api/ListMailboxMobileDevices` — `Exchange.Mailbox.Read`
  Lists mobile devices associated with a specific Exchange Online mailbox. query: Mailbox, tenantFilter*
- `GET /api/ListMailboxRules` — `Exchange.Mailbox.Read`
  query: tenantFilter*, UseReportDB
- `GET /api/ListMailboxes` — `Exchange.Mailbox.Read`
  Lists Exchange Online mailboxes for a tenant. Supports UseReportDB=true query parameter to retrieve cached data from the reporting database for significantly better performance, especially when querying AllTenants. Wh... query: manualPagination, Minimal, nextLink, PageSize, tenantFilter*, UseReportDB
- `GET /api/ListOoO` — `Exchange.Mailbox.Read`
  Retrieves Out of Office (automatic reply) settings for a specific Exchange Online user. query: tenantFilter*, userid
- `GET /api/ListRestrictedUsers` — `Exchange.Mailbox.Read`
  Lists users from the restricted senders list in Exchange Online. query: tenantFilter*
- `GET /api/ListSharedMailboxStatistics` — `Exchange.Mailbox.Read`
  Lists shared mailboxes and their usage statistics for a tenant. query: tenantFilter*
- `GET /api/ListmailboxPermissions` — `Exchange.Mailbox.Read`
  query: ByUser, tenantFilter*, User, UseReportDB, userId

### Email-Exchange > Administration > Contacts

- `POST /api/AddContact` — `Exchange.Contact.ReadWrite`
  body: City, Company, CountryOrRegion, displayName, email, firstName, hidefromGAL, lastName, mailTip, mobilePhone, phone, PostalCode, State, StreetAddress, tenantid, Title, website
- `POST /api/AddContactTemplates` — `Exchange.Contact.ReadWrite`
  body: displayName
- `POST /api/DeployContactTemplates` — `Exchange.Contact.ReadWrite`
  This function deploys contact(s) from template(s) to selected tenants. body: selectedTenants [{label, value}], TemplateList [{label, value}]
- `POST /api/EditContact` — `Exchange.Contact.ReadWrite`
  body: City, Company, ContactID, CountryOrRegion, displayName, email, firstName, hidefromGAL, LastName, mailTip, mobilePhone, phone, PostalCode, State, StreetAddress, tenantID, Title, website
- `POST /api/EditContactTemplates` — `Exchange.Contact.ReadWrite`
  body: ContactTemplateID*, displayName
- `GET /api/ListContactTemplates` — `Exchange.Contact.Read`
  Lists saved mail contact templates used for creating new Exchange contacts. query: ID
- `GET /api/ListContacts` — `Exchange.Contact.Read`
  Lists Exchange Online mail contacts for a tenant, with optional filtering by contact ID for detailed view. query: id, tenantFilter*
- `POST /api/RemoveContact` — `Exchange.Contact.ReadWrite`
  query: GUID, Mail, tenantFilter* body: GUID, Mail, tenantFilter*
- `POST /api/RemoveContactTemplates` — `Exchange.Contact.ReadWrite`
  query: ID body: ID

### Email-Exchange > Administration > Mailbox Retention

- `POST /api/ExecManageRetentionPolicies` — `Exchange.RetentionPolicies.ReadWrite`
  query: name, tenantFilter* body: CreatePolicies [object], DeletePolicies, ModifyPolicies, tenantFilter*
- `POST /api/ExecManageRetentionTags` — `Exchange.RetentionPolicies.ReadWrite`
  query: name, tenantFilter* body: CreateTags [object], DeleteTags, ModifyTags, tenantFilter*
- `POST /api/ExecSetMailboxRetentionPolicies` — `Exchange.Mailbox.ReadWrite`
  query: tenantFilter* body: Mailboxes [string], PolicyName*, tenantFilter*

### Email-Exchange > Reports

- `POST /api/ExecGetMailFlowReportPdf` — `Exchange.Mailbox.Read`
  Server-renders the Exchange mail flow report as application/pdf bytes. Reads the same three Exchange reports the Mail Flow page uses (Get-MailFlowStatusReport plus the TopMailSender and TopSpamRecipient traffic summar... query: days, tenantFilter* body: tenantFilter*
- `GET /api/ListActiveSyncDevices` — `Exchange.Mailbox.Read`
  Lists all ActiveSync mobile devices registered across Exchange Online mailboxes in a tenant. query: tenantFilter*
- `GET /api/ListAntiPhishingFilters` — `Exchange.SpamFilter.Read`
  Lists anti-phishing policies and their associated rules configured in Exchange Online Protection. query: tenantFilter*
- `GET /api/ListGlobalAddressList` — `Exchange.Mailbox.Read`
  Lists all recipients in the Exchange Online Global Address List, including display names, email addresses, and recipient types. query: tenantFilter*
- `GET /api/ListMailFlowReports` — `Exchange.Mailbox.Read`
  Returns Exchange Online mail flow reports: disposition counts by day (Get-MailFlowStatusReport) and top sender/recipient summaries (Get-MailTrafficSummaryReport). Both support up to 90 days. query: category, days, reportType, tenantFilter*
- `GET /api/ListMailboxCAS` — `Exchange.Mailbox.Read`
  query: tenantFilter*
- `GET /api/ListMailboxForwarding` — `Exchange.Mailbox.Read`
  Lists mailbox forwarding rules and configurations for a tenant. Supports UseReportDB=true query parameter to retrieve cached data from the reporting database for significantly better performance, especially when query... query: tenantFilter*, UseReportDB
- `GET /api/ListMalwareFilters` — `Exchange.SpamFilter.Read`
  Lists malware filter policies and their associated rules configured in Exchange Online Protection. query: tenantFilter*
- `GET /api/ListSafeAttachmentsFilters` — `Exchange.SpamFilter.Read`
  Lists Safe Attachments policies and their associated rules configured in Microsoft Defender for Office 365. query: tenantFilter*
- `GET /api/ListSharedMailboxAccountEnabled` — `Exchange.Mailbox.Read`
  Lists shared mailboxes that have direct sign-in enabled (account not disabled), which is a security concern. Supports UseReportDB=true to read cached data from the reporting database (required for AllTenants). query: tenantFilter*, UseReportDB

### Email-Exchange > Resources

- `POST /api/AddEquipmentMailbox` — `Exchange.Equipment.ReadWrite`
  body: displayName, tenantID, username, userPrincipalName
- `POST /api/AddRoomList` — `Exchange.Room.ReadWrite`
  body: displayName, primDomain {label, value}, tenantFilter*, tenantid, username
- `POST /api/AddRoomMailbox` — `Exchange.Room.ReadWrite`
  body: displayName, ResourceCapacity, tenantid, username, userPrincipalName
- `POST /api/EditEquipmentMailbox` — `Exchange.Equipment.ReadWrite`
  body: displayName, equipmentId, hiddenFromAddressListsEnabled, tenantID, userPrincipalName
- `POST /api/EditRoomList` — `Exchange.Room.ReadWrite`
  body: AddMember [{label, value}], AddOwner [string], allowExternal, description, displayName, groupId, mailNickname, RemoveMember [string], RemoveOwner [object], tenantFilter*
- `POST /api/EditRoomMailbox` — `Exchange.Room.ReadWrite`
  body: capacity, DefaultCalendarPermission {label, value}, displayName, hiddenFromAddressListsEnabled, roomId, tenantID, userPrincipalName
- `GET /api/ListEquipment` — `Exchange.Equipment.Read`
  Lists equipment mailboxes (projectors, vehicles, etc.) in Exchange Online for a tenant. query: EquipmentId, tenantFilter*
- `GET /api/ListRoomLists` — `Exchange.Room.Read`
  Lists room list distribution groups and their members in Exchange Online. query: groupID, members, owners, tenantFilter*
- `GET /api/ListRooms` — `Exchange.Room.Read`
  query: roomId, tenantFilter*

### Email-Exchange > Spamfilter

- `POST /api/AddQuarantinePolicy` — `Exchange.Spamfilter.ReadWrite`
  body: AllowSender, BlockSender, Delete, IncludeMessagesFromBlockedSenderAddress, Name, Preview, QuarantineNotification, ReleaseActionPreference {label, value}, selectedTenants
- `POST /api/AddSpamFilter` — `Exchange.SpamFilter.ReadWrite`
  body: PowerShellCommand, Priority, selectedTenants
- `POST /api/AddSpamFilterTemplate` — `Exchange.Spamfilter.ReadWrite`
  body: name, PowerShellCommand
- `POST /api/AddTenantAllowBlockList` — `Exchange.SpamFilter.ReadWrite`
  body: entries, listMethod, listType, NoExpiration, notes, RemoveAfter, tenantID {label, value}
- `POST /api/AddTenantAllowBlockListTemplate` — `Exchange.SpamFilter.ReadWrite`
  body: entries, listMethod, listType, NoExpiration, notes, RemoveAfter, templateName
- `POST /api/EditAntiPhishingFilter` — `Exchange.SpamFilter.ReadWrite`
  query: RuleName, State, tenantFilter* body: RuleName, State, tenantFilter*
- `POST /api/EditMalwareFilter` — `Exchange.SpamFilter.ReadWrite`
  query: RuleName, State, tenantFilter* body: RuleName, State, tenantFilter*
- `POST /api/EditQuarantinePolicy` — `Exchange.Spamfilter.ReadWrite`
  query: tenantFilter*, Type body: Action, AllowSender, BlockSender, Delete, EndUserSpamNotificationCustomFromAddress, EndUserSpamNotificationFrequency {label, value}, Identity, IncludeMessagesFromBlockedSenderAddress, Name, OrganizationBrandingEnabled, Preview, QuarantineNotification, ReleaseActionPreference {label, value}, TenantFilter*
- `POST /api/EditSafeAttachmentsFilter` — `Exchange.SpamFilter.ReadWrite`
  query: RuleName, State, tenantFilter* body: RuleName, State, tenantFilter*
- `POST /api/EditSpamFilter` — `Exchange.SpamFilter.ReadWrite`
  query: name, tenantFilter* body: name, state
- `POST /api/EditTenantAllowBlockListTemplate` — `Exchange.SpamFilter.ReadWrite`
  body: entries, GUID*, listMethod, listType, NoExpiration, notes, RemoveAfter, templateName
- `POST /api/ExecMailQuarantineSubmit` — `Exchange.SpamFilter.ReadWrite`
  Submits a quarantined email message to Microsoft for review (threat submission) via the Graph API. body: category {label, value}, Identity*, RecipientAddress, tenantFilter*
- `POST /api/ExecMailboxSafeSender` — `Exchange.SpamFilter.ReadWrite`
  Adds a sender to a mailbox trusted/safe senders list via Set-MailboxJunkEmailConfiguration. body: mailbox, sender, tenantFilter*
- `POST /api/ExecQuarantineManagement` — `Exchange.SpamFilter.ReadWrite`
- `POST /api/ExportMailQuarantine` — `Exchange.SpamFilter.Read`
  Exports filtered quarantine results as CSV or JSON for admin download. body: format, tenantFilter*
- `GET /api/GetMailQuarantineMessage` — `Exchange.SpamFilter.Read`
  Returns detailed metadata for a single quarantined message (without exporting EML). query: Identity*, tenantFilter*
- `GET /api/ListConnectionFilter` — `Exchange.ConnectionFilter.Read`
  Lists hosted connection filter policies (IP allow/block lists) in Exchange Online Protection. query: tenantFilter*
- `GET /api/ListConnectionFilterTemplates` — `Exchange.ConnectionFilter.Read`
  Lists saved connection filter policy templates for Exchange Online Protection. query: ID
- `GET /api/ListMailQuarantine` — `Exchange.SpamFilter.Read`
  Lists quarantined email messages in Exchange Online Protection for a tenant. Supports server-side filtering via Get-QuarantineMessage parameters. Default behavior returns one page (100 rows, last 7 days) unless fetchA... query: fetchAll, manualPagination, nextLink, page, pageSize, tenantFilter*
- `GET /api/ListMailQuarantineMessage` — `Exchange.SpamFilter.Read`
  Exports and retrieves the raw EML content of a specific quarantined email message by its Identity. query: Identity, tenantFilter*
- `GET /api/ListMailQuarantineMessageDetails` — `Exchange.SpamFilter.Read`
  Retrieves Defender analyzed email details (threats, delivery, authentication, URLs, attachments) for a quarantined message via the Graph beta security/collaboration/analyzedEmails API. Falls back to parsing the messag... query: Identity*, tenantFilter*
- `GET /api/ListMailQuarantineMessageHeader` — `Exchange.SpamFilter.Read`
  Retrieves the message headers of a specific quarantined email message by its Identity. query: Identity, tenantFilter*
- `GET /api/ListQuarantinePolicy` — `Exchange.SpamFilter.Read`
  Lists quarantine policies configured in Exchange Online Protection, controlling end-user access to quarantined messages. query: tenantFilter*, Type
- `GET /api/ListSpamFilterTemplates` — `Exchange.SpamFilter.Read`
  Lists saved spam filter policy templates for Exchange Online Protection. query: ID
- `GET /api/ListSpamfilter` — `Exchange.SpamFilter.Read`
  Lists hosted content filter (anti-spam) policies and their rule states in Exchange Online Protection. query: tenantFilter*
- `GET /api/ListTenantAllowBlockList` — `Exchange.SpamFilter.Read`
  Lists Tenant Allow/Block List entries (senders, URLs, file hashes, IPs) from Exchange Online Protection. Supports UseReportDB=true query parameter to retrieve cached data from the reporting database for significantly... query: tenantFilter*, UseReportDB
- `GET /api/ListTenantAllowBlockListTemplates` — `Exchange.SpamFilter.Read`
  Lists saved Tenant Allow/Block List templates for Exchange Online Protection. query: ID
- `GET /api/ListUserReportedMessage` — `Exchange.SpamFilter.Read`
  Retrieves the raw EML content of a user reported message by its Internet Message ID. Tries the quarantine store first (Export-QuarantineMessage), then falls back to reading the message from the recipient's or reporter... query: InternetMessageId*, RecipientEmail, ReporterEmail, tenantFilter*
- `GET /api/ListUserReportedMessages` — `Exchange.SpamFilter.Read`
  Lists user reported email threat submissions (Defender Submissions with source 'user') for a tenant. query: tenantFilter*
- `POST /api/RemoveConnectionfilterTemplate` — `Exchange.ConnectionFilter.ReadWrite`
  body: ID
- `POST /api/RemoveQuarantinePolicy` — `Exchange.Spamfilter.ReadWrite`
  query: Identity, Name, tenantFilter* body: Identity, Name, TenantFilter*
- `POST /api/RemoveSpamfilter` — `Exchange.Spamfilter.ReadWrite`
  query: name, tenantFilter* body: name
- `POST /api/RemoveSpamfilterTemplate` — `Exchange.Spamfilter.ReadWrite`
  body: ID
- `POST /api/RemoveTenantAllowBlockList` — `Exchange.SpamFilter.ReadWrite`
  body: Entries, ListType, tenantFilter*
- `POST /api/RemoveTenantAllowBlockListTemplate` — `Exchange.SpamFilter.ReadWrite`
  query: ID body: ID

### Email-Exchange > Tools

- `POST /api/ExecEmailTroubleshoot` — `Exchange.TransportRule.Read`
  body: days, endDate, fromIP, messageId, policyName, policyTypes, quarantineType, recipient {label, value}, recipientDomain, releaseStatus, sender {label, value}, senderDomain, startDate, status {label, value}, subject, subjectExact, tenantFilter*, toIP
- `POST /api/ExecHistoricalSearch` — `Exchange.Mailbox.ReadWrite`
  Starts or cancels an Exchange Online historical search. Historical searches cover up to 90 days, deliver results as CSV (max 100,000 rows) and are limited to 250 submissions per day per tenant. body: Action, deliveryStatus {label, value}, direction {label, value}, jobId*, messageId, notifyAddress, originalClientIP, recipientAddress, reportTitle, reportType {label, value}, senderAddress, tenantFilter*
- `POST /api/ExecIRMConfiguration` — `Exchange.Mailbox.ReadWrite`
  Updates the Microsoft Purview Message Encryption configuration for a tenant (AzureRMSLicensingEnabled, SimplifiedClientAccessEnabled, EnablePdfEncryption, DecryptAttachmentForEncryptOnly, SimplifiedClientAccessDoNotFo... body: Action, Recipient, Sender, tenantFilter*, TransportDecryptionSetting
- `GET /api/ExecMailTest` — `CIPP.Core.Read`
  Checks the mailbox configuration behind CIPP's message trace tooling. Action=CheckConfig reports whether the CIPP-SAM app holds the delegated Mail.Read permission and which mailbox the current token resolves to. query: Action
- `POST /api/ExecMailboxRestore` — `Exchange.Mailbox.ReadWrite`
  query: Action, Identity, tenantFilter* body: Action, AssociatedMessagesCopyOption {label, value}, BadItemLimit, BatchName, CompletedRequestAgeLimit, ConflictResolutionOption {label, value}, ExcludeDumpster, ExcludeFolders {label, value}, Identity, IncludeFolders {label, value}, LargeItemLimit, RequestName, SourceIsArchive, SourceMailbox {label, value}, SourceRootFolder, TargetIsArchive, TargetMailbox {label, value}, TargetRootFolder, TargetType {label, value}, TenantFilter*
- `POST /api/ListExoRequest` — `CIPP.Core.Read`
  Executes an arbitrary read-only Exchange Online cmdlet (Get-* or Search-*) for a tenant. Accepts cmdlet name and parameters in the request body. body: Anchor, AsApp, AvailableCmdlets, Cmdlet, cmdParams, Compliance, Select, TenantFilter*, UseSystemMailbox
- `GET /api/ListHistoricalSearches` — `Exchange.Mailbox.Read`
  Lists Exchange Online historical searches (async message trace/report jobs) submitted in the last 10 days. query: jobId, tenantFilter*
- `GET /api/ListIRMConfiguration` — `Exchange.Mailbox.Read`
  Lists the Information Rights Management (IRM) configuration for a tenant. Used to check whether Microsoft Purview Message Encryption is active and whether an on-premises AD RMS deployment still has to be migrated to A... query: tenantFilter*
- `GET /api/ListMailboxRestores` — `Exchange.Mailbox.Read`
  Lists mailbox restore requests and their status for Exchange Online, with optional statistics for a specific restore operation. query: Identity, IncludeReport, Statistics, tenantFilter*
- `POST /api/ListMessageTrace` — `Exchange.Mailbox.Read`
  Traces email delivery in Exchange Online via the Graph message trace API (/beta/admin/exchange/tracing/messageTraces), searchable by sender, recipient, subject, status, IP, message ID and date range. Graph works over... body: days, endDate, fromIP, ID, messageId, messageTraceId, recipient {label, value}, sender, startDate, status, subject, subjectFilterType {label, value}, tenantFilter*, toIP, traceDetail

### Email-Exchange > Transport

- `POST /api/AddConnectionFilter` — `Exchange.ConnectionFilter.ReadWrite`
  body: PowerShellCommand, selectedTenants
- `POST /api/AddConnectionFilterTemplate` — `Exchange.ConnectionFilter.ReadWrite`
  body: name, PowerShellCommand
- `POST /api/AddEditTransportRule` — `Exchange.TransportRule.ReadWrite`
  This function creates a new transport rule or edits an existing one (mail flow rule). body: ActivationDate, AnyOfCcHeader [object], AnyOfCcHeaderMemberOf [object], AnyOfRecipientAddressContainsWords [string], AnyOfRecipientAddressMatchesPatterns [string], AnyOfToCcHeader [object], AnyOfToCcHeaderMemberOf [object], AnyOfToHeader [object], AnyOfToHeaderMemberOf [object], ApplyClassification, ApplyHtmlDisclaimerFallbackAction {label, value}, ApplyHtmlDisclaimerLocation {label, value}, ApplyHtmlDisclaimerText, ApplyOME, AttachmentContainsWords [string], AttachmentExtensionMatchesWords [string], AttachmentHasExecutableContent, AttachmentIsPasswordProtected, AttachmentIsUnsupported, AttachmentMatchesPatterns [string], AttachmentNameMatchesPatterns [string], AttachmentProcessingLimitExceeded, AttachmentPropertyContainsWords [string], AttachmentSizeOver, BlindCopyTo [object], Comments, CopyTo [object], DeleteMessage, Enabled, ExceptIfAnyOfCcHeader [object], ExceptIfAnyOfCcHeaderMemberOf [object], ExceptIfAnyOfRecipientAddressContainsWords [string], ExceptIfAnyOfRecipientAddressMatchesPatterns [string], ExceptIfAnyOfToCcHeader [object], ExceptIfAnyOfToCcHeaderMemberOf [object], ExceptIfAnyOfToHeader [object], ExceptIfAnyOfToHeaderMemberOf [object], ExceptIfAttachmentContainsWords [string], ExceptIfAttachmentExtensionMatchesWords [string], ExceptIfAttachmentHasExecutableContent, ExceptIfAttachmentIsPasswordProtected, ExceptIfAttachmentIsUnsupported, ExceptIfAttachmentMatchesPatterns [string], ExceptIfAttachmentNameMatchesPatterns [string], ExceptIfAttachmentProcessingLimitExceeded, ExceptIfAttachmentPropertyContainsWords [string], ExceptIfAttachmentSizeOver, ExceptIfFrom [object], ExceptIfFromAddressContainsWords [string], ExceptIfFromAddressMatchesPatterns [string], ExceptIfFromMemberOf [object], ExceptIfFromScope {label, value}, ExceptIfHeaderContainsWords [string], ExceptIfHeaderContainsWordsMessageHeader, ExceptIfHeaderMatchesPatterns [string], ExceptIfHeaderMatchesPatternsMessageHeader, ExceptIfMessageSizeOver, ExceptIfMessageTypeMatches {label, value}, ExceptIfRecipientAddressContainsWords [string], ExceptIfRecipientAddressMatchesPatterns [string], ExceptIfRecipientDomainIs [object], ExceptIfSCLOver {label, value}, ExceptIfSenderDomainIs [object], ExceptIfSenderIpRanges [string], ExceptIfSentTo [object], ExceptIfSentToMemberOf [object], ExceptIfSentToScope {label, value}, ExceptIfSubjectContainsWords [string], ExceptIfSubjectMatchesPatterns [string], ExceptIfSubjectOrBodyContainsWords [string], ExceptIfSubjectOrBodyMatchesPatterns [string], ExceptIfWithImportance {label, value}, ExpiryDate, From [object], FromAddressContainsWords [string], FromAddressMatchesPatterns [string], FromMemberOf [object], FromScope {label, value}, GenerateIncidentReport [string], GenerateNotification, HeaderContainsWords [string], HeaderContainsWordsMessageHeader, HeaderMatchesPatterns [string], HeaderMatchesPatternsMessageHeader, IncidentReportContent [string], MessageSizeOver, MessageTypeMatches {label, value}, Mode {label, value}, ModerateMessageByManager, ModerateMessageByUser [object], Name, PrependSubject, Priority, Quarantine, RecipientAddressContainsWords [string], RecipientAddressMatchesPatterns [string], RecipientDomainIs [object], RedirectMessageTo [object], RejectMessageEnhancedStatusCode, RejectMessageReasonText, RemoveHeader, RouteMessageOutboundConnector, ruleId, SCLOver {label, value}, SenderAddressLocation {label, value}, SenderDomainIs [object], SenderIpRanges [string], SentTo [object], SentToMemberOf [object], SentToScope {label, value}, SetAuditSeverity {label, value}, SetHeaderName, SetHeaderValue, SetSCL {label, value}, State, StopRuleProcessing, SubjectContainsWords [string], SubjectMatchesPatterns [string], SubjectOrBodyContainsWords [string], SubjectOrBodyMatchesPatterns [string], tenantFilter*, WithImportance {label, value}
- `POST /api/AddExConnector` — `Exchange.Connector.ReadWrite`
  body: PowerShellCommand, selectedTenants
- `POST /api/AddExConnectorTemplate` — `Exchange.Connector.ReadWrite`
  body: cippconnectortype, name*
- `POST /api/AddTransportRule` — `Exchange.TransportRule.ReadWrite`
  body: PowerShellCommand, selectedTenants
- `POST /api/AddTransportTemplate` — `Exchange.TransportRule.ReadWrite`
  body: Name, PowerShellCommand
- `POST /api/EditExConnector` — `Exchange.Connector.ReadWrite`
  query: GUID, State, tenantFilter*, Type body: GUID, State, tenantFilter*, Type
- `POST /api/EditTransportRule` — `Exchange.TransportRule.ReadWrite`
  query: guid, state, tenantFilter* body: guid, state, tenantFilter*
- `GET /api/ListExConnectorTemplates` — `Exchange.Connector.Read`
  Lists saved Exchange connector templates for creating inbound/outbound connectors. query: ID
- `GET /api/ListExchangeConnectors` — `Exchange.Connector.Read`
  Lists inbound and outbound mail flow connectors configured in Exchange Online. query: tenantFilter*
- `GET /api/ListTransportRules` — `Exchange.TransportRule.Read`
  query: id, tenantFilter*
- `GET /api/ListTransportRulesTemplates` — `Exchange.TransportRule.Read`
  Lists saved transport rule templates for Exchange Online mail flow rules. query: ID, noJson
- `POST /api/RemoveExConnector` — `Exchange.Connector.ReadWrite`
  query: GUID, tenantFilter*, Type body: GUID, tenantFilter*, Type
- `POST /api/RemoveExConnectorTemplate` — `Exchange.Connector.ReadWrite`
  query: ID body: ID
- `POST /api/RemoveTransportRule` — `Exchange.TransportRule.ReadWrite`
  query: guid, tenantFilter* body: guid, tenantFilter*
- `POST /api/RemoveTransportRuleTemplate` — `Exchange.TransportRule.ReadWrite`
  query: ID body: ID

### Endpoint > Applications

- `POST /api/AddAppTemplate` — `Endpoint.Application.ReadWrite`
  body: apps, description, displayName, GUID
- `POST /api/AddChocoApp` — `Endpoint.Application.ReadWrite`
  body: ApplicationName, AssignTo, customArguments, CustomGroup, customrepo, description, DisableRestart, excludeGroup, ExcludeGroupIds, GroupIds, InstallAsSystem, InstallationIntent, PackageName, selectedTenants [object]
- `POST /api/AddEdgeApp` — `Endpoint.Application.ReadWrite`
  body: AssignTo, CustomGroup, displayLanguageLocale {label, value}, edgeChannel {label, value}, excludeGroup, ExcludeGroupIds, GroupIds, IntuneBody, selectedTenants [object]
- `POST /api/AddMSPApp` — `Endpoint.Application.ReadWrite`
  body: AssignTo, CustomGroup, DisplayName, excludeGroup, ExcludeGroupIds, GroupIds, PackageName, params, RMMName {label, value}, selectedTenants [object]
- `POST /api/AddOfficeApp` — `Endpoint.Application.ReadWrite`
  body: AcceptLicense, arch, AssignTo, CustomGroup, customXml, excludedApps [{label, value}], excludeGroup, ExcludeGroupIds, GroupIds, IntuneBody, languages [{label, value}], RemoveVersions, selectedTenants [object], SharedComputerActivation, updateChannel {label, value}, useCustomXml
- `POST /api/AddStoreApp` — `Endpoint.Application.ReadWrite`
  body: ApplicationName, AssignTo, CustomGroup, description, excludeGroup, ExcludeGroupIds, GroupIds, InstallAsSystem, InstallationIntent, PackageName, selectedTenants [object]
- `POST /api/AddWin32ScriptApp` — `Endpoint.Application.ReadWrite`
  body: ApplicationName, AssignTo, CustomGroup, description, detectionFile, detectionPath, detectionScript, DisableRestart, enforceSignatureCheck, excludeGroup, ExcludeGroupIds, GroupIds, InstallAsSystem, InstallationIntent, installScript*, publisher, runAs32Bit, selectedTenants [object], uninstallScript
- `POST /api/ExecAppUpload` — `Endpoint.Application.ReadWrite`
- `POST /api/ExecAssignApp` — `Endpoint.Application.ReadWrite`
  query: AppType, AssignTo, GroupIds, GroupNames, ID, Intent, tenantFilter* body: AppType, assignmentDirection, AssignmentFilterName, AssignmentFilterType, assignmentMode, AssignTo, excludeGroup, ExcludeGroupIds, ExcludeGroupNames, GroupIds, GroupNames, ID, Intent, tenantFilter*
- `POST /api/ExecDeployAppTemplate` — `Endpoint.Application.ReadWrite`
  body: AssignTo, customGroup, selectedTenants [object], templateId
- `POST /api/ExecSyncVPP` — `Endpoint.Application.ReadWrite`
  body: tenantFilter*
- `GET /api/ListAppStatus` — `Endpoint.Device.Read`
  Lists Intune application installation status across devices for a specific application, including install state and error codes. query: AppFilter, tenantFilter*
- `GET /api/ListAppTemplates` — `Endpoint.Application.Read`
  Lists the saved application deployment templates, each with its display name, description and the applications it bundles. These are CIPP templates, not a tenant's deployed apps. query: ID
- `GET /api/ListApplicationQueue` — `Endpoint.Application.Read`
- `GET /api/ListApps` — `Endpoint.Application.Read`
  query: tenantFilter*
- `POST /api/ListAppsRepository` — `Endpoint.Application.Read`
  Searches external application repositories (WinGet, Chocolatey, etc.) for available application packages. body: Repository, Search
- `GET /api/ListDetectedAppDevices` — `Identity.Device.Read`
  Lists Intune-managed devices that have a specific detected application installed, identified by App ID. query: AppID*, tenantFilter*
- `GET /api/ListDetectedApps` — `Identity.Device.Read`
  Lists applications detected on Intune-managed devices in a tenant, optionally including device associations. query: DeviceID, includeDevices, tenantFilter*
- `POST /api/ListPotentialApps` — `Endpoint.Application.Read`
  Searches application repositories (WinGet, Chocolatey) for available applications matching a search string. body: SearchString, type
- `POST /api/RemoveApp` — `Endpoint.Application.ReadWrite`
  query: ID, tenantFilter* body: ID, tenantFilter*
- `POST /api/RemoveAppTemplate` — `Endpoint.Application.ReadWrite`
  query: ID body: ID
- `POST /api/RemoveQueuedApp` — `Endpoint.Application.ReadWrite`
  body: ID

### Endpoint > Autopilot

- `POST /api/AddAPDevice` — `Endpoint.Autopilot.ReadWrite`
  Adds Autopilot devices to a tenant via Partner Center API body: autopilotData, Groupname, TenantFilter* {label, value}
- `POST /api/AddAutopilotConfig` — `Endpoint.Autopilot.ReadWrite`
  body: Assignto, Description, DisplayName, GroupIds [{label, value}], selectedTenants {label, value}
- `POST /api/AddCorporateDeviceIdentifier` — `Endpoint.Autopilot.ReadWrite`
  Uploads corporate device identifiers (manufacturer, model and serial number) for Windows Autopilot device preparation via the Graph importedDeviceIdentities API body: devicePrepData, overwriteExisting, tenantFilter* {label, value}
- `POST /api/AddEnrollment` — `Endpoint.Autopilot.ReadWrite`
  body: AllowFail, AllowReset, blockDevice, EnableLog, ErrorMessage, InstallWindowsUpdates, OBEEOnly, selectedTenants {label, value}, ShowProgress, TimeOutInMinutes
- `POST /api/ExecAssignAPDevice` — `Endpoint.Autopilot.ReadWrite`
  body: device, serialNumber, tenantFilter*, user
- `POST /api/ExecAssignAutopilotProfile` — `Endpoint.Autopilot.ReadWrite`
  body: AssignTo*, GroupIds [{label, value}], ProfileId*, ProfileName, tenantFilter*
- `POST /api/ExecRenameAPDevice` — `Endpoint.Autopilot.ReadWrite`
  body: deviceId, displayName [string], serialNumber, tenantFilter*
- `POST /api/ExecSetAPDeviceGroupTag` — `Endpoint.Autopilot.ReadWrite`
  body: deviceId, groupTag [string], serialNumber, tenantFilter*
- `POST /api/ExecSyncAPDevices` — `Endpoint.Autopilot.ReadWrite`
  query: tenantFilter* body: tenantFilter*
- `GET /api/ListAPDevices` — `Endpoint.Autopilot.Read`
  Lists Windows Autopilot device identities registered in a tenant. query: tenantFilter*
- `GET /api/ListAutopilotconfig` — `Endpoint.Autopilot.Read`
  Lists Windows Autopilot deployment profiles, Enrollment Status Page configurations, or Windows Hello for Business policies for a tenant. query: tenantFilter*, type
- `POST /api/RemoveAPDevice` — `Endpoint.Autopilot.ReadWrite`
  query: ID, tenantFilter* body: ID, tenantFilter*
- `POST /api/RemoveAutopilotConfig` — `Endpoint.Autopilot.ReadWrite`
  body: assignments, displayName, ID*, tenantFilter*

### Endpoint > MEM

- `POST /api/AddAssignmentFilter` — `Endpoint.MEM.ReadWrite`
  body: assignmentFilterManagementType, description, displayName, platform, rule, tenantFilter* [{label, value}]
- `POST /api/AddAssignmentFilterTemplate` — `Endpoint.MEM.ReadWrite`
  body: assignmentFilterManagementType, description, displayName, GUID, platform, rule
- `POST /api/AddDefenderDeployment` — `Endpoint.MEM.ReadWrite`
  body: ASR, Compliance, EDR, Exclusion, Policy, selectedTenants
- `POST /api/AddDefenderTemplate` — `Endpoint.MEM.ReadWrite`
  body: ASR, EDR, Exclusion, package, Policy, templateName*
- `POST /api/AddIntunePolicyClone` — `Endpoint.MEM.ReadWrite`
  body: ID, newDescription, newDisplayName*, ODataType, tenantFilter*, URLName
- `POST /api/AddIntuneReusableSetting` — `Endpoint.MEM.ReadWrite`
  query: TemplateId, tenantFilter* body: TemplateId, TemplateList {label, value}, tenantFilter*
- `POST /api/AddIntuneReusableSettingTemplate` — `Endpoint.MEM.ReadWrite`
  body: description, displayName, GUID, json, rawJSON
- `POST /api/AddIntuneTemplate` — `Endpoint.MEM.ReadWrite`
  query: ID, ODataType, tenantFilter, URLName body: description, displayName, ID, ODataType, RawJSON, TemplateType, tenantFilter, URLName
- `POST /api/AddPolicy` — `Endpoint.MEM.ReadWrite`
  body: assignmentFilter, AssignmentFilterName, AssignmentFilterType, AssignTo, customGroup, Description, displayName, excludeGroup, ExcludeGroupIds, GroupIds, RAWJson, replacemap, ReusableSettings [string], TemplateGuid, TemplateID, TemplateList {label, value}, TemplateType, tenantFilter* {label, value}
- `POST /api/EditAssignmentFilter` — `Endpoint.MEM.ReadWrite`
  body: description, displayName, filterId, rule, tenantFilter*
- `POST /api/EditIntunePolicy` — `Endpoint.MEM.Read`
  body: description, ID, newDisplayName, platformType, policyType, tenantFilter*
- `POST /api/EditIntuneScript` — `Endpoint.MEM.ReadWrite`
  query: ScriptId, tenantFilter* body: IntuneScript, ScriptId, ScriptType, TenantFilter*
- `POST /api/EditPolicy` — `Endpoint.MEM.ReadWrite`
  body: Assignto, Description, Displayname, groupid, tenantid
- `POST /api/ExecAddCippCveException` — `Security.Alert.ReadWrite`
  query: tenantFilter* body: applyTo, cveId, exceptionType, expiryDate, justification, tenantFilter*
- `POST /api/ExecAssignPolicy` — `Endpoint.MEM.ReadWrite`
  body: assignmentDirection, AssignmentFilterName, AssignmentFilterType, assignmentMode, AssignTo, excludeGroup, ExcludeGroupIds, ExcludeGroupNames, GroupIds, GroupNames, ID, platformType, tenantFilter*, Type
- `POST /api/ExecAssignmentFilter` — `Endpoint.MEM.ReadWrite`
  query: tenantFilter* body: Action, ID, tenantFilter*
- `POST /api/ExecBitlockerSearch` — `Endpoint.Device.Read`
  Finds a BitLocker recovery key across every tenant the caller can access, by keyId or deviceId. Intended for the case where a user has a recovery key ID from the BitLocker prompt but the tenant is unknown. query: deviceId, keyId, limit, tenantFilter body: deviceId, keyId, limit, tenantFilter
- `POST /api/ExecCompareIntunePolicy` — `Endpoint.MEM.Read`
  body: sourceA, sourceB
- `POST /api/ExecDeviceAction` — `Endpoint.MEM.ReadWrite`
  body: Action, GUID, input [string], macOsUnlockCode, tenantFilter*, user {label, value}
- `POST /api/ExecDevicePasscodeAction` — `Endpoint.MEM.ReadWrite`
  body: Action, GUID, tenantFilter*
- `POST /api/ExecGetLocalAdminPassword` — `Endpoint.Device.Read`
  Retrieves the Windows LAPS local administrator password for a device, identified by its Entra device GUID. Returns a live credential in plain text; the retrieval is written to the CIPP audit log. body: guid, TenantFilter*
- `POST /api/ExecGetRecoveryKey` — `Endpoint.Device.Read`
  Retrieves a device's disk encryption recovery key by device GUID. RecoveryKeyType selects BitLocker (the default) or FileVault. Returns a live recovery key in plain text; the retrieval is written to the CIPP audit log. query: GUID, tenantFilter* body: GUID, RecoveryKeyType, tenantFilter*
- `POST /api/ExecRemoveCippCveException` — `Security.Alert.ReadWrite`
  query: cveId*, removeScope, tenantFilter* body: cveId, removeScope, tenantFilter*
- `POST /api/ExecRemoveEnrollmentProfile` — `Endpoint.MEM.ReadWrite`
  Deletes an Apple ADE or Android Enterprise enrollment profile. body: displayName, id, profileId*, profileType, tenantFilter*, tokenId*
- `POST /api/ExecSyncDEP` — `Endpoint.MEM.ReadWrite`
  Syncs devices from Apple Business Manager to Intune body: tenantFilter*
- `GET /api/ListAndroidEnrollmentProfiles` — `Endpoint.Autopilot.Read`
  Lists Android Enterprise enrollment profiles and hydrates token fields when Graph omits them from the list response. query: tenantFilter*
- `GET /api/ListAppProtectionPolicies` — `Endpoint.MEM.Read`
  Lists Intune app protection policies for a tenant. Supports UseReportDB=true query parameter to retrieve cached data from the reporting database for significantly better performance, especially when querying AllTenants. query: tenantFilter*, UseReportDB
- `GET /api/ListAppleEnrollmentProfiles` — `Endpoint.Autopilot.Read`
  Lists Apple Automated Device Enrollment tokens and enrollment profiles. query: tenantFilter*
- `GET /api/ListAssignmentFilterTemplates` — `Endpoint.MEM.Read`
  Lists the saved Intune assignment filter templates, each with its platform, filter rule and management type. Pass ID to return a single template. These are CIPP templates, not a tenant's deployed filters. query: ID
- `GET /api/ListAssignmentFilters` — `Endpoint.MEM.Read`
  Lists Intune assignment filters for a tenant. Supports UseReportDB=true query parameter to retrieve cached data from the reporting database for significantly better performance, especially when querying AllTenants. query: filterId, tenantFilter*, UseReportDB
- `GET /api/ListCVEManagement` — `Endpoint.Security.Read`
  Lists CVEs affecting a tenant's devices, from Defender threat and vulnerability management, along with any exceptions recorded in CIPP. AllTenants and UseReportDB=true read the cached report database instead of Defend... query: tenantFilter, UseReportDB
- `GET /api/ListCompliancePolicies` — `Endpoint.MEM.Read`
  Lists Intune device compliance policies for a tenant. Supports UseReportDB=true query parameter to retrieve cached data from the reporting database for significantly better performance, especially when querying AllTen... query: tenantFilter*, UseReportDB
- `GET /api/ListDefenderState` — `Endpoint.MEM.Read`
  Lists Microsoft Defender antivirus state and detected threats for Intune-managed devices in a tenant. query: DeviceID, tenantFilter*
- `GET /api/ListDefenderTVM` — `Endpoint.MEM.Read`
  Lists software vulnerabilities from Microsoft Defender Threat and Vulnerability Management (TVM), grouped by CVE ID. query: tenantFilter*
- `GET /api/ListDeviceDetails` — `Identity.Device.Read`
  Retrieves detailed information about a specific Intune-managed device by ID, name, or serial number. query: DeviceID, DeviceName, DeviceSerial, tenantFilter*
- `GET /api/ListIntuneApprovalRequests` — `Endpoint.MEM.Read`
  Lists the multi-admin approval (MAA) requests raised in a tenant. When an access policy protects a resource type, Intune defers the change and records it here until a second administrator approves it, so this is where... query: PendingOnly, tenantFilter*
- `GET /api/ListIntuneIntents` — `Endpoint.MEM.Read`
  Lists Intune security baseline and endpoint protection intents (legacy template-based policies) with their settings and categories. query: tenantFilter*
- `GET /api/ListIntunePolicy` — `Endpoint.MEM.Read`
  Lists Intune device configuration policies for a tenant. Supports UseReportDB=true query parameter to retrieve cached data from the reporting database for significantly better performance, especially when querying All... query: DefinitionIds, ID, IncludeSettingDefinitions, tenantFilter*, URLName, UseReportDB
- `GET /api/ListIntuneReusableSettingTemplates` — `Endpoint.MEM.Read`
  Lists the saved Intune reusable setting templates, the shared setting groups that settings catalog policies reference rather than redefining. Pass ID to return a single template. query: ID
- `GET /api/ListIntuneReusableSettings` — `Endpoint.MEM.Read`
  Lists Intune reusable policy settings for a tenant. Supports UseReportDB=true query parameter to retrieve cached data from the reporting database for significantly better performance, especially when querying AllTenants. query: ID, tenantFilter*, UseReportDB
- `GET /api/ListIntuneScript` — `Endpoint.MEM.Read`
  Lists Intune device management scripts (Windows, macOS, Linux, and remediation scripts) for a tenant. Supports UseReportDB=true query parameter to retrieve cached data from the reporting database for significantly bet... query: tenantFilter*, UseReportDB
- `GET /api/ListIntuneTemplates` — `Endpoint.MEM.Read`
  query: ID, mode, View
- `POST /api/RemoveAssignmentFilterTemplate` — `Endpoint.MEM.ReadWrite`
  query: ID body: ID
- `POST /api/RemoveIntuneReusableSetting` — `Endpoint.MEM.ReadWrite`
  query: DisplayName, ID, tenantFilter* body: DisplayName, ID*, tenantFilter*
- `POST /api/RemoveIntuneReusableSettingTemplate` — `Endpoint.MEM.ReadWrite`
  query: ID* body: ID
- `POST /api/RemoveIntuneScript` — `Endpoint.MEM.ReadWrite`
  body: DisplayName, ID, ScriptType, TenantFilter*
- `POST /api/RemoveIntuneTemplate` — `Endpoint.MEM.ReadWrite`
  query: ID body: ID
- `POST /api/RemovePolicy` — `Endpoint.MEM.ReadWrite`
  query: ID, tenantFilter*, URLName body: ID, tenantFilter*, URLName

### Endpoint > Reports

- `GET /api/ListAllTenantDeviceCompliance` — `Tenant.DeviceCompliance.Read`
  query: tenantFilter*
- `GET /api/ListDevices` — `Endpoint.Device.Read`
  Lists Intune-managed devices for a tenant, including device compliance and configuration status. query: tenantFilter*
- `GET /api/ListNinjaDeviceInfo` — `Endpoint.Device.Read`
  query: tenantFilter*

### Identity > Administration > Devices

- `POST /api/ExecDeviceDelete` — `Identity.Device.ReadWrite`
  query: action, ID, tenantFilter* body: action, ID, tenantFilter*

### Identity > Administration > Groups

- `POST /api/AddGroup` — `Identity.Group.ReadWrite`
  body: aliases, allowExternal, description, disableNesting, displayName, groupType {label, value}, hideFromGAL, licenses [{label, value}], members [{label, value}], membershipRules, owners [{label, value}], primaryEmailAddress, primDomain {label, value}, subscribeMembers, tenantFilter* {label, value}, username
- `POST /api/AddGroupTeam` — `Identity.Group.ReadWrite`
  body: GroupId, TeamSettings, TenantFilter*
- `POST /api/AddGroupTemplate` — `Identity.Group.ReadWrite`
  body: aliases, allowExternal, description, displayName, groupType {label, value}, GUID, hideFromGAL, licenses, membershipRules, username
- `POST /api/EditGroup` — `Identity.Group.ReadWrite`
  body: AddContact [object], AddDevice [object], AddLicenses [{label, value}], AddMember [object], AddOwner [object], allowExternal, description, displayName, groupId, groupName, groupType, hideFromOutlookClients, mail, mailNickname, membershipRules, RemoveContact [object], RemoveLicenses [{label, value}], RemoveMember [object], RemoveOwner [object], securityEnabled, sendCopies, tenantFilter*, tenantId, visibility
- `POST /api/EditGroupAliases` — `Exchange.Group.ReadWrite`
  body: AddedAliases, GroupType, id*, MakePrimary, RemovedAliases, tenantFilter*
- `POST /api/ExecGroupMembers` — `Identity.Group.ReadWrite`
  Manages group membership (members and owners) via a switch-style action parameter. Accepts one or more directory object IDs, UPNs, or mail addresses (users, groups, etc.). Automatically resolves the group type from Gr... body: action, groupId, tenantFilter*, users
- `GET /api/ListGroupAliases` — `Exchange.Groups.Read`
  query: groupId*, groupType, tenantFilter*
- `GET /api/ListGroupSenderAuthentication` — `Exchange.Groups.Read`
  Lists sender authentication settings for an Exchange distribution group or mail-enabled security group, controlling who can send to the group. query: groupid, tenantFilter*, Type
- `GET /api/ListGroupTemplates` — `Identity.Group.Read`
  query: id
- `GET /api/ListGroups` — `Identity.Group.Read`
  Lists Entra ID groups for a tenant, including group members and owners. Supports UseReportDB=true query parameter to retrieve cached data from the reporting database for significantly better performance, especially wh... query: expandMembers, expandOwners, groupID, groupType, manualPagination, members, nextLink, owners, PageSize, tenantFilter*, UseReportDB
- `POST /api/RemoveGroupTemplate` — `Identity.Group.ReadWrite`
  query: ID body: ID

### Identity > Administration > Roles

- `POST /api/AddPIMRoleSettingsTemplate` — `Identity.Role.ReadWrite`
  Saves a Privileged Identity Management role settings template. The settings are validated against CIPP's secure floor (activation must expire within 24 hours and require MFA or an authentication context plus a justifi... body: captureRoleId {label, value}, captureRoleName, description, GUID, roles [{label, value}], roleScope {label, value}, settings, templateName, tenantFilter {label, value}
- `POST /api/ExecPIMRoleAssignment` — `Identity.Role.ReadWrite`
  Converts a permanent assignment to eligible, grants an eligibility (GrantEligible), grants a time-bound active assignment, extends, renews, or removes an assignment. Duration is an ISO 8601 value up to MaxRoleAssignmentDuration (default P365D: PT1H, P30D, P90D, P180D, P365D) or a StartDateTime/EndDateTime pair passed through as scheduleInfo.expiration afterDuration or afterDateTime. Over-max and past end dates are HTTP 400 and are not shortened. Entra Expiration_Admin_Assignment / Expiration_Admin_Eligibility can still refuse the request; the Graph error is returned. body: Action {label, value}, AssignmentType {label, value}, DirectoryScopeId {label, value}, Duration {label, value}, EndDateTime {label, value}, StartDateTime {label, value}, Justification, PrincipalId {label, value}, RoleDefinitionId {label, value}, tenantFilter* {label, value}, TimeZone {label, value}
- `GET /api/ListPIMRoleSettingsTemplates` — `Identity.Role.Read`
  Lists saved Privileged Identity Management role settings templates. A template names a set of roles and the activation, eligibility, assignment, approval and notification rules to enforce on them; the PIMRoleSettings... query: GUID, id
- `GET /api/ListPIMRoles` — `Identity.Role.Read`
  Returns one row per role (per tenant when AllTenants is selected) with the role's definition details, how many principals hold it permanently, eligibly or with a time-bound active assignment, the role's PIM policy sum... query: principalId, roleTemplateId, tenantFilter*, UseReportDB
- `GET /api/ListRoleAssignments` — `Identity.Role.Read`
  Returns one row per principal, role and scope showing whether the assignment is Permanent (active with no end date), Active (time-bound), ActivatedFromEligible or Eligible, whether it is held directly or through a rol... query: includeUnassigned, permanentOnly, principalId, roleTemplateId, tenantFilter*
- `GET /api/ListRoles` — `Identity.Role.Read`
  Lists a tenant's Entra ID role definitions along with the active members of each, via the unified RBAC API. Unlike the legacy /directoryRoles endpoint this includes every built-in and custom role definition, even ones... query: tenantFilter*
- `POST /api/RemovePIMRoleSettingsTemplate` — `Identity.Role.ReadWrite`
  Deletes a saved Privileged Identity Management role settings template by GUID. Tenants already configured from the template keep their settings. query: ID body: GUID, ID

### Identity > Administration > Users

- `POST /api/AddGuest` — `Identity.User.ReadWrite`
  body: displayName, mail, message, redirectUri, sendInvite, tenantFilter*
- `POST /api/AddJITAdminTemplate` — `Identity.Role.ReadWrite`
  body: defaultDomain, defaultDuration, defaultExistingUser, defaultExpireAction, defaultFirstName, defaultForTenant, defaultGroups, defaultLastName, defaultNotificationActions, defaultRoles, defaultUsageLocation {label, value}, defaultUseGroups, defaultUserAction, defaultUserName, defaultUseRoles, defaultVacationCAPolicy, defaultVacationExcludeAuditAlerts, defaultVacationMode, generateTAPByDefault, reasonTemplate, templateName*, tenantFilter*
- `POST /api/AddJITRoleTemplate` — `Identity.Role.ReadWrite`
  Creates a JIT Role Template - a named allow-list of directory roles that can be assigned to a CIPP custom role to restrict which roles that role's members may grant via JIT Admin. body: roles, templateName*
- `POST /api/AddUser` — `Identity.User.ReadWrite`
  body: AddedAliases, AddToGroups, businessPhones, city, companyName, copyFrom {label, value}, country, customData, defaultAttributes, department, disableLegacyProtocols, DisplayName, Domain, givenName, jobTitle, licenses {label, value}, mailNickname, mobilePhone, MustChangePass, otherMails, password, perUserMfa, postalCode, PostExecution, PrimDomain {label, value}, PsaTicketId, reference, Scheduled, setManager {label, value}, setSponsor {label, value}, sharedCalendarPermission {label, value}, sharedCalendars, sharedMailboxes, sharedMailboxPermission, sharePointSiteRole {label, value}, sharePointSites, sherwebLicense {label, value}, state, streetAddress, surname, tenantFilter*, usageLocation {label, value}, username
- `POST /api/AddUserBulk` — `Identity.User.ReadWrite`
  body: BulkUser [object], disableLegacyProtocols, licenses {label, value}, primDomain {label, value}, tenantFilter*, usageLocation {label, value}
- `POST /api/AddUserDefaults` — `Identity.User.ReadWrite`
  body: addedAliases, addToGroups, Autopassword, businessPhones, businessPhones[0], city, companyName, copyFrom, country, defaultAttributes, defaultForTenant, department, displayName, givenName, groupMemberships, GUID, jobTitle, licenses, mobilePhone, MustChangePass, otherMails, password, perUserMfa, postalCode, primDomain {label, value}, removeLicenses, setManager, setSponsor, sharedCalendarPermission {label, value}, sharedCalendars, sharedMailboxes, sharedMailboxPermission, sharePointSiteRole {label, value}, sharePointSites, state, streetAddress, surname, templateName, tenantFilter*, usageLocation {label, value}, usernameFormat {label, value}, usernameSpaceHandling {label, value}, usernameSpaceReplacement
- `POST /api/EditJITAdminTemplate` — `Identity.Role.ReadWrite`
  body: defaultDomain, defaultDuration, defaultExistingUser, defaultExpireAction, defaultFirstName, defaultForTenant, defaultGroups, defaultLastName, defaultNotificationActions, defaultRoles, defaultUsageLocation {label, value}, defaultUseGroups, defaultUserAction, defaultUserName, defaultUseRoles, defaultVacationCAPolicy, defaultVacationExcludeAuditAlerts, defaultVacationMode, generateTAPByDefault, GUID*, reasonTemplate, templateName*, tenantFilter*
- `POST /api/EditJITRoleTemplate` — `Identity.Role.ReadWrite`
  Updates an existing JIT Role Template. body: GUID*, roles, templateName*
- `POST /api/EditUser` — `Identity.User.ReadWrite`
  body: AddedAliases, AddToGroups [object], businessPhones, city, clearProperties, companyName, CopyFrom {label, value}, country, customData, defaultAttributes, department, DisplayName, Domain, givenName, id*, jobTitle, licenses, mailNickname, mobilePhone, MustChangePass, otherMails, password, postalCode, PostExecution, primDomain {label, value}, reference, RemoveFromGroups [object], removeLicenses, Scheduled, setManager {label, value}, setSponsor {label, value}, sherwebLicense {label, value}, state, streetAddress, surname, tenantFilter*, usageLocation {label, value}, username, userPrincipalName
- `POST /api/EditUserAliases` — `Identity.User.ReadWrite`
  body: AddedAliases, id*, MakePrimary, RemovedAliases, tenantFilter*
- `GET /api/ExecBECBulkCheck` — `Identity.User.Read`
  Queues one BEC investigation per user, each its own sequential orchestration, with a queue entry for progress. Accepts either an array of { UserIds, tenantFilter } items (the Users table bulk action) or one object wit...
- `POST /api/ExecBECCheck` — `Identity.User.Read`
  GET with GUID (or caseId) returns that run: while it is queued or running { Waiting = true, Progress } where Progress is the job status (queued until a worker picks it up, then running) and the per-step state the page... query: caseId, GUID, tenantFilter*, userid, userName body: tenantFilter*, userid, userName
- `POST /api/ExecBECEvidenceExport` — `Identity.User.Read`
  Collates the run's stored results, one CSV per finding set, the score, the containment history, every logbook entry stamped with the case id and the full and C-suite-summary report PDFs (rendered server-side) into a Z... body: caseId, tenantFilter*
- `POST /api/ExecBECIPReview` — `Identity.User.ReadWrite`
  Validates the request and queues a background re-run of the case's address-dependent sections: the investigator's overrides (an address or CIDR range marked Safe, Suspicious or Compromised, with an optional note) beco... body: CaseId, CorrelateUsers [{label, value}], Overrides [object], tenantFilter* {label, value}
- `POST /api/ExecBECRemediate` — `Identity.User.ReadWrite`
  Runs the selected containment actions (see ListBECRemediationActions) for a user. With no Actions the default set runs (the DefaultSelected actions, configurable instance-wide from CIPP settings). Actions marked Criti... body: Actions [{label, value}], Async, CaseId, Confirmation, Parameters, tenantFilter*, userid*, username*
- `POST /api/ExecBECReport` — `Identity.User.ReadWrite`
  Action=Delete removes a BEC run permanently: its results payload, its evidence package and the run row. Runs are otherwise kept indefinitely. body: Action, caseId, tenantFilter*
- `POST /api/ExecBulkLicense` — `Identity.User.ReadWrite`
  Applies license changes to many users across many tenants in one call. The body is a JSON array; entries are grouped by tenantFilter internally, so a single call may span tenants.
- `POST /api/ExecClrImmId` — `Identity.User.ReadWrite`
  body: ID, tenantFilter*
- `POST /api/ExecClrOnPremAttributes` — `Identity.User.ReadWrite`
  body: Attributes [{label, value}], ID, tenantFilter*
- `POST /api/ExecCreateTAP` — `Identity.User.ReadWrite`
  query: generatePwPushLink, ID, isUsableOnce, lifetimeInMinutes, startDateTime, tenantFilter* body: generatePwPushLink, ID, isUsableOnce, lifetimeInMinutes, startDateTime, tenantFilter*
- `POST /api/ExecDisableUser` — `Identity.User.ReadWrite`
  query: Enable, ID, tenantFilter* body: Enable, ID, tenantFilter*
- `POST /api/ExecDismissRiskyUser` — `Identity.User.ReadWrite`
  query: tenantFilter*, userDisplayName, userId, userPrincipalName body: tenantFilter*, userDisplayName, userId, userPrincipalName
- `POST /api/ExecDomainMigration` — `Identity.User.ReadWrite`
  body: groups [object], sourceDomain, targetDomain, tenantFilter*, users [object]
- `POST /api/ExecExpirePassword` — `Identity.User.ReadWrite`
  query: displayName, ID, tenantFilter* body: displayName, ID, tenantFilter*
- `POST /api/ExecGetBecReportPdf` — `Identity.User.Read`
  Server-renders a stored Business Email Compromise (BEC) run as application/pdf bytes. Reads the run through Get-CIPPBecReport (the BecReports metadata row plus its BecResults payload) and composes it through the share... query: caseId, tenantFilter*, userDisplayName, userId, userName, variant body: caseId, tenantFilter*, userDisplayName, userId, userName, variant
- `POST /api/ExecJITAdmin` — `Identity.Role.ReadWrite`
  Just-in-time admin management. StartDate and EndDate are unix seconds. The window is honored up to MaxRoleAssignmentDuration (default P365D). A longer window or an end date in the past is HTTP 400 and is not shortened. body: AdminRoles [{label, value}], Domain {label, value}, EndDate, existingUser {label, value}, ExpireAction {label, value}, FirstName, GroupMemberships {label, value}, LastName, PostExecution, reason, StartDate, tapLifetimeInMinutes, tenantFilter* {label, value}, usageLocation {label, value}, userAction, Username, UseTAP
- `POST /api/ExecMigrateOneDriveShortCuts` — `Identity.User.ReadWrite`
  body: id {label, value}, tenantFilter*, username {label, value}
- `POST /api/ExecOffboardUser` — `Identity.User.ReadWrite`
  Runs the offboarding wizard: one scheduled offboarding job per user, immediately or at the scheduled time, reporting live progress under one job id. Action=Rerun queues an existing offboarding task again; Action=Rerun... query: Action body: Action, forward {label, value}, OOO, PostExecution, PsaTicketId, reference, Scheduled, StepIndex, StepTitle, TaskId, tenantFilter* {label, value}, user [{label, value}]
- `POST /api/ExecOneDriveProvision` — `Identity.User.ReadWrite`
  query: tenantFilter*, UserPrincipalName body: tenantFilter*, UserPrincipalName [string]
- `POST /api/ExecOneDriveShortCut` — `Identity.User.ReadWrite`
  Accepts one { username, userid, siteUrl, destination, optional shortcutName, tenantFilter } object or an array of them (the Users table bulk action). Every user is attempted: a failure for one user (for example a shor...
- `POST /api/ExecPasswordNeverExpires` — `Identity.User.ReadWrite`
  body: PasswordPolicy {label, value}, tenantFilter*, userId, userPrincipalName
- `POST /api/ExecPerUserMFA` — `Identity.User.ReadWrite`
  body: State {label, value}, tenantFilter*, userId, userPrincipalName
- `POST /api/ExecRemoveAdminRole` — `Identity.Role.ReadWrite`
  Removes a user from an assigned Microsoft Entra admin role. body: RoleId {label, value}, RoleName {label, value}, RoleTemplateId {label, value}, tenantFilter* {label, value}, Users
- `POST /api/ExecRemoveOneDriveShortCut` — `Identity.User.ReadWrite`
  body: id {label, value}, name {label, value}, tenantFilter*, username {label, value}
- `POST /api/ExecRemoveRoleMember` — `Identity.Role.ReadWrite`
  body: MemberId, MemberName, RoleId, RoleName, TenantFilter*
- `POST /api/ExecReprocessUserLicenses` — `Identity.User.ReadWrite`
  query: ID, tenantFilter*, userPrincipalName body: ID, tenantFilter*, userPrincipalName
- `POST /api/ExecRequirePasswordChange` — `Identity.User.ReadWrite`
  Requires password change at next sign-in without resetting the password. Sets passwordProfile.forceChangePasswordNextSignIn via Graph. Not supported for directory-synced users. query: ID, tenantFilter* body: ID, tenantFilter*
- `POST /api/ExecResetMFA` — `Identity.User.ReadWrite`
  body: ID, MethodId, tenantFilter*
- `POST /api/ExecResetPass` — `Identity.User.ReadWrite`
  query: displayName, ID, MustChange, password, tenantFilter* body: displayName, ID, MustChange, password, tenantFilter*
- `POST /api/ExecRestoreDeleted` — `Tenant.Directory.ReadWrite`
  query: ID, tenantFilter* body: displayName, ID, tenantFilter*, userPrincipalName
- `POST /api/ExecRevokeSessions` — `Identity.User.ReadWrite`
  query: id, tenantFilter*, Username body: id, tenantFilter*, Username
- `POST /api/ExecRoleAssignment` — `Identity.Role.ReadWrite`
  body: action, displayName, expiration, reason, roles [{label, value}], tenantFilter*, userId, userPrincipalName
- `POST /api/ExecScheduleGroupMembershipVacation` — `Identity.Group.ReadWrite`
  Adds the selected users to each selected group at the start date and removes them again at the end date. Users who were already members of a group are left untouched. body: endDate, Groups [{label, value}], postExecution, reference, startDate, tenantFilter*, Users
- `POST /api/ExecSendPush` — `Identity.User.Read`
  Sends a test MFA push notification to a user's authenticator app and reports whether it was approved, or - when an OTP code is supplied - verifies that typed code without sending a push. Used to confirm a user's MFA r... body: OTP, TenantFilter*, UserEmail
- `POST /api/ExecSetCloudManaged` — `Identity.DirSync.ReadWrite`
  Sets the cloud-managed status of a user, group, or contact. body: displayName, ID, isCloudManaged, tenantFilter*, type
- `POST /api/ExecSetDefaultMFAMethod` — `Identity.User.ReadWrite`
  Sets the default second factor a user is prompted with, by patching signInPreferences. Note this is ignored at sign-in while system-preferred MFA is enabled for the user. body: ID, MethodType {label, value}, tenantFilter*
- `POST /api/ExecSetManager` — `Identity.User.ReadWrite`
- `POST /api/ExecSetUserPhoto` — `Identity.User.ReadWrite`
  query: action, tenantFilter*, userId* body: action, photoData*, tenantFilter*, userId
- `GET /api/ListBECPhishingSpread` — `Identity.User.Read`
  Given a sender address (and optionally a subject fragment), walks the message trace for the last N days and groups the recipients: address, internal or external, message count, first and last delivery and the subjects... query: days, sender, subject, tenantFilter*
- `POST /api/ListBECRemediationActions` — `Identity.User.ReadWrite`
  Returns the catalog of containment actions ExecBECRemediate accepts - id, label, description, impact (Low/Medium/High/Critical), whether it is reversible and whether it runs by default (the instance-wide defaults from...
- `GET /api/ListBECReports` — `Identity.User.Read`
  Lists every stored BEC run (case id, user, status, threat level and score, when it was extracted, who requested it) for a tenant, or for every tenant with tenantFilter=AllTenants. Optionally narrowed to one user with... query: tenantFilter, userId
- `GET /api/ListDeletedItems` — `Tenant.Directory.Read`
  Lists soft-deleted directory objects in Entra ID, including users, groups, applications, service principals, and administrative units. query: tenantFilter*
- `GET /api/ListGuestUsers` — `Identity.User.Read`
  Lists all guest accounts in a tenant with a computed lifecycle status (Active, Pending Acceptance, Stale, Never Signed In or Disabled) based on the invitation state and sign-in activity. Supports UseReportDB=true to s... query: manualPagination, nextLink, PageSize, staleDays, tenantFilter*, UseReportDB
- `GET /api/ListJITAdmin` — `Identity.Role.Read`
  List Just-in-time admin users for a tenant or all tenants. query: tenantFilter*
- `GET /api/ListJITAdminTemplates` — `Identity.Role.Read`
  query: GUID, includeAllTenants, TenantFilter
- `GET /api/ListJITAllowedRoles` — `Identity.Role.Read`
  Returns the directory roles the calling user is permitted to assign via JIT Admin, based on the JIT Role Template(s) attached to their CIPP custom role(s). When the caller is unrestricted the full role catalog is avai...
- `GET /api/ListJITRoleTemplates` — `Identity.Role.Read`
  Lists JIT Role Templates - named allow-lists of directory roles used to restrict which roles a CIPP custom role may assign via JIT Admin. query: GUID
- `GET /api/ListNewUserDefaults` — `Identity.User.Read`
  query: ID, includeAllTenants, TenantFilter
- `GET /api/ListOffboardingProgress` — `Identity.User.Read`
  Returns the progress rows of an offboarding job started from the wizard, or of a background BEC remediation (ExecBECRemediate with Async): one row per user with its overall status and the status and message of every s... query: DeploymentId*
- `GET /api/ListPerUserMFA` — `Identity.User.Read`
  Lists per-user MFA state (enabled, enforced, disabled) for users in a tenant via the legacy MFA management API. query: allUsers, tenantFilter*, userId
- `GET /api/ListRiskyUsers` — `Identity.User.Read`
  query: tenantFilter*
- `GET /api/ListUserCounts` — `Identity.User.Read`
  query: tenantFilter*
- `GET /api/ListUserDevices` — `Identity.User.Read`
  Lists Intune-managed devices registered to a specific user, including compliance status and endpoint protection details. query: tenantFilter*, UserID
- `GET /api/ListUserGroups` — `Identity.User.Read`
  Lists Entra ID group memberships for a specific user. query: tenantFilter*, userId
- `GET /api/ListUserMailboxDetails` — `Exchange.Mailbox.Read`
  query: tenantFilter*, UserID, userMail
- `GET /api/ListUserMailboxRules` — `Exchange.Mailbox.Read`
  Lists inbox rules configured on a specific user's Exchange Online mailbox. query: tenantFilter*, userEmail, UserID
- `GET /api/ListUserOneDriveShortcuts` — `Identity.User.Read`
  Lists OneDrive remoteItem shortcuts for a user from the drive root and the Shortcuts folder. query: tenantFilter*, userId, userPrincipalName*
- `GET /api/ListUserPhoto` — `Identity.User.Read`
  Retrieves the profile photo for a specific Entra ID user as raw image bytes. query: tenantFilter, UserID
- `GET /api/ListUserSettings` — `Identity.User.Read`
- `GET /api/ListUserSigninLogs` — `Identity.User.Read`
  Lists recent sign-in log entries for a specific Entra ID user, ordered by most recent. query: tenantFilter*, top, UserID
- `GET /api/ListUserTrustedBlockedSenders` — `Exchange.Mailbox.Read`
  Lists trusted and blocked sender entries configured for a specific user's Exchange Online mailbox junk email settings. query: tenantFilter*, UserID, userPrincipalName
- `GET /api/ListUsers` — `Identity.User.Read`
  Lists Entra ID users for a tenant with license and sign-in details, or retrieves a specific user by ID. Supports UseReportDB=true to serve cached users from the reporting database; AllTenants always uses the cache. Wh... query: graphFilter, IncludeLogonDetails, manualPagination, nextLink, PageSize, tenantFilter*, UseReportDB, UserID
- `POST /api/PatchUser` — `Identity.User.ReadWrite`
- `POST /api/RemoveDeletedObject` — `Tenant.Directory.ReadWrite`
  query: ID, tenantFilter* body: displayName, ID, tenantFilter*, userPrincipalName
- `POST /api/RemoveJITAdminTemplate` — `Identity.Role.ReadWrite`
  query: ID* body: ID
- `POST /api/RemoveJITRoleTemplate` — `Identity.Role.ReadWrite`
  Deletes a JIT Role Template. query: ID* body: ID
- `POST /api/RemoveTrustedBlockedSender` — `Exchange.Mailbox.ReadWrite`
  body: tenantFilter*, typeProperty, userPrincipalName, value
- `POST /api/RemoveUser` — `Identity.User.ReadWrite`
  query: ID, tenantFilter*, userPrincipalName body: ID, tenantFilter*, userPrincipalName
- `POST /api/RemoveUserDefaultTemplate` — `Identity.User.ReadWrite`
  query: ID body: ID

### Identity > Reports

- `GET /api/ListAzureADConnectStatus` — `Tenant.Directory.Read`
  Retrieves Entra ID Connect (Azure AD Connect) synchronization status and configuration for a tenant, including sync intervals, password sync, and pass-through authentication settings. query: DataToReturn, tenantFilter*
- `GET /api/ListBasicAuth` — `Identity.AuditLog.Read`
  query: tenantFilter*
- `GET /api/ListGroupUsage` — `Identity.Group.Read`
  Compiles where each Entra group is used (Conditional Access, Intune assignments, group-based licensing, Teams, nested groups, Entra roles, enterprise applications, Exchange transport rules) from the CIPP reporting dat... query: tenantFilter*
- `GET /api/ListInactiveAccounts` — `Tenant.Directory.Read`
  Lists user accounts that have not signed in for a configurable number of days (default 180), based on sign-in activity data. query: InactiveDays, tenantFilter*
- `GET /api/ListMFAUsers` — `Identity.User.Read`
  Lists users and their MFA registration status for a tenant. Supports UseReportDB=true query parameter to retrieve cached data from the reporting database for significantly better performance, especially when querying... query: manualPagination, nextLink, PageSize, tenantFilter*, UseReportDB
- `GET /api/ListObjectHistory` — `Identity.AuditLog.Read`
  Aggregates change history from Graph directoryAudits and (for Exchange objects) the Unified Audit Log. Returns a normalised timeline array with parsed property changes, actor details, and source metadata. Supports use... query: days, id, objectId, objectType, tenantFilter*
- `GET /api/ListSignIns` — `Identity.AuditLog.Read`
  Lists recent sign-in log entries for a tenant, filterable by various criteria. Supports AllTenants queries.  Deprecated: use ListGraphRequest with Endpoint=auditLogs/signIns instead, which supports $filter, $top, $ord... query: Days, failedLogonsOnly, FailureThreshold, Filter, tenantFilter*

### Security

- `POST /api/ExecEdiscoveryCase` — `Security.Ediscovery.ReadWrite`
  body: action, caseId, description, displayName, externalId, tenantFilter*
- `POST /api/ExecEdiscoveryCaseExport` — `Security.Ediscovery.ReadWrite`
  body: caseId, displayName, exportCriteria, exportFormat, exportLocation, searchId, tenantFilter*
- `POST /api/ExecEdiscoveryCaseHold` — `Security.Ediscovery.ReadWrite`
  body: action, caseId, contentQuery, description, displayName, holdId, siteSources [object], tenantFilter*, userSources [object]
- `POST /api/ExecEdiscoveryCaseSearch` — `Security.Ediscovery.ReadWrite`
  body: action, caseId, contentQuery, dataSourceScopes, description, displayName, searchId, tenantFilter*
- `GET /api/ListEdiscoveryCaseHolds` — `Security.Ediscovery.Read`
  query: caseId, tenantFilter*
- `GET /api/ListEdiscoveryCaseOperations` — `Security.Ediscovery.Read`
  query: caseId, tenantFilter*
- `GET /api/ListEdiscoveryCaseSearches` — `Security.Ediscovery.Read`
  query: caseId, tenantFilter*
- `GET /api/ListEdiscoveryCases` — `Security.Ediscovery.Read`
  query: tenantFilter*

### Security > Compliance-DLP

- `POST /api/AddDlpCompliancePolicy` — `Security.DlpCompliancePolicy.ReadWrite`
  body: PowerShellCommand, selectedTenants
- `POST /api/AddDlpCompliancePolicyTemplate` — `Security.DlpCompliancePolicy.ReadWrite`
  body: PowerShellCommand
- `POST /api/EditDlpCompliancePolicy` — `Security.DlpCompliancePolicy.ReadWrite`
  query: Identity, State, tenantFilter* body: Identity, Name, parameters, State, tenantFilter*
- `GET /api/ListDlpCompliancePolicy` — `Security.DlpCompliancePolicy.Read`
  Lists Data Loss Prevention (DLP) compliance policies and their associated rules from the Security & Compliance Center. query: tenantFilter*
- `GET /api/ListDlpCompliancePolicyTemplates` — `Security.DlpCompliancePolicy.Read`
  Lists saved DLP compliance policy templates for deploying standardized DLP configurations. query: ID
- `POST /api/RemoveDlpCompliancePolicy` — `Security.DlpCompliancePolicy.ReadWrite`
  query: Identity, tenantFilter* body: Identity, Name, tenantFilter*
- `POST /api/RemoveDlpCompliancePolicyTemplate` — `Security.DlpCompliancePolicy.ReadWrite`
  query: ID body: ID

### Security > Compliance-Retention

- `POST /api/AddRetentionCompliancePolicy` — `Security.RetentionCompliancePolicy.ReadWrite`
  body: PowerShellCommand, selectedTenants
- `POST /api/AddRetentionCompliancePolicyTemplate` — `Security.RetentionCompliancePolicy.ReadWrite`
  query: tenantFilter* body: Identity, Name, PowerShellCommand, tenantFilter*
- `POST /api/EditRetentionCompliancePolicy` — `Security.RetentionCompliancePolicy.ReadWrite`
  query: Identity, State, tenantFilter* body: Identity, Name, parameters, State, tenantFilter*
- `GET /api/ListRetentionCompliancePolicy` — `Security.RetentionCompliancePolicy.Read`
  Lists retention compliance policies and their associated rules from the Security & Compliance Center. query: tenantFilter*
- `GET /api/ListRetentionCompliancePolicyTemplates` — `Security.RetentionCompliancePolicy.Read`
  Lists saved retention compliance policy templates for deploying standardized retention configurations. query: ID
- `POST /api/RemoveRetentionCompliancePolicy` — `Security.RetentionCompliancePolicy.ReadWrite`
  query: Identity, tenantFilter* body: ForceDeletion, Identity, Name, tenantFilter*
- `POST /api/RemoveRetentionCompliancePolicyTemplate` — `Security.RetentionCompliancePolicy.ReadWrite`
  query: ID body: ID

### Security > Compliance-SIT

- `POST /api/AddSensitiveInfoType` — `Security.SensitiveInfoType.ReadWrite`
  body: PowerShellCommand, selectedTenants
- `POST /api/AddSensitiveInfoTypeTemplate` — `Security.SensitiveInfoType.ReadWrite`
  query: tenantFilter* body: Id, Identity, Name, PowerShellCommand, tenantFilter*
- `POST /api/EditSensitiveInfoType` — `Security.SensitiveInfoType.ReadWrite`
  query: Identity, tenantFilter* body: Identity, Name, parameters, tenantFilter*
- `GET /api/ListSensitiveInfoType` — `Security.SensitiveInfoType.Read`
  Lists sensitive information types (SITs) configured in the Security & Compliance Center, optionally including built-in types. query: IncludeBuiltIn, tenantFilter*
- `GET /api/ListSensitiveInfoTypeRulePackage` — `Security.SensitiveInfoType.Read`
  Returns the rule pack behind a custom Sensitive Information Type - the parsed rule configuration (entities with confidence/proximity and their resolved regex/keyword/fingerprint detection) plus the raw ClassificationR... query: RulePackId*, tenantFilter*
- `GET /api/ListSensitiveInfoTypeTemplates` — `Security.SensitiveInfoType.Read`
  Lists saved sensitive information type templates for deploying custom SIT configurations. query: ID
- `POST /api/RemoveSensitiveInfoType` — `Security.SensitiveInfoType.ReadWrite`
  query: Identity, tenantFilter* body: Identity, Name, tenantFilter*
- `POST /api/RemoveSensitiveInfoTypeTemplate` — `Security.SensitiveInfoType.ReadWrite`
  query: ID body: ID

### Security > Compliance-SensitivityLabel

- `POST /api/AddSensitivityLabel` — `Security.SensitivityLabel.ReadWrite`
  body: PowerShellCommand, selectedTenants
- `POST /api/AddSensitivityLabelTemplate` — `Security.SensitivityLabel.ReadWrite`
  body: PowerShellCommand, tenantFilter*
- `POST /api/EditSensitivityLabel` — `Security.SensitivityLabel.ReadWrite`
  query: Identity, tenantFilter* body: Identity, Name, parameters, tenantFilter*
- `GET /api/ListSensitivityLabel` — `Security.SensitivityLabel.Read`
  Lists sensitivity labels and label policies configured in the Security & Compliance Center for a tenant. query: tenantFilter*
- `GET /api/ListSensitivityLabelTemplates` — `Security.SensitivityLabel.Read`
  Lists saved sensitivity label templates for deploying standardized label configurations. query: ID
- `POST /api/RemoveSensitivityLabel` — `Security.SensitivityLabel.ReadWrite`
  query: Identity, tenantFilter* body: Identity, Name, tenantFilter*
- `POST /api/RemoveSensitivityLabelTemplate` — `Security.SensitivityLabel.ReadWrite`
  query: ID body: ID

### Security > Defender

- `GET /api/ListMDEOnboarding` — `Security.Defender.Read`
  Lists Microsoft Defender for Endpoint onboarding status for devices in a tenant. Supports UseReportDB=true query parameter to retrieve cached data from the reporting database for significantly better performance. Auto... query: tenantFilter*, UseReportDB

### Security > Incidents

- `GET /api/ExecAlertsList` — `Security.Alert.Read`
  query: tenantFilter*
- `GET /api/ExecIncidentsList` — `Security.Incident.Read`
  query: EndDate, StartDate, tenantFilter*
- `GET /api/ExecMDOAlertsList` — `Security.Alert.Read`
  Lists Microsoft Defender for Office 365 and Defender for Endpoint alerts for a tenant, filtered to those service sources. tenantFilter=AllTenants reads the cached alert table rather than querying each tenant live. query: tenantFilter*
- `POST /api/ExecSetMdoAlert` — `Security.Incident.ReadWrite`
  query: Assigned, Classification, Determination*, GUID, Status, tenantFilter* body: Assigned, Classification, Determination, GUID, Status, tenantFilter*
- `POST /api/ExecSetSecurityAlert` — `Security.Alert.ReadWrite`
  query: GUID, Status, tenantFilter* body: GUID, Status, tenantFilter*
- `POST /api/ExecSetSecurityIncident` — `Security.Incident.ReadWrite`
  body: AssignToSelf, Classification, Comment, Determination*, GUID, Redirected, Severity {label, value}, Status, tenantFilter*
- `GET /api/ListCheckExtAlerts` — `CIPP.Core.Read`
  Lists extension alert check results from third-party integrations for a tenant. query: tenantFilter*

### Security > Safe-Links-Policy

- `POST /api/AddSafeLinksPolicyFromTemplate` — `Exchange.SafeLinks.ReadWrite`
  This function deploys SafeLinks policies and rules from templates to selected tenants. body: selectedTenants [{label, value}], TemplateList [{label, value}]
- `POST /api/AddSafeLinksPolicyTemplate` — `Exchange.SafeLinks.ReadWrite`
  body: AdminDisplayName, Description, Name, PolicyName*, TemplateDescription, TemplateName
- `POST /api/CreateSafeLinksPolicyTemplate` — `Exchange.SafeLinks.ReadWrite`
  This function creates a new Safe Links policy template from scratch. body: TemplateDescription, TemplateName
- `POST /api/EditSafeLinksPolicy` — `Exchange.SpamFilter.ReadWrite`
  This function modifies an existing Safe Links policy and its associated rule. query: PolicyName, RuleName, tenantFilter* body: AdminDisplayName, AllowClickThrough, Comments, CustomNotificationText, DeliverMessageAfterScan, DisableUrlRewrite, DoNotRewriteUrls [object], EnableForInternalSenders, EnableOrganizationBranding, EnableSafeLinksForEmail, EnableSafeLinksForOffice, EnableSafeLinksForTeams, ExceptIfRecipientDomainIs [object], ExceptIfSentTo [object], ExceptIfSentToMemberOf [object], PolicyName, Priority, RecipientDomainIs [object], RuleName, ScanUrls, SentTo [object], SentToMemberOf [object], State, tenantFilter*, TrackClicks
- `POST /api/EditSafeLinksPolicyTemplate` — `Exchange.SafeLinks.ReadWrite`
  This function updates an existing Safe Links policy template. body: ID*, TemplateDescription, TemplateName
- `POST /api/ExecDeleteSafeLinksPolicy` — `Exchange.SpamFilter.ReadWrite`
  This function deletes a Safe Links rule and its associated policy. query: PolicyName, RuleName, tenantFilter* body: PolicyName, RuleName, tenantFilter*
- `POST /api/ExecNewSafeLinksPolicy` — `Exchange.SpamFilter.ReadWrite`
  This function creates a new Safe Links policy and an associated rule. query: tenantFilter* body: AdminDisplayName, AllowClickThrough, Comments, CustomNotificationText, DeliverMessageAfterScan, DisableUrlRewrite, DoNotRewriteUrls [object], EnableForInternalSenders, EnableOrganizationBranding, EnableSafeLinksForEmail, EnableSafeLinksForOffice, EnableSafeLinksForTeams, ExceptIfRecipientDomainIs [object], ExceptIfSentTo [object], ExceptIfSentToMemberOf [object], PolicyName, Priority, RecipientDomainIs [object], RuleName, ScanUrls, SentTo [object], SentToMemberOf [object], State, tenantFilter*, TrackClicks
- `GET /api/ListSafeLinksPolicy` — `Security.SafeLinksPolicy.Read`
  This function is used to list the Safe Links policies in the tenant, including unmatched rules and policies. query: tenantFilter*
- `GET /api/ListSafeLinksPolicyDetails` — `Exchange.SpamFilter.Read`
  This function retrieves details for a specific Safe Links policy and rule. query: PolicyName, RuleName, tenantFilter*
- `GET /api/ListSafeLinksPolicyTemplateDetails` — `Exchange.SafeLinks.Read`
  This function retrieves details for a specific Safe Links policy template. query: ID*
- `GET /api/ListSafeLinksPolicyTemplates` — `Exchange.SafeLinks.Read`
  Lists saved Safe Links policy templates for deploying standardized Safe Links configurations. query: ID
- `POST /api/RemoveSafeLinksPolicyTemplate` — `Exchange.SafeLinks.ReadWrite`
  query: ID body: ID

### Teams-Sharepoint

- `POST /api/AddSite` — `Sharepoint.Site.ReadWrite`
  body: customSiteDesignId {label, value}, hubSiteId {label, value}, isPublic, lcid {label, value}, sensitivityLabel {label, value}, shareByEmailEnabled, siteDescription, siteDesign {label, value}, siteName, siteOwner {label, value}, storageQuota, templateName {label, value}, tenantFilter*, timeZoneId {label, value}
- `POST /api/AddSiteBulk` — `Sharepoint.Site.ReadWrite`
  body: bulkSites [object], tenantFilter*
- `POST /api/AddTeam` — `Teams.Group.ReadWrite`
  body: additionalMembers, allowAddRemoveApps, allowChannelMentions, allowCreatePrivateChannels, allowCreateUpdateChannels, allowCreateUpdateRemoveConnectors, allowCreateUpdateRemoveTabs, allowCustomMemes, allowDeleteChannels, allowGiphy, allowGuestCreateUpdateChannels, allowGuestDeleteChannels, allowOwnerDeleteMessages, allowStickersAndMemes, allowTeamMentions, allowUserDeleteMessages, allowUserEditMessages, description, displayName, giphyContentRating, owner*, templateName, tenantid, visibility
- `POST /api/DeleteSharepointSite` — `Sharepoint.Site.ReadWrite`
  body: DisplayName, SiteId*, tenantFilter*
- `POST /api/EditSharepointSettings` — `Sharepoint.Admin.ReadWrite`
  body: defaultLinkPermission, defaultSharingLinkType, fileAnonymousLinkType, folderAnonymousLinkType, isResharingByExternalUsersEnabled, requireAnonymousLinksExpireInDays, sharingAllowedDomainList, sharingBlockedDomainList, sharingCapability, sharingDomainRestrictionMode, tenantFilter*
- `POST /api/EditTeamsSettings` — `Teams.Group.ReadWrite`
  body: allowAnonymousUsersToJoinMeeting, allowAnonymousUsersToStartMeeting, allowBox, allowCommunicationComplianceEndUserReporting, allowDropBox, allowEgnyte, allowExternalParticipantGiveRequestControl, allowGoogleDrive, allowGuestUser, allowOwnerDeleteMessage, allowPSTNUsersToBypassLobby, allowSecurityEndUserReporting, allowShareFile, allowTeamsConsumer, allowUserDeleteChat, allowUserDeleteMessage, allowUserEditMessage, assignUser, autoAdmittedUsers, createCustomEmojis, deleteCustomEmojis, designatedPresenterRoleMode, enableFederationAccess, enableMeetingBackgroundImages, enableTeamsConsumerAccess, federationAllowedDomains, federationBlockedDomains, federationMode, meetingChatEnabledType, policyName, readReceiptsEnabledType, section, tenantFilter*
- `POST /api/ExecBulkRemoveSharingLinks` — `Sharepoint.Site.ReadWrite`
  Revokes all sharing links / external direct grants on one site in bulk, sourced from the SharePointSharingLinks reporting cache. Scope selects which classifications are revoked: Anonymous (anyone links only), External... body: Scope {label, value}, SiteUrl*, tenantFilter*
- `POST /api/ExecCreateSharingLink` — `Sharepoint.Site.ReadWrite`
  body: driveId, expirationDateTime, itemId, linkScope, linkType, password, recipients [object], tenantFilter*
- `POST /api/ExecEmptySiteRecycleBin` — `Sharepoint.SiteRecycleBin.ReadWrite`
  Permanently empty a site recycle bin (first stage, second stage, or both). Item ids are used only server-side; the response never includes file names. body: SiteUrl*, Stage, tenantFilter*
- `POST /api/ExecGetPermissionsReportPdf` — `Sharepoint.Site.Read`
  Server-renders the SharePoint Permissions report as application/pdf bytes. Gathers the same shaped data the Permissions page uses (ListSharePointPermissions, from the CIPP reporting cache), composes it through the sha... query: tenantFilter* body: tenantFilter*
- `POST /api/ExecGetSharingReportPdf` — `Sharepoint.Site.Read`
  Server-renders the SharePoint & OneDrive Sharing report as application/pdf bytes. Gathers the same shaped data the Sharing page uses (ListSharePointSharing, from the CIPP reporting cache), composes it through the shar... query: tenantFilter* body: tenantFilter*
- `POST /api/ExecHubSiteAssociation` — `Sharepoint.Site.ReadWrite`
  body: Disconnect*, DisplayName, HubSiteId {label, value}, SiteUrl*, tenantFilter*
- `POST /api/ExecNotifySiteOwner` — `Sharepoint.Site.ReadWrite`
  body: CustomMessage, DisplayName, OwnerEmail*, SiteUrl, StorageAllocatedGB, StorageUsedGB, tenantFilter*, Type
- `POST /api/ExecOneDriveCompare` — `Sharepoint.Site.Read`
  query: tenantFilter* body: DestDriveId*, DestFolderId, DestSiteId, DestUserId, MaxDepth, SourceDriveId*, SourceFolderId, SourceSiteId, SourceUserId, TenantFilter*
- `POST /api/ExecOneDriveFileAction` — `Sharepoint.Site.ReadWrite`
  query: tenantFilter* body: Action, ConflictBehavior*, CopyName, DestinationDriveId*, DestinationFolderId* {label, value}, DestinationSiteId, DestinationUserId, DriveId*, FolderName*, ItemId*, ItemName, NewName*, ParentId, SiteId, TenantFilter*, UserId
- `POST /api/ExecReactivateSite` — `Sharepoint.Site.ReadWrite`
  Reactivates (unarchives) a Microsoft 365 Archive site through the Graph beta site: unarchive endpoint (POST /beta/sites/{site-id}/unarchive). Primarily used to reactivate archived OneDrive accounts before granting per... body: SiteId, SiteUrl*, tenantFilter*, WebId
- `POST /api/ExecRemoveDeletedSite` — `Sharepoint.Site.ReadWrite`
  body: DisplayName, SiteUrl*, tenantFilter*
- `POST /api/ExecRemoveLibraryPermission` — `Sharepoint.Site.ReadWrite`
  Removes a principal's permission on a document library (ListId) or on the site root web (ListId omitted) via the SharePoint REST API. Supplying RoleDefinitionId removes that one permission level; omitting it removes e... body: LibraryName, ListId, PrincipalId*, PrincipalName, RoleDefinitionId, SiteUrl*, tenantFilter*, Title
- `POST /api/ExecRemoveSPOExternalUser` — `Sharepoint.Site.ReadWrite`
  Fully removes an external user's guest access: deletes their Entra guest account (when one exists) AND removes them from every SharePoint site they hold membership on, in one pass - so no orphaned accounts or lingerin... body: DisplayName, EntraUserId, LoginName, SiteUrls, tenantFilter*
- `POST /api/ExecRemoveSharingLink` — `Sharepoint.Site.ReadWrite`
  Revokes a sharing link (or direct sharing grant) on a SharePoint or OneDrive item by deleting the permission from the drive item. Also removes the revoked link from the SharePointSharingLinks reporting cache so the sh... body: CacheId, DriveId, FileName, ItemId, PermissionId, tenantFilter*
- `POST /api/ExecRemoveSiteUser` — `Sharepoint.Site.ReadWrite`
  Removes a user from one or more SharePoint sites entirely: deleting the site user removes them from every site group and direct permission grant at once. Uses the SharePoint REST API with certificate authentication. N... body: DisplayName, SiteUrl, SiteUrls, tenantFilter*, user
- `POST /api/ExecRemoveTeamsVoicePhoneNumberAssignment` — `Teams.Voice.ReadWrite`
  body: AssignedTo, PhoneNumber, PhoneNumberType, tenantFilter*
- `POST /api/ExecRestoreDeletedSite` — `Sharepoint.Site.ReadWrite`
  Restores a deleted SharePoint site from the tenant recycle bin via the SharePoint admin CSOM API. body: SiteUrl*, tenantFilter*, Url
- `POST /api/ExecRestoreRecycleBinItems` — `Sharepoint.SiteRecycleBin.ReadWrite`
  Restores one or more items from a SharePoint site's recycle bin via the SharePoint REST API RestoreByIds method with certificate authentication. body: Ids, ItemNames, SiteUrl*, tenantFilter*
- `POST /api/ExecRevokeOneDriveLink` — `Sharepoint.Site.ReadWrite`
  body: DisplayName, DriveId*, ItemId, PermissionId, RevokeAll, SiteId, tenantFilter*
- `POST /api/ExecSPOVersionCleanup` — `Sharepoint.Site.ReadWrite`
  body: BatchDeleteMode, DeleteOlderThanDays, MajorVersionLimit, MajorWithMinorVersionsLimit, SiteUrl, tenantFilter*
- `POST /api/ExecSearchFiles` — `Sharepoint.Site.Read`
  query: From, SearchQuery, Size, tenantFilter* body: FilterDateFrom, FilterDateTo, FilterModifiedBy, From, SearchQuery, Size, TenantFilter*
- `POST /api/ExecSetLibraryInheritance` — `Sharepoint.Site.ReadWrite`
  Controls whether a document library inherits its permissions from the site, via the SharePoint REST API.  Action 'Break' detaches the library so it holds its own permissions. CopyRoleAssignments (default true) copies... body: Action, ClearSubscopes, CopyRoleAssignments, LibraryName, ListId*, SiteUrl*, tenantFilter*
- `POST /api/ExecSetLibraryPermission` — `Sharepoint.Site.ReadWrite`
  Grants users and/or groups a SharePoint permission level on a document library (ListId) or on the site root web (ListId omitted) via the SharePoint REST API. Principals are resolved with ensureuser unless PrincipalId... body: Groups, LibraryName, ListId, Mode, PermissionLevel, PrincipalId, PrincipalName, RoleDefinitionId, SiteUrl*, tenantFilter*, Users
- `POST /api/ExecSetOneDriveSharing` — `Teams.SharePoint.ReadWrite`
  body: SharingCapability {label, value}, tenantFilter*, UPN
- `POST /api/ExecSetSharePointMember` — `Sharepoint.Site.ReadWrite`
  Adds one or more users to, or removes a user from, a SharePoint site role (Owners, Members or Visitors). Group-connected sites manage Owners/Members through the backing M365 group via Graph; Visitors (and classic/comm... body: Add, GroupID, Role, SharePointType, tenantFilter*, URL, user
- `POST /api/ExecSetSiteProperties` — `Sharepoint.Site.ReadWrite`
  Sets admin-level properties on a single SharePoint site (sharing, lifecycle, version policy) through Set-CIPPSPOSite. Only whitelisted properties are accepted; enum values arrive as friendly names (matching Invoke-Lis... body: LockState {label, value}, SiteUrl*, tenantFilter*
- `POST /api/ExecSetSiteProperty` — `Sharepoint.Site.ReadWrite`
  body: AnonymousLinkExpirationInDays, DefaultLinkPermission, DefaultSharingLinkType, DisplayName, LockState, RestrictedAccessControl, SharingCapability, SiteId*, StorageMaximumLevelGB, StorageWarningLevelGB, tenantFilter*
- `POST /api/ExecSharePointImageOptimize` — `Sharepoint.Site.ReadWrite`
  Scanning and compressing a document library can take far longer than the ~230s Azure HTTP gateway window, so the work is queued for background processing and the caller polls Invoke-ListImageOptimizerResults (by Queue... query: tenantFilter* body: DriveId, FolderId, FolderPath, IncludeSubfolders, JpegQuality, LibraryName, MaxFiles, MinimumFileSizeMB, MinimumSavingsPercent, Mode, SiteId, SiteUrl, StripMetadata, TenantFilter*, VersionCleanupMode, WhatIf
- `POST /api/ExecSharePointImageVersionCleanup` — `Sharepoint.Site.ReadWrite`
  Deletes old versions of the supplied drive items, keeping the current version. Intended for use after a successful compression run when the admin wants to reclaim storage held by version history. WhatIf defaults to $t... query: tenantFilter* body: CleanupMode, DriveId, DriveItemId, Files, SiteId, SiteUrl, TenantFilter*, WhatIf
- `POST /api/ExecSharePointInviteGuest` — `Sharepoint.Site.ReadWrite`
  body: displayName, groupId, mail, redirectUri, sendInvite, SharePointType, TeamID, tenantFilter*, URL
- `POST /api/ExecSharePointMemberAudit` — `Sharepoint.Site.ReadWrite`
  body: action, drivePermissionId, groupId*, issues [object], repairType, sharePointType, siteId, siteUrl*, tenantFilter*, userEmail, userId
- `POST /api/ExecSharePointPerms` — `Sharepoint.Site.ReadWrite`
  body: onedriveAccessUser, RemovePermission, tenantFilter*, UPN, URL, user
- `POST /api/ExecSharePointTemplate` — `Sharepoint.Admin.ReadWrite`
  Saves, retrieves, deletes and deploys SharePoint provisioning templates. A template holds one or more site templates, each with its own document libraries and permission grants. query: Action, DeploymentId*, TemplateId body: Action, DeploymentId, SiteOwner*, siteTemplates [object], TemplateId, templateName, tenantFilter*
- `POST /api/ExecSharingTroubleshoot` — `Sharepoint.Site.Read`
  body: resourceType, resourceUrl, tenantFilter*, userEmail
- `POST /api/ExecSiteBrowserActions` — `Sharepoint.Site.ReadWrite`
  Mutating / operational actions for the SharePoint site browser (non-permissions). Body.Action selects the operation. SiteUrl + tenantFilter are always required. Version cleanup: StartVersionCleanup, GetVersionCleanupS... body: Action*, BatchDeleteMode {label, value}, DeleteOlderThanDays, MajorVersionLimit, MajorWithMinorVersionsLimit, SiteId, SiteUrl, SyncListPolicy, tenantFilter*
- `POST /api/ExecSiteBrowserLibraryCopy` — `Sharepoint.Site.ReadWrite`
  Starts or preflights a SharePoint document library content copy (CreateCopyJobs + MoveButKeepSource). Actions: PreflightLibraryCopy, StartLibraryCopy. query: Action body: Action*, DestLibraryName, DestListId, DestSiteId, DestSiteName, DestSiteUrl, NameConflictBehavior, SourceLibraryName, SourceListId, SourceSiteId, SourceSiteName, SourceSiteUrl, tenantFilter*
- `POST /api/ExecSiteBrowserPermissions` — `Sharepoint.Site.ReadWrite`
  Mutating actions for the SharePoint site browser permissions dialog. Body.Action selects the operation. SiteUrl + tenantFilter are always required. ListId scopes library actions; omit it for the site root web. Sharing... body: Action*, ClearSubscopes, CopyRoleAssignments, GroupId*, GroupName, Groups, LibraryName, ListId*, PermissionId*, PermissionLevel {label, value}, PrincipalId*, PrincipalName, RoleDefinitionId {label, value}, SiteId*, SiteUrl*, tenantFilter*, Title, userPrincipalName, Users
- `POST /api/ExecSiteRename` — `Sharepoint.Site.ReadWrite`
  body: DisplayName, NewTitle, NewUrl, SiteId*, SiteUrl*, tenantFilter*
- `POST /api/ExecTeamAction` — `Teams.Group.ReadWrite`
  query: TeamID, tenantFilter* body: Action, AppInstallationID*, AppName, ChannelDescription, ChannelID*, ChannelName*, ChannelOwnerID* {label, value}, ChannelRole {label, value}, ChannelType, CloneDescription, CloneDisplayName, CloneVisibility, DisplayName, MemberName, MembershipID*, NewRole*, TeamID, TenantFilter*, UserID* {label, value}
- `POST /api/ExecTeamFromGroup` — `Teams.Group.ReadWrite`
  query: SiteId, tenantFilter* body: DisplayName, SiteId*, TenantFilter*
- `POST /api/ExecTeamMember` — `Teams.Group.ReadWrite`
  query: TeamID, tenantFilter* body: Action, DisplayName, MembershipID {label, value}, Role, TeamID, TenantFilter*, UserID {label, value}
- `POST /api/ExecTeamSettings` — `Teams.Group.ReadWrite`
  query: TeamID, tenantFilter* body: description, DisplayName, giphyContentRating {label, value}, TeamID, TenantFilter*, visibility {label, value}
- `POST /api/ExecTeamsVoicePhoneNumberAssignment` — `Teams.Voice.ReadWrite`
  body: input {label, value}, locationOnly, PhoneNumber, PhoneNumberType, TenantFilter*
- `POST /api/ExecTempFileCleanup` — `Sharepoint.Site.ReadWrite`
  body: files, tenantFilter*
- `POST /api/ExecTempFileScan` — `Sharepoint.Site.ReadWrite`
  body: filters, scope*, siteId, tenantFilter*, userId
- `POST /api/ExecValidateExternalDomain` — `Sharepoint.Site.Read`
  query: context, email, tenantFilter* body: context, email, tenantFilter*
- `POST /api/ExecZipFiles` — `Sharepoint.Site.ReadWrite`
  query: tenantFilter* body: DestinationFolderId, DestinationSiteId, DestinationUserId, Items [object], TenantFilter*, ZipFileName
- `GET /api/ListDeletedSites` — `Sharepoint.Site.Read`
  Lists deleted SharePoint sites still restorable from the tenant recycle bin, via the SharePoint admin CSOM API. query: tenantFilter*
- `GET /api/ListHubSites` — `Sharepoint.Site.Read`
  query: tenantFilter*
- `POST /api/ListImageOptimizerResults` — `Sharepoint.Site.ReadWrite`
  Companion to Invoke-ExecSharePointImageOptimize. Returns Status 'Running' while the background worker is still processing, and the full optimizer result object once the job has completed (or an error message if it fai... query: queueId*, Reference, tenantFilter*
- `GET /api/ListOneDriveFiles` — `Sharepoint.Site.Read`
  query: DriveId*, FolderId, SiteId, tenantFilter*, UserId
- `GET /api/ListOneDriveSharing` — `Sharepoint.Site.Read`
  query: DriveId*, SiteId, tenantFilter*
- `GET /api/ListSPOVersionCleanup` — `Sharepoint.Site.Read`
  Reports the file version history cleanup status for a SharePoint site, given its SiteUrl. Shows whether a trim job is configured or running and what it has reclaimed. query: SiteUrl, tenantFilter*
- `GET /api/ListSharePointDocumentLibraries` — `Sharepoint.Site.Read`
  query: SiteId*, tenantFilter*
- `GET /api/ListSharePointExternalUsers` — `Sharepoint.Site.Read`
  Lists external/guest users known to SharePoint from two sources: the tenant external users store (populated when a guest first redeems a share) and a sweep of every site's user list (which also catches guests who were... query: tenantFilter*
- `GET /api/ListSharePointFolders` — `Sharepoint.Site.Read`
  Accepts a SiteId and optional DriveId (document library). When DriveId is omitted the default document library for the site is used. Returns folder items with their id and library-relative path so callers can scope a... query: DriveId, SiteId, tenantFilter*
- `GET /api/ListSharePointImageCandidates` — `Sharepoint.Site.Read`
  Returns the SharePoint Image Optimizer result object in Audit mode. No files are modified and no versions are deleted. Accepts parameters from either the query string or the request body so it can be called as a GET (... query: DriveId, FolderId, FolderPath, IncludeSubfolders, LibraryName, MaxFiles, MinimumFileSizeMB, SiteId, SiteUrl, tenantFilter*
- `GET /api/ListSharePointPermissions` — `Sharepoint.Site.Read`
  Compiles the SharePoint permissions report for a tenant from CACHED data in the CIPP reporting database (SharePointPermissions). No live enumeration is performed - refresh the data by syncing that cache (ExecCIPPDBCac... query: tenantFilter*
- `GET /api/ListSharePointSharing` — `Sharepoint.Site.Read`
  Compiles the SharePoint & OneDrive sharing report for a tenant from CACHED data in the CIPP reporting database (SharePointSharingLinks, SharePointSiteUsage, OneDriveUsage). No live Graph enumeration is performed - ref... query: tenantFilter*
- `GET /api/ListSharePointTemplates` — `Sharepoint.Admin.Read`
  Lists saved SharePoint provisioning templates (site templates and their document libraries).
- `GET /api/ListSharepointAdminUrl` — `CIPP.Core.Read`
  Retrieves the SharePoint Admin Center URL for a tenant and redirects to it. Pass ReturnUrl to get the URL back as JSON instead of being redirected.  The URL cannot be derived from the tenant name - it has to be resolv... query: ReturnUrl, tenantFilter*
- `GET /api/ListSharepointQuota` — `Sharepoint.Admin.Read`
  query: live, tenantFilter*
- `GET /api/ListSharepointSettings` — `Sharepoint.Admin.Read`
  query: tenantFilter*
- `GET /api/ListSiteActivity` — `Sharepoint.Site.Read`
  Lists cached site activity rows from the CIPP reporting database for SharePoint and Teams sites. Supports tenantFilter and optional Type filter (SharePoint or TeamsSite). query: siteId, tenantFilter*, Type
- `GET /api/ListSiteBrowser` — `Sharepoint.Site.Read`
  SharePoint site browser listing (sites only — not OneDrive). Root: Get-CIPPSPOAdminListData (SPO.Tenant/RenderAdminListData, Active sites catalog) — StorageUsed / NumOfFiles / TemplateName in one paged call. Graph get... query: SiteId, SiteUrl, tenantFilter*
- `GET /api/ListSiteBrowserLibraryCopy` — `Sharepoint.Site.Read`
  Returns sanitized aggregate status for a SharePoint library copy operation (OperationId). query: OperationId, tenantFilter*
- `GET /api/ListSiteBrowserPermissions` — `Sharepoint.Site.Read`
  Extensive permission inventory for a SharePoint site or library for the site browser. Collects SPO site admins, associated Owners/Members/Visitors (with members), all site groups (with members), web/library role assig... query: ListId, SiteId*, SiteUrl*, tenantFilter*
- `GET /api/ListSiteLibraries` — `Sharepoint.Site.Read`
  Lists the visible document libraries of a SharePoint site via the Graph API. The site can be addressed by SiteId or by SiteUrl (hostname:path addressing). Returns the SharePoint list GUID as Id so the result can be us... query: SiteId, SiteUrl, tenantFilter*
- `GET /api/ListSiteLiveStorage` — `Sharepoint.Site.Read`
  query: SiteId*, tenantFilter*
- `GET /api/ListSiteMembers` — `Sharepoint.Site.Read`
  Lists the actual membership of a SharePoint site: the users in the site's associated Owners/Members/Visitors role groups via the SharePoint REST API with certificate authentication, plus site collection admins. On gro... query: Filter, SiteId, SiteUrl, tenantFilter*
- `GET /api/ListSitePermissions` — `Sharepoint.Site.Read`
  Lists the permissions of a SharePoint scope via the SharePoint REST API with certificate authentication: the inheritance state plus every role assignment, flattened to one row per principal and permission level. Suppl... query: ListId, SiteUrl*, tenantFilter*
- `GET /api/ListSiteProperties` — `Sharepoint.Site.Read`
  Returns a single site's admin-level properties (sharing, lifecycle and version policy) via the SharePoint admin CSOM API, with enum values translated to friendly names so the Edit Site form can consume and round-trip... query: SiteUrl*, tenantFilter*
- `GET /api/ListSiteRecycleBin` — `Sharepoint.SiteRecycleBin.Read`
  Lists the contents of a SharePoint site's recycle bin (first and second stage) via the SharePoint REST API with certificate authentication. query: SiteUrl*, tenantFilter*
- `GET /api/ListSiteRecycleBinSummary` — `Sharepoint.SiteRecycleBin.Read`
  Aggregate recycle bin sizes for a site (counts + bytes by stage). Never returns item titles, leaf names, or paths — storage-report privacy ceiling. query: MaxItems, SiteUrl*, tenantFilter*
- `GET /api/ListSiteRoleDefinitions` — `Sharepoint.Site.Read`
  Lists the permission levels defined on a SharePoint site via the SharePoint REST API with certificate authentication. Reading them from the site rather than assuming the five built-ins means custom permission levels a... query: IncludeUnassignable, SiteUrl*, tenantFilter*
- `GET /api/ListSiteStorageComposition` — `Sharepoint.Site.Read`
  Site-level storage composition at library ceiling: tip / previous-version estimate / recycle estimate from root web StorageMetrics + site StorageUsed. No file names. query: SiteUrl*, tenantFilter*
- `GET /api/ListSiteUserAccess` — `Sharepoint.Site.Read`
  Explains how one user can reach a SharePoint site or document library: every route that grants them access, and the permission level each route carries. This is the effective access answer that the permission lists ca... query: ListId, SiteUrl*, tenantFilter*, UserPrincipalName*
- `GET /api/ListSites` — `Sharepoint.Site.Read`
  Lists SharePoint sites or OneDrive usage for a tenant. Requires a Type parameter (SharePointSiteUsage or OneDriveUsageAccount). SharePoint live data uses SPO admin RLD plus Graph enrichment; OneDrive live data uses Gr... query: tenantFilter*, Type, URLOnly, UseReportDB
- `GET /api/ListStorageCleanupScan` — `Sharepoint.Site.Read`
  Reads the hold-only StorageCleanupScan CIPPDB cache and rebuilds the scans map expected by the storage report cleanup opportunity helpers. No live enumeration — refresh via ExecCIPPDBCache Name=StorageCleanupScan. Rep... query: tenantFilter*
- `GET /api/ListTeams` — `Teams.Group.Read`
  query: ID, tenantFilter*, type
- `GET /api/ListTeamsActivity` — `Teams.Activity.Read`
  query: tenantFilter*, Type
- `GET /api/ListTeamsAutoAttendants` — `Teams.Voice.Read`
  query: tenantFilter*
- `GET /api/ListTeamsCallQueues` — `Teams.Voice.Read`
  query: tenantFilter*
- `GET /api/ListTeamsDialPlans` — `Teams.Voice.Read`
  query: tenantFilter*
- `GET /api/ListTeamsLisLocation` — `Teams.Voice.Read`
  Lists Teams emergency calling Location Information Service (LIS) locations configured for a tenant. query: tenantFilter*
- `GET /api/ListTeamsSettings` — `Teams.Group.Read`
  query: tenantFilter*
- `GET /api/ListTeamsVoice` — `Teams.Voice.Read`
  Lists Microsoft Teams voice and PSTN usage for a tenant. Supports UseReportDB=true query parameter to retrieve cached data from the reporting database for significantly better performance, especially when querying All... query: tenantFilter*, UseReportDB
- `POST /api/ListTempFileScanResults` — `Sharepoint.Site.ReadWrite`
  query: queueId*, Reference, tenantFilter*

### Tenant > AI

- `POST /api/ExecCopilotSettings` — `Tenant.AI.ReadWrite`
  Sets a single Microsoft 365 Copilot policy setting to Enabled (1), Disabled (0) or Not configured (cleared). query: tenantFilter* body: settingId {label, value}, tenantFilter*, value {label, value}
- `POST /api/ExecGetShadowAIReportPdf` — `Tenant.AI.Read`
  Server-renders the Shadow AI report as application/pdf bytes. Gathers the same shaped data the Shadow AI page uses (ListShadowAI) and composes it through the shared CIPPSharp component kit (Build-CippShadowAIReportTre... query: tenantFilter* body: sectionConfig [string], tenantFilter*
- `POST /api/ExecShadowAISanction` — `Tenant.AI.ReadWrite`
  Marks an AI tool from the Shadow AI catalog as company sanctioned for a tenant, or removes that status. Sanctioned tools are stored per tenant in the ShadowAIConfig table and are reported by ListShadowAI with risk 'In... query: tenantFilter* body: Action, tenantFilter*, Tool, Tools
- `GET /api/ListAgent365PackageDetail` — `Tenant.AI.Read`
  Gets the full detail for a single Microsoft Agent 365 / Copilot package by id, including the allowedUsersAndGroups, acquireUsersAndGroups and elementDetails that the list endpoint omits. Uses delegated auth: this call... query: id, tenantFilter*
- `GET /api/ListAgent365Packages` — `Tenant.AI.Read`
  Lists Microsoft Agent 365 / Copilot packages (agents and Microsoft 365 apps) in the tenant catalog via the Package Management API. Requires a Microsoft Agent 365 license on the tenant. Uses delegated auth: the Package... query: Filter, tenantFilter*
- `GET /api/ListCopilotSettings` — `Tenant.AI.Read`
  Lists the Microsoft 365 Copilot admin policy settings for a tenant, one row per setting, with the current raw value and a friendly state (Enabled / Disabled / Not configured). query: tenantFilter*
- `GET /api/ListCopilotUsage` — `Tenant.AI.Read`
  Returns Microsoft 365 Copilot usage reports for a tenant, flattened into table rows. Type=Adoption  -> getMicrosoft365CopilotUserCountSummary (per-product enabled vs active users) Type=Trend     -> getMicrosoft365Copi... query: period, tenantFilter*, Type
- `GET /api/ListShadowAI` — `Tenant.AI.Read`
  Compiles a Shadow AI overview for a tenant by matching CACHED data from the CIPP reporting database (DetectedApps, ServicePrincipals, OAuth2PermissionGrants) against the curated AI catalog (Config/ShadowAI.json). No l... query: tenantFilter*

### Tenant > Administration > Alerts

- `POST /api/AddAlert` — `CIPP.Alert.ReadWrite`
  body: actions, AlertComment, becActions [{label, value}], conditions [object], CustomSubject, excludedTenants, logbook {label, value}, PsaTicketPriority {label, value}, RowKey, tenantFilter* [string]
- `POST /api/AddScriptedAlert` — `CIPP.Alert.ReadWrite`
  Creates or updates a scripted CIPP alert, stored as a hidden scheduled task.  A selection of two or more tenants or groups is stored verbatim and expanded on every run, so tenant group membership is always current. body: excludedTenants, tenantFilter* [string]
- `POST /api/ExecAuditLogSearch` — `Tenant.Alert.ReadWrite`
  query: Action, SearchId, tenantFilter* body: Action, EndTime, SearchId, StartTime, tenantFilter*
- `POST /api/ExecScheduleAuditExclusionVacation` — `CIPP.Alert.ReadWrite`
  Adds the selected users to the audit log location alert exclusion list at the start date and removes them again at the end date, so location-based alerts do not fire while they travel. Works on its own and does not re... body: endDate, postExecution, reference, startDate, tenantFilter*, Users
- `POST /api/ExecToggleAlert` — `CIPP.Alert.ReadWrite`
  Enables or disables an alert rule without deleting it. Works for both audit log alerts and scheduled alert tasks. query: Disabled, EventType, ID body: Disabled, EventType, ID
- `GET /api/ListAlertsQueue` — `CIPP.Alert.Read`
- `GET /api/ListAuditLogCoverage` — `Tenant.Alert.Read`
  Lists the V2 audit-log coverage ledger (AuditLogCoverage) - one row per tenant + 60-minute search window with its state (Planned / Created / Downloaded / Retry / DeadLetter / Skipped), record count, attempts and last... query: EndDate, RelativeTime, StartDate, tenantFilter
- `GET /api/ListAuditLogSearches` — `Tenant.Alert.Read`
  Lists or creates Microsoft 365 Unified Audit Log searches for a tenant, with support for retrieving search results. query: Days, SearchId, tenantFilter*, Type
- `GET /api/ListAuditLogTest` — `Tenant.Alert.Read`
  Tests audit log webhook rules against a specific search to validate rule matching and alert triggering. query: SearchId, TenantFilter
- `GET /api/ListAuditLogs` — `CIPP.Alert.Read`
  Lists audit log entries from the CIPP audit log store, filterable by tenant, date range, and log ID. query: EndDate, LogId, RelativeTime, StartDate, tenantFilter*
- `GET /api/ListPendingWebhooks` — `CIPP.Alert.Read`
- `GET /api/ListWebhookAlert` — `CIPP.Alert.Read`
  Lists configured webhook alert rules that trigger on specific audit log events.
- `POST /api/PublicWebhooks` — `Public`
  query: CIPPID, Type, validationCode, ValidationToken body: validationCode, value
- `POST /api/RemoveQueuedAlert` — `CIPP.Alert.ReadWrite`
  query: EventType, ID body: EventType, ID
- `POST /api/RemoveWebhookAlert` — `CIPP.Alert.ReadWrite`
  query: ID, tenantFilter*

### Tenant > Administration > Application Approval

- `POST /api/ExecAddMultiTenantApp` — `Tenant.Application.ReadWrite`
  body: AppId, configMode, CopyPermissions, permissions [object], selectedTemplate, tenantFilter* {label, value}
- `GET /api/ExecAppApproval` — `Tenant.Application.Read`
  Builds an admin consent URL for every tenant, for the given ApplicationId or the CIPP-SAM application by default. Returns the links only; nothing is granted until someone opens one and consents. query: ApplicationId
- `POST /api/ExecAppApprovalTemplate` — `Tenant.Application.ReadWrite`
  query: Action, TemplateId body: Action, ApplicationManifest, AppType, TemplateId, TemplateName
- `POST /api/ExecAppPermissionTemplate` — `Tenant.ApplicationTemplates.ReadWrite`
  query: Action, TemplateId body: Action, Permissions, TemplateId, TemplateName
- `POST /api/ExecApplication` — `Tenant.Application.ReadWrite`
  query: Action, AppId*, Id*, tenantFilter*, Type body: Action, AppId, DisplayName, EndDateTime, Id, KeyIds {label, value}, Payload, tenantFilter*, Thumbprint {label, value}, Type
- `POST /api/ExecCreateAppTemplate` — `Tenant.Application.ReadWrite`
  body: AppId*, DisplayName*, Overwrite, TenantFilter*, Type
- `POST /api/ExecManageAppCredentials` — `Tenant.Application.ReadWrite`
  body: Action, AppId, AppType, CredentialType, DisplayName, EndDateTime, ExpiryDate, ExpiryMonths {label, value}, Id, KeyId, tenantFilter*
- `GET /api/ListAppApprovalTemplates` — `Tenant.Application.Read`
  Lists saved application approval templates for standardized app consent configurations.
- `GET /api/ListAppConsentRequests` — `Tenant.Administration.Read`
  Lists pending application consent requests in a tenant, filterable by request status. query: Filter, RequestStatus, tenantFilter*

### Tenant > Administration > Domains

- `POST /api/AddDomain` — `Tenant.Administration.ReadWrite`
  body: domain*, tenantFilter*
- `POST /api/ExecDomainAction` — `Tenant.Administration.ReadWrite`
  body: Action*, domain*, tenantFilter*
- `GET /api/ListDomains` — `Tenant.Administration.Read`
  Lists verified domains for a tenant, showing default and initial domain status. query: tenantFilter*

### Tenant > Administration > Integration Templates

- `POST /api/ExecDeleteIntegrationApp` — `Tenant.Application.ReadWrite`
  body: appId, appObjectId, tenantFilter*
- `POST /api/ExecDeployIntegrationApp` — `Tenant.Application.ReadWrite`
  body: customizations, templateId*, tenants [{label, value}]
- `POST /api/ExecIntegrationTemplate` — `Tenant.Application.ReadWrite`
  query: action, id body: action, appNamePattern, description, documentationUrl, generateSecret, id*, name*, permissions [string], redirectUris, secretExpirationDays
- `GET /api/ListIntegrationAppStatus` — `Tenant.Application.Read`
  query: templateId
- `POST /api/ListIntegrationAppStatus` — `Tenant.Application.Read`
  query: templateId body: templateId*, tenants [{label, value}]
- `GET /api/ListIntegrationDeployments` — `Tenant.Application.Read`
  query: deploymentId
- `GET /api/ListIntegrationTemplates` — `Tenant.Application.Read`
  query: id

### Tenant > Administration > Tenant

- `POST /api/AddTenant` — `Tenant.Config.ReadWrite`
  query: Action, TenantName body: Action, AddressLine1, AddressLine2, City, CompanyName, Country, Email, FirstName, LastName, PhoneNumber, PostalCode, State, TenantName
- `POST /api/EditTenant` — `Tenant.Config.ReadWrite`
  body: customerId, tenantAlias, tenantGroups [object]
- `POST /api/EditTenantOffboardingDefaults` — `Tenant.Config.ReadWrite`
  body: customerId, defaultDomainName, offboardingDefaults
- `POST /api/EditTenantVacationDefaults` — `Tenant.Config.ReadWrite`
  body: customerId, defaultDomainName, vacationDefaults
- `POST /api/ExecAddSPN` — `Tenant.Administration.ReadWrite`
- `POST /api/ExecOffboardTenant` — `Tenant.Administration.ReadWrite`
  body: RemoveCSPGuestUsers, RemoveCSPnotificationContacts, RemoveDomainAnalyserData, RemoveMultitenantCSPApps, RemoveQuarantineAlert, TenantFilter* {label, value}, TerminateContract, TerminateGDAP, vendorApplications [{label, value}]
- `POST /api/ExecOnboardTenant` — `Tenant.Administration.ReadWrite`
  body: addMissingGroups, autoMapRoles, Cancel, gdapRoles, id, ignoreMissingRoles, Retry, standardsExcludeAllTenants, tenantGroups
- `POST /api/ExecRegistrationCampaign` — `Tenant.Administration.ReadWrite`
  body: enforceRegistrationAfterAllowedSnoozes, excludeGroups, excludeUsers, includeAllUsers, includeGroups, includeUsers, snoozeDurationInDays, state {label, value}, targetedAuthenticationMethod {label, value}, tenantFilter* {label, value}
- `POST /api/ExecSendOrgMessage` — `Tenant.Directory.ReadWrite`
  query: freq, ID, tenantFilter*, type, URL
- `POST /api/ExecUpdateSecureScore` — `Tenant.Administration.ReadWrite`
  body: ControlName, reason, resolutionType {label, value}, TenantFilter*, vendorInformation
- `GET /api/ListExternalTenantInfo` — `CIPP.Core.Read`
  Looks up publicly available tenant information for an external Entra ID tenant by domain or tenant ID. query: tenant
- `POST /api/ListOffboardTenants` — `Tenant.Administration.ReadWrite`
  Lists tenants available for offboarding, including tenants in error state.
- `GET /api/ListOrg` — `CIPP.Core.Read`
  Retrieves the Entra ID organization profile for a tenant, including display name, addresses, and tenant metadata. query: tenantFilter*
- `GET /api/ListPartnerRelationships` — `Tenant.Relationship.Read`
  Lists cross-tenant access policy partner configurations for a tenant, showing delegated admin and collaboration settings. query: tenantFilter*
- `GET /api/ListResellerRelationshipLink` — `Tenant.Relationship.Read`
  Retrieves the indirect reseller relationship invitation link from Partner Center for onboarding new customer tenants.
- `GET /api/ListTenantDetails` — `CIPP.Core.Read`
  Retrieves detailed organization information for a tenant, including addresses, assigned plans, sync status, and custom properties. query: tenantFilter*
- `GET /api/ListTenantOnboarding` — `Tenant.Administration.Read`
  Lists tenant onboarding requests and their step-by-step progress, including GDAP relationship setup.
- `GET /api/ListTenants` — `CIPP.Core.Read`
  Lists all managed tenants accessible to the current user, with support for cache clearing and tenant filtering. This is the primary endpoint for tenant enumeration. Pass Search for a fuzzy, case-insensitive substring... query: AllTenantSelector, IncludeOffboardingDefaults, IncludeTenantDefaults, Mode, Search, TenantFilter, TriggerRefresh
- `POST /api/ListTenants` — `CIPP.Core.Read`
  Lists all managed tenants accessible to the current user, with support for cache clearing and tenant filtering. This is the primary endpoint for tenant enumeration. Pass Search for a fuzzy, case-insensitive substring... query: AllTenantSelector, IncludeOffboardingDefaults, IncludeTenantDefaults, Mode, Search, TenantFilter, TriggerRefresh body: ClearCache, TenantsOnly
- `GET /api/ListUsersAndGroups` — `Tenant.Directory.Read`
  Lists both users and groups for a tenant in a single batch call, returning ID and display name for selection/lookup purposes. query: tenantFilter*
- `POST /api/RemoveTenantCapabilitiesCache` — `Tenant.Administration.ReadWrite`
  query: defaultDomainName body: defaultDomainName*
- `POST /api/SetAuthMethod` — `Tenant.Administration.ReadWrite`
  body: GroupIds, Id, state, tenantFilter*

### Tenant > Conditional

- `POST /api/AddCAPolicy` — `Tenant.ConditionalAccess.ReadWrite`
  body: CreateGroups, DisableSD, NewState, overwrite, RawJSON, replacename, tenantFilter* {label, value}
- `POST /api/AddCATemplate` — `Tenant.ConditionalAccess.ReadWrite`
  body: conditions, name, tenantFilter*
- `POST /api/AddNamedLocation` — `Tenant.ConditionalAccess.ReadWrite`
  body: Countries {label, value}, includeUnknownCountriesAndRegions, Ips, policyName, selectedTenants {label, value}, Trusted, Type
- `POST /api/EditCAPolicy` — `Tenant.ConditionalAccess.ReadWrite`
  query: GUID, newDisplayName, State, tenantFilter* body: GUID, newDisplayName, State, tenantFilter*
- `POST /api/ExecCAExclusion` — `Tenant.ConditionalAccess.ReadWrite`
  body: CreateTravelPolicy, EndDate, excludeLocationAuditAlerts, ExclusionType, PolicyId, postExecution, reference, StartDate, tenantFilter*, TravelCountries {label, value}, UserID, Username, Users, vacation
- `POST /api/ExecCAServiceExclusion` — `Tenant.ConditionalAccess.ReadWrite`
  query: GUID, tenantFilter* body: GUID, tenantFilter*
- `POST /api/ExecCaCheck` — `Tenant.ConditionalAccess.Read`
  Runs a Conditional Access "what if" evaluation, reporting which policies would apply to a sign-in with the given user, application, device platform, device compliance, location, client app type, authentication flow an... body: authenticationFlow {label, value}, ClientAppType {label, value}, Country {label, value}, DeviceCompliant {label, value}, DevicePlatform {label, value}, IncludeApplications [{label, value}], InsiderRiskLevel {label, value}, IpAddress, SignInRiskLevel {label, value}, tenantFilter*, userID {label, value}, UserRiskLevel {label, value}
- `POST /api/ExecCreateCATemplate` — `Tenant.ConditionalAccess.ReadWrite`
  body: displayName*, name
- `POST /api/ExecEditCAPolicyFull` — `Tenant.ConditionalAccess.ReadWrite`
  query: PolicyId*, tenantFilter* body: PolicyBody*, PolicyId, tenantFilter*
- `POST /api/ExecNamedLocation` — `Tenant.ConditionalAccess.ReadWrite`
  query: change, input, namedLocationId, tenantFilter body: change, input {label, value}, namedLocationId, tenantFilter
- `GET /api/ListCAPolicyCoverage` — `Tenant.ConditionalAccess.Read`
  Resolves identity assignment coverage for a single Conditional Access policy: which users are touched by includes or exclusions, their net status (covered or excluded), and why (users, transitive groups, roles, guests... query: GUID, id, tenantFilter*
- `GET /api/ListCAtemplates` — `Tenant.ConditionalAccess.Read`
  Lists saved Conditional Access policy templates for deploying standardized CA configurations. query: guid, id, mode
- `GET /api/ListConditionalAccessPolicies` — `Tenant.ConditionalAccess.Read`
  Lists Conditional Access policies for a tenant with resolved display names for users, groups, applications, and locations. When manualPagination is set on an AllTenants read, one page is returned per request with a co... query: manualPagination, nextLink, PageSize, tenantFilter*
- `GET /api/ListConditionalAccessPolicyChanges` — `Tenant.ConditionalAccess.Read`
  Lists audit log entries showing changes to a specific Conditional Access policy, including before/after values. query: displayName, id, tenantFilter*
- `GET /api/ListNamedLocations` — `Tenant.ConditionalAccess.Read`
  Lists Conditional Access named locations (IP ranges and country-based locations) configured in a tenant. query: tenantFilter*
- `POST /api/RemoveCAPolicy` — `Tenant.ConditionalAccess.ReadWrite`
  query: GUID, tenantFilter* body: GUID, tenantFilter*
- `POST /api/RemoveCATemplate` — `Tenant.ConditionalAccess.ReadWrite`
  query: ID body: ID

### Tenant > CrossTenant

- `POST /api/EditCrossTenantPartner` — `Tenant.CrossTenant.ReadWrite`
  body: automaticUserConsentSettings, b2bCollaborationInbound, b2bCollaborationOutbound, b2bDirectConnectInbound, b2bDirectConnectOutbound, inboundTrust, partnerTenantId*, tenantFilter*
- `POST /api/EditCrossTenantPolicy` — `Tenant.CrossTenant.ReadWrite`
  body: automaticUserConsentSettings, b2bCollaborationInbound, b2bCollaborationOutbound, b2bDirectConnectInbound, b2bDirectConnectOutbound, inboundTrust, tenantFilter*, tenantRestrictions
- `POST /api/EditExternalCollaboration` — `Tenant.CrossTenant.ReadWrite`
  body: allowedToSignUpEmailBasedSubscriptions, allowEmailVerifiedUsersToJoinOrganization, allowInvitesFrom, blockMsnSignIn, domainRestrictions, guestUserRoleId, tenantFilter*
- `POST /api/ExecAddCrossTenantPartner` — `Tenant.CrossTenant.ReadWrite`
  body: automaticUserConsentSettings, b2bCollaborationInbound, b2bCollaborationOutbound, b2bDirectConnectInbound, b2bDirectConnectOutbound, inboundTrust, partnerTenantId*, tenantFilter*
- `POST /api/ExecAddCrossTenantTemplate` — `Tenant.CrossTenant.ReadWrite`
  body: createdAt, description, GUID, settings, templateName*
- `POST /api/ExecApplyCrossTenantTemplate` — `Tenant.CrossTenant.ReadWrite`
  body: GUID*, tenantFilter*
- `POST /api/ExecRemoveCrossTenantPartner` — `Tenant.CrossTenant.ReadWrite`
  query: partnerTenantId, tenantFilter* body: partnerTenantId*, tenantFilter*
- `POST /api/ExecRemoveCrossTenantTemplate` — `Tenant.CrossTenant.ReadWrite`
  query: GUID body: GUID*
- `GET /api/ListCrossTenantHealth` — `Tenant.CrossTenant.Read`
  query: tenantFilter*
- `GET /api/ListCrossTenantPartners` — `Tenant.CrossTenant.Read`
  query: tenantFilter*
- `GET /api/ListCrossTenantPolicy` — `Tenant.CrossTenant.Read`
  query: tenantFilter*
- `GET /api/ListCrossTenantTemplates` — `Tenant.CrossTenant.Read`
- `GET /api/ListExternalCollaboration` — `Tenant.CrossTenant.Read`
  query: tenantFilter*

### Tenant > GDAP

- `POST /api/ExecAddGDAPRole` — `Tenant.Relationship.ReadWrite`
  query: Action body: Action, customSuffix, gdapRoles [object], mappings [object], templateId
- `POST /api/ExecAutoExtendGDAP` — `Tenant.Relationship.ReadWrite`
  query: ID body: ID
- `POST /api/ExecDeleteGDAPRelationship` — `Tenant.Relationship.ReadWrite`
  query: GDAPId body: GDAPId
- `POST /api/ExecDeleteGDAPRoleMapping` — `Tenant.Relationship.ReadWrite`
  query: GroupId body: GroupId
- `POST /api/ExecGDAPAccessAssignment` — `Tenant.Relationship.ReadWrite`
  query: Action, Id body: Action, Id, RoleTemplateId
- `POST /api/ExecGDAPInvite` — `Tenant.Relationship.ReadWrite`
  query: Action body: Action, InviteId, Reference, roleMappings
- `POST /api/ExecGDAPInviteApproved` — `Tenant.Relationship.ReadWrite`
- `POST /api/ExecGDAPRemoveGArole` — `Tenant.Relationship.ReadWrite`
  query: GDAPId body: GDAPId
- `POST /api/ExecGDAPRepairRoleMappings` — `Tenant.Relationship.ReadWrite`
- `POST /api/ExecGDAPRoleTemplate` — `Tenant.Relationship.ReadWrite`
  query: Action, TemplateId body: CustomSuffix, GroupId, NewRoles, OriginalTemplateId, RoleMappings [object], TemplateId
- `GET /api/ListGDAPAccessAssignments` — `Tenant.Relationship.Read`
  Lists GDAP access assignments for a specific delegated admin relationship, including security group members and their role mappings. query: Id
- `GET /api/ListGDAPContracts` — `Tenant.Relationship.Read`
  Lists Microsoft partner contracts (customer tenant relationships) from the Graph API. query: $top
- `GET /api/ListGDAPInvite` — `Tenant.Relationship.Read`
  Lists GDAP relationship invitations and their role mappings, optionally filtered by relationship ID. query: RelationshipId
- `GET /api/ListGDAPRelationships` — `Tenant.Relationship.Read`
  Lists GDAP delegated admin relationships with customer tenants, with optional filtering by relationship ID or OData filter. query: $filter, $top, id
- `GET /api/ListGDAPRoles` — `Tenant.Relationship.Read`
  Lists the configured GDAP role-to-security-group mappings used for delegated admin access. Pass ?validate=true to annotate each mapping with the state of its partner tenant group. query: validate
- `GET /api/ListGDAPServicePrincipals` — `Tenant.Relationship.Read`
  Lists service principals in a customer tenant owned by the partner or specified vendor tenant IDs, useful for identifying GDAP-related app registrations. query: $top, ownerType, tenantFilter*, vendorTenantIds

### Tenant > Reports

- `POST /api/ExecCSPLicense` — `Tenant.Directory.ReadWrite`
  body: Action, Add, DaysBeforeRenewal, Quantity, Remove, SKU {label, value}, SubscriptionIds, tenantFilter*
- `POST /api/ExecGetLicenseReportPdf` — `Tenant.Directory.Read`
  Server-renders the License Optimisation report as application/pdf bytes. Runs the same license recommendation analysis the License Optimization page reads through ListLicenseRecommendations (Get-CIPPLicenseRecommendat... query: brandingPresetId, currency, inactiveDays, protectSecurityFeatures, recommendDowngrades, recommendTerms, recommendUpgrades, tenantFilter*, tenureMonths body: brandingPresetId, currency, inactiveDays, protectSecurityFeatures, recommendDowngrades, recommendTerms, recommendUpgrades, sections, tenantFilter*, tenureMonths
- `POST /api/ExecLicensePricing` — `Tenant.Directory.ReadWrite`
  Manage MSP-global license price overrides used by the license optimization report. SetPrice upserts a per-SKU monthly price; RemovePrice deletes an override so the SKU falls back to the shipped MSRP estimate. BulkImpo... body: Action*, Currency, MonthlyPrice, Mode, Product_Display_Name, Rows [object], skuId, skuPartNumber
- `GET /api/ListCSPLicenses` — `Tenant.Directory.Read`
  Lists CSP (Cloud Solution Provider) license subscriptions for a tenant via the Sherweb integration. query: tenantFilter*
- `GET /api/ListCSPsku` — `Tenant.Directory.Read`
  Lists available CSP SKUs and current subscriptions for a tenant via the Sherweb integration. query: currentSkuOnly, tenantFilter*
- `GET /api/ListGraphReports` — `Tenant.Reports.Read`
  Retrieves Microsoft 365 usage reports (Graph or Office reports) for a tenant, such as email activity, OneDrive usage, or Teams device usage. query: period, report, tenantFilter*, type
- `GET /api/ListLicenseOptimization` — `Tenant.Directory.Read`
  License cost-optimization report for a tenant: a monetary summary plus reclaim opportunities across five waste tiers (unassigned seats, disabled and inactive licensed accounts, mailbox-only downgrade candidates, and r... query: currency, inactiveDays, tenantFilter*
- `GET /api/ListLicensePricing` — `Tenant.Directory.Read`
  Lists the resolved monthly price for every known license SKU: MSP price overrides merged over the shipped MSRP estimates. Consumed by the license optimization report and its price-management UI. Each row carries a Sou... query: currency
- `GET /api/ListLicenseRecommendations` — `Tenant.Directory.Read`
  License recommendation report for a tenant: the waste tiers from ListLicenseOptimization plus evidence-based downgrade targets (from 90-day usage reports against the license catalog), consolidation and protection upgr... query: currency, inactiveDays, protectSecurityFeatures, recommendDowngrades, recommendTerms, recommendUpgrades, tenantFilter*, tenureMonths
- `GET /api/ListLicenses` — `Tenant.Directory.Read`
  query: IncludeExcluded, tenantFilter*
- `GET /api/ListLicensesReport` — `Tenant.Directory.Read`
  Lists a detailed license overview across all tenants or a single tenant, including SKU breakdowns, costs, and availability. query: QueueId, tenantFilter*
- `GET /api/ListMessageCenterMessages` — `Tenant.Administration.Read`
  Lists Microsoft 365 message center messages for a tenant: the change notices, announcements of new and retiring features, planned changes and action-required posts Microsoft publishes, with category, severity, service... query: tenantFilter*, UseReportDB
- `GET /api/ListOAuthApps` — `Tenant.Application.Read`
  Lists OAuth application consent grants and permissions for a tenant. Supports UseReportDB=true query parameter to retrieve cached data from the reporting database for significantly better performance, especially when... query: tenantFilter*, UseReportDB
- `GET /api/ListSecureScoreReport` — `Tenant.Reports.Read`
  Returns the latest Microsoft Secure Score per tenant from the CIPP reporting database, with no live Graph calls. Reads the nightly cache and projects to the score fields only, so the large controlScores breakdown on e... query: includeHistory, tenantFilter
- `GET /api/ListServiceHealth` — `Tenant.Administration.Read`
  Lists active Microsoft 365 service health issues and advisories for a tenant or all tenants. query: defaultDomainName, displayName, tenantFilter*
- `GET /api/ListServiceHealthIssues` — `Tenant.Administration.Read`
  Lists Microsoft 365 service health issues for a tenant: the incidents and advisories Microsoft has posted about service outages, degradations and their status, impact, affected services and timeline. For AllTenants ea... query: Open, tenantFilter*, UseReportDB
- `GET /api/ListServiceHealthOverviews` — `Tenant.Administration.Read`
  Lists the Microsoft 365 service health overview for a tenant: the current health status of each cloud service (Exchange Online, SharePoint Online, Microsoft Teams, Entra ID, Intune and others), for example serviceOper... query: tenantFilter*, UseReportDB

### Tenant > SecuritySimulations

- `GET /api/ListCAGapAnalysis` — `Tenant.SecuritySimulations.Read`
  Conditional Access gap analysis for one tenant from the cached policies: findings, the persona-by-control coverage matrix and the 1 to 10 posture score. query: tenantFilter*
- `GET /api/ListCASituations` — `Tenant.SecuritySimulations.Read`
  Evaluates every predefined sign-in situation (admin, user and guest personas under unmanaged devices, foreign locations, legacy clients, device-code flow, risk levels and more) live against the tenant's Conditional Ac... query: country, tenantFilter*

### Tenant > Standards

- `POST /api/AddBaseline` — `Tenant.Baselines.ReadWrite`
  Creates or updates a baseline. There is no baseline blob: the Baselines delta rows (design doc §4.1) are the editable source of truth for every standard's configuration, and the BaselineRollouts row (§12.2) holds the... body: alertEmails, alertWebhookUrl, assignedTenants, description, disableAlerts, disableScheduledRuns, excludedTenants [{label, value}], GitHub, GUID, stages [object], templateName
- `POST /api/AddStandardsDeploy` — `Tenant.Standards.ReadWrite`
  body: tenant
- `POST /api/AddStandardsTemplate` — `Tenant.Standards.ReadWrite`
  body: createdAt, excludedTenants, GitHub, GUID, standards, templateName, tenantFilter
- `GET /api/BestPracticeAnalyser_List` — `Tenant.BestPracticeAnalyser.Read`
- `GET /api/DomainAnalyser_List` — `Tenant.DomainAnalyser.Read`
  query: tenantFilter
- `POST /api/ExecBaselineAddStandard` — `Tenant.Baselines.ReadWrite`
  Adds one standard, with its configured settings, to a stage of an existing baseline. The baseline is read with Get-CIPPBaseline, the standard is appended to the stage (replacing an existing single-instance copy) and t... body: alertEnabled, baselineId, remediateEnabled, stage, standard, variables
- `POST /api/ExecBaselineMigrate` — `Tenant.Baselines.ReadWrite`
  Migrates classic StandardsTemplateV2 templates (standards + drift) into baselines. action 'preview' returns the full mapping report without writing; 'commit' migrates the selected templates (all when none selected). r... body: action, addDetectStandards, reportOnly, templateIds
- `POST /api/ExecBaselineOverride` — `Tenant.Baselines.ReadWrite`
  Creates or removes a tenant-scoped delta (design doc §4.1) overriding one standard for one tenant. Presence is the override: the delta's expectedValue (the configured variable values) fully replaces what the baselines... body: action, standard, tenantFilter*, variables
- `POST /api/ExecBaselineRun` — `Tenant.BaselinesRun.ReadWrite`
  Starts an on-demand baseline run directly as a durable orchestration: a full baseline run (templateId), a tenant- or standard-scoped run, a compare (no remediation), or a oneoff (single standard, remediation forced on... body: mode, standard, templateId, tenantFilter* {label, value}
- `POST /api/ExecBaselineStage` — `Tenant.Baselines.ReadWrite`
  Advances a tenant to the next stage of a baseline (manual stage approval), or with action 'evaluate' re-checks the next stage's conditions now instead of waiting for the scheduled run. The tenant receives all standard... body: action, templateId, tenantFilter*
- `POST /api/ExecDomainAnalyser` — `Tenant.DomainAnalyser.ReadWrite`
  body: tenantFilter {label, value}
- `POST /api/ExecDriftClone` — `Tenant.Standards.ReadWrite`
  body: id*
- `POST /api/ExecGetBaselineWhatIfReportPdf` — `Tenant.Baselines.Read`
  Server-renders the Security Baseline report for a tenant as application/pdf bytes: where the assigned baselines stand today, what is already in place, the Conditional Access and Intune policies and the settings the ba... query: brandingPresetId, tenantFilter* body: brandingPresetId, sectionConfig, simulatedTemplateIds [string], tenantFilter*
- `POST /api/ExecGetExecutiveReportPdf` — `Tenant.Standards.Read`
  Server-renders the Executive Summary report as application/pdf bytes. Every figure is read from the nightly Reporting DB cache via New-CIPPDbRequest (Users/Guests/Roles for the environment overview, LicenseOverview, M... query: brandingPresetId, tenantFilter* body: brandingPresetId, sectionConfig, tenantFilter*
- `POST /api/ExecStandardConvert` — `Tenant.Standards.ReadWrite`
- `POST /api/ExecStandardTemplateSchedule` — `Tenant.Standards.ReadWrite`
  query: TemplateId body: runManually, TemplateId
- `POST /api/ExecStandardsRun` — `Tenant.Standards.ReadWrite`
  query: templateId, tenantFilter*
- `POST /api/ExecUpdateBaselineDeviation` — `Tenant.BaselinesDeviations.ReadWrite`
  Triage for baseline drift on a resolved (tenant, standard) row: Accept (reason required, optional expiry, optional remediate-on-expire), Deny (method remediate|delete - the engine remediates on the next run regardless... body: action, expires, method, path*, reason, remediateOnExpire, standard, tenantFilter*
- `POST /api/ExecUpdateDriftDeviation` — `Tenant.Standards.ReadWrite`
  body: deviations [object], persistentDeny, reason, RemoveDriftCustomization, TenantFilter*
- `GET /api/ListBaselineAlignment` — `Tenant.Baselines.Read`
  Baseline alignment data. With ?tenantFilter= returns the tenant payload (summary, resolved rows with history, stage states, deviation feed); with ?tenantFilter=&history=true returns the flattened run-event history; wi... query: byStandard, history, tenantFilter*
- `GET /api/ListBaselineStandards` — `Tenant.Baselines.Read`
  Lists the Baseline definition catalog: the standards available to add to a baseline, including their configurable variables and metadata.
- `GET /api/ListBaselines` — `Tenant.Baselines.Read`
  Lists baselines with their stages, per-stage rollout occupancy, and per-tenant stage states.
- `GET /api/ListDomainAnalyser` — `Tenant.DomainAnalyser.Read`
  Lists domain analysis results (SPF, DKIM, DMARC, DNSSEC) for tenant domains. query: tenantFilter*
- `GET /api/ListDomainHealth` — `Tenant.DomainAnalyser.Read`
  Performs real-time DNS health checks (MX, SPF, DMARC, DKIM, DNSSEC, MTA-STS, HTTPS) for a specific domain. query: Action*, Domain*, ExpectedInclude, ExpectedTarget, Record, Selector, Subdomains
- `GET /api/ListStandards` — `Tenant.Standards.Read`
  Lists configured tenant standards (compliance policies) and their settings, with optional consolidated view. query: ShowConsolidated, tenantFilter*
- `GET /api/ListStandardsCompare` — `Tenant.BestPracticeAnalyser.Read`
  Compares current tenant configuration against applied standards, showing compliance status and drift for each standard. query: templateId, tenantFilter*
- `GET /api/ListStandardsCurrentState` — `Tenant.Standards.Read`
  Lists the current remediation state of standards applied to a specific tenant, including last check results. query: tenantFilter*
- `GET /api/ListTenantAlignment` — `Tenant.Standards.Read`
  Lists tenant alignment data showing how well tenants conform to their assigned standards templates.  Pass summary=true for the estate roll-up only: per-tenant averages collapsed into score buckets, the overall average... query: granular, summary
- `GET /api/ListTenantDrift` — `Tenant.Standards.Read`
  Lists configuration drift for tenants, comparing current state against the desired state defined by applied standards. query: tenantFilter*
- `POST /api/RemoveBaseline` — `Tenant.Baselines.ReadWrite`
  Deletes a baseline with its rollout state, delta rows, and resolved rows - the alignment view reflects the removal immediately. query: ID body: ID*
- `POST /api/RemoveStandard` — `Tenant.Standards.ReadWrite`
  query: ID
- `POST /api/RemoveStandardTemplate` — `Tenant.Standards.ReadWrite`
  query: ID body: ID
- `GET /api/listStandardTemplates` — `Tenant.Standards.Read`
  Lists saved standards templates that define sets of standards to apply to tenants. query: id

### Tenant > Tests

- `POST /api/AddTestReport` — `CIPP.Dashboard.Read`
  body: CustomTests, description, DevicesTests, IdentityTests, name* [string], ReportId
- `POST /api/DeleteTestReport` — `CIPP.Dashboard.Read`
  body: ReportId
- `POST /api/ExecCustomTestRun` — `Tenant.Tests.ReadWrite`
  Re-runs the enabled Custom tests against the most recent cached data for the requested tenant(s) by starting the standard tests orchestration with a Custom-only suite filter. Used by the cross-tenant Custom Test Repor... query: tenantFilter body: tenantFilter
- `POST /api/ExecTestRefresh` — `Tenant.Tests.ReadWrite`
  query: tenantFilter*, testName body: tenantFilter*, testName
- `POST /api/ExecTestRun` — `Tenant.Tests.ReadWrite`
  query: mode, tenantFilter* body: mode, tenantFilter*
- `GET /api/ListAvailableTests` — `CIPP.Dashboard.Read`
  Lists the compliance tests CIPP can run against a tenant, both the built-in framework tests (CIS, CISA, Essential Eight, EIDSCA, ORCA) and any custom PowerShell tests added to this instance. Returns the catalogue of t...
- `GET /api/ListTestReports` — `Tenant.Reports.Read`
- `GET /api/ListTestResultsTenants` — `Tenant.Reports.Read`
  Cross-tenant overview of stored test results. Backed by Get-CIPPTestResultsTenants, which queries the shared CippTestResults table server-side and enriches Custom rows with their definition. Results are filtered to th... query: category, countsOnly, includeCounts, risk, rowStatus, status, summaryOnly, tenantFilter, testId, testType
- `GET /api/ListTests` — `Tenant.Reports.Read`
  query: reportId, summaryOnly, tenantFilter*

### Tenant > Tools

- `POST /api/ExecGraphExplorerPreset` — `CIPP.Core.Read`
  body: action, preset
- `GET /api/ListGraphExplorerPresets` — `CIPP.Core.Read`
  Lists saved Graph Explorer query presets for the current user or shared presets. query: Endpoint

### Tools > Breach-Lookup

- `POST /api/ExecBreachSearch` — `CIPP.BreachLookup.Read`
  Queues a breach search for a tenant against Have I Been Pwned. The search runs as a background job and can take up to 24 hours; this returns as soon as it is queued, not with the results. Read the results with ListBre... body: tenantFilter*
- `GET /api/ListBreachesAccount` — `CIPP.BreachLookup.Read`
  Checks an email account or domain against the Have I Been Pwned (HIBP) breach database. query: account
- `GET /api/ListBreachesTenant` — `CIPP.BreachLookup.Read`
  Lists cached data breach results for user accounts in a tenant from the CIPP breach monitoring cache. query: tenantFilter*

### Tools > Custom-Scripts

- `POST /api/AddCustomScript` — `CIPP.Tests.ReadWrite`
  body: Action, AlertOnFailure, AlertStatuses, Category, Description, Enabled, ImplementationEffort*, MarkdownTemplate, Pillar*, RestoreToVersion, ResultMode, ResultSchema, ReturnType, Risk, ScriptContent*, ScriptGuid*, ScriptName*, UserImpact*
- `POST /api/ExecCustomScript` — `CIPP.Tests.ReadWrite`
  body: Parameters, ScriptGuid*, TenantFilter*
- `GET /api/ListCustomScripts` — `CIPP.Tests.Read`
  Lists custom PowerShell scripts stored in CIPP, with optional filtering by script GUID and version history. query: IncludeAllVersions, ScriptGuid
- `POST /api/RemoveCustomScript` — `CIPP.Tests.ReadWrite`
  query: ScriptGuid* body: ScriptGuid

### Tools > GitHub

- `POST /api/ExecCommunityRepo` — `CIPP.TemplateLibrary.ReadWrite`
  This function makes changes to a community repository in table storage body: Action, Branch, Force, FullName, GUID, Id, Message, Path, TemplateTypes
- `POST /api/ExecGitHubAction` — `CIPP.Extension.ReadWrite`
  Call GitHub API query: Action body: Action
- `GET /api/ListCommunityRepoTemplates` — `CIPP.TemplateLibrary.Read`
  Builds a catalog of templates across community repositories using a single git tree call per repository. Joins against the templates table to flag imported templates and available updates. When a Path is supplied, ret... query: Branch, FullName, Path
- `GET /api/ListCommunityRepos` — `CIPP.TemplateLibrary.Read`
  This function lists community repositories in Table Storage query: WriteAccess
- `GET /api/ListGitHubReleaseNotes` — `CIPP.Core.Read`
  Returns release metadata for the provided repository and semantic version. Hotfix versions (e.g. v8.5.2) map back to the base release tag (v8.5.0).

### Tools > Report-Builder

- `POST /api/ExecGenerateReportBuilderReport` — `CIPP.ReportBuilder.ReadWrite`
  query: TemplateName, tenantFilter* body: Action, Blocks, ReportGUID*, TemplateGUID, TemplateName, TenantFilter*
- `GET /api/ExecGetReportBuilderPdf` — `CIPP.ReportBuilder.Read`
  Returns the server-rendered PDF for a generated Report Builder report as application/pdf bytes. Backs both the in-app preview (shown in an iframe) and the download button on the view page. A report generated before se... query: id*, ReportGUID
- `POST /api/ExecPreviewReportBuilderPdf` — `CIPP.ReportBuilder.ReadWrite`
  Renders the current (unsaved) Report Builder state to a PDF and returns it as application/pdf bytes without persisting a generated-report row. Powers the builder's live preview and download. query: tenantFilter* body: Blocks, Settings, TemplateGUID, TemplateName, TenantFilter*
- `POST /api/ExecReportBuilderTemplate` — `CIPP.ReportBuilder.ReadWrite`
  body: Action, Blocks, GUID*, Name* [string]
- `GET /api/ListBrandingPresets` — `CIPP.Core.Read`
  Lists named report branding presets — colours, logo, cover image, footer and watermark — that a report template can be pointed at instead of the default branding.  Read-only and separate from ExecBrandingSettings on p... query: includeImages
- `GET /api/ListGeneratedReports` — `CIPP.ReportBuilder.Read`
  Lists generated reports from the CIPP Report Builder, filterable by tenant or report GUID. query: ReportGUID, tenantFilter*
- `GET /api/ListReportBuilderTemplates` — `CIPP.ReportBuilder.Read`
  Lists saved Report Builder templates that define custom report configurations with data blocks and formatting.

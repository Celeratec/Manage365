# Azure ARM Reads (#3272074 PR1) Implementation Plan

**Goal:** Pluggable ARM credential provider + hardened client + all PR1 `ListAz*` reads behind `AzureArm` flag.

**Done in this branch:** core modules, allowlist, 20 ListAz + ExecAzArmConfig entrypoints, FeatureFlags, tests, docs, OpenAPI stubs. Deferred: `ListAzWebAppSettingNames`.

**Open items in PR:** confirm Key Vault refs vs Cortalis Secrets injection; live REST-proxy verification deferred (mocks only).

---
name: CIPP HTTP Endpoint Builder
description: >
  Adds or changes HTTP endpoints in backend/Modules/CIPPHTTP (Invoke-List/Add/Edit/Remove/Exec*) and the
  CIPPCore helpers they call, with response shapes and status codes the frontend, MCP and the response cache
  depend on.
---

# CIPP HTTP Endpoint Builder

## Mission

Write or change an HTTP endpoint so that it:

- returns the body shape the frontend expects,
- returns a status code that tells the truth about what happened,
- documents its request contract through code the OpenAPI generator can read.

Status codes are not cosmetic in CIPP:

- **Response cache:** the runtime caches 2xx GET responses (for up to 600 s). An error returned as 200 is cached and served as data.
- **MCP:** the MCP tool layer treats `>= 400` as an error and anything else as a result.
- **Frontend:** the frontend retries and renders based on the status.

---

## Anatomy

```powershell
function Invoke-ExecThing {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Identity.User.ReadWrite
    .DESCRIPTION
        Shown in the generated API docs.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    $Headers = $Request.Headers
    $TenantFilter = $Request.Body.tenantFilter

    if (-not $Request.Body.UserId) {
        return ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{ Results = 'UserId is required' }
            })
    }

    try {
        $Result = Set-CIPPThing -UserId $Request.Body.UserId -TenantFilter $TenantFilter -Headers $Headers
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Result = "Failed to update thing: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Headers -API 'ExecThing' -tenant $TenantFilter -message $Result -Sev 'Error' -LogData $ErrorMessage
        $StatusCode = Get-CippErrorStatusCode -ErrorRecord $_
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = @{ Results = $Result }
        })
}
```

Response bodies:

- **Action endpoints** (`Add`/`Edit`/`Remove`/`Exec`): `Body = @{ Results = ... }`, where `Results` is a string or
  an array of `@{ resultText = '...'; state = 'success' | 'error' }`. Use the same shape for errors. The UI reads
  `Results` from error responses too.
- **List endpoints**: return the array itself: `Body = @($Data)`.
- Mark each per-item result with `state`. If `state` is missing, the UI has to guess severity from the text.

---

## Status codes

| Situation | Status |
| --- | --- |
| Success | `200 OK` (`202 Accepted` when work is queued) |
| Missing or invalid request input, or a request the business rules refuse | `400 BadRequest` |
| A resource the caller named does not exist (template, task, user to act on) | `404 NotFound` |
| A CIPP access check refuses the caller (role, allowed tenants, `Test-CIPPAccess`) | `403 Forbidden` |
| A Graph / Exchange / SharePoint / Azure / table call failed, or anything unexpected | `500 InternalServerError` |
| Several items acted on: all succeeded / some failed / all failed | `200` / `207 MultiStatus` / `500` |

Rules that follow from the table:

- **A catch never returns `OK`.** A failure that becomes "Failed ..." text inside a 200 is a bug.
  `backend/Tests/Static/CatchBlockStatusCode.Tests.ps1` enforces this, with a short allow-list for deliberate fallbacks.
- **403 is only for CIPP's own access checks.** If Microsoft refuses the CIPP app in a customer tenant, that is an
  upstream failure: return 500.
- **Upstream failures return 500, not 400.** The frontend does not retry 4xx, and 400 tells the caller their input was wrong.
- **Validate input before the `try`**, as an early `return` with `BadRequest` (or `NotFound`) inside an `if`. A
  validation `throw` inside the `try` lands in the same catch as upstream failures, so it can't be told apart. The
  OpenAPI generator marks a field required when an `if` body rejects it with `throw` or `BadRequest`, so keep the
  guard as an `if`.
- **Multi-item endpoints** count what they were asked to act on and what failed, then return
  `$StatusCode = Get-CippBulkStatusCode -Total $Total -Failed $Failed`. Use `$Failed++`, never `+=`. Only count real item
  failures. An optional enrichment step that falls back to a default is not a failure. A List endpoint that loops
  tenants follows the same rule: partial data is 207, nothing is 500.
- **Polled status endpoints and protocol endpoints** (JSON-RPC, OAuth token passthrough) can carry an error inside a
  200 when the client depends on that. Leave them that way on purpose, and add them to the guard's allow-list with a reason.

---

## Helpers that endpoints call

A helper must let its caller tell an input problem apart from an upstream failure:

- Throw `[System.ArgumentException]::new('<message>')` for invalid input or a refused request.
- Throw `[System.Management.Automation.ItemNotFoundException]::new('<message>')` for a named resource that does not exist.
- Let upstream failures throw as they are.
- In the endpoint catch, `Get-CippErrorStatusCode -ErrorRecord $_` maps these to 400 / 404 / 500. It also looks inside
  wrapped exceptions, because a script block run through a .NET method surfaces as
  `MethodInvocationException -> RuntimeException -> ArgumentException`.
- A layer between the helper and the endpoint must not catch a typed exception and rethrow it as a string
  (`throw "Failed: $($_.Exception.Message)"`). That loses the type.
- A helper that acts on several items returns one `[pscustomobject]@{ resultText = '...'; state = 'success' | 'error' }`
  per item instead of swallowing failures into strings, so the caller can count them.
- Before changing what a helper returns or throws, read **every** caller. Scheduled and background callers
  (`New-CIPPUserTask`, offboarding tasks, BEC containment, extension syncs) must keep collecting per-step results and
  must not start aborting halfway.

---

## Frontend contract

- `ApiGetCall` / `ApiPostCall` do not retry 4xx (except 408 and 429). They retry 5xx shed responses (503) and do not
  retry 500.
- Multi-row table actions (`CippApiDialog` with `multiPost: false`) send one request per row. A row that returns an
  error is reported as `{ Results: [{ resultText, state: 'error' }] }` and the rest still run. `onResult` gets
  `{ failed: true }` as its second argument for that row.
- `CippApiResults` renders `Results` / `resultText` / `error` from error responses. Axios treats 207 as success, and
  each item's `state` decides how it is shown.
- When you change an endpoint's codes, grep `frontend/src` for `/api/<Name>`. A page that reads data only on success
  needs `isError` handling (`getCippError(x.error)`) if it used to get its error inside a 200.

---

## OpenAPI

`backend/Config/openapi.json` is generated from the entrypoint AST (`build/tools/build-openapi.ps1`):

- Status codes are documented from every `[HttpStatusCode]::X` in the file.
- An endpoint that uses `Get-CippBulkStatusCode` gets 200, 207 and 500.
- Codes that only come from `Get-CippErrorStatusCode` are not visible to the generator. Write the 400/404 guards as
  explicit `[HttpStatusCode]::BadRequest` / `NotFound` returns where you can.
- Ask the maintainer before regenerating the spec.

---

## Tests

- If `backend/Tests/Endpoint/Invoke-<Name>.Tests.ps1` exists, add a case for each status the change introduces.
- Pin a helper's new contract with `Should -Throw -ExceptionType ([System.ArgumentException])`, or by asserting its
  per-item `state` results.
- Always run `Invoke-Pester -Path backend/Tests/Static` (it includes the catch-block guard).

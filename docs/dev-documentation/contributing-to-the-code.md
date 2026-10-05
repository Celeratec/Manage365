# Contributing to the Code

Contributions to CIPP are welcome. The entire project, frontend and backend, lives in a single mono-repository: [CyberDrain/CIPP](https://github.com/CyberDrain/CIPP). The old separate CIPP and CIPP-API repositories are deprecated.

Before writing any code, set up a local development environment by following the guide in [setting-up-for-local-development.md](cipp-dev-guide/setting-up-for-local-development.md "mention").

## Before You Start

- **File an issue.** If you are fixing a bug, file a complete bug report [on GitHub](https://github.com/CyberDrain/CIPP/issues) and assign it to yourself. If you are adding a feature, create an issue with "Feature Request" in the title and assign it to yourself.
- **Understand the repo layout.** Read the [project-structure.md](cipp-dev-guide/project-structure.md "mention") page so you know where frontend pages, backend modules, and tests live.
- **Speed and security** are fundamental pillars of CIPP. If it is not fast, it is not good, and if it is not secure, it is not getting merged.
- **Use native APIs over PowerShell modules.** PowerShell modules slow the entire runtime. The backend currently loads only `Az.Keyvault` and `Az.Accounts` and we prefer to keep it that way.

{% hint style="info" %}
You can assign yourself an issue on GitHub by commenting `I would like to work on this please!` on the issue. You must enter that text verbatim.
{% endhint %}

## Pull Requests

- All pull requests target the **`dev`** branch. The `main` branch is the current release and does not accept direct PRs.
- Use a [Conventional Commits](https://www.conventionalcommits.org/) title, for example `feat(identity): add bulk user offboarding endpoint` or `fix(graph): handle expired token on retry`.
- Keep pull requests focused. A bug fix and a new feature belong in separate PRs.
- When your change alters what a user sees or can do (new fields, columns, buttons, renamed labels, new behaviour), update the matching documentation page in the same PR. See [contributing-to-the-documentation.md](contributing-to-the-documentation.md "mention") for the style guide.

## Function Naming

Every HTTP endpoint handler in `backend/Modules/CIPPHTTP/` must use one of these prefixes:

| Prefix           | Purpose                                         | Example               |
| ---------------- | ----------------------------------------------- | --------------------- |
| `Invoke-List*`   | Returns a list or read-only data (GET)          | `Invoke-ListUsers`    |
| `Invoke-Add*`    | Creates a new object                            | `Invoke-AddUser`      |
| `Invoke-Edit*`   | Modifies an existing object                     | `Invoke-EditUser`     |
| `Invoke-Remove*` | Deletes or removes an object                    | `Invoke-RemoveUser`   |
| `Invoke-Exec*`   | Executes an action (for example, send MFA push) | `Invoke-ExecSendPush` |

The HTTP router in CIPPCore maps the `CIPPEndpoint` route parameter to `Invoke-{CIPPEndpoint}`, so the function name is exactly what appears in the URL.

## Backend Guidelines

- **Always pass `-tenantid`** to `New-GraphGetRequest`, `New-GraphPOSTRequest`, `New-GraphBulkRequest`, and `New-ExoRequest`. Omitting it hits the partner tenant instead of the customer.
- Backend modules under `backend/Modules/` are **ModuleBuilder-compiled**. Editing a source file does nothing until it is recompiled. The module watcher handles this automatically during local development; see the [setting-up-for-local-development.md](cipp-dev-guide/setting-up-for-local-development.md "mention") page for details.
- Run the relevant **Pester tests** before submitting:

```powershell
pwsh -File backend/Tests/Invoke-CippTests.ps1                                # all tests
pwsh -File backend/Tests/Invoke-CippTests.ps1 -Path backend/Tests/Standards  # one area
```

## Frontend Guidelines

- See [frontend-testing.md](cipp-dev-guide/frontend-testing.md "mention") for test conventions and how to run the test suites.
- Remember to lint your code with prettier, as to not cause another war of formatters.

## Documentation

If your change adds, removes, or renames anything a user can see in the interface, update the documentation in the same pull request. User-facing docs live under `docs/` and mirror the frontend route path. The full style guide and submission process are in [contributing-to-the-documentation.md](contributing-to-the-documentation.md "mention").

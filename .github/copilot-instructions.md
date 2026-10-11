## Commit messages

Generate all commit messages in **Conventional Commits** format:

```
<type>(<optional scope>): <description>

[optional body]

[optional footer(s)]
```

**Rules:**

- **Type** is required and must be one of:
  - `feat` — a new feature
  - `fix` — a bug fix
  - `docs` — documentation only
  - `style` — formatting, whitespace, no code-behavior change
  - `refactor` — code change that neither fixes a bug nor adds a feature
  - `perf` — a performance improvement
  - `test` — adding or correcting tests
  - `build` — build system or dependency changes
  - `ci` — CI/CD configuration changes
  - `chore` — routine maintenance, no production code change
  - `revert` — reverts a previous commit
- **Scope** is optional and given in parentheses after the type (e.g. `feat(identity):`). Use a short, lowercase area name when it adds clarity.
- **Description** is a short, imperative-mood summary ("add", not "added"/"adds"), lowercase, no trailing period, ideally ≤ 72 characters.
- **Body** (optional) explains the *what* and *why*, not the *how*. Separate it from the description with one blank line.
- **Breaking changes** are indicated with a `!` before the colon (e.g. `feat!:`) and/or a `BREAKING CHANGE:` footer describing the change.
- Reference issues/PRs in the footer where relevant (e.g. `Closes #123`).

**Examples:**

```
feat(identity): add bulk user offboarding endpoint
fix(graph): handle expired token on retry
docs: update authentication model overview
refactor(standards)!: rename remediation parameter
```

## HTTP endpoint status codes

Endpoints in `backend/Modules/CIPPHTTP` must return a status code that matches what happened. The full guide is
`.github/agents/CIPP-Endpoint-Agent.md`.

- `200` success, `400` invalid input or refused request, `404` named resource missing, `403` CIPP access check only,
  `500` upstream (Graph/Exchange/SharePoint/Azure/table) or unexpected failure.
- Multi-item endpoints: `$StatusCode = Get-CippBulkStatusCode -Total $Total -Failed $Failed` (200 / 207 / 500).
- A `catch` never returns `[HttpStatusCode]::OK`. Use `$StatusCode = Get-CippErrorStatusCode -ErrorRecord $_`, which
  maps `ArgumentException` to 400, `ItemNotFoundException` to 404 and anything else to 500.
- Validate input before the `try`, as an `if` that returns `BadRequest`, so it can't be mistaken for an upstream failure.
- Helpers throw `[System.ArgumentException]` / `[System.Management.Automation.ItemNotFoundException]` for input and
  not-found errors, and return per-item `@{ resultText; state }` results rather than swallowing failures into strings.

# Frontend Testing

The frontend test suite exists to catch regressions, whether they come from an upstream dependency bump or from a code change in a PR. There are two vitest projects, and you can run everything with `yarn test` from the `frontend` directory. All paths on this page are relative to `frontend` unless noted otherwise.

### What Goes Where

| Test type                 | Location                            | Runs in                                                          | Command                    |
| ------------------------- | ----------------------------------- | ---------------------------------------------------------------- | -------------------------- |
| Component logic           | `tests/**/<Component>.test.jsx`     | jsdom (the `unit` project)                                       | `yarn test:unit`           |
| Browser-level interaction | `tests/**/<Component>.stories.jsx`  | Headless Chromium (the `storybook` project, via `@storybook/addon-vitest`) | `yarn test:storybook`      |

### Deciding Where a Test Belongs

* If you are asserting render branches, prop handling, text output, or utility functions, write a `.test.jsx` file in jsdom. These are fast, need no browser, and heavy child components can be mocked with `vi.mock`.
* If the component needs real layout, scrolling, portals, or browser APIs that jsdom can't fake (the Material React Table row virtualizer, drag interactions), write a story with a `play()` function that asserts the behavior. The storybook project runs every story in Chromium.
* A story that is purely visual documentation is fine too, it still counts as a render smoke test. It will catch a crash, but nothing subtler.
* Prefer asserting output and behavior over presence. A dependency bump that changes *what* renders (not *whether* it renders) should fail a test.

{% hint style="info" %}
`play()` assertions are encouraged. Under `@storybook/addon-vitest` they run as regular vitest tests, so a story without one only catches crashes, not behavior changes.
{% endhint %}

### Storybook as a Component Workbench

`yarn storybook` serves the story catalog at `http://localhost:6006` with no backend, auth, or tenant required. On the Linux/macOS Docker loop you don't need to run anything — the `cipp-storybook` container serves the same URL as part of `docker-compose-all.yml`. Every story renders inside the full provider stack (MUI theme with a light/dark toggle, Redux, React Query, and a mock settings context pinned to `testdomain.com`), and `/api/*` requests are answered by the MSW handlers in `tests/mocks/handlers.js`. That makes a story the fastest way to develop or debug a component outside the app.

To reproduce a state the live API rarely produces (an error response, an empty tenant, a half-populated report), give the story its own handler:

```jsx
import { http, HttpResponse } from 'msw'

export const EmptyTenant = {
  parameters: {
    msw: {
      handlers: [http.get('/api/ListUsers', () => HttpResponse.json({ Results: [] }))],
    },
  },
}
```

Story-level handlers take precedence over the shared ones. A story written this way also runs as a browser test in the storybook vitest project, so a repro built while debugging a component can graduate into a pinned regression by adding a `play()` function.

### The Test Harness

| Item                                    | Description                                                                                                                                              |
| --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `tests/test-utils.jsx`                  | Provides `renderWithTheme` (MUI theme only) and `renderWithProviders` (Redux, React Query, settings context, and theme). Any component that calls `ApiGetCall` anywhere in its tree needs `renderWithProviders`. |
| `vitest.setup.js` / `.storybook/vitest.setup.js` | Shared setup for the jsdom and browser projects. Both raise testing-library's `asyncUtilTimeout` to 10 seconds because coverage instrumentation slows lazy chunks and fetches past the 1 second default. Don't add per-call `waitFor` timeouts, the global covers it. `vitest.setup.js` also owns the per-file boundary scrub for the shared worker contexts (module registry, history state, storage, timers). |
| `tests/mocks/handlers.js`               | MSW handlers that answer `/api/*` requests in Storybook, globally via `preview.jsx` with story-level overrides via `parameters.msw`.                       |
| `tests/mocks/api-call.js`               | Shared `vi.mock` factory for `src/api/ApiCall`, how the jsdom tests mock API responses. Usage notes at the top of the file.                                |
| `tests/mocks/`                          | Next.js modules (`next/router`, `next/dynamic`, and friends) are aliased to lightweight mocks here. Storybook uses `@storybook/react-vite`, not the Next.js framework adapter. |
| `tests/mocks/tiptap-extension-image.js` | A stub for `@tiptap/extension-image`. `mui-tiptap` requires it as a peer dependency but the app doesn't install it.                                        |
| `tests/Overview.mdx`                    | Documents the Storybook internals: aliases, MSW setup, shared execution contexts, and warning suppressions.                                               |

{% hint style="warning" %}
Both vitest projects run without per-file isolation for speed: unit files share worker threads and story files share one chromium page. `vitest.setup.js` flushes the module registry, `history.state`, storage, and fake timers at every file boundary, but tests must still stub globals with a configurable `Object.defineProperty` (plain assignment throws on getter-only globals like the `navigator.clipboard` that `userEvent.setup()` installs), remove their own `window` listeners, and claim their viewport in stories that measure layout. A test that passes alone but fails in the full run is reading a neighbor's leftovers: re-run with `--isolate` to confirm, then fix the leak. Details in `tests/Overview.mdx`.
{% endhint %}

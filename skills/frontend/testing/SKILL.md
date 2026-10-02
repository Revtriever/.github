---
name: testing
description: >
  Test strategy for revtriever-fe: Vitest + Testing Library + MSW, spec file layout, test/ helpers
  (render, router, msw, fixtures), how to mock the API, coverage thresholds. Use whenever writing or
  changing tests. Triggers on: "test", "teste", "spec", "vitest", "testing library", "msw", "mock",
  "cobertura", "coverage", "renderWithProviders", "renderRouterAt", "fixture", "e2e".
---

# Testing — revtriever-fe

**Vitest 4 + Testing Library (React, user-event, jest-dom) + MSW 2**, jsdom environment. Same runner
as the API, so one mental model across the org.

## Commands and gates

| Command | What it does |
|---|---|
| `npm test` | `vitest run --config vitest.config.ts` (all specs once) |
| `npm run test:watch` | watch mode |
| `npm run test:cov` | same run with v8 coverage |
| `npm run typecheck` | `tsc -b --noEmit` (covers `src` and `test`) |

Husky `pre-push` runs `npm run typecheck && npm test`; CI re-runs everything.
**Coverage thresholds are 85% for lines, branches, functions and statements** (`vitest.config.ts`),
over `src/**/*.{ts,tsx}` excluding specs, `routeTree.gen.ts`, `*.d.ts` and `main.tsx`. They are a
floor enforced by `test:cov`; read the number on your diff, don't chase 100%.

## Layout

- **Specs sit next to the code**: `settlement-card.tsx` → `settlement-card.spec.tsx`,
  `billing-keys.ts` → `billing-keys.spec.ts`. Vitest picks up `src/**/*.spec.{ts,tsx}` only
  (`*.test.*` is not collected).
- **Route-level specs** live in `src/routes/-specs/` (the `-` prefix keeps them out of the route
  tree): `public-routes.spec.tsx`, `admin-guard.spec.tsx`, `signup-flow.spec.tsx`...
- `test/` at the repo root holds shared test infrastructure (not collected as specs):
  - `test/setup.ts` — jest-dom matchers, `asyncUtilTimeout: 5000`, starts the MSW server with
    `onUnhandledRequest: 'error'`, `cleanup()` and `server.resetHandlers()` after each test, and
    jsdom shims (pointer capture and `scrollIntoView` for Radix, `IntersectionObserver`,
    `ResizeObserver`).
  - `test/msw/server.ts` — `setupServer(...handlers)`; `test/msw/handlers.ts` — the default
    handlers (a single file, minimal baseline responses for calls every screen makes).
  - `test/fixtures/` — typed sample data (`catalog.ts`, `negotiation.ts`), typed with the feature's
    types, shared by several specs.
  - `test/render.tsx` — `renderWithProviders(ui)`.
  - `test/router.tsx` — `renderRouterAt(path)`.
- `globals` is **off**: import `describe`, `it`, `expect`, `vi` from `vitest` in every spec.
- Specs import helpers by relative path (`'../../../../test/msw/server'`); the `@/` alias only maps
  to `src`.
- Test titles are pt-BR sentences describing behavior ("mostra o motivo da recusa sem o nome da
  exceção nem o requestId").

## What we test, at which level

| Level | Scope | Tool |
|---|---|---|
| Unit | pure logic: formatters, masks, schemas, mappers, key factories, toast copy | Vitest (`*.spec.ts`) |
| Hook | a hook with its Query/Form context | `renderHook` or a tiny `Harness` component + `renderWithProviders` |
| Component / page | a screen behaving from the user's point of view | RTL + MSW (`*.spec.tsx`) |
| Route | guards, redirects and search params through the real route tree | `renderRouterAt` |

There is no E2E suite in this repo today.

## Rules

1. **Query by role and label/text, never by class.** `getByRole('button', { name: /entrar/i })`,
   `getByLabelText('E-mail')`. If it is hard to query it is probably hard to use — fix the
   accessibility. `data-testid` is a last resort for non-semantic wrappers (a couple of preview
   components use it); don't add it to anything interactive.
2. **The API is mocked at the network level with MSW, never by stubbing data hooks.** Add the
   per-test response with `server.use(http.get('*/billing/plan', ...))` (patterns start with `*/`).
   Return the real problem+json shape for failures (`type`, `title`, `status`, `detail`,
   `requestId`) with the right HTTP `status`, so the `ApiError` path and `FailureAlert` are
   exercised for real. Unhandled requests fail the test: add a handler instead of silencing it.
   Put a response in `test/msw/handlers.ts` only when most specs need it.
3. **Render with the real providers.** `renderWithProviders` wraps Theme, a fresh `QueryClient`
   (`retry: false`), Session, Toast, PageHeader and CopilotFocus providers. A page that uses router
   hooks is tested by mocking only the router module
   (`vi.mock('@tanstack/react-router', () => ({ useNavigate: ..., useSearch: ..., Link: ... }))`
   with `vi.hoisted` mocks, see `login-page.spec.tsx`). To test guards and real navigation use
   `renderRouterAt('/path')`, which builds the actual `routeTree` on a memory history and returns
   the router to assert `router.state.location`.
4. **Test behavior, not implementation**: "shows the total after loading", not "calls useQuery
   once". Refactoring internals must not break tests.
5. Each screen has at least: happy path, empty state, API error (message visible; `requestId` only
   for 5xx), and — when it has a form — one validation failure and one submit failure.
6. **Async: `await screen.findBy...`** over `waitFor` + `getBy`. Use `userEvent.setup()` for
   interactions (`const user: UserEvent = userEvent.setup()`), awaited. No arbitrary timeouts; for
   timers use `vi.useFakeTimers()` deliberately and restore it.
7. Money in assertions: build the expected text with `formatMoney(cents)` (normalize the NBSP:
   `.replace(/\u00A0/g, ' ')`) instead of hand-writing "R$ 450,00".
8. Types stay strict in specs: annotate helpers and variables (`typedef` applies to specs too).
9. **Function size applies to specs too** (40 lines per function): a `describe` callback is a
   function. Keep each `describe` focused on one behavior and push setup into named helpers
   (`mockAddCardRejected()`, `fillAndSubmit(user, number)`) or fixtures instead of one giant block.

## What NOT to test

Generated API types (`schema.d.ts`), `routeTree.gen.ts`, Tailwind classes, Radix internals, or that a
library does what its docs say.

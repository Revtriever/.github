---
name: data-fetching
description: >
  How revtriever-fe talks to the API: openapi-fetch client with generated types, TanStack Query
  hooks in features/*/api, query keys, invalidation, error handling, token refresh, realtime and
  analytics meta. Use whenever fetching or mutating data, creating a hook in features/*/api, or
  handling API errors. Triggers on: "fetch", "api", "query", "mutation", "useQuery", "useMutation",
  "cache", "invalidate", "erro da api", "loading", "openapi", "client", "tipos da api",
  "api:types", "refresh token", "requestId", "unwrap".
---

# Data Fetching — revtriever-fe

## The client is generated, never hand-written

`npm run api:types` downloads the API's OpenAPI document from `http://localhost:3333/docs-json`
(needs `SWAGGER_USER`/`SWAGGER_PASSWORD`, so run the API locally first) and regenerates
`src/shared/lib/api/schema.d.ts` with `openapi-typescript`. That file is committed and excluded from
lint. The typed client (`openapi-fetch`) is `apiClient` in `src/shared/lib/api/client.ts`.

- Paths, params, bodies and responses are typed from the real contract. A breaking change in the API
  breaks the build at the exact call site — that is the point. After an API change, rerun
  `api:types` and fix what typecheck reports.
- Never redeclare an API type by hand. Derive it from `paths` in the feature's `types.ts`:

```typescript
import type { paths } from '@/shared/lib/api/schema';

export type SettlementList = paths['/billing/settlements']['get']['responses']['200']['content']['application/json'];
export type Settlement = SettlementList['data'][number];
export type BillingProfileInput = NonNullable<paths['/companies/me/billing-profile']['put']['requestBody']>['content']['application/json'];
```

## Hooks are the only data access

Every call lives in `features/<feature>/api/` as a hook. Components never import the client — the
rule is `no-restricted-imports` on `**/shared/lib/api/client` plus `no-restricted-syntax` against
`fetch(...)` (lint messages cite this skill). The override that lifts both rules is limited to
`src/features/*/api/**`, `src/app/providers/**` and `src/shared/lib/api/**`.

Every response goes through `unwrap` (returns `data`, throws `ApiError` on error) or `unwrapEmpty`
(for 204s). Hooks declare their return type explicitly:

```typescript
export function useSettlements(page: number): UseQueryResult<SettlementList> {
    return useQuery({
        queryKey: billingKeys.settlements(page),
        queryFn: async ({ signal }) =>
            unwrap(await apiClient.GET('/billing/settlements', { params: { query: { page, pageSize: 25 } }, signal }))
    });
}
```

Always pass `signal` so Query can cancel. File naming in `api/`: `use-<thing>.query.ts` for a query,
`use-<action>.mutation.ts` for one mutation, `use-<thing>.mutations.ts` when a file holds several
related mutations (`use-cancellation.mutations.ts`). Hooks that compose several queries or add
behaviour sit beside them without the suffix (`use-dashboard-data.ts`, `use-upgrade.ts`).

## Query keys

One key factory per feature, in `api/<feature>-keys.ts` (`billing-keys.ts`, `admin-keys.ts`,
`dunning-keys.ts`...). Every key starts with the feature root so the whole module can be invalidated:

```typescript
export const billingKeys = {
    all: ['billing'] as const,
    settlements: (page: number): readonly ['billing', 'settlements', number] => [...billingKeys.all, 'settlements', page] as const,
    settlement: (settlementId: string): readonly ['billing', 'settlement', string] =>
        [...billingKeys.all, 'settlement', settlementId] as const
};
```

- Don't inline a raw array at a call site; add a factory entry. (A few older hooks in `payment/api`
  still inline keys; new code doesn't.) Extending a factory key at the call site —
  `[...billingKeys.cancellation(), 'recovered']` — is acceptable when the suffix is local to one
  hook.
- Everything that changes the result belongs in the key (page, filters, ids).
- Key factories are exempt from `typedef.variableDeclaration` (they must stay `readonly` tuples) and
  have their own spec (`billing-keys.spec.ts`) asserting the shape and the shared prefix.

## Mutations and invalidation

```typescript
export function useUndoCancellation(): UseMutationResult<void, Error, void> {
    const client: QueryClient = useQueryClient();
    return useMutation({
        mutationFn: async (): Promise<void> => {
            unwrapEmpty(await apiClient.DELETE('/billing/cancellation'));
        },
        onSuccess: (): void => {
            void client.invalidateQueries({ queryKey: billingKeys.all });
        }
    });
}
```

- Invalidate the narrowest key that could have changed; `<feature>Keys.all` is fine when many
  screens read the same resource.
- No optimistic updates for money operations; show real state or nothing.
- The component decides the user-facing outcome (toast via `useToast()` from
  `@/app/providers/toast-provider`, navigation). Toast copy for a feature sits in
  `<feature>/<feature>-toasts.ts` as pure functions returning a `ToastRequest`
  (`billing-toasts.ts`), so it can be unit-tested.
- **Analytics are declared, not called.** A mutation attaches `meta: track({ event: 'checkout_accepted',
  failure: 'checkout_accept_failed' })` (`@/shared/lib/analytics/track`); the `MutationCache` in
  `QueryProvider` emits the success and failure events (`failure_reason` is the problem `type`,
  never `detail`). Features don't import `capture` themselves.

## Realtime

`useRealtimeEvent(event, handler)` (`shared/lib/realtime`) subscribes to the socket.io connection
(re-attached when the token changes). The pattern is to invalidate the query on the event, as
`useCancellation` does with `'cancellation.changed'`. The server is still the source of truth;
never write the event payload into local state.

## Errors: the API speaks problem+json

`unwrap` turns any failure into `ApiError` (`src/shared/lib/api/api-error.ts`) with
`problem: { type, title, status, detail, requestId, meta? }`, plus `status`, `requestId` and
`fieldIssues()` (the `meta.errors` entries with a dotted `path` and a `message`).

- **Show `detail`** — the API writes it to be displayed. A non-API failure gets a generic pt-BR
  message from `ApiError.fromUnknown`.
- Render failures with `<FailureAlert error title />` (`shared/ui`). It shows `detail`, and shows the
  `requestId` **only for 5xx** — a 4xx is the user's to fix and needs no support id. The
  error `title` is a Nest exception name and is never shown.
- `type` is the stable error code (`billing.profile_incomplete`); branch on it when the UI must react
  differently, never on the message text.
- Field-level mapping from `fieldIssues()` is described in the `forms` skill.
- **401 is handled by the client middleware, never by a component**: it calls `POST /auth/refresh`
  (single-flight, `refreshSession()`), retries the original request once with the new token, and on
  failure clears `tokenStore`, which drops the session. Paths that authenticate with their own
  short-lived token (`/auth/refresh`, `/auth/totp/enroll|activate|verify`) are excluded from the
  renewal.
- `429`: handle explicitly where the API can return it (`CardCaptureFailure.retryAfterSeconds` in
  `features/payment`); never fall to the generic failure message.
- The one place that does not use `apiClient` is the public card-capture call to the motor
  (`VITE_MOTOR_URL`, `features/payment/api/card-capture.ts`); it lives in `api/` and is covered by the
  same lint override.

## Defaults (QueryProvider, set once)

`staleTime: 30_000`; queries retry up to 2 times but **never on a 4xx** (`ApiError` with status
< 500); mutations never retry. Don't override per hook without a reason. Loading states are
skeletons of the real layout (`Skeleton`, `SkeletonTable`, `Loading` in `shared/ui`), not spinners.

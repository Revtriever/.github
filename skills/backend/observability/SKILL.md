---
name: observability
description: >
  Logging, correlation, tracing, log search and alerting rules for revtriever-api. Use this skill
  whenever writing log statements, creating a new flow entry point (endpoint, cron, queue consumer),
  propagating context to async jobs, wiring OpenTelemetry, investigating an incident through logs,
  or creating a dashboard or alert. Triggers on: "log", "logger", "logging", "requestId",
  "correlation", "trace", "tracing", "span", "OTel", "OpenTelemetry", "structuredMetadata",
  "LOG_IDENTIFIER", "pino", "observability", "Grafana", "Loki", "Tempo", "LogQL", "search logs",
  "buscar log", "investigar", "alerta", "alert", "dashboard", "cardinality", "cardinalidade".
---

# Observability — revtriever-api

Structured JSON logs with **pino** (`nest-pino`), traces/metrics with **OpenTelemetry**, everything
shipped to Grafana Cloud via OTLP. Backend is config only — code never knows about Grafana.

## Correlation: requestId

One id finds the whole flow. Non-negotiable rules:

1. **Every flow entry point creates a requestId** (uuid v7) if none exists yet:
   HTTP request (middleware), cron tick, queue consumer receiving an EXTERNAL event (webhook).
2. **Everything downstream propagates it, never recreates it**: async jobs, fan-out, retries.
   - In-process: `AsyncLocalStorage`. The logger reads it automatically — code never passes
     requestId around by hand and never logs it explicitly.
   - Across the queue: the publisher copies requestId (and companyId) into the `QueueEnvelope`; the
     worker restores them into the context before any log line runs. This lives in the queue module
     — feature code never touches it.
3. Fan-out children keep the parent requestId. If a child needs its own identity (e.g. one message
   per charge in a batch), it ADDS `chargeId`/`jobId` — it never replaces requestId.

Searching `{requestId="..."}` in Loki must return the entire story: entry point → services →
queue hops → outbound calls. That is the acceptance test for this section.

## Log shape

Every log line carries (automatically, via logger context — not hand-passed):

| Field        | Source                  | Notes                            |
| ------------ | ----------------------- | -------------------------------- |
| `requestId`  | AsyncLocalStorage       | always                           |
| `companyId`  | AsyncLocalStorage       | whenever a tenant is in scope    |
| `identifier` | LOG_IDENTIFIER constant | always                           |
| `traceId`    | OTel context            | injected by pino instrumentation |
| `meta`       | call site               | structured payload, see below    |

### LOG_IDENTIFIER

Each service/flow declares one stable constant. It is the grep handle for "all logs of this
component", independent of message wording.

```typescript
const LOG_IDENTIFIER: string = 'asaas-webhook-ingestion';

this.logger.info({ identifier: LOG_IDENTIFIER, meta: { eventId, type } }, 'webhook accepted');
```

Naming: kebab-case, `<feature>-<operation>`. Renaming one is a breaking change for saved Grafana
queries — treat it like renaming a public API.

### Structured metadata, static messages

- The `message` is **static text** — never interpolate data into it. Data goes in `meta`.
  Wrong: `` `charge ${id} failed after ${n} retries` ``. Right: message `'charge recovery failed'`,
  meta `{ chargeId, retries }`.
- `meta` is one flat-ish object per call site. IDs, counts, enums, durations — yes.
  Whole entities, raw gateway payloads, buffers — no (log the id, fetch the data in the DB).

### Error codes in logs

Log the error CODE (`identity.invalid_email_otp`), never the translated message. The message is a
presentation concern resolved at the HTTP boundary; the code is the stable handle for dashboards
and alerts.

### PII — hard rule

Never log end-customer personal data: name, email, phone, document, card data, Pix keys, message
content. Log the ids (`customerId`, `chargeId`) instead. Gateway payloads are stored in the events
table, not in logs. There is no "just this once".

The same line applies to credentials, and a URL is where they hide: the webhook URL of a connection
ends in the token that authorizes posting settlements as that gateway. Log the shape, mask the
secret — `https://.../webhooks/sicoob/***`.

### Cardinality — labels vs structured metadata

Where a field lands decides what it costs. Loki bills by stream: every distinct combination of
**labels** is a new stream, and a tenant id as a label multiplies streams by customer.

- **Labels** (stream selector, `{}`): `service_name`, `deployment_environment_name`, `level`.
  That list is closed. Adding to it is a capacity decision, not a convenience.
- **Structured metadata** (filter with `|`): everything else — `identifier`, `requestId`,
  `companyId`, and every `meta` key. Filtering on these is cheap and does not create streams.
- **Metric labels**: `companyId` is **never** one. Allowed labels are closed sets — `provider`,
  `result`, `reason`, `queue`, `stepType`, `outcome`, `cardBrand`. Slicing by tenant is a job for
  logs and traces, never for metrics.

## Field reference

What exists to search on, by `identifier`. Adding an identifier or a `meta` key means updating this
table — same rule as renaming one.

| `identifier`                  | Covers                                                            | Distinctive `meta` keys                                                                                                                                                                      |
| ----------------------------- | ----------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `dunning-engine`              | Case run lifecycle, sweep, webhook routing, opt-out, flow seeding | `flowId`, `rootStepId`, `reason`, `concluded`/`suspended`/`queued`/`failed`/`skipped`, `eventType`, `eventId`, `companies`, `cases`, `steps`, `contactId`                                    |
| `dunning-step`                | Individual step outcomes, scheduling, send guard-rails, branching | `flowId`, `stepId`, `type`, `attempts`, `reason`, `detail`, `wakeAt`, `retryAt`, `switchStepId`, `takenCaseId`, `cancelledCaseIds`, `queue`, `dedupeKey`                                     |
| `dunning-card-retry`          | Card retry decision and outcome                                   | `flowId`, `stepId`, `chargeId`, `decision`, `declineCode`, `cardBrand`, `reversible`, `cooldownHours`, `attemptsInWindow`, `brandLimit`, `windowHours`, `approved`, `durationMs`, `provider` |
| `gateways-connection`         | Connect, disconnect, credential verification, webhook arrival     | `provider`, `environment`, `externalAccountId`, `eventId`, `webhookUrl`                                                                                                                      |
| `identity-auth`               | Login, invite, OTP, TOTP lifecycle, password changes              | `userId`                                                                                                                                                                                     |
| `auth-refresh-reuse`          | Refresh token reuse — family revoked                              | `familyId`, `revokedSessions`, `userId`                                                                                                                                                      |
| `identity-company-onboarding` | Company creation                                                  | `companyId`, `ownerUserId`                                                                                                                                                                   |
| `identity-company-settings`   | Dunning pause/resume, send window changes                         | `companyId`, `startHour`, `endHour`                                                                                                                                                          |
| `queue-consumer`              | Worker startup, enqueue failure, missing handler                  | `queue`, `type`, `detail`                                                                                                                                                                    |
| `email-send`                  | Delivery                                                          | `template`                                                                                                                                                                                   |
| `realtime-publisher`          | Redis pub/sub emit (skipped without tenant, publish failure)      | `event`                                                                                                                                                                                      |
| `realtime-gateway`            | WS connect/reject/disconnect, subscriber bridge, delivery failure | `socketId`                                                                                                                                                                                   |
| `http-error`                  | Unhandled exceptions, untranslated error codes                    | `code`, `err`                                                                                                                                                                                |
| `llm-bedrock`                 | Converse call retries and final failure                           | `modelId`, `attempt`, `maxAttempts`, `retryable`, `awsError`                                                                                                                                 |
| `llm-claude-code`             | Local-only driver over `claude -p`: run summary, bridged tool calls, CLI failure | `modelId`, `purpose`, `durationMs`, `turns`, `costUsd`, `models`, `tool`, `toolUseId`, `resultChars`, `isError`                                                                              |
| `llm-metering`                | Monthly cap refusal, unmetered generation (no tenant)             | `period`                                                                                                                                                                                     |
| `llm-pricing`                 | Model missing from `LLM_PRICE_TABLE` (cost recorded as zero)      | `modelId`                                                                                                                                                                                    |
| `copilot-chat`                | Capability failures, tool-round cap reached                       | `name`, `used`                                                                                                                                                                               |
| `insights-narration`          | Narration generated or fallen back to template                    | `inputTokens`, `outputTokens`, `code`                                                                                                                                                        |

`message` is static by rule, so it is a reliable filter — `| message="dunning send blocked"` is as
stable as the identifier.

## Searching

The entry point is almost always one of three handles.

**From a requestId** — the whole story, across HTTP, queue hops and workers:

```logql
{service_name="revtriever-api"} | requestId="0199..."
```

**From a case** — everything that ever happened to one dunning flow:

```logql
{service_name="revtriever-api"} | flowId="0199..."
```

Because `flowId` is on `dunning-engine`, `dunning-step` and `dunning-card-retry` alike, this one
query reconstructs the case: which branch the switch took, why a send was blocked, whether the card
retry was allowed and what the decline evidence was.

**From a component** — behaviour of one subsystem regardless of wording:

```logql
{service_name="revtriever-api"} | identifier="dunning-card-retry" | decision!="allowed"
```

**Counting, not reading** — turn any filter into a rate to see shape instead of lines:

```logql
sum by (reason) (count_over_time(
  {service_name="revtriever-api"} | identifier="dunning-step" | message="dunning send blocked" [1h]))
```

**Pivoting to the trace**: every line carries `trace_id` (injected by the pino instrumentation), so
a log line links straight into Tempo. Use logs to find _which_ execution, traces to see _where_ the
time went. `requestId` survives batching and manual replays and is what support asks the customer
for; `trace_id` is per-execution plumbing.

**What is deliberately absent**: no payer name, e-mail, phone, document, card data or Pix payload.
When an investigation needs the raw gateway body, it is in the `GatewayEvents` table, keyed by the
`eventId` in the log — not in Loki.

## Alerting

- **Alert on absence, not only on errors.** The failure mode of this product is silence: a stalled
  ruler throws nothing, it just stops recovering money. Any periodic producer needs a
  "did not run in the last N" rule.
- **`NoData` must map to `Alerting`** on those rules. The Grafana default resolves no-data to OK,
  which is exactly backwards when the absence of the signal _is_ the incident.
- **An alert with no contact point is not an alert.** Routing is part of the definition of done.
- **Rules follow the data.** Provisioning dashboards and rules before telemetry flows produces
  permanent `NoData` noise, which teaches the team to ignore alerts — the worst possible outcome.
- Alert on the **age of the oldest waiting job**, not on queue depth. Depth alone hides a stuck
  consumer behind healthy-looking numbers.

## Levels

- `error` — flow broken, human may need to act. Always include the error and the ids to replay.
- `warn` — degraded but self-healing (retry scheduled, fallback used, circuit open).
- `info` — state transitions that matter: flow started/finished, charge state changed, message sent,
  webhook accepted/rejected. One line per meaningful transition — not per function call.
- `debug` — everything else. Off in production by default.

## Tracing

**Auto-instrumentation is the baseline; manual spans are the exception.** `src/tracing.ts` starts the
OTel SDK BEFORE any application import (first line of `main.ts`) — instrumentation patches modules at
load, so importing the app first silently disables everything. It also loads the env file itself,
because Nest's ConfigModule has not run yet.

What it gives for free: HTTP server/client, Postgres, AWS SDK (SQS/SES/S3/KMS) and pino log
correlation (`trace_id`/`span_id` in every line). **Never write a span per controller** — that is
noise. Write one only when the name is a business concept (`dunning.evaluate_case`) via
`TracingService.withSpan`.

**Queue propagation is mandatory and is the part everyone gets wrong.** The publisher injects the
W3C carrier into the envelope (`trace` field) and the consumer resumes it with
`TracingService.continueFrom`, so a charge that fails, gets queued and is recovered by a worker is
ONE trace. Verified end to end: the same `trace_id` appears in the HTTP log and in the worker log.

**Attributes over span count.** Every span carries `companyId`, `requestId` and the domain ids that
matter (`chargeId`, `provider`). Same PII rule as logs — ids only, never personal data.

**Sampling**: 100% while volume is small (best debugging, fits the free tier). The trigger to move to
tail sampling with a Collector is the bill, not aesthetics.

**Traces don't replace metrics**: the same SDK exports OTel metrics (RED per route and per queue
handler). Use metrics for rates and percentiles, traces for the individual story.

requestId and traceId coexist on purpose: traceId is per-trace plumbing, requestId is the business
handle that survives batching and manual replays — and it is what support asks the customer for.

## Connection

Grafana Cloud stack `regalsyrup1014` (free tier, `prod-sa-east-1`). Datasources when writing
queries: `grafanacloud-prom`, `grafanacloud-logs` (Loki), `grafanacloud-traces` (Tempo).

Local/dev env values live in `~/.config/revtriever/grafana-otlp.env` (push token in a sibling file;
the service account token for the Grafana API is `grafana-sa-token`, next to it). In AWS they are
secrets injected into the task. Exporter is OTLP http/protobuf; switching backends is an env change,
never a code change. Self-hosting the LGTM stack is a deliberate future decision, triggered only
when Grafana Cloud free tier limits actually hurt.

**Logs travel the same pipe as traces.** A pino transport turns each line into an OTLP LogRecord and
ships it through the gateway already configured — one exporter, one auth, and `service.name` matches
the traces, so log↔trace correlation is free. A collector sidecar (Alloy) is the fallback for
scraping containers that are not ours, not the default.

Note the trap: `@opentelemetry/instrumentation-pino` only **injects `trace_id` into the line**. It
ships nothing. Enabling it without the transport produces logs that look correlated and never leave
stdout.

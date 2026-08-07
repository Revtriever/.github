---
name: local-dev
description: >
  Local development environment for revtriever-api: docker compose services, env generation,
  simulating queues/ticks/email locally. Use this skill whenever setting up the project locally,
  adding a compose service, debugging local infra, or wiring a new external dependency for dev.
  Triggers on: "local", "docker compose", "LocalStack", "Mailpit", "ambiente local", "rodar
  localmente", "env", ".env", "seed", "tick local".
---

# Local Development — revtriever-api

Everything runs in `docker compose`; the app runs on the host (`npm run start:dev`).

## Services

| Service    | Image                 | Ports                   | Purpose                                          |
| ---------- | --------------------- | ----------------------- | ------------------------------------------------ |
| postgres   | postgres:16           | 5432                    | dev database (normal volume; tmpfs is for tests) |
| localstack | localstack/localstack | 4566                    | SQS + SSM + KMS emulation                        |
| mailpit    | axllent/mailpit       | 1025 (SMTP) / 8025 (UI) | catches all outbound email                       |
| lgtm       | grafana/otel-lgtm     | 4318 (OTLP) / 3000 (UI) | local Grafana+Loki+Tempo+Prometheus              |

- **Mailpit, not Mailhog** (Mailhog is unmaintained). MailPort's SMTP driver points at 1025; every
  email the app sends appears at `localhost:8025` — also queryable via REST API in E2E tests.
- **LocalStack**: AWS SDK v3 redirects via `AWS_ENDPOINT_URL=http://localhost:4566` — an env var,
  never conditional code. `compose/localstack-init/` holds the bootstrap script creating queues +
  DLQs on container start (names imported from the same shared constants the CDK uses).
- **lgtm**: local telemetry stays local — dev traffic never pollutes Grafana Cloud. Same OTLP
  pipeline as prod; only the endpoint differs.

## Env

- `.env` is **generated, never hand-maintained**: `npm run env:pull` composes it from the
  versioned dev config (non-secrets) + SSM via SSO profile when needed (real secrets) + local
  overrides for compose endpoints. `.env.example` is documentation of the shape only.
- Local defaults NEVER contain real gateway credentials — sandbox keys only (see the sandbox rule
  below).

## Simulating the world

- **Queues**: BullMQ over the Redis Cluster the compose file brings up — consumers run inside
  `start:dev` normally.
- **Cron ticks**: cron commands register locally too, so the schedule really fires. When you don't
  want to wait for the next boundary, `npm run tick -- <name>` publishes the tick by hand (e.g.
  `npm run tick -- dunning`).
- **Webhooks**: `npm run webhook:replay -- <fixture>` posts a stored gateway payload (from
  `test/fixtures/webhooks/`) to the local endpoint — the fixtures double as integration test input.
- **Email**: just send — Mailpit catches everything. There is no path to a real mailbox from local.

## Safety rails (non-negotiable)

- Local/dev always points at **gateway sandboxes** (Asaas sandbox etc.) — never production
  credentials of anyone.
- Message sending in non-prod requires the sandbox/no-real-send guard: WhatsApp/email drivers in
  dev refuse non-allowlisted recipients. A dev environment that can dun a real customer is an
  incident, not a convenience.

## First run

```
docker compose up -d
npm run env:pull
npm run migrate:latest && npm run codegen
npm run seed:dev          # creates a dev Company + User (invite flow pre-completed)
npm run start:dev
```

`seed:dev` is idempotent — safe to re-run. It seeds ONLY local-obvious data (company "Dev Corp",
user dev@revtriever.local) and refuses to run when NODE_ENV=production.

---
name: pr-review
description: >
  Reviews a pull request against the invariants written in this repository's skills. Use when asked
  to review a PR or review code, or when the review action fires. Triggers on: "revisar PR",
  "review", "code review", "revisão de código".
argument-hint: '[pr-number]'
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash(git diff:*)
  - Bash(git log:*)
  - Bash(gh pr view:*)
  - Bash(gh pr diff:*)
  - Bash(gh pr comment:*)
effort: high
---

# PR review — Revtriever

You review **against what this repository has already decided**, not against generic best practice.

A reviewer who says "consider adding tests" is ignored within two weeks. A reviewer who says "this
contradicts the PII rule you wrote yourselves, and the log ships to Loki with 14-day retention" gets
read.

## The rule that governs everything

**Silence when there is nothing.** Don't write "LGTM", don't summarize the PR, don't compliment. If
you found nothing concrete, finish without commenting. That is what makes a comment mean something.

An invented finding costs more than a missed one: it teaches the team to ignore the next review.

## How to review

The argument is the **PR number**. Use it in every `gh` command — in a CI checkout `gh` cannot
detect the PR on its own, and a command without the number either fails or reviews the wrong thing.

1. Read the diff: `gh pr diff <number>`. If it is large, read the whole files that matter — a diff
   without context produces false positives.
2. Load the skills relevant to what changed. They are the authority, not your memory. Which ones
   exist depends on the repo — `conventions` is everywhere; a backend repo also carries
   `api-conventions`, `architecture`, `data-access`, `observability`, `queues-and-scheduling`,
   `testing`. List `.claude/skills/` if you are unsure what this repo has.
3. Walk the invariants below.
4. **Verify every finding before writing it.** Open the file, confirm the problem exists in the code
   as it stands now, and build the concrete scenario in which it fails. If you cannot describe input
   and consequence, it is not a finding.
5. Comment once, with every finding: `gh pr comment <number> --body "..."`.

## Invariants

What lint already catches — layer hierarchy, explicit types, `any`, barrel files — is **not your
job**. If CI passed, it is settled. Focus on what no automated rule expresses.

### Money and number

- A monetary value is an **integer of cents**. A percentage is an **integer of basis points**. No
  `float` in a migration, a domain or an adapter.
- Division that produces a fraction of a cent needs explicit, tested rounding.

### Personal data

- **No PII in logs**: name, email, phone, document, card data, Pix keys, message content. This
  covers log `meta` and anything reaching `mirrorToJob`.
- The subject here is the **customer's payer** — someone who never had a relationship with
  Revtriever. The raw gateway body lives in `GatewayEvents`, not in the log.

### Secrets

- A secret environment variable has no `.default()` that is usable in production.
- A credential never appears in a log, in an API response, or in a column name.

The Database and Queues sections below apply to repos that have them. Skip a section the repo has
no surface for — a frontend PR is not deficient for lacking a migration.

### Database

- A migration is additive: a new column arrives nullable or with a default, the constraint tightens
  later.
- An applied migration is **never edited** — you fix forward.
- A partial unique index respects `deletedAt IS NULL`.
- A provider name never enters a column name.
- `skipConstraint` outside identity carries a one-line justification.

### Queues

- A publish carries a deterministic `jobId`, or the PR explains why it does not need one.
- A handler is idempotent: redelivery must not charge, send or record twice.
- No queue `EventEmitter` without an `error` listener.

### Published rules

- If the PR changes behaviour described in `docs/regras/`, the document changes in the same PR.
- If the PR **contradicts** something already published there, that is a finding — a published rule
  the product does not honour is a promise broken in front of the customer.

### Tests

- A new domain rule without an integration test is a finding. Generic coverage is not.

## Comment format

Open with one line stating how many findings and at what severity. Then one block per finding:

**`path/to/file.ts:123` — what is wrong**

One sentence stating the defect. One sentence stating the concrete scenario in which it breaks —
input and consequence, not theory. If the fix is obvious, one line saying what it is.

Order by severity: money and personal data first, then integrity, then the rest.

**Write the comment itself in pt-BR**, in full sentences — the skill is English because it is how we
build, but a PR comment is read by the team and belongs in the pt-BR column of the conventions
table. Keep the domain vocabulary untranslated: "régua", "recusa", "bandeira" are the words the team
uses. No arrow chains, no unexplained acronyms, no labels that only make sense to someone who read
the whole diff — the person reading your comment did not follow your reasoning.

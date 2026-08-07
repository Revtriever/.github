---
name: conventions
description: >
  Language split, TypeScript & lint rules, git and PR conventions for every Revtriever repository.
  Use this skill whenever writing new code, naming things, committing, or opening PRs. For NestJS
  DTOs, OpenAPI decorators and the error contract, see the api-conventions skill (backend repos
  only). Triggers on: "naming", "eslint", "prettier", "typedef", "tipagem", "commit", "branch",
  "PR", "convention", "padrão", "estilo".
---

# Conventions — Revtriever

Applies to **every** repository in the org. Stack-specific rules live in their own skills
(`api-conventions`, `architecture`, `data-access`) and are synced only to the repos that need them.

## Language

The split is by **audience**, not by file type. How we build it is English; what it does and why we
chose it is pt-BR.

| English                                        | pt-BR                                               |
| ---------------------------------------------- | --------------------------------------------------- |
| Code: identifiers, types, file names           | Business rules (`docs/regras/`)                     |
| Log messages and `LOG_IDENTIFIER`              | Product decisions (`docs/dunning.md`)               |
| Error **codes** (`identity.invalid_email_otp`) | Error **messages** — the pt-BR catalogue per module |
| Skills (`.claude/skills/`)                     | Commits, issues, PR descriptions                    |
| Design docs (`docs/identity.md`)               | Anything a customer could read                      |

Two consequences worth spelling out, because both have already caused a wrong guess:

- **A design doc and a business-rules doc about the same module are not duplicates.** One says the
  refresh token is opaque and rotates per family; the other says your session lasts 30 days and
  drops if someone reuses a credential. Different readers, different languages, both needed.
- **Don't translate the domain vocabulary.** "Régua", "bandeira", "recusa" are the words the team
  actually uses, and this is a BR-specific domain (Pix, LGPD, limites de bandeira). Translating
  breeds three English words for one concept and a glossary nobody maintains.

## TypeScript & lint

**These rules are identical in every repo.** The eslint configs carry the same typing block; only
the exemption paths differ. A rule present in one repo and missing in another is a bug in the
config, not a difference of opinion.

- `tsconfig` strict, `noUncheckedIndexedAccess` on. ESLint `typescript-eslint` preset
  **strict-type-checked** + Prettier (formatting is Prettier's job, never ESLint's).
- **Explicit types everywhere** (`typedef`): every variable, member, property and parameter is
  annotated; every function/method declares its return type (`explicit-function-return-type` with
  `allowExpressions`, plus `explicit-module-boundary-types`); every class member declares
  accessibility. Also on: `prefer-readonly`, `no-import-type-side-effects`.
- Small units enforced: `max-lines-per-function: 40`, `complexity: 10`, `max-depth: 3`,
  `max-params: 8`.
- **No `any`** — `unknown` + narrowing. `as` casts need a comment or a type guard instead.
- **No default exports. No barrel files** (`index.ts` re-exports) — they breed circular imports;
  import from the concrete file.
- File names kebab-case with the framework's suffixes: `charge-recovery.application.ts`,
  `charges.repository.ts`, `use-settlements.query.ts`, `settlement-card.tsx`.
- Enums: `as const` object + union type, or plain string unions — never TS `enum`.

### The typedef exemption list — one reason, not a grab bag

`typedef.variableDeclaration` is off for a short list of files. The single criterion: **the
declaration is the source of a derived type, and annotating it destroys the derivation.** Anything
that fails that test is not exempt — annotate it.

| Exempt                          | What breaks if you annotate                                                                      |
| ------------------------------- | ------------------------------------------------------------------------------------------------ |
| `*.schema.ts` / `*.schemas.ts`  | `z.infer<typeof schema>` collapses to the annotation                                             |
| `types.ts` / `*.types.ts`       | `as const` maps lose the literal union (`(typeof THEMES)[keyof typeof THEMES]`)                  |
| `shared/config/*.ts`            | the config object IS the shape everything else reads                                             |
| `features/*/api/*-keys.ts` (FE) | query-key factories are consumed as `readonly [...]` tuples                                      |
| `routes/**/*.tsx` (FE)          | TanStack Router derives the route tree from the inferred `Route`                                 |
| `main.tsx` (FE)                 | `Register { router: typeof router }` — annotating `createRouter(...)` kills path typing app-wide |

Corollaries, each one learned the hard way:

- A hook's **call site** is not exempt. `const settlements: UseQueryResult<SettlementList> = useSettlements(1)`
  is the expected shape — the hook already declares that return type, so repeating it costs one line
  and keeps the rule uniform.
- `cva()` looks exempt-shaped but isn't: hand-write the variant props type and annotate
  (`const buttonVariants: (props?: ButtonVariantProps) => string = cva(...)`).
  `VariantProps<typeof buttonVariants>` still resolves from the annotation.
- Never annotate with a machine-generated structural blob (`UseFormReturn<{ code: string }, any, ...>`).
  Use the named type (`UseFormReturn<TotpCodeInput>`) — an annotation containing `any` is worse than
  no annotation at all.

### Flat config replaces, it does not merge

In eslint flat config, a later block that names a rule **replaces** the earlier configuration of
that rule for the matching files — options are not merged. Two blocks that both configure
`no-restricted-imports` for overlapping globs means the last one wins entirely, and the first one's
patterns silently stop firing. Order the blocks so the narrowest comes last, and absorb the broader
patterns into it rather than relying on both to apply.

## Git

- **Trunk-based**: short-lived branches off `main`, PR, squash-merge. No develop branch, no release
  branches.
- Branch names: `feat/identity-login`, `fix/webhook-dedup`, `chore/bump-kysely`.
- **Conventional commits** enforced by commitlint (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`,
  `test:`, `ci:`). Scope optional but encouraged: `feat(identity): ...`. `subject-case` rejects a
  leading uppercase — write the subject lowercase.
- Hooks (husky): pre-commit = lint-staged (ESLint fix + Prettier on staged files only);
  pre-push = typecheck + unit tests; commit-msg = commitlint. Hooks are convenience — **CI is the
  enforcement** and re-runs everything in full.
- PRs: small, one concern. Description says WHY. Skill/doc updates ride in the same PR as the
  change that makes them true — except skills themselves, which live in `Revtriever/.github` and
  are synced (see below).

## Skills are synced, not edited in place

`.claude/skills/` in this repo is **generated**. The source of truth is `Revtriever/.github` under
`skills/<group>/<name>/SKILL.md`, and the sync action mirrors it here — a skill edited locally is
overwritten on the next sync, and one that no longer exists upstream is pruned.

To change a skill, open a PR against `Revtriever/.github`. The human approval there is the gate;
the push into this repo happens without further review because it already passed.

A skill that is genuinely specific to one repo can live locally, but it must be listed in
`sync-config.json` as an exception first — otherwise the prune deletes it.

## Comments

**No comments in code.** Clean code, small methods, strong typing — the code explains itself; if it
needs narration, refactor until it doesn't. Context that can't live in code goes in docs/ or the
skill. The single sanctioned exception: a `skipConstraint` use outside the identity module carries
a one-line justification (security-critical annotation, see data-access skill).

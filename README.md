# .github

Org-wide defaults: issue templates, labels, project management e as **skills do Claude Code**.

## Skills — source of truth centralizado

A pasta `skills/` deste repositório é a **fonte única de verdade** para as skills do Claude Code.
Cada repo recebe só as skills relevantes pro seu contexto, no formato nativo
`.claude/skills/<nome>/SKILL.md`.

### Como funciona

1. Abra um PR aqui alterando arquivos em `skills/`
2. O PR precisa de **aprovação humana** — esse é o gate de qualidade
3. Depois do merge em `main`, a action **Sync Skills** dá push direto na `main` dos repos configurados
4. Nenhuma aprovação adicional nos repos destino: o gate já aconteceu aqui
5. O Claude Code descobre as skills sozinho em `.claude/skills/`

### Estrutura

```
skills/
├── sync-config.json                 # mapeamento repo → grupos
├── shared/                          # todos os repos recebem
│   ├── conventions/SKILL.md         # idioma, tipagem, lint, git
│   └── pr-review/SKILL.md           # como revisar um PR
└── backend/                         # repos NestJS
    ├── api-conventions/SKILL.md     # DTO/zod, OpenAPI, controller, contrato de erro
    ├── architecture/SKILL.md        # camadas, ports, injeção
    ├── caching/SKILL.md
    ├── data-access/SKILL.md         # Kysely, tenant, migrations
    ├── infrastructure/SKILL.md
    ├── local-dev/SKILL.md
    ├── observability/SKILL.md       # pino, OTel, requestId
    ├── queues-and-scheduling/SKILL.md
    └── testing/SKILL.md
```

### Mapeamento por grupo

| Grupo        | Skills recebidas     | Repos            |
| ------------ | -------------------- | ---------------- |
| **backend**  | `shared` + `backend` | revtriever-api   |
| **frontend** | `shared`             | revtriever-fe    |

O front recebe só as `shared` porque as de backend são específicas de NestJS/Kysely/BullMQ — jogar
regra de repository layer num repo React é ruído, não padrão. Quando existir skill própria de
frontend, cria a pasta `skills/frontend/` e adiciona em `folders` do grupo.

Pra adicionar repos ou grupos, edite `skills/sync-config.json`.

### `.claude/skills` no repo destino é um espelho

A sync **poda** qualquer skill que não esteja no conjunto canônico do grupo. Ou seja: editar uma
skill direto no repo destino não adianta — o próximo sync sobrescreve; e criar uma skill local
solta faz ela sumir.

Se um repo precisa mesmo de uma skill só dele, declare em `keep` no `sync-config.json`:

```json
"keep": { "revtriever-api": ["skill-so-daqui"] }
```

Aí a poda respeita, mas o conteúdo continua sendo responsabilidade do repo.

### Execução manual

A action aceita `workflow_dispatch` com `repos` (lista separada por vírgula, ou `all`) e `dry_run`.

### Setup necessário

A action precisa do secret **`GH_TOKEN`** neste repositório. O `GITHUB_TOKEN` padrão só
tem escopo do repo onde o workflow roda, então não consegue dar push no `revtriever-api` /
`revtriever-fe`.

Use um **fine-grained PAT** restrito aos dois repos, com `Contents: Read and write`. Nada além
disso.

## Workflows

| Workflow        | Trigger                                          | O que faz                                        |
| --------------- | ------------------------------------------------ | ------------------------------------------------ |
| **Sync Skills** | Push em `main` alterando `skills/`, ou manual    | Sincroniza `.claude/skills/` nos repos do config  |

## Issue templates

`.github/ISSUE_TEMPLATE/` — PRD, feature, bug e tech debt.

## Project board

`setup-project.sh` cria o project board da org com os campos de gestão. Requer escopo `project`
no `gh`.

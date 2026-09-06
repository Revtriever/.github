# Revtriever

Recuperação de receita para negócios de cobrança recorrente no Brasil — cartão recusado, boleto vencido e assinatura em risco viram cobrança recuperada via WhatsApp e Pix.

## Produto

| Repositório | O que é |
| --- | --- |
| [revtriever-api](https://github.com/Revtriever/revtriever-api) 🔒 | Motor de cobrança: API, régua de recuperação e gateways (NestJS + Kysely + AWS) |
| [revtriever-fe](https://github.com/Revtriever/revtriever-fe) 🔒 | Painel web (React + TS) |
| [revtriever-site](https://github.com/Revtriever/revtriever-site) 🔒 | Landing page pública — [revtriever.com](https://revtriever.com) (Astro + Tailwind) |
| [revtriever-docs](https://github.com/Revtriever/revtriever-docs) 🔒 | Documentação do motor — [docs.revtriever.com](https://docs.revtriever.com) (Astro Starlight) |

## Plataforma

| Repositório | O que é |
| --- | --- |
| [revtriever-observability](https://github.com/Revtriever/revtriever-observability) 🔒 | Grafana as code: dashboards, alertas e políticas de notificação versionados |
| [revtriever-observability-infra](https://github.com/Revtriever/revtriever-observability-infra) 🔒 | Stack LGTM self-hospedada — Grafana, Loki, Tempo e Prometheus numa EC2, com logs e traces no S3 |

## Agentes e padrões

| Repositório | O que é |
| --- | --- |
| [revtriever-skills](https://github.com/Revtriever/revtriever-skills) | Skills públicas pra quem integra com o motor — o seu agente de código aprende a usar a API do jeito certo |
| [.github](https://github.com/Revtriever/.github) | Templates de issue e PR, padrões de gestão e as skills internas de engenharia |

🔒 = repositório privado.

## Integrando com o motor

```bash
npx skills add Revtriever/revtriever-skills
```

Referência completa em [docs.revtriever.com](https://docs.revtriever.com) — e em [`/llms-full.txt`](https://docs.revtriever.com/llms-full.txt) para agentes.

Trabalho organizado no [project board da org](https://github.com/orgs/Revtriever/projects).

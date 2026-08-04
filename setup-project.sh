#!/usr/bin/env bash
# Cria o project board da org Revtriever com os campos de gestão.
# Requer escopo project no gh:  gh auth refresh -h github.com -s project
set -euo pipefail

OWNER="Revtriever"
TITLE="Revtriever Roadmap"

echo "== criando project"
NUMBER=$(gh project create --owner "$OWNER" --title "$TITLE" --format json | python3 -c "import json,sys; print(json.load(sys.stdin)['number'])")
echo "   project #$NUMBER"

field() {
  gh project field-create "$NUMBER" --owner "$OWNER" --name "$1" --data-type "$2" ${3:+--single-select-options "$3"} > /dev/null
  echo "   campo: $1"
}

echo "== campos"
field "Priority"  SINGLE_SELECT "P0 — agora,P1 — próxima,P2 — planejado,P3 — algum dia"
field "Size"      SINGLE_SELECT "XS — até 2h,S — meio dia,M — 1-2 dias,L — 3-5 dias,XL — quebrar em partes"
field "Work"      SINGLE_SELECT "PRD,Feature,Bug,Tech debt,Chore,Spike"
field "Area"      SINGLE_SELECT "Identity,Gateways,Dunning,Messaging,Billing,Infra,Frontend,DX"
field "Epic"      TEXT
field "Target"    DATE
field "Spent (h)" NUMBER

echo "== vinculando repositórios"
for repo in revtriever-api revtriever-fe; do
  gh project link "$NUMBER" --owner "$OWNER" --repo "$repo" > /dev/null && echo "   $repo"
done

echo
echo "Pronto: https://github.com/orgs/$OWNER/projects/$NUMBER"
echo "Ajuste as colunas de Status na UI (sugestão: Backlog · Refinement · Ready · In progress · In review · Done)."

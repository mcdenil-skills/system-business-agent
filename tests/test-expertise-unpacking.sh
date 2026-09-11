#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/skills/expertise-unpacking/SKILL.md"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

require_text() {
  local pattern="$1"
  local meaning="$2"
  rg -qi "$pattern" "$SKILL" || fail "$meaning"
}

[[ -f "$SKILL" ]] || fail "missing expertise-unpacking/SKILL.md"

require_text '^name: expertise-unpacking$' "wrong skill name"
require_text 'Специалист' "missing specialist route"
require_text 'Предприниматель' "missing entrepreneur route"
require_text 'Смешанный маршрут' "missing mixed route"
require_text 'один вопрос' "missing one-question-at-a-time rule"
require_text 'профессиональн.*путь' "missing professional history"
require_text 'личн.*вклад' "missing personal contribution check"
require_text 'предпринимательск.*капитал' "missing entrepreneur capital"
require_text 'AI-компетенц|AI-навык' "missing AI maturity branch"
require_text 'факт.*гипотез|гипотез.*факт' "missing fact versus hypothesis rule"
require_text 'подтвержден' "missing confirmation gate"
require_text 'Навигационные плашки' "missing guided onboarding"
require_text 'Свой вариант' "missing free-form option"
require_text 'обычным нумерованным сообщением' "missing text fallback"
require_text 'не показывай её на каждом вопросе' "missing popup restraint"
require_text 'knowledge/my-expertise\.md' "missing canonical Markdown result"
require_text 'knowledge/my-expertise\.html' "missing HTML view"
require_text 'не.*контентн.*стратег|контентн.*стратег.*не' "missing content boundary"
require_text 'не.*выбира.*продукт|продукт.*не.*выбира' "missing product-selection boundary"

printf 'PASS: expertise-unpacking structure\n'

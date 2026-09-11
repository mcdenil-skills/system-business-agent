#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/skills/product-selection/SKILL.md"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

require_text() {
  local pattern="$1"
  local meaning="$2"
  rg -qi "$pattern" "$SKILL" || fail "$meaning"
}

[[ -f "$SKILL" ]] || fail "missing product-selection/SKILL.md"

require_text '^name: product-selection$' "wrong skill name"
require_text 'knowledge/my-expertise\.md' "missing expertise input"
require_text 'knowledge/product-choice\.md' "missing working file"
require_text 'knowledge/my-product\.md' "missing canonical product file"
require_text 'knowledge/my-product\.html' "missing interactive HTML file"
require_text 'одн.*главн.*гипотез.*одн.*дв.*запасн|одн.*главн.*и.*1.?2.*запасн' "missing hypothesis limit"
require_text 'Люди ищут' "missing search-demand signal"
require_text 'Люди испытывают проблему' "missing problem signal"
require_text 'Люди.*платят|платные решения' "missing spending signal"
require_text 'прям.*ссылк|прям.*URL' "missing direct-source rule"
require_text 'дата.*доступ|дата проверки' "missing source date"
require_text 'что.*не подтвержда' "missing evidence boundary"
require_text 'Вордстат' "missing Wordstat research"
require_text 'скриншот|скопированн.*результат' "missing manual Wordstat fallback"
require_text 'не.*обход.*капч|капч.*не.*обход' "missing anti-bot safety rule"
require_text 'ситуаци.*желаем.*прогресс.*препятств.*альтернатив' "missing lightweight JTBD chain"
require_text 'Семь вопросов|7 вопросов' "missing seven-question interview"
require_text 'Последний реальный случай' "missing last-real-case question"
require_text 'минимум.*тр[её]х.*интервью|тр[её]х.*независим.*интервью' "missing three-interview threshold"
require_text 'предоплат' "missing prepayment test"
require_text 'подтвержд[её]н деньгами' "missing money-confirmed status"
require_text 'не.*product.market fit|не.*устойчив.*спрос' "missing one-sale limitation"
require_text 'без внешних библиотек|не подключай внешние' "missing standalone HTML rule"
require_text 'Кратко.*Подробно' "missing HTML detail switch"
require_text 'печать|PDF' "missing print support"
require_text 'покаж.*сохран|подтвержд.*сохран' "missing confirmation before memory write"
require_text 'плашк' "missing guided choice panels"
require_text 'нумерованн.*сообщен|нумерованн.*спис' "missing text UI fallback"
require_text 'Claude.*Codex|Codex.*Claude' "missing cross-client compatibility"

printf 'PASS: product-selection structure\n'

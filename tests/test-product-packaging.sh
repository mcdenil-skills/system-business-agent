#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/skills/product-packaging/SKILL.md"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

require_text() {
  rg -qi "$1" "$SKILL" || fail "$2"
}

[[ -f "$SKILL" ]] || fail "missing product-packaging/SKILL.md"
[[ "$(find "$ROOT/skills/product-packaging" -type f | wc -l | tr -d ' ')" == "1" ]] || fail "skill must contain only SKILL.md"
[[ "$(wc -l < "$SKILL" | tr -d ' ')" -lt 500 ]] || fail "skill exceeds progressive-disclosure limit"

require_text '^name: product-packaging$' "wrong skill name"
require_text '^description:.*выбранный продукт' "missing narrow trigger"
require_text 'knowledge/my-expertise\.md' "missing expertise input"
require_text 'knowledge/product-choice\.md' "missing selection input"
require_text 'knowledge/my-product\.md' "missing canonical Markdown"
require_text 'knowledge/my-product\.html' "missing derived HTML"
require_text 'Если есть только навыки' "missing missing-product route"
require_text 'предложи.*product-selection' "missing selection handoff"
require_text 'реально существующий продукт' "missing existing-business route"
require_text 'один вопрос за раз' "missing guided interview"
require_text 'нумерованн.*сообщен' "missing native-question fallback"
require_text 'критери.*при[её]мки' "missing observable acceptance"
require_text 'что НЕ входит|что входит и не входит' "missing exclusions"
require_text 'участие клиента' "missing client dependencies"
require_text 'трудозатрат.*прямые расходы' "missing pricing feasibility"
require_text 'не.*универсальн|универсальные нормы' "missing non-universal pricing guard"
require_text 'не повышает статус' "packaging must not validate demand"
require_text 'не.*устойчивый спрос|не.*product.market fit' "missing one-payment limitation"
require_text 'В одну строку' "missing one-liner"
require_text '3-5.*предложен' "missing short description"
require_text 'Полное предложение' "missing full description"
require_text 'Мой лид-магнит.*Путь клиента' "missing unrelated-section preservation"
require_text 'не переписывай весь' "missing precise memory updates"
require_text 'без внешних библиотек' "missing autonomous HTML"
require_text 'Кратко.*Подробно' "missing detail switch"
require_text 'Clipboard API' "missing copy fallback"
require_text 'печати.*PDF|печати или сохранения в PDF' "missing print"
require_text 'экранируй' "missing untrusted-text safety"
require_text 'Claude Code.*Codex' "missing cross-client compatibility"

rg -q 'product-packaging.*не установлен' "$ROOT/AGENTS.md" || fail "missing registry entry"
rg -q 'Упаковка продукта.*product-packaging' "$ROOT/skills/installer/SKILL.md" || fail "missing installer alias"
rg -q 'Упакуй мой выбранный продукт' "$ROOT/README.md" || fail "missing run prompt"

# Local layout smoke test, not a live GitHub download or model-behaviour test.
TEST_WORKSPACE="$(mktemp -d)"
mkdir -p "$TEST_WORKSPACE/knowledge" "$TEST_WORKSPACE/memory"
cp "$ROOT/USER.md" "$ROOT/MEMORY.md" "$ROOT/SOUL.md" "$TEST_WORKSPACE/"
cp "$ROOT/knowledge/README.md" "$TEST_WORKSPACE/knowledge/"
before="$(find "$TEST_WORKSPACE" -type f -exec shasum -a 256 {} \; | sort)"
for attempt in 1 2; do
  for client in .claude .codex; do
    mkdir -p "$TEST_WORKSPACE/$client/skills/product-packaging"
    cp -R "$ROOT/skills/product-packaging/." "$TEST_WORKSPACE/$client/skills/product-packaging/"
  done
done
cmp -s "$SKILL" "$TEST_WORKSPACE/.claude/skills/product-packaging/SKILL.md" || fail "Claude copy differs"
cmp -s "$SKILL" "$TEST_WORKSPACE/.codex/skills/product-packaging/SKILL.md" || fail "Codex copy differs"
after="$(find "$TEST_WORKSPACE" -type f ! -path '*/.claude/*' ! -path '*/.codex/*' -exec shasum -a 256 {} \; | sort)"
[[ "$before" == "$after" ]] || fail "local skill copy changed private memory"
[[ "$(find "$TEST_WORKSPACE/.claude/skills" "$TEST_WORKSPACE/.codex/skills" -type f | wc -l | tr -d ' ')" == "2" ]] || fail "duplicate skill files"

printf 'PASS: product-packaging structure and local two-client layout; model behaviour covered by separate evals\n'

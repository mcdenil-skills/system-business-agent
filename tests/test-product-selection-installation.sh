#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_INSTALLER="$ROOT/skills/installer"
SOURCE_SKILL="$ROOT/skills/product-selection"
TEST_HOME="$(mktemp -d)"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

source_file_count="$(find "$SOURCE_SKILL" -type f | wc -l | tr -d ' ')"
[[ "$source_file_count" == "1" ]] || fail "published skill must contain only SKILL.md"

cp "$ROOT/AGENTS.md" "$ROOT/CLAUDE.md" "$ROOT/MEMORY.md" "$ROOT/README.md" "$ROOT/SOUL.md" "$ROOT/USER.md" "$TEST_HOME/"
cp -R "$ROOT/knowledge" "$ROOT/memory" "$TEST_HOME/"
mkdir -p "$TEST_HOME/.claude/skills/installer" "$TEST_HOME/.codex/skills/installer"
cp -R "$SOURCE_INSTALLER/." "$TEST_HOME/.claude/skills/installer/"
cp -R "$SOURCE_INSTALLER/." "$TEST_HOME/.codex/skills/installer/"

printf '\nПРОВЕРКА-USER-НЕ-МЕНЯТЬ\n' >> "$TEST_HOME/USER.md"
printf '\nПРОВЕРКА-MEMORY-НЕ-МЕНЯТЬ\n' >> "$TEST_HOME/MEMORY.md"
printf 'ПРОВЕРКА-KNOWLEDGE-НЕ-МЕНЯТЬ\n' > "$TEST_HOME/knowledge/private-note.md"

user_before="$(shasum -a 256 "$TEST_HOME/USER.md" | awk '{print $1}')"
memory_before="$(shasum -a 256 "$TEST_HOME/MEMORY.md" | awk '{print $1}')"
knowledge_before="$(shasum -a 256 "$TEST_HOME/knowledge/private-note.md" | awk '{print $1}')"

install_skill() {
  mkdir -p "$TEST_HOME/.claude/skills/product-selection" "$TEST_HOME/.codex/skills/product-selection"
  cp -R "$SOURCE_SKILL/." "$TEST_HOME/.claude/skills/product-selection/"
  cp -R "$SOURCE_SKILL/." "$TEST_HOME/.codex/skills/product-selection/"
}

install_skill
install_skill

[[ -f "$TEST_HOME/.claude/skills/product-selection/SKILL.md" ]] || fail "Claude skill missing"
[[ -f "$TEST_HOME/.codex/skills/product-selection/SKILL.md" ]] || fail "Codex skill missing"
cmp -s "$TEST_HOME/.claude/skills/product-selection/SKILL.md" "$TEST_HOME/.codex/skills/product-selection/SKILL.md" || fail "skill copies differ"
cmp -s "$TEST_HOME/.claude/skills/installer/SKILL.md" "$TEST_HOME/.codex/skills/installer/SKILL.md" || fail "installer copies differ"
rg -q 'product-selection' "$TEST_HOME/.claude/skills/installer/SKILL.md" || fail "installer does not list product-selection"
rg -q 'Помоги выбрать и проверить мой первый продукт' "$TEST_HOME/.claude/skills/installer/SKILL.md" || fail "installer lacks verification phrase"
rg -q 'product-selection.*не установлен' "$TEST_HOME/AGENTS.md" || fail "agent registry lacks product-selection"

user_after="$(shasum -a 256 "$TEST_HOME/USER.md" | awk '{print $1}')"
memory_after="$(shasum -a 256 "$TEST_HOME/MEMORY.md" | awk '{print $1}')"
knowledge_after="$(shasum -a 256 "$TEST_HOME/knowledge/private-note.md" | awk '{print $1}')"

[[ "$user_before" == "$user_after" ]] || fail "USER.md changed"
[[ "$memory_before" == "$memory_after" ]] || fail "MEMORY.md changed"
[[ "$knowledge_before" == "$knowledge_after" ]] || fail "knowledge changed"

skill_count="$(find "$TEST_HOME/.claude/skills" "$TEST_HOME/.codex/skills" -mindepth 1 -maxdepth 1 -type d -name product-selection | wc -l | tr -d ' ')"
[[ "$skill_count" == "2" ]] || fail "duplicate skill directories created"

printf 'PASS: product-selection installs in both environments without changing memory\n'

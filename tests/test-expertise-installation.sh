#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AGENT="$ROOT"
SOURCE_INSTALLER="$ROOT/skills/installer"
SOURCE_SKILL="$ROOT/skills/expertise-unpacking"
TEST_HOME="$(mktemp -d)"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

cp "$AGENT/AGENTS.md" "$AGENT/CLAUDE.md" "$AGENT/MEMORY.md" "$AGENT/README.md" "$AGENT/SOUL.md" "$AGENT/USER.md" "$TEST_HOME/"
cp -R "$AGENT/knowledge" "$AGENT/memory" "$TEST_HOME/"
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
  mkdir -p "$TEST_HOME/.claude/skills/expertise-unpacking" "$TEST_HOME/.codex/skills/expertise-unpacking"
  cp -R "$SOURCE_SKILL/." "$TEST_HOME/.claude/skills/expertise-unpacking/"
  cp -R "$SOURCE_SKILL/." "$TEST_HOME/.codex/skills/expertise-unpacking/"
}

install_skill
install_skill

[[ -f "$TEST_HOME/.claude/skills/expertise-unpacking/SKILL.md" ]] || fail "Claude skill missing"
[[ -f "$TEST_HOME/.codex/skills/expertise-unpacking/SKILL.md" ]] || fail "Codex skill missing"
cmp -s "$TEST_HOME/.claude/skills/expertise-unpacking/SKILL.md" "$TEST_HOME/.codex/skills/expertise-unpacking/SKILL.md" || fail "skill copies differ"
cmp -s "$TEST_HOME/.claude/skills/installer/SKILL.md" "$TEST_HOME/.codex/skills/installer/SKILL.md" || fail "installer copies differ"

user_after="$(shasum -a 256 "$TEST_HOME/USER.md" | awk '{print $1}')"
memory_after="$(shasum -a 256 "$TEST_HOME/MEMORY.md" | awk '{print $1}')"
knowledge_after="$(shasum -a 256 "$TEST_HOME/knowledge/private-note.md" | awk '{print $1}')"

[[ "$user_before" == "$user_after" ]] || fail "USER.md changed"
[[ "$memory_before" == "$memory_after" ]] || fail "MEMORY.md changed"
[[ "$knowledge_before" == "$knowledge_after" ]] || fail "knowledge changed"

skill_count="$(find "$TEST_HOME/.claude/skills" "$TEST_HOME/.codex/skills" -mindepth 1 -maxdepth 1 -type d -name expertise-unpacking | wc -l | tr -d ' ')"
[[ "$skill_count" == "2" ]] || fail "duplicate skill directories created"

printf 'PASS: expertise-unpacking installs in both environments without changing memory\n'

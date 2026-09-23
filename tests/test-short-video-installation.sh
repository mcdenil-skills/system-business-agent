#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_INSTALLER="$ROOT/skills/installer"
SOURCE_SKILL="$ROOT/skills/short-video-scriptwriter"
TEST_HOME="$(mktemp -d)"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[[ -f "$SOURCE_SKILL/SKILL.md" ]] || fail "short-video-scriptwriter is absent"
[[ "$(find "$SOURCE_SKILL" -type f | wc -l | tr -d ' ')" == "1" ]] || fail "published skill must contain only SKILL.md"
[[ "$(wc -l < "$SOURCE_SKILL/SKILL.md" | tr -d ' ')" -lt 500 ]] || fail "skill exceeds progressive-disclosure limit"

cp "$ROOT/AGENTS.md" "$ROOT/CLAUDE.md" "$ROOT/MEMORY.md" "$ROOT/README.md" "$ROOT/SOUL.md" "$ROOT/USER.md" "$TEST_HOME/"
cp -R "$ROOT/knowledge" "$ROOT/memory" "$TEST_HOME/"
mkdir -p "$TEST_HOME/.claude/skills/installer" "$TEST_HOME/.codex/skills/installer"
cp -R "$SOURCE_INSTALLER/." "$TEST_HOME/.claude/skills/installer/"
cp -R "$SOURCE_INSTALLER/." "$TEST_HOME/.codex/skills/installer/"

printf '\nПРОВЕРКА-USER-НЕ-МЕНЯТЬ\n' >> "$TEST_HOME/USER.md"
printf '\nПРОВЕРКА-MEMORY-НЕ-МЕНЯТЬ\n' >> "$TEST_HOME/MEMORY.md"
printf 'ПРОВЕРКА-KNOWLEDGE-НЕ-МЕНЯТЬ\n' > "$TEST_HOME/knowledge/private-note.md"

private_before="$(find "$TEST_HOME/knowledge" "$TEST_HOME/memory" "$TEST_HOME/USER.md" "$TEST_HOME/MEMORY.md" "$TEST_HOME/SOUL.md" -type f -exec shasum -a 256 {} \; | sort)"

install_skill() {
  for client in .claude .codex; do
    mkdir -p "$TEST_HOME/$client/skills/short-video-scriptwriter"
    cp -R "$SOURCE_SKILL/." "$TEST_HOME/$client/skills/short-video-scriptwriter/"
  done
}

install_skill
install_skill

[[ -f "$TEST_HOME/.claude/skills/short-video-scriptwriter/SKILL.md" ]] || fail "Claude skill missing"
[[ -f "$TEST_HOME/.codex/skills/short-video-scriptwriter/SKILL.md" ]] || fail "Codex skill missing"
cmp -s "$TEST_HOME/.claude/skills/short-video-scriptwriter/SKILL.md" "$TEST_HOME/.codex/skills/short-video-scriptwriter/SKILL.md" || fail "Claude and Codex copies differ"
cmp -s "$SOURCE_SKILL/SKILL.md" "$TEST_HOME/.codex/skills/short-video-scriptwriter/SKILL.md" || fail "installed copy differs from the store"

private_after="$(find "$TEST_HOME/knowledge" "$TEST_HOME/memory" "$TEST_HOME/USER.md" "$TEST_HOME/MEMORY.md" "$TEST_HOME/SOUL.md" -type f -exec shasum -a 256 {} \; | sort)"
[[ "$private_before" == "$private_after" ]] || fail "skill installation changed private memory"

rg -q 'short-video-scriptwriter.*не установлен' "$TEST_HOME/AGENTS.md" || fail "agent registry lacks the skill"
rg -q 'Коротк.*ролик.*short-video-scriptwriter.*доступен|Вирусн.*ролик.*short-video-scriptwriter.*доступен' "$TEST_HOME/.claude/skills/installer/SKILL.md" || fail "installer lacks the official alias"
rg -q 'Помоги придумать и написать мой короткий ролик' "$TEST_HOME/.codex/skills/installer/SKILL.md" || fail "installer lacks the verification phrase"

printf 'PASS: short-video-scriptwriter installs identically in Claude and Codex without changing memory\n'

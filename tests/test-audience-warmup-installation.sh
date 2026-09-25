#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_INSTALLER="$ROOT/skills/installer"
SOURCE_SKILL="$ROOT/skills/audience-warmup"
TEST_HOME="$(mktemp -d)"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[[ -f "$SOURCE_SKILL/SKILL.md" ]] || fail "audience-warmup is absent"

cp "$ROOT/AGENTS.md" "$ROOT/CLAUDE.md" "$ROOT/MEMORY.md" "$ROOT/README.md" "$ROOT/SOUL.md" "$ROOT/USER.md" "$TEST_HOME/"
cp -R "$ROOT/knowledge" "$ROOT/memory" "$TEST_HOME/"
for client in .claude .codex; do
  mkdir -p "$TEST_HOME/$client/skills/installer"
  cp -R "$SOURCE_INSTALLER/." "$TEST_HOME/$client/skills/installer/"
done

printf '\nПРОВЕРКА-USER-НЕ-МЕНЯТЬ\n' >> "$TEST_HOME/USER.md"
printf '\nПРОВЕРКА-MEMORY-НЕ-МЕНЯТЬ\n' >> "$TEST_HOME/MEMORY.md"
printf 'ПРОВЕРКА-KNOWLEDGE-НЕ-МЕНЯТЬ\n' > "$TEST_HOME/knowledge/private-note.md"
printf '# Старый план\nНе трогать\n' > "$TEST_HOME/knowledge/warmup-plan.md"

private_before="$(find "$TEST_HOME/knowledge" "$TEST_HOME/memory" "$TEST_HOME/USER.md" "$TEST_HOME/MEMORY.md" "$TEST_HOME/SOUL.md" -type f -exec shasum -a 256 {} \; | sort)"

install_skill() {
  for client in .claude .codex; do
    mkdir -p "$TEST_HOME/$client/skills/audience-warmup"
    cp -R "$SOURCE_SKILL/." "$TEST_HOME/$client/skills/audience-warmup/"
  done
}

install_skill
install_skill

diff -qr "$SOURCE_SKILL" "$TEST_HOME/.claude/skills/audience-warmup" >/dev/null || fail "Claude copy differs from the store"
diff -qr "$TEST_HOME/.claude/skills/audience-warmup" "$TEST_HOME/.codex/skills/audience-warmup" >/dev/null || fail "Claude and Codex copies differ"
[[ -f "$TEST_HOME/.codex/skills/audience-warmup/assets/warmup-plan-template.html" ]] || fail "template missing in Codex copy"
[[ -f "$TEST_HOME/.claude/skills/audience-warmup/references/technologies.md" ]] || fail "references missing in Claude copy"

private_after="$(find "$TEST_HOME/knowledge" "$TEST_HOME/memory" "$TEST_HOME/USER.md" "$TEST_HOME/MEMORY.md" "$TEST_HOME/SOUL.md" -type f -exec shasum -a 256 {} \; | sort)"
[[ "$private_before" == "$private_after" ]] || fail "skill installation changed private memory"

skill_count="$(find "$TEST_HOME/.claude/skills" "$TEST_HOME/.codex/skills" -mindepth 1 -maxdepth 1 -type d -name audience-warmup | wc -l | tr -d ' ')"
[[ "$skill_count" == "2" ]] || fail "duplicate skill directories created"

rg -q 'audience-warmup.*не установлен' "$TEST_HOME/AGENTS.md" || fail "agent registry lacks the skill"
rg -q 'Прогрев аудитории.*audience-warmup.*доступен' "$TEST_HOME/.claude/skills/installer/SKILL.md" || fail "installer lacks the official alias"
rg -q 'Помоги сделать прогрев и контент-план' "$TEST_HOME/.codex/skills/installer/SKILL.md" || fail "installer lacks the verification phrase"

printf 'PASS: audience-warmup installs identically in Claude and Codex without changing memory\n'

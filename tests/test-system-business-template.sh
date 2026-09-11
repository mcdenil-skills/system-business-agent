#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AGENT="$ROOT"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

for path in AGENTS.md CLAUDE.md SOUL.md USER.md MEMORY.md README.md memory/.gitkeep knowledge/README.md; do
  [[ -f "$AGENT/$path" ]] || fail "missing $path"
done

rg -q '^@AGENTS\.md$' "$AGENT/CLAUDE.md" || fail "CLAUDE.md does not load AGENTS.md"

if rg -qi 'продюсер контента|про что снимать|контент-стратег' "$AGENT/AGENTS.md" "$AGENT/SOUL.md" "$AGENT/README.md"; then
  fail "content-agent role leaked into system-business"
fi

INSTALLER="$AGENT/skills/installer/SKILL.md"

[[ -f "$INSTALLER" ]] || fail "missing canonical installer"
[[ ! -e "$AGENT/.claude/skills/installer/SKILL.md" ]] || fail "source repository contains duplicate Claude installer"
[[ ! -e "$AGENT/.codex/skills/installer/SKILL.md" ]] || fail "source repository contains duplicate Codex installer"

rg -q 'mcdenil-skills/system-business-agent' "$INSTALLER" || fail "wrong public repository"
rg -qi 'Распаковка профессиональной экспертности.*expertise-unpacking|expertise-unpacking.*Распаковка профессиональной экспертности' "$INSTALLER" || fail "missing expertise-unpacking alias"
rg -q '\.claude/skills/<name>' "$INSTALLER" || fail "missing Claude destination"
rg -q '\.codex/skills/<name>' "$INSTALLER" || fail "missing Codex destination"
rg -qi 'не изменяй.*USER\.md|USER\.md.*не изменяй' "$INSTALLER" || fail "missing memory protection"

printf 'PASS: system-business template and canonical skill store\n'

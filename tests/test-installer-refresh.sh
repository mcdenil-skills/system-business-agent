#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REFRESH="$ROOT/skills/installer/scripts/refresh-official-installer.sh"
WORK="$(mktemp -d)"
AGENT="$WORK/agent"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

mkdir -p "$AGENT/.claude/skills/installer" "$AGENT/.codex/skills/installer" "$AGENT/memory" "$AGENT/knowledge"
printf '# Agent\n' > "$AGENT/AGENTS.md"
printf '# User\nИван\n' > "$AGENT/USER.md"
printf '# Memory\nПроверенный факт\n' > "$AGENT/MEMORY.md"
printf '# Day\nСтарая запись\n' > "$AGENT/memory/2026-09-23.md"
printf '# Knowledge\nМатериал участника\n' > "$AGENT/knowledge/private.md"

cat > "$AGENT/.claude/skills/installer/SKILL.md" <<'EOF'
---
name: installer
description: Старая тестовая версия без новых официальных скиллов.
---

# Старый каталог

Доступны только три старых скилла.
EOF
cp "$AGENT/.claude/skills/installer/SKILL.md" "$AGENT/.codex/skills/installer/SKILL.md"

before_user="$(shasum -a 256 "$AGENT/USER.md")"
before_memory="$(shasum -a 256 "$AGENT/MEMORY.md")"
before_day="$(shasum -a 256 "$AGENT/memory/2026-09-23.md")"
before_knowledge="$(shasum -a 256 "$AGENT/knowledge/private.md")"

[[ -f "$REFRESH" ]] || fail "missing installer refresh script"
INSTALLER_SOURCE_DIR="$ROOT/skills/installer" bash "$REFRESH" "$AGENT"

diff -qr "$ROOT/skills/installer" "$AGENT/.claude/skills/installer" >/dev/null || fail "Claude installer was not refreshed exactly"
diff -qr "$AGENT/.claude/skills/installer" "$AGENT/.codex/skills/installer" >/dev/null || fail "Claude and Codex installers differ after refresh"
rg -q 'short-video-scriptwriter' "$AGENT/.claude/skills/installer/SKILL.md" || fail "refreshed catalog still misses short-video-scriptwriter"
rg -q 'audience-warmup' "$AGENT/.claude/skills/installer/SKILL.md" || fail "refreshed catalog still misses audience-warmup"

[[ "$before_user" == "$(shasum -a 256 "$AGENT/USER.md")" ]] || fail "USER.md changed during refresh"
[[ "$before_memory" == "$(shasum -a 256 "$AGENT/MEMORY.md")" ]] || fail "MEMORY.md changed during refresh"
[[ "$before_day" == "$(shasum -a 256 "$AGENT/memory/2026-09-23.md")" ]] || fail "daily memory changed during refresh"
[[ "$before_knowledge" == "$(shasum -a 256 "$AGENT/knowledge/private.md")" ]] || fail "knowledge changed during refresh"

printf 'PASS: stale installer refreshes identically for Claude and Codex without changing user memory\n'

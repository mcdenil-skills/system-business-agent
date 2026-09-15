#!/usr/bin/env bash
set -euo pipefail

# Explicit release check; requires network. No deletion of temporary workspaces.
INSTALL_SOURCE="${1:-https://github.com/mcdenil-skills/system-business-agent.git}"
INSTALL_CHECK_DIR="$(mktemp -d)"
git clone --depth 1 "$INSTALL_SOURCE" "$INSTALL_CHECK_DIR/store"
STORE="$INSTALL_CHECK_DIR/store"
STUDENT="$INSTALL_CHECK_DIR/student"
mkdir -p "$STUDENT"

for path in AGENTS.md CLAUDE.md SOUL.md USER.md MEMORY.md README.md .gitignore; do
  cp "$STORE/$path" "$STUDENT/"
done
cp -R "$STORE/knowledge" "$STORE/memory" "$STUDENT/"
for client in .claude .codex; do
  mkdir -p "$STUDENT/$client/skills/installer"
  cp -R "$STORE/skills/installer/." "$STUDENT/$client/skills/installer/"
done

[[ ! -e "$STUDENT/.git" ]] || { printf 'FAIL: Git history copied\n'; exit 1; }
[[ ! -e "$STUDENT/skills" ]] || { printf 'FAIL: entire store copied\n'; exit 1; }
[[ "$(find "$STUDENT/.claude/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" == "1" ]]
rg -q 'Упаковка продукта.*product-packaging.*доступен' "$STUDENT/.claude/skills/installer/SKILL.md"

private_before="$(find "$STUDENT/knowledge" "$STUDENT/memory" "$STUDENT/USER.md" "$STUDENT/MEMORY.md" "$STUDENT/SOUL.md" -type f -exec shasum -a 256 {} \; | sort)"

# Same sparse download and destinations as the prompt-driven installer.
git clone --no-checkout --depth 1 "$INSTALL_SOURCE" "$INSTALL_CHECK_DIR/sparse"
git -C "$INSTALL_CHECK_DIR/sparse" sparse-checkout init --no-cone
git -C "$INSTALL_CHECK_DIR/sparse" sparse-checkout set /skills/product-packaging/
git -C "$INSTALL_CHECK_DIR/sparse" checkout main
for client in .claude .codex; do
  mkdir -p "$STUDENT/$client/skills/product-packaging"
  cp -R "$INSTALL_CHECK_DIR/sparse/skills/product-packaging/." "$STUDENT/$client/skills/product-packaging/"
done
cmp -s "$STUDENT/.claude/skills/product-packaging/SKILL.md" "$STUDENT/.codex/skills/product-packaging/SKILL.md"
cmp -s "$STORE/skills/product-packaging/SKILL.md" "$STUDENT/.codex/skills/product-packaging/SKILL.md"
private_after="$(find "$STUDENT/knowledge" "$STUDENT/memory" "$STUDENT/USER.md" "$STUDENT/MEMORY.md" "$STUDENT/SOUL.md" -type f -exec shasum -a 256 {} \; | sort)"
[[ "$private_before" == "$private_after" ]] || { printf 'FAIL: private memory changed\n'; exit 1; }

printf 'PASS: fresh download, installer-only base, sparse skill download, matching Claude/Codex copies, unchanged memory\n'
git -C "$STORE" rev-parse HEAD

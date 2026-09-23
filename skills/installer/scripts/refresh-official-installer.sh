#!/usr/bin/env bash
set -euo pipefail

agent_root="${1:-$PWD}"
official_repo="https://github.com/mcdenil-skills/system-business-agent.git"

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

[[ -d "$agent_root" ]] || fail "папка агента не найдена: $agent_root"
[[ "$agent_root" != "/" ]] || fail "корень диска нельзя использовать как папку агента"
[[ -f "$agent_root/AGENTS.md" ]] || fail "в папке нет AGENTS.md"
[[ -f "$agent_root/USER.md" ]] || fail "в папке нет USER.md"
[[ -f "$agent_root/MEMORY.md" ]] || fail "в папке нет MEMORY.md"

refresh_tmp_dir="$(mktemp -d)"
source_version="local-source"

if [[ -n "${INSTALLER_SOURCE_DIR:-}" ]]; then
  source_dir="$INSTALLER_SOURCE_DIR"
else
  git clone --no-checkout --depth 1 "$official_repo" "$refresh_tmp_dir/store" >/dev/null
  git -C "$refresh_tmp_dir/store" sparse-checkout init --no-cone
  printf '/skills/installer/\n' > "$refresh_tmp_dir/store/.git/info/sparse-checkout"
  git -C "$refresh_tmp_dir/store" checkout main >/dev/null
  source_dir="$refresh_tmp_dir/store/skills/installer"
  source_version="$(git -C "$refresh_tmp_dir/store" rev-parse HEAD)"
fi

[[ -f "$source_dir/SKILL.md" ]] || fail "в официальном источнике нет installer/SKILL.md"
[[ -f "$source_dir/scripts/refresh-official-installer.sh" ]] || fail "официальная версия установщика неполная"
grep -q '^name: installer$' "$source_dir/SKILL.md" || fail "проверка имени официального установщика не пройдена"

restore_previous_installers() {
  local client backup destination failed_copy
  for client in .claude .codex; do
    backup="$refresh_tmp_dir/${client#.}-backup"
    destination="$agent_root/$client/skills/installer"
    failed_copy="$refresh_tmp_dir/${client#.}-failed"
    if [[ -d "$backup" ]]; then
      if [[ -d "$destination" ]]; then
        mv "$destination" "$failed_copy"
      fi
      mkdir -p "$agent_root/$client/skills"
      mv "$backup" "$destination"
    fi
  done
}

trap restore_previous_installers ERR

for client in .claude .codex; do
  destination="$agent_root/$client/skills/installer"
  backup="$refresh_tmp_dir/${client#.}-backup"
  mkdir -p "$agent_root/$client/skills"
  if [[ -d "$destination" ]]; then
    mv "$destination" "$backup"
  fi
  cp -R "$source_dir" "$destination"
done

diff -qr "$agent_root/.claude/skills/installer" "$agent_root/.codex/skills/installer" >/dev/null || fail "версии установщика для Claude и Codex различаются"
trap - ERR

printf 'UPDATED_INSTALLER_VERSION=%s\n' "$source_version"

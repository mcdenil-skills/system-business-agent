#!/usr/bin/env bash
set -euo pipefail

PRODUCT_LINE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Layout smoke test plus the real refresh script. This does not simulate a model
# following the installer or a published GitHub installation.
python3 - "$PRODUCT_LINE_ROOT" <<'PY'
from pathlib import Path
import hashlib
import os
import shutil
import subprocess
import sys
import tempfile

root = Path(sys.argv[1])
source = root / 'skills/product-line'
assert (source / 'SKILL.md').is_file(), 'missing product-line source package'
work = Path(tempfile.mkdtemp(prefix='product-line-install-'))
protected = ['USER.md', 'MEMORY.md', 'SOUL.md', 'memory', 'knowledge']

def hashes(paths):
    result = {}
    for start in paths:
        for path in ([start] if start.is_file() else start.rglob('*')):
            if path.is_file():
                result[str(path)] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result

def package_hashes(path):
    return {str(p.relative_to(path)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in path.rglob('*') if p.is_file()}

for edition in ['old', 'new']:
    agent = work / edition
    agent.mkdir()
    for name in ['AGENTS.md', 'CLAUDE.md', 'USER.md', 'MEMORY.md', 'SOUL.md']:
        shutil.copy2(root / name, agent / name)
    for name in ['memory', 'knowledge']:
        shutil.copytree(root / name, agent / name)
    (agent / 'knowledge/nested').mkdir()
    (agent / 'knowledge/nested/private.md').write_text('Личная заметка ученика <не менять>\n')
    (agent / 'memory/2026-10-17.md').write_text('Ранее принятое решение\n')
    for name in ['USER.md', 'MEMORY.md', 'SOUL.md']:
        with (agent / name).open('a') as f:
            f.write('\nСохранить этот фрагмент при установке.\n')
    if edition == 'old':
        registry = (agent / 'AGENTS.md').read_text()
        (agent / 'AGENTS.md').write_text('\n'.join(line for line in registry.splitlines() if '`product-line`' not in line) + '\n')
    for client in ['.claude', '.codex']:
        installer = agent / client / 'skills/installer'
        installer.mkdir(parents=True)
        if edition == 'old':
            (installer / 'SKILL.md').write_text('---\nname: installer\ndescription: Старый каталог\n---\nТолько старые скиллы.\n')
            (installer / 'obsolete-marker.txt').write_text('старый файл не должен остаться после refresh')
        else:
            shutil.copytree(root / 'skills/installer', installer, dirs_exist_ok=True)
    before = hashes([agent / name for name in protected])
    env = dict(os.environ, INSTALLER_SOURCE_DIR=str(root / 'skills/installer'))
    subprocess.run(['bash', str(root / 'skills/installer/scripts/refresh-official-installer.sh'), str(agent)], env=env, check=True, capture_output=True)
    for client in ['.claude', '.codex']:
        assert package_hashes(agent / client / 'skills/installer') == package_hashes(root / 'skills/installer'), f'{edition}: installer refresh not exact'
        assert 'product-line' in (agent / client / 'skills/installer/SKILL.md').read_text(), f'{edition}: new skill absent from refreshed catalog'
    for attempt in range(2):
        for client in ['.claude', '.codex']:
            destination = agent / client / 'skills/product-line'
            shutil.copytree(source, destination, dirs_exist_ok=True)
            assert package_hashes(destination) == package_hashes(source), f'{edition}: installation differs from canonical source'
    assert hashes([agent / name for name in protected]) == before, f'{edition}: private files changed'
    assert not (agent / 'skills').exists() and not (agent / '.git').exists(), f'{edition}: repository internals leaked into student agent'
    assert len(list(agent.glob('.*/skills/product-line/SKILL.md'))) == 2, f'{edition}: duplicate or missing skill'
print('PASS: old/new agent refresh, repeatable two-client package layout and unchanged USER/MEMORY/SOUL/nested knowledge/diaries')
PY

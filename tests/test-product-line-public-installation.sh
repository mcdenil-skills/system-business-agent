#!/usr/bin/env bash
set -euo pipefail

# Explicit release check, not a model-behavior test. Requires network.
# Repeats the documented refresh/sparse-copy path against published main.
python3 - "${1:-https://github.com/mcdenil-skills/system-business-agent.git}" <<'PY'
from pathlib import Path
import hashlib
import os
import shutil
import subprocess
import sys
import tempfile

remote = sys.argv[1]
work = Path(tempfile.mkdtemp(prefix='product-line-public-install-'))
store = work / 'store'
subprocess.run(['git', 'clone', '--depth', '1', '--branch', 'main', remote, str(store)], check=True)
commit = subprocess.check_output(['git', '-C', str(store), 'rev-parse', 'HEAD'], text=True).strip()

def hashes(path):
    return {str(p.relative_to(path)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in path.rglob('*') if p.is_file()}

def private_hashes(agent):
    return {name: hashes(agent / name) if (agent / name).is_dir()
            else hashlib.sha256((agent / name).read_bytes()).hexdigest()
            for name in ['USER.md', 'MEMORY.md', 'SOUL.md', 'memory', 'knowledge']}

package = store / 'skills/product-line'
assert (package / 'SKILL.md').is_file(), 'product-line is not published'
expected = hashes(package)
assert len(expected) == 5, 'incomplete published package'
sparse = work / 'sparse'
subprocess.run(['git', 'clone', '--no-checkout', '--depth', '1', '--branch', 'main', remote, str(sparse)], check=True)
subprocess.run(['git', '-C', str(sparse), 'sparse-checkout', 'init', '--no-cone'], check=True)
subprocess.run(['git', '-C', str(sparse), 'sparse-checkout', 'set', '/skills/product-line/'], check=True)
subprocess.run(['git', '-C', str(sparse), 'checkout', 'main'], check=True)
assert subprocess.check_output(['git', '-C', str(sparse), 'rev-parse', 'HEAD'], text=True).strip() == commit, 'main changed during test; retry'

for edition in ['old', 'new']:
    agent = work / edition
    agent.mkdir()
    for name in ['AGENTS.md', 'CLAUDE.md', 'SOUL.md', 'USER.md', 'MEMORY.md']:
        shutil.copy2(store / name, agent / name)
    for name in ['memory', 'knowledge']:
        shutil.copytree(store / name, agent / name)
    (agent / 'knowledge/private/nested').mkdir(parents=True)
    (agent / 'knowledge/private/nested/note.md').write_text('Private student note\n')
    if edition == 'old':
        registry = (agent / 'AGENTS.md').read_text()
        (agent / 'AGENTS.md').write_text('\n'.join(line for line in registry.splitlines() if '`product-line`' not in line) + '\n')
    for client in ['.claude', '.codex']:
        destination = agent / client / 'skills/installer'
        destination.mkdir(parents=True)
        shutil.copytree(store / 'skills/installer', destination, dirs_exist_ok=True)
        if edition == 'old':
            (destination / 'SKILL.md').write_text('Old installer catalog without product-line\n')
    before = private_hashes(agent)
    env = dict(os.environ)
    env.pop('INSTALLER_SOURCE_DIR', None)
    subprocess.run(['bash', str(agent / '.claude/skills/installer/scripts/refresh-official-installer.sh'), str(agent)], env=env, check=True)
    for client in ['.claude', '.codex']:
        catalog = agent / client / 'skills/installer'
        assert hashes(catalog) == hashes(store / 'skills/installer'), 'public refresh differs from published installer'
        line = next(line for line in (catalog / 'SKILL.md').read_text().splitlines() if line.startswith('|') and '`product-line`' in line)
        assert '| доступен |' in line, 'published catalog does not advertise availability'
        target = agent / client / 'skills/product-line'
        shutil.copytree(sparse / 'skills/product-line', target, dirs_exist_ok=True)
        assert hashes(target) == expected, 'installed package differs from public source'
    assert private_hashes(agent) == before, 'installation changed personal memory'
    assert not (agent / '.git').exists() and not (agent / 'skills').exists(), 'store internals leaked into student agent'

print('PASS: published main, public installer refresh old/new, sparse package download, exact Claude/Codex copies, unchanged private memory')
print('Commit:', commit)
print('Workspace:', work)
PY

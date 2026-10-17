#!/usr/bin/env bash
set -euo pipefail

PRODUCT_LINE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$PRODUCT_LINE_ROOT" <<'PY'
from pathlib import Path
import re
import sys
import copy
import json
import subprocess
import tempfile

root = Path(sys.argv[1])
skill = root / 'skills/product-line'
expected = {'SKILL.md', 'references/design-checks.md', 'assets/product-line-template.html', 'THIRD_PARTY_NOTICES.md', 'scripts/render_product_line.py'}
assert (skill / 'SKILL.md').is_file(), 'missing skills/product-line/SKILL.md'
files = {str(p.relative_to(skill)) for p in skill.rglob('*') if p.is_file()}
assert files == expected, f'incomplete or unexpected installed package: {sorted(files ^ expected)}'
entry = (skill / 'SKILL.md').read_text()
assert entry.startswith('---\n'), 'missing skill metadata'
frontmatter = entry.split('---', 2)[1]
keys = re.findall(r'^([a-z_-]+):', frontmatter, re.M)
assert set(keys) == {'name', 'description'}, f'unsupported metadata: {keys}'
assert re.search(r'^name: product-line$', frontmatter, re.M), 'wrong skill name'
assert len(entry.splitlines()) <= 350, 'entrypoint exceeds 350 lines; use the focused reference'
for relative in ['references/design-checks.md', 'assets/product-line-template.html', 'scripts/render_product_line.py']:
    assert relative in entry, f'entrypoint does not route to {relative}'
assert 'knowledge/product-line.md' in entry and 'knowledge/product-line.html' in entry, 'missing output contract'
assert 'product-selection' in entry and 'product-packaging' in entry, 'missing neighbouring-skill boundary'
assert 'Claude Code' in entry and 'Codex' in entry, 'missing cross-client instructions'
assert 'MEMORY.md' in entry and 'USER.md' in entry and 'SOUL.md' in entry, 'missing memory contract'
assert re.search(r'product-line.*не установлен', (root / 'AGENTS.md').read_text()), 'missing registry entry'
installer = (root / 'skills/installer/SKILL.md').read_text()
assert re.search(r'Продуктовая линейка.*product-line', installer), 'Russian name not mapped by installer'
assert 'Помоги собрать продуктовую линейку вокруг моего основного продукта' in installer, 'missing verification phrase'
line = next(line for line in installer.splitlines() if line.startswith('|') and '`product-line`' in line)
assert '| доступен |' in line, 'published skill must be available in the installer catalog'
readme = (root / 'README.md').read_text()
assert 'Установи скилл «Продуктовая линейка»' in readme, 'README must provide the installation prompt'
assert 'Продуктовая линейка» подготовлен как локальная рабочая версия' not in readme, 'README still describes an unpublished skill'
ci = (root / '.github/workflows/ci.yml').read_text()
for test in ['test-product-line.sh', 'test-product-line-installation.sh', 'check-product-line-html.cjs']:
    assert test in ci, f'CI does not cover {test}'
template = (skill / 'assets/product-line-template.html').read_text()
assert '<script type="application/json" id="product-line-data">null</script>' in template, 'template must ship without student data'
for forbidden in ['innerHTML', 'outerHTML', 'insertAdjacentHTML', 'document.write', 'eval(']:
    assert forbidden not in template, f'unsafe dynamic rendering: {forbidden}'
assert not re.search(r'(?:src|href)=[\"\x27]https?://|@import|\bfetch\s*\(|XMLHttpRequest|WebSocket', template, re.I), 'installed template must work offline'
assert not re.search(r'\bTODO\b|\bFIXME\b|\bTBD\b', entry), 'unfinished skill scaffold'
notices = (skill / 'THIRD_PARTY_NOTICES.md').read_text()
for author in ['Corey Haines', 'RampStack', 'Affitor']:
    assert author in notices, f'missing attribution: {author}'
helper = skill / 'scripts/render_product_line.py'
demo = json.loads((root / 'tests/evals/product-line/files/demo-product-line-data.json').read_text())
with tempfile.TemporaryDirectory(prefix='product-line-render-') as folder:
    source, output = Path(folder) / 'data.json', Path(folder) / 'result.html'
    def render(data):
        source.write_text(json.dumps(data, ensure_ascii=False))
        return subprocess.run([sys.executable, str(helper), str(source), str(output)], capture_output=True, text=True)
    hostile = copy.deepcopy(demo)
    hostile['meta']['title'] = '</script><script>alert(1)</script>'
    assert render(hostile).returncode == 0, 'valid data must render'
    saved = output.read_text()
    assert '\\u003c/script>' in saved and hostile['meta']['title'] not in saved, 'escape embedded script text'
    stdin_result = subprocess.run([sys.executable, str(helper), '-', str(output)], input=json.dumps(hostile), capture_output=True, text=True)
    assert stdin_result.returncode == 0 and output.read_text() == saved, 'stdin renders without a persistent JSON file'
    mutations = [lambda d: d['roleDecisions'][0].update(role='Основной продукт'),
                 lambda d: d['offers'][0].update(result=None),
                 lambda d: d['transitions'][0].update(to='missing'),
                 lambda d: d.update(version=True)]
    for mutate in mutations:
        data = copy.deepcopy(demo)
        mutate(data)
        assert render(data).returncode != 0, 'invalid contract must be rejected before writing'
        assert output.read_text() == saved, 'failed validation must preserve previous HTML'
print('PASS: product-line package, two-client contract, installer catalog and CI wiring (model behaviour tested separately)')
PY

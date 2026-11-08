"""Check local handoff links, requirement IDs, and the generated static preview."""

from collections import Counter
from configparser import ConfigParser
from html.parser import HTMLParser
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
from urllib.parse import unquote, urlsplit
import json
import re
import sys

sys.dont_write_bytecode = True

root = Path(__file__).resolve().parents[1]
requirements = (root / 'docs/requirements.md').read_text()
ids = re.findall(r'^- \*\*([A-Z]{3}-\d{3}) —', requirements, re.M)
scenarios = re.findall(r'^\| (AC-\d{3}) \|', requirements, re.M)
for name, items in [('requirements', ids), ('acceptance scenarios', scenarios)]:
    duplicates = [key for key, count in Counter(items).items() if count > 1]
    assert not duplicates, f'Duplicate {name}: {duplicates}'
references = set(re.findall(r'\b(?:ING|DAT|QRY|STO|LIF|WEB|OPS|DEP|CAT)-\d{3}\b', requirements))
assert references == set(ids), f'Undefined requirement IDs: {references - set(ids)}'
rows = '\n'.join(line for line in requirements.splitlines() if re.match(r'^\| AC-\d{3} \|', line))
mapped = set(re.findall(r'\b[A-Z]{3}-\d{3}\b', rows))
assert set(ids) <= mapped, f'Unmapped requirements: {set(ids) - mapped}'
for snapshot in (root / 'docs/history').glob('requirements-*.md'):
    old_ids = set(re.findall(r'^- \*\*([A-Z]{3}-\d{3}) —', snapshot.read_text(), re.M))
    assert old_ids <= set(ids), f'Removed stable IDs from {snapshot.name}: {old_ids - set(ids)}'

submodules = ConfigParser(interpolation=None)
submodules.read(root / '.gitmodules')
uninitialized_submodules = [
    (root / submodules[section]['path']).resolve()
    for section in submodules.sections()
    if section.startswith('submodule ')
    and not (root / submodules[section]['path'] / '.git').exists()
]
checked_links = 0
skipped_submodule_links = []
documents = [root / 'README.md', root / 'AGENTS.md']
documents += sorted(
    path for path in (root / 'docs').rglob('*.md')
    if not path.is_relative_to(root / 'docs/history')
)
for path in documents:
    content = path.read_text()
    assert sum(line.startswith('```') for line in content.splitlines()) % 2 == 0, f'Unbalanced code fences: {path}'
    for link in re.findall(r'\[[^\]]*\]\(([^)]+)\)', content):
        parsed = urlsplit(link)
        if parsed.scheme or parsed.netloc or not parsed.path:
            continue
        assert not parsed.path.startswith('/'), f'Nonportable local link in {path}: {link}'
        target = (path.parent / unquote(parsed.path)).resolve()
        if any(target.is_relative_to(submodule) for submodule in uninitialized_submodules):
            skipped_submodule_links.append(str(target.relative_to(root)))
            continue
        assert target.exists(), f'Broken local link in {path}: {link}'
        checked_links += 1

spec = spec_from_file_location('prototype_build', root / 'prototype/build.py')
build = module_from_spec(spec)
spec.loader.exec_module(build)
preview = (root / 'prototype/index.html').read_text()
assert preview == build.render_preview(), 'Preview is stale; run python3 prototype/build.py'

class Assets(HTMLParser):
    def handle_starttag(self, tag, attributes):
        attributes = dict(attributes)
        for key in ('src', 'href'):
            value = attributes.get(key, '')
            assert not value.startswith(('http:', 'https:', '//')), f'External preview asset: {value}'

Assets().feed(preview)
assert '__UPLOT_' not in preview, 'Unresolved template marker'
assert 'Permission is hereby granted' in preview, 'Missing embedded uPlot license'
result = {
    'requirements': len(ids),
    'acceptance_scenarios': len(scenarios),
    'stable_ids_preserved': True,
    'undefined_or_unmapped_ids': 0,
    'local_link_targets_checked': checked_links,
    'uninitialized_submodule_links': skipped_submodule_links,
    'preview_matches_source': True,
    'external_preview_assets': 0,
    'scope': 'Planning bundle integrity; no backend or R2 validation',
}
output = root / 'prototype/validation/handoff-check-results.json'
output.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))

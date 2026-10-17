#!/usr/bin/env python3
"""Validate product-line data and render the bundled offline HTML (stdlib only)."""
import argparse
import json
import os
from pathlib import Path
import sys
import tempfile

ROLES = {'core', 'lead-magnet', 'tripwire', 'upsell', 'cross-sell', 'downsell'}
BRANCHES = {'upgrade': {'upsell'}, 'complement': {'cross-sell'},
            'alternative': {'downsell', 'tripwire'}}
OFFER_FIELDS = 'id role name audience result format price status priority scope limits effort timing costs evidence unknowns'.split()
BRIEF_FIELDS = 'offerId title recipient problem result format rationale sample delivery cta check'.split()
PLACEHOLDER = '<script type="application/json" id="product-line-data">null</script>'


def require(condition, message):
    if not condition:
        raise ValueError(message)


def strings(value, fields, section):
    require(isinstance(value, dict), section + ': expected object')
    for field in fields:
        require(isinstance(value.get(field), str), section + '.' + field + ': expected string')


def array(value, section, text=False):
    require(isinstance(value, list), section + ': expected array')
    if text:
        require(all(isinstance(item, str) for item in value), section + ': expected strings')


def validate(data):
    require(isinstance(data, dict) and type(data.get('version')) is int
            and data['version'] == 1, 'Unsupported data version')
    strings(data.get('meta'), 'title segment coreProduct updated status scope'.split(), 'meta')
    offers = data.get('offers')
    array(offers, 'offers')
    require(bool(offers), 'Add one core offer')
    ids = {}
    for offer in offers:
        strings(offer, OFFER_FIELDS, 'offers')
        require(offer['id'].strip() and offer['id'] not in ids, 'Offer ids must be nonempty and unique')
        require(offer['role'] in ROLES, 'offers.role: use technical role codes')
        ids[offer['id']] = offer['role']
    require(sum(role == 'core' for role in ids.values()) == 1, 'Exactly one core offer required')
    decisions = data.get('roleDecisions')
    array(decisions, 'roleDecisions')
    seen = set()
    for item in decisions:
        strings(item, ['role', 'decision', 'reason'], 'roleDecisions')
        require(item['role'] in ROLES and item['role'] not in seen,
                'roleDecisions.role: use unique technical role codes')
        seen.add(item['role'])
    transitions = data.get('transitions')
    array(transitions, 'transitions')
    for item in transitions:
        strings(item, ['from', 'to', 'kind', 'trigger', 'reason', 'action'], 'transitions')
        require(item['from'] in ids and item['to'] in ids and item['from'] != item['to'],
                'Transition must reference two existing distinct offers')
        require(item['kind'] in {'primary', *BRANCHES}, 'Unknown transition kind')
        if item['kind'] in BRANCHES:
            require(ids[item['to']] in BRANCHES[item['kind']], 'Transition target role mismatch')
    require('entryBrief' in data, 'entryBrief is required; use null when absent')
    brief = data['entryBrief']
    if brief is not None:
        strings(brief, BRIEF_FIELDS, 'entryBrief')
        array(brief.get('outline'), 'entryBrief.outline', text=True)
        require(brief['offerId'] in ids, 'Brief must reference an existing offer')
    strings(data.get('test'), 'hypothesis audience action period decision'.split(), 'test')
    array(data['test'].get('signals'), 'test.signals', text=True)
    array(data.get('unknowns'), 'unknowns', text=True)
    require(isinstance(data.get('nextStep'), str), 'nextStep: expected string')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('data', help='JSON path derived from current product-line.md; - reads stdin')
    parser.add_argument('output', type=Path, help='Destination product-line.html')
    args = parser.parse_args()
    template = Path(__file__).resolve().parent.parent / 'assets/product-line-template.html'
    try:
        input_path = None if args.data == '-' else Path(args.data)
        require(args.output.resolve() != template.resolve()
                and (input_path is None or args.output.resolve() != input_path.resolve()),
                'Output must not overwrite input or template')
        data = json.loads(sys.stdin.read() if input_path is None else input_path.read_text(encoding='utf-8'))
        validate(data)
        source = template.read_text(encoding='utf-8')
        require(source.count(PLACEHOLDER) == 1, 'Template placeholder missing or duplicated')
        payload = json.dumps(data, ensure_ascii=False, allow_nan=False).replace('<', '\\u003c')
        html = source.replace(PLACEHOLDER, PLACEHOLDER.replace('>null<', '>' + payload + '<'))
        args.output.parent.mkdir(parents=True, exist_ok=True)
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=args.output.parent,
                                             prefix='.product-line-', suffix='.tmp', delete=False) as handle:
                temporary = Path(handle.name)
                handle.write(html)
            os.replace(temporary, args.output)
        finally:
            if temporary is not None and temporary.exists():
                temporary.unlink()
        print('Validated and rendered: ' + str(args.output))
    except (ValueError, OSError) as error:
        parser.exit(1, 'Product-line render error: ' + str(error) + '\n')


if __name__ == '__main__':
    main()

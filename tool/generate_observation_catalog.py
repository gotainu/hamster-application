#!/usr/bin/env python3
"""Generate the TS/Dart observation bindings from the only authoritative catalog.

Edit shared/observation_catalog.json, then run this script. --check is read-only.
No Firebase, network, dependency install or deploy is involved.
"""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def quoted(value):
    return json.dumps(value, ensure_ascii=False)


def dart_value(value):
    if isinstance(value, list):
        return '[' + ', '.join(dart_value(item) for item in value) + ']'
    encoded = quoted(value)
    return encoded.replace('$', r'\$') if isinstance(value, str) else encoded


def validate(data):
    if not isinstance(data.get('version'), str) or not data['version']:
        raise ValueError('catalog version must be a non-empty string')
    seen = set()
    for item in data['items']:
        for field in ('id', 'label'):
            if not isinstance(item[field], str) or not item[field]:
                raise ValueError(f'{field} must be a non-empty string')
        if not isinstance(item['order'], int) or isinstance(item['order'], bool):
            raise ValueError('order must be an integer')
        for field in ('active', 'insightEligible', 'defaultNormal'):
            if not isinstance(item[field], bool):
                raise ValueError(f'{field} must be boolean')
        for field in ('legacyIds', 'legacyNames'):
            if not isinstance(item[field], list) or any(not isinstance(value, str) or not value for value in item[field]):
                raise ValueError(f'{field} must contain non-empty strings')
        for key in [item['id'], item['label'], *item['legacyIds'], *item['legacyNames']]:
            if key in seen:
                raise ValueError(f'ambiguous catalog key: {key}')
            seen.add(key)


def render(data):
    validate(data)
    digest = hashlib.sha256(json.dumps(data, sort_keys=True, ensure_ascii=False, separators=(',', ':')).encode()).hexdigest()
    header = f'// Generated from shared/observation_catalog.json; do not edit.\n// Canonical SHA-256: {digest}\n'
    ts_items = [{**{key: value for key, value in item.items() if key != 'legacyIds'}, 'aliases': item['legacyIds']} for item in data['items']]
    ts = header + "import type {ObservationCatalogItem} from './observationCatalog';\n\n"
    ts += f"export const OBSERVATION_CATALOG_VERSION = {quoted(data['version'])};\n"
    ts += 'export const generatedObservationCatalog: readonly ObservationCatalogItem[] = ' + json.dumps(ts_items, ensure_ascii=False, indent=2) + ';\n'
    dart = header + "part of 'observation_catalog.dart';\n\n"
    dart += f"const observationCatalogVersion = {dart_value(data['version'])};\n"
    dart += 'const observationCatalog = <ObservationCatalogItem>[\n'
    for item in data['items']:
        dart += '  ObservationCatalogItem(\n'
        for key in ('id', 'label', 'order', 'active', 'insightEligible', 'defaultNormal'):
            dart += f'    {key}: {dart_value(item[key])},\n'
        dart += f"    aliases: {dart_value(item['legacyIds'])},\n"
        dart += f"    legacyNames: {dart_value(item['legacyNames'])},\n"
        dart += '  ),\n'
    dart += '];\n'
    return {'functions/src/health/observationCatalog.generated.ts': ts,
            'lib/models/observation_catalog.generated.dart': dart}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--catalog', type=Path, default=ROOT / 'shared/observation_catalog.json')
    parser.add_argument('--output-root', type=Path, default=ROOT)
    args = parser.parse_args()
    rendered = render(json.loads(args.catalog.read_text()))
    mismatches = []
    for relative, content in rendered.items():
        target = args.output_root / relative
        if args.check:
            if not target.exists() or target.read_text() != content:
                mismatches.append(relative)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content)
    if mismatches:
        parser.exit(1, 'Observation Catalog bindings are stale: ' + ', '.join(mismatches) + '\n')
    print('Observation Catalog bindings: ' + ('PASS' if args.check else 'generated'))


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Generate deterministic Care Action bindings. Catalog is the sole authority; --check is read-only."""
import argparse
import hashlib
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent

def value(x):
    if x is None: return 'null'
    return json.dumps(x,ensure_ascii=False).replace('$',r'\$') if isinstance(x,str) else json.dumps(x)

def detail_definitions(item):
    return ([item['detail']] if item.get('detail') else []) + item.get('details',[])

def validate(data):
    if not isinstance(data.get('version'),str) or not data['version']: raise ValueError('version required')
    seen=set()
    for item in data['items']:
        if item['inputType'] not in ('tri_state','cleaning_choice','duration_minutes') or type(item['active']) is not bool or type(item['order']) is not int: raise ValueError('invalid item definition')
        for key in [item['id'],item['label'],*item['legacyIds'],*item['legacyNames']]:
            if not isinstance(key,str) or not key or key in seen: raise ValueError('ambiguous item identity')
            seen.add(key)
        definitions=detail_definitions(item)
        keys=[detail['key'] for detail in definitions]
        if len(keys)!=len(set(keys)): raise ValueError('duplicate detail key')
        for detail in definitions:
            if detail['type'] not in ('enum','integer') or not detail['key'] or not detail['label']: raise ValueError('invalid detail')
            if detail['type']=='integer' and (type(detail['min']) is not int or type(detail['max']) is not int or detail['min']>detail['max']): raise ValueError('invalid detail range')
            if 'legacy' in detail and type(detail['legacy']) is not bool: raise ValueError('invalid legacy flag')
            ids=[v['id'] for v in detail.get('values',[])]
            if len(ids)!=len(set(ids)): raise ValueError('duplicate options')
            if detail['type']=='enum' and not ids: raise ValueError('enum needs values')
            condition=detail.get('onlyWhen')
            if condition:
                parent=next((other for other in definitions if other['key']==condition['key']),None)
                if not parent or parent is detail or not condition['values'] or any(v not in [o['id'] for o in parent.get('values',[])] for v in condition['values']): raise ValueError('invalid detail condition')

def render_detail(detail, indent):
    result='CareActionDetail(\n'
    for key in ('key','label','type','unit','meaning','min','max','legacy'):
        if key in detail: result+=f'{indent}  {key}: {value(detail[key])},\n'
    if detail.get('onlyWhen'):
        c=detail['onlyWhen']
        result+=f"{indent}  onlyWhen: CareActionDetailCondition(key: {value(c['key'])}, values: [{', '.join(value(v) for v in c['values'])}]),\n"
    result+=f'{indent}  values: <CareActionDetailOption>[\n'
    for option in detail.get('values',[]): result+=f"{indent}    CareActionDetailOption(id: {value(option['id'])}, label: {value(option['label'])}),\n"
    return result+f'{indent}  ],\n{indent})'

def render(data):
    validate(data)
    digest=hashlib.sha256(json.dumps(data,sort_keys=True,ensure_ascii=False,separators=(',',':')).encode()).hexdigest()
    header=f'// Generated from shared/care_action_catalog.json; do not edit.\n// Canonical SHA-256: {digest}\n'
    items=[{**{k:v for k,v in item.items() if k!='legacyIds'},'aliases':item['legacyIds']} for item in data['items']]
    ts=header+"import type {CareActionCatalogItem} from './careActionCatalog';\n\n"+f"export const CARE_ACTION_CATALOG_VERSION = {value(data['version'])};\n"+'export const generatedCareActionCatalog: readonly CareActionCatalogItem[] = '+json.dumps(items,ensure_ascii=False,indent=2)+';\n'
    dart=header+"part of 'care_action_catalog.dart';\n\n"+f"const careActionCatalogVersion = {value(data['version'])};\nconst careActionCatalog = <CareActionCatalogItem>[\n"
    for item in data['items']:
        dart+='  CareActionCatalogItem(\n'
        for key in ('id','label','order','active','inputType'): dart+=f'    {key}: {value(item[key])},\n'
        for key,source in [('aliases','legacyIds'),('legacyNames','legacyNames')]: dart+=f"    {key}: [{', '.join(value(x) for x in item[source])}],\n"
        if item.get('detail'): dart+='    detail: '+render_detail(item['detail'],'    ')+',\n'
        if item.get('details'):
            dart+='    details: <CareActionDetail>[\n'
            for detail in item['details']: dart+='      '+render_detail(detail,'      ')+',\n'
            dart+='    ],\n'
        dart+='  ),\n'
    dart+='];\n'
    return {'functions/src/careActions/careActionCatalog.generated.ts':ts,'lib/models/care_action_catalog.generated.dart':dart}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');parser.add_argument('--catalog',type=Path,default=ROOT/'shared/care_action_catalog.json');parser.add_argument('--output-root',type=Path,default=ROOT);args=parser.parse_args()
    mismatches=[]
    for relative,content in render(json.loads(args.catalog.read_text())).items():
        target=args.output_root/relative
        if args.check:
            if not target.exists() or target.read_text()!=content: mismatches.append(relative)
        else: target.parent.mkdir(parents=True,exist_ok=True);target.write_text(content)
    if mismatches: parser.exit(1,'Care Action bindings stale: '+', '.join(mismatches)+'\n')
    print('Care Action Catalog: '+('PASS' if args.check else 'generated'))
if __name__=='__main__': main()

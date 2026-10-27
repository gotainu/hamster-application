import {createHash} from 'node:crypto';
import {normalizeInstant} from './time';

export function canonicalStringify(value:unknown):string {
  if(value===null || typeof value==='string' || typeof value==='boolean') return JSON.stringify(value);
  if(typeof value==='number' && Number.isFinite(value)) return JSON.stringify(value);
  if(Array.isArray(value)) return '['+value.map(canonicalStringify).join(',')+']';
  if(typeof value==='object' && value!==null) {
    return '{'+Object.keys(value).sort().filter(k=>(value as Record<string,unknown>)[k]!==undefined)
      .map(k=>JSON.stringify(k)+':'+canonicalStringify((value as Record<string,unknown>)[k])).join(',')+'}';
  }
  throw new Error('unsupported_non_json_value');
}
export function hash(value:unknown):string {return createHash('sha256').update(canonicalStringify(value)).digest('hex');}
/** Fixture lists and policy lists are sets, not event order. Receipt/revision fields define order. */
export function normalizeInput(value:unknown):unknown {
  if(typeof value==='string' && /^\d{4}-\d{2}-\d{2}T/.test(value)) return normalizeInstant(value);
  if(Array.isArray(value)) return value.map(normalizeInput).sort((a,b)=>{const x=canonicalStringify(a),y=canonicalStringify(b);return x<y?-1:x>y?1:0;});
  if(value!==null && typeof value==='object') return Object.fromEntries(Object.entries(value).map(([k,v])=>[k,normalizeInput(v)]));
  return value;
}

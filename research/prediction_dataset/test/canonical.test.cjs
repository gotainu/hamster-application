'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const path=require('node:path');
const {loadTypeScript}=require('../tools/load-typescript.cjs');
const {normalizeInput,hash}=loadTypeScript(path.join(__dirname,'../src/canonical.ts'));

test('canonical unordered arrays have a total order even for Unicode-collation-equivalent text',()=>{
  const values=['é','e\u0301','種','synthetic_a-b','synthetic_ab'];
  assert.equal(hash(normalizeInput(values)),hash(normalizeInput([...values].reverse())));
});
test('canonical object field order and equivalent explicit timestamp offsets do not change input hash',()=>{
  assert.equal(hash(normalizeInput({a:1,b:'2030-04-01T09:00:00.000000001+09:00'})),
    hash(normalizeInput({b:'2030-04-01T00:00:00.000000001Z',a:1})));
});

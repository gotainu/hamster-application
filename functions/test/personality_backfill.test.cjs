'use strict';
const assert = require('node:assert/strict');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const test = require('node:test');
const script = path.resolve(__dirname, '../scripts/personality_backfill.cjs');
test('backfill refuses production project, absent emulator, and remote host before initializing Firebase', () => {
  for (const [project, host] of [['hamcare-production', '127.0.0.1:19180'], ['demo-test', ''], ['demo-test', 'firestore.googleapis.com:443']]) {
    const result = spawnSync(process.execPath, [script, '--uids=fixture', '--project='+project], {encoding:'utf8', env:{...process.env, FIRESTORE_EMULATOR_HOST:host}});
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /demo-|local emulator|localhost/);
  }
});
test('backfill dry-run is the default and explicit write requires guarded local demo target', () => {
  const m = require(script);
  assert.equal(m.parseOptions(['--project=demo-test','--uids=a,b']).dryRun, true);
  assert.equal(m.parseOptions(['--project=demo-test','--uids=a,b','--write']).dryRun, false);
  assert.throws(() => m.parseOptions(['--uids=a','--write','--dry-run']), /Choose/);
  assert.throws(() => m.parseOptions(['--project=demo-test','--uids=../unsafe']), /UID/);
});
test('backfill preserves an explicitly historical evaluation date for skip rather than pretending it is current', async () => {
  const m = require(script); const calls=[];
  const db={projectId:'demo-test'};
  const result=await m.backfillUsers({db,target:{projectId:'demo-test',emulatorHost:'127.0.0.1:19180'},uids:['a','a','b'],evaluationDateKey:'2026-09-23',now:new Date('2026-10-08T02:00:00Z'),dryRun:true,
    sync:async p=>{calls.push(p); return {status:'historical_skipped'};}});
  assert.equal(calls.length,2); assert.ok(calls.every(c=>c.dryRun&&c.evaluationDateKey==='2026-09-23'));
  assert.deepEqual(result.map(r=>r.status),['historical_skipped','historical_skipped']);
});

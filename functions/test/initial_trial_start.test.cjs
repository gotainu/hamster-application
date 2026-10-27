'use strict';
const assert = require('node:assert/strict');
const {test} = require('node:test');
const {loadStarSource, fakeFirestore, Stamp} = require('./support/star_source_loader.cjs');
const clockStart = new Date('2026-10-24T00:00:00.000Z');
const trialPath = uid => `users/${uid}/feature_access/initial_trial_v2`;
const journeyPath = uid => `users/${uid}/journey_events/initial_trial_started`;
function fixture({validationUids = ''} = {}) {
  let clock = new Date(clockStart);
  const previous = process.env.TRIAL_TEST_UIDS;
  process.env.TRIAL_TEST_UIDS = validationUids;
  const {db, admin} = fakeFirestore({clock: () => clock});
  admin.firestore.Timestamp = Stamp;
  admin.firestore.Timestamp.fromDate = d => new Stamp(d);
  const load = loadStarSource({admin, now: () => clock});
  const source = load('featureTrials');
  const policy = load('trialPolicy').initialTrialPolicy;
  return {db, source, policy, setClock: value => {clock = value;}, restore: () => {
    if(previous === undefined) delete process.env.TRIAL_TEST_UIDS;
    else process.env.TRIAL_TEST_UIDS = previous;
  }};
}
function canonical(data) {
  return JSON.stringify(data, (_k, v) => v instanceof Stamp ? {millis: v.toMillis()} : v);
}

test('ordinary user starts with operator validation identities present; identity label conveys no extra entitlement', async () => {
  const f = fixture({validationUids: 'synthetic-developer'});
  try {
    const result = await f.source.startInitialTrial({auth: {uid: 'synthetic-ordinary'}, data: {}});
    assert.equal(result.started, true);
    const stored = f.db.documents.get(trialPath('synthetic-ordinary'));
    assert.equal(stored.status, 'active');
    assert.equal(stored.testOnly, false);
    assert.equal(stored.aiRequestLimit, 20);
    assert.equal(stored.aiRequestUsed, 0);
    assert.equal(stored.aiReservationCostMicros, 50000);
    assert.equal(stored.aiCostMicrosLimit, 1000000);
    assert.equal(stored.aiCostMicrosUsed, 0);
    assert.equal(stored.startedAt.toDate().toISOString(), clockStart.toISOString());
    assert.equal(stored.endsAt.toMillis() - stored.startedAt.toMillis(), 21 * 86400000);
    const developer = await f.source.startInitialTrial({auth: {uid: 'synthetic-developer'}, data: {}});
    assert.equal(developer.started, true);
    const devStored = f.db.documents.get(trialPath('synthetic-developer'));
    assert.equal(devStored.testOnly, true);
    for (const key of ['aiRequestLimit','aiRequestUsed','aiReservationCostMicros','aiCostMicrosLimit','aiCostMicrosUsed'])
      assert.equal(devStored[key], stored[key]);
  } finally {f.restore();}
});

test('repeat and concurrent starts create one immutable 21-day trial and one journey event', async () => {
  const f = fixture(); const uid = 'synthetic-concurrent';
  try {
    const result = await Promise.all([f.source.startInitialTrial({auth: {uid}}), f.source.startInitialTrial({auth: {uid}})]);
    assert.deepEqual(result.map(x=>x.started).sort(), [false,true]);
    assert.equal(f.db.writes.filter(x=>x[1] === trialPath(uid)).length,1);
    assert.equal(f.db.writes.filter(x=>x[1] === journeyPath(uid)).length,1);
    const initial = canonical(f.db.documents.get(trialPath(uid)));
    const event = canonical(f.db.documents.get(journeyPath(uid)));
    f.setClock(new Date(clockStart.getTime() + 15 * 86400000));
    assert.equal((await f.source.startInitialTrial({auth: {uid}})).started,false);
    assert.equal(canonical(f.db.documents.get(trialPath(uid))),initial);
    assert.equal(canonical(f.db.documents.get(journeyPath(uid))),event);
  } finally {f.restore();}
});

test('expired trial and consumed counters are never reset or extended on start', async () => {
  const f = fixture(); const uid = 'synthetic-expired';
  try {
    await f.source.startInitialTrial({auth: {uid}});
    const stored = f.db.documents.get(trialPath(uid));
    stored.aiRequestUsed = 20; stored.aiCostMicrosUsed = 1000000;
    const initial = canonical(stored); const writes = f.db.writes.length;
    f.setClock(new Date(clockStart.getTime() + 21 * 86400000));
    const result = await f.source.startInitialTrial({auth: {uid}});
    assert.equal(result.started,false); assert.equal(result.accessSource,'none');
    assert.equal(canonical(f.db.documents.get(trialPath(uid))),initial);
    assert.equal(f.db.writes.length,writes);
  } finally {f.restore();}
});

test('operator policy misconfiguration cannot start a clock or consume budget', async () => {
  for(const key of ['aiRequestLimit','aiCostMicrosLimit']) {
    const f = fixture();
    try {
      f.policy[key] = 0;
      await assert.rejects(f.source.startInitialTrial({auth: {uid: 'synthetic-config'}}), e => e.code === 'failed-precondition' && e.message.includes('運営側'));
      assert.equal(f.db.documents.size,0); assert.equal(f.db.writes.length,0);
    } finally {f.restore();}
  }
});

test('paid user has no new free-trial history and unauthenticated request has no writes', async () => {
  const f = fixture(); const uid = 'synthetic-paid';
  try {
    f.db.documents.set(`users/${uid}/billing/subscription`,{plan:'paid',status:'active',currentPeriodEnd:new Stamp(new Date('2026-11-24T00:00:00Z'))});
    assert.deepEqual(await f.source.startInitialTrial({auth:{uid}}),{accessSource:'paid',started:false});
    assert.equal(f.db.writes.length,0);
    await assert.rejects(f.source.startInitialTrial({}),e=>e.code==='unauthenticated');
    assert.equal(f.db.writes.length,0);
  } finally {f.restore();}
});

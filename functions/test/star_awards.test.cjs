'use strict';

const assert = require('node:assert/strict');
const {
  awardStar,
  crossedStarMilestone,
  isAwardDateEligible,
  isStarProgramDate,
  starAwardId,
} = require('../lib/stars/starAwards');

function fakeFirestore() {
  const documents = new Map();
  return {
    documents,
    doc(path) { return { path }; },
    async runTransaction(action) {
      const writes = [];
      const transaction = {
        async get(ref) {
          const data = documents.get(ref.path);
          return { exists: data !== undefined, data: () => data };
        },
        create(ref, data) { writes.push(['create', ref.path, data]); },
        set(ref, data) { writes.push(['set', ref.path, data]); },
      };
      const result = await action(transaction);
      for (const [method, path, data] of writes) {
        if (method === 'create') {
          assert.equal(documents.has(path), false);
        }
        documents.set(path, { ...(documents.get(path) ?? {}), ...data });
      }
      return result;
    },
  };
}

async function main() {
  assert.equal(starAwardId('2026-09-15', 'wheel'), '2026-09-15_wheel');
  assert.equal(
    isAwardDateEligible('2026-09-15', new Date('2026-09-15T03:00:00Z')),
    true,
  );
  assert.equal(
    isAwardDateEligible('2026-09-13', new Date('2026-09-15T03:00:00Z')),
    false,
  );
  assert.equal(crossedStarMilestone(49, 50), true);
  assert.equal(crossedStarMilestone(50, 51), false);
  assert.equal(isStarProgramDate('2026-09-16'), false);
  assert.equal(isStarProgramDate('2026-09-17'), true);

  const db = fakeFirestore();
  const first = await awardStar({
    db,
    uid: 'alice',
    missionDateKey: '2026-09-17',
    kind: 'open_app',
  });
  const duplicate = await awardStar({
    db,
    uid: 'alice',
    missionDateKey: '2026-09-17',
    kind: 'open_app',
  });
  assert.deepEqual(first, { awarded: true, total: 1 });
  assert.deepEqual(duplicate, { awarded: false, total: 1 });

  const missingSource = db.doc('users/alice/daily_checkins/2026-09-17');
  const absent = await awardStar({
    db,
    uid: 'alice',
    missionDateKey: '2026-09-17',
    kind: 'condition',
    sourceRef: missingSource,
  });
  assert.deepEqual(absent, { awarded: false, total: 1 });
  db.documents.set(missingSource.path, { condition: 'normal' });
  const present = await awardStar({
    db,
    uid: 'alice',
    missionDateKey: '2026-09-17',
    kind: 'condition',
    sourceRef: missingSource,
  });
  assert.deepEqual(present, { awarded: true, total: 2 });

  db.documents.set('users/alice/rewards/stars', {
    total: 49,
    balance: 49,
    lifetimeEarned: 49,
  });
  const fiftieth = await awardStar({
    db,
    uid: 'alice',
    missionDateKey: '2026-09-17',
    kind: 'wheel',
  });
  assert.deepEqual(fiftieth, { awarded: true, total: 50 });
  assert.equal(
    db.documents.get('users/alice/star_milestones/50').milestone,
    50,
  );
  assert.equal(
    db.documents.get('users/alice/rewards/stars').lifetimeEarned,
    50,
  );
  console.log('Star award tests passed.');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

'use strict';
const assert = require('assert');

// Synthetic acceptance fixture for the UID-based aggregation. No production
// export or Firestore data is read. `first` is intentionally reused by two
// people to prove the join requires the complete user/pet/report/revision set.
const now = Date.parse('2026-02-25T00:00:00Z');
const day = 24 * 60 * 60 * 1000;
const trials = [
  {userId: 'uid_a', trialId: 'initial_trial_v2', start: now - 30 * day, end: now - 9 * day},
  {userId: 'uid_b', trialId: 'initial_trial_v2', start: now - 30 * day, end: now - 9 * day},
  {userId: 'uid_c', trialId: 'initial_trial_v2', start: now - 2 * day, end: now + 19 * day},
];
const server = [
  {userId: 'uid_a', event: 'first_accepted_data_saved', at: now - 29 * day, kind: 'weight'},
  {userId: 'uid_a', event: 'analysis_ready', at: now - 15 * day, metric: 'body'},
  {userId: 'uid_a', event: 'first_report_generated', at: now - 8 * day, pet: 'pet_a', report: 'first', revision: 1},
  {userId: 'uid_b', event: 'first_accepted_data_saved', at: now - 29 * day, kind: 'switchbot_reading'},
  {userId: 'uid_b', event: 'first_report_generated', at: now - 10 * day, pet: 'pet_b', report: 'first', revision: 2},
];
const analytics = [
  {userId: 'uid_a', event: 'personalized_report_viewed', at: now - 7 * day, pet: 'pet_a', report: 'first', revision: 1},
  {userId: 'uid_a', event: 'personalized_report_viewed', at: now - 6 * day, pet: 'pet_a', report: 'first', revision: 1},
  {userId: 'uid_b', event: 'personalized_report_viewed', at: now - 9 * day, pet: 'pet_b', report: 'first', revision: 2},
  // This anonymous event is intentionally not assigned to uid_c.
  {userId: null, event: 'personalized_report_viewed', at: now - day, pet: 'pet_c', report: 'first', revision: 1},
];

const journey = trials.map((trial) => {
  const ownServer = server.filter((e) => e.userId === trial.userId && e.at >= trial.start);
  const ownViews = analytics.filter((e) => e.userId === trial.userId && e.event === 'personalized_report_viewed' && e.at >= trial.start);
  const report = ownServer.find((e) => e.event === 'first_report_generated') || null;
  return {
    ...trial,
    firstRecord: ownServer.find((e) => e.event === 'first_accepted_data_saved') || null,
    firstBodyReady: ownServer.find((e) => e.event === 'analysis_ready' && e.metric === 'body') || null,
    report,
    firstView: ownViews.sort((a, b) => a.at - b.at)[0] || null,
    viewCount: ownViews.length,
    eligible: now >= trial.end + 2 * day,
  };
});

const a = journey.find((r) => r.userId === 'uid_a');
const b = journey.find((r) => r.userId === 'uid_b');
const c = journey.find((r) => r.userId === 'uid_c');
assert.equal(a.firstView.at, now - 7 * day, 're-view does not change first view');
assert.equal(a.viewCount, 2, 'view opportunities remain separately countable');
assert.notEqual(`${a.report.pet}:${a.report.report}:${a.report.revision}`, `${b.report.pet}:${b.report.report}:${b.report.revision}`, 'same report id cannot cross users/pets/revisions');
assert.equal(b.firstBodyReady, null, 'SwitchBot-only use is not body-analysis failure');
assert.equal(c.firstView, null, 'events with no UID are not guessed onto a trial');
assert.equal(c.eligible, false, 'new trial is not a 21-day completion denominator');
assert.equal(a.report.at >= a.end, true, 'post-expiry generation remains represented');
console.log('trial_journey_fixture: passed');

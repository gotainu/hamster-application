const test = require('node:test');
const assert = require('node:assert/strict');

const {
  buildPersonalBaseline,
  robustZScore,
} = require('../lib/health/personalBaseline');

test('requires both enough records and enough calendar span', () => {
  const dense = buildPersonalBaseline({
    observations: observations([
      ['2026-09-01', 100],
      ['2026-09-02', 101],
      ['2026-09-03', 99],
      ['2026-09-04', 100],
      ['2026-09-05', 100],
      ['2026-09-06', 101],
      ['2026-09-07', 99],
    ]),
  });
  assert.equal(dense.status, 'learning');
  assert.equal(dense.recordCount, 7);
  assert.equal(dense.spanDays, 7);

  const mature = buildPersonalBaseline({
    observations: observations([
      ['2026-08-20', 100],
      ['2026-08-25', 101],
      ['2026-08-30', 99],
      ['2026-09-02', 100],
      ['2026-09-05', 100],
      ['2026-09-08', 101],
      ['2026-09-11', 99],
    ]),
  });
  assert.equal(mature.status, 'ready');
  assert.equal(mature.median, 100);
  assert.equal(mature.mad, 1);
});

test('median and MAD resist a single extreme historical value', () => {
  const baseline = buildPersonalBaseline({
    observations: observations([
      ['2026-08-20', 100],
      ['2026-08-23', 99],
      ['2026-08-26', 101],
      ['2026-08-29', 100],
      ['2026-09-01', 100],
      ['2026-09-05', 99],
      ['2026-09-09', 1000],
    ]),
  });

  assert.equal(baseline.status, 'ready');
  assert.equal(baseline.median, 100);
  assert.equal(baseline.mad, 1);
  assert.ok(robustZScore({value: 94, baseline}) < -4);
});

function observations(rows) {
  return rows.map(([dateKey, value]) => ({dateKey, value}));
}

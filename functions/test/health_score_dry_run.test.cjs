const test = require('node:test');
const assert = require('node:assert/strict');

const {
  buildHealthScoreDryRunReport,
} = require('../lib/health/healthScoreDryRun');

function assessment(overrides = {}) {
  return {
    overall: {
      observedState: 'good',
      state: 'good',
      score: 100,
      scoreCoverage: 1,
    },
    domains: {
      activity: {state: 'good'},
    },
    dataQuality: {
      unscoredDomains: [],
    },
    ...overrides,
  };
}

function previous(overrides = {}) {
  return {
    overall: {
      observedState: 'good',
      score: 100,
    },
    domains: {
      activity: {state: 'good'},
    },
    ...overrides,
  };
}

test('reports hidden scores, safety preservation, and activity changes', () => {
  const report = buildHealthScoreDryRunReport([
    {
      dateKey: '2026-09-10',
      previousAssessment: previous({
        overall: {observedState: 'alert', score: 40},
        domains: {activity: {state: 'alert'}},
      }),
      candidateAssessment: assessment({
        overall: {
          observedState: 'alert',
          state: 'alert',
          score: null,
          scoreCoverage: 0.6,
        },
        domains: {activity: {state: 'insufficientData'}},
        dataQuality: {unscoredDomains: ['activity']},
      }),
    },
    {
      dateKey: '2026-09-11',
      previousAssessment: previous(),
      candidateAssessment: assessment({
        overall: {
          observedState: 'caution',
          state: 'caution',
          score: 85,
          scoreCoverage: 1,
        },
        domains: {activity: {state: 'caution'}},
      }),
    },
  ]);

  assert.equal(report.inputDays, 2);
  assert.equal(report.referenceScore.previousPublishedDays, 2);
  assert.equal(report.referenceScore.candidatePublishedDays, 1);
  assert.equal(report.safety.previousAlertsPreserved, 1);
  assert.equal(report.safety.previousAlertsDowngraded, 0);
  assert.equal(report.safety.newCandidateSafetySignals, 1);
  assert.equal(report.activity.changedDecisions, 2);
  assert.equal(report.activity.becameInsufficientDays, 1);
  assert.deepEqual(report.unscoredDomainCounts, {activity: 1});
});

test('accepts legacy state and score fields when observed fields are absent', () => {
  const report = buildHealthScoreDryRunReport([
    {
      dateKey: '2026-09-12',
      previousAssessment: {
        overall: {state: 'caution', score: 80},
        domains: {activity: {state: 'good'}},
      },
      candidateAssessment: assessment(),
    },
  ]);

  assert.deepEqual(report.previousStateCounts, {caution: 1});
  assert.equal(report.referenceScore.previousPublishedDays, 1);
  assert.equal(report.safety.previousSafetySignalsLost, 1);
  assert.equal(report.changedDays[0].previousState, 'caution');
});

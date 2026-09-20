const test = require('node:test');
const assert = require('node:assert/strict');

const {
  buildHealthIncidentId,
  decideHealthIncidentDelivery,
  healthNotificationWeekKey,
  isWithinQuietHours,
  normalizeHealthIncidentCondition,
} = require('../lib/health/healthIncidentDelivery');
const {
  buildGoldHealthNotificationCandidate,
  titleForResolvedHealthIncident,
} = require('../lib/health/goldHealthNotification');
const {
  buildActiveHealthIncidents,
} = require('../lib/health/healthIncidentLifecycle');
const {
  defaultHealthNotificationDryRunPolicy,
  replayHealthNotificationHistory,
} = require('../lib/health/healthNotificationDryRun');

function snapshot(overrides = {}) {
  return {
    sentAt: null,
    claimedAt: null,
    severity: null,
    state: null,
    score: null,
    acknowledgedAt: null,
    snoozedUntil: null,
    reactivatedAt: null,
    cautionNotificationsThisWeek: 0,
    ...overrides,
  };
}

function policy(overrides = {}) {
  return {
    criticalAlertsEnabled: true,
    cautionFrequency: 'every_three_days',
    quietHoursEnabled: false,
    quietHoursStart: 21,
    quietHoursEnd: 8,
    timeZone: 'Asia/Tokyo',
    weeklyCautionLimit: 2,
    ...overrides,
  };
}

function assessment(dateKey, humidityFlag = 'humidityHigh') {
  const emptyDomain = {
    state: 'stable',
    score: 100,
    flags: [],
    summary: '',
    recommendedActions: [],
    sourceUpdatedAt: null,
  };

  return {
    dateKey,
    featureDateKey: dateKey,
    domains: {
      environment: {
        state: 'caution',
        score: 82,
        flags: [humidityFlag],
        summary: '過去7日間の湿度に注意したい状態です。',
        recommendedActions: ['ケージ周辺の通気を確認してください。'],
        sourceUpdatedAt: null,
        components: {
          temperature: {
            state: 'good',
            score: 100,
            summary: '温度は安定しています。',
            flags: [],
          },
          humidity: {
            state: 'caution',
            score: 70,
            summary: '湿度が高めです。',
            flags: [humidityFlag],
          },
        },
      },
      activity: emptyDomain,
      body: emptyDomain,
      condition: emptyDomain,
      nutrition: emptyDomain,
    },
    overall: {
      state: 'caution',
      score: 82,
      observedState: 'caution',
      observedScore: 82,
      confidence: 'high',
      isProvisional: false,
      flags: [humidityFlag],
      summary: '湿度に注意したい状態です。',
      recommendedActions: ['ケージ周辺の通気を確認してください。'],
      primaryFactor: '環境: 過去7日間の湿度に注意したい状態です。',
    },
    dataQuality: {
      completeness: 1,
      availableDomains: ['environment'],
      missingDomains: [],
      staleDomains: [],
    },
    aiAdvisorContext: null,
    evaluatorVersion: 4,
    evaluatedAt: new Date(`${dateKey}T00:00:00Z`),
  };
}

function stableAssessment(dateKey) {
  const value = assessment(dateKey);
  value.domains.environment.state = 'stable';
  value.domains.environment.score = 100;
  value.domains.environment.flags = [];
  value.domains.environment.components.humidity.state = 'good';
  value.domains.environment.components.humidity.score = 100;
  value.domains.environment.components.humidity.flags = [];
  value.overall.state = 'stable';
  value.overall.score = 100;
  value.overall.observedState = 'stable';
  value.overall.observedScore = 100;
  value.overall.flags = [];
  value.overall.primaryFactor = null;
  return value;
}

test('synonymous humidity flags share one incident id', () => {
  const direct = normalizeHealthIncidentCondition(
    'environment',
    'humidityHigh',
  );
  const rolling = normalizeHealthIncidentCondition(
    'environment',
    'humidityHighRecentWindow',
  );

  assert.equal(direct, 'humidity_high');
  assert.equal(rolling, direct);
  assert.equal(
    buildHealthIncidentId('environment', direct),
    'environment:humidity_high',
  );
});

test('notification key stays stable across dates and humidity flag aliases', () => {
  const first = buildGoldHealthNotificationCandidate(
    assessment('2026-09-10', 'humidityHigh'),
  );
  const nextDay = buildGoldHealthNotificationCandidate(
    assessment('2026-09-11', 'humidityHighRecentWindow'),
  );

  assert.equal(first.incidentId, 'environment:humidity_high');
  assert.equal(nextDay.incidentId, first.incidentId);
  assert.equal(nextDay.notificationKey, first.notificationKey);
});

test('lifecycle builder emits stable active incident records', () => {
  const incidents = buildActiveHealthIncidents(
    assessment('2026-09-10', 'humidityHighRecentWindow'),
  );
  const humidity = incidents.find(
    (incident) => incident.incidentId === 'environment:humidity_high',
  );

  assert.ok(humidity);
  assert.equal(humidity.documentId, 'environment__humidity_high');
  assert.equal(humidity.severity, 'medium');
  assert.equal(humidity.state, 'caution');
});

test('unchanged caution is suppressed for 72 hours, then becomes a reminder', () => {
  const sentAt = new Date('2026-09-10T00:00:00Z');
  const previous = snapshot({
    sentAt,
    severity: 'medium',
    state: 'caution',
    score: 70,
  });

  const withinWindow = decideHealthIncidentDelivery({
    now: new Date('2026-09-12T00:00:00Z'),
    severity: 'medium',
    state: 'caution',
    score: 70,
    previous,
    policy: policy(),
  });
  const afterWindow = decideHealthIncidentDelivery({
    now: new Date('2026-09-13T00:00:00Z'),
    severity: 'medium',
    state: 'caution',
    score: 70,
    previous,
    policy: policy(),
  });

  assert.equal(withinWindow.shouldNotify, false);
  assert.equal(withinWindow.suppressionReason, 'reminderWindow');
  assert.equal(afterWindow.shouldNotify, true);
  assert.equal(afterWindow.eventType, 'reminder');
});

test('escalation bypasses the reminder window', () => {
  const decision = decideHealthIncidentDelivery({
    now: new Date('2026-09-10T01:00:00Z'),
    severity: 'high',
    state: 'alert',
    score: 40,
    previous: snapshot({
      sentAt: new Date('2026-09-10T00:00:00Z'),
      severity: 'medium',
      state: 'caution',
      score: 70,
    }),
    policy: policy(),
  });

  assert.equal(decision.shouldNotify, true);
  assert.equal(decision.eventType, 'escalated');
});

test('improving and acknowledged incidents do not produce reminders', () => {
  const sentAt = new Date('2026-09-10T00:00:00Z');
  const improving = decideHealthIncidentDelivery({
    now: new Date('2026-09-14T00:00:00Z'),
    severity: 'medium',
    state: 'caution',
    score: 77,
    previous: snapshot({
      sentAt,
      severity: 'medium',
      state: 'caution',
      score: 70,
    }),
    policy: policy(),
  });
  const acknowledged = decideHealthIncidentDelivery({
    now: new Date('2026-09-14T00:00:00Z'),
    severity: 'medium',
    state: 'caution',
    score: 70,
    previous: snapshot({
      sentAt,
      severity: 'medium',
      state: 'caution',
      score: 70,
      acknowledgedAt: new Date('2026-09-10T02:00:00Z'),
    }),
    policy: policy(),
  });

  assert.equal(improving.suppressionReason, 'improving');
  assert.equal(acknowledged.suppressionReason, 'acknowledged');
});

test('a concurrent evaluator cannot claim the same incident twice', () => {
  const decision = decideHealthIncidentDelivery({
    now: new Date('2026-09-10T00:05:00Z'),
    severity: 'medium',
    state: 'caution',
    score: 70,
    previous: snapshot({
      claimedAt: new Date('2026-09-10T00:00:00Z'),
    }),
    policy: policy(),
  });

  assert.equal(decision.shouldNotify, false);
  assert.equal(decision.suppressionReason, 'claimInProgress');
});

test('acknowledgement and snooze suppress only unchanged incidents', () => {
  const sentAt = new Date('2026-09-10T00:00:00Z');
  const snoozed = decideHealthIncidentDelivery({
    now: new Date('2026-09-10T05:00:00Z'),
    severity: 'medium',
    state: 'caution',
    score: 70,
    previous: snapshot({
      sentAt,
      severity: 'medium',
      state: 'caution',
      score: 70,
      snoozedUntil: new Date('2026-09-11T00:00:00Z'),
    }),
    policy: policy(),
  });
  const escalated = decideHealthIncidentDelivery({
    now: new Date('2026-09-10T05:00:00Z'),
    severity: 'high',
    state: 'alert',
    score: 40,
    previous: snapshot({
      sentAt,
      severity: 'medium',
      state: 'caution',
      score: 70,
      snoozedUntil: new Date('2026-09-11T00:00:00Z'),
    }),
    policy: policy(),
  });

  assert.equal(snoozed.suppressionReason, 'snoozed');
  assert.equal(escalated.eventType, 'escalated');
});

test('reactivated incident is delivered as a recurrence', () => {
  const decision = decideHealthIncidentDelivery({
    now: new Date('2026-09-14T00:00:00Z'),
    severity: 'medium',
    state: 'caution',
    score: 70,
    previous: snapshot({
      sentAt: new Date('2026-09-10T00:00:00Z'),
      severity: 'medium',
      state: 'caution',
      score: 70,
      acknowledgedAt: new Date('2026-09-10T01:00:00Z'),
      reactivatedAt: new Date('2026-09-14T00:00:00Z'),
    }),
    policy: policy(),
  });

  assert.equal(decision.shouldNotify, true);
  assert.equal(decision.eventType, 'recurrence');
});

test('state-change-only preference removes repetitive caution reminders', () => {
  const decision = decideHealthIncidentDelivery({
    now: new Date('2026-09-14T00:00:00Z'),
    severity: 'medium',
    state: 'caution',
    score: 70,
    previous: snapshot({
      sentAt: new Date('2026-09-10T00:00:00Z'),
      severity: 'medium',
      state: 'caution',
      score: 70,
    }),
    policy: policy({cautionFrequency: 'state_changes_only'}),
  });

  assert.equal(decision.shouldNotify, false);
  assert.equal(decision.suppressionReason, 'disabledByPreference');
});

test('Japan quiet hours defer medium notifications but not critical alerts', () => {
  const night = new Date('2026-09-10T14:30:00Z'); // 23:30 JST
  assert.equal(
    isWithinQuietHours({
      now: night,
      startHour: 21,
      endHour: 8,
      timeZone: 'Asia/Tokyo',
    }),
    true,
  );

  const medium = decideHealthIncidentDelivery({
    now: night,
    severity: 'medium',
    state: 'caution',
    score: 70,
    previous: snapshot(),
    policy: policy({quietHoursEnabled: true}),
  });
  const critical = decideHealthIncidentDelivery({
    now: night,
    severity: 'high',
    state: 'alert',
    score: 30,
    previous: snapshot(),
    policy: policy({quietHoursEnabled: true}),
  });

  assert.equal(medium.suppressionReason, 'quietHours');
  assert.equal(critical.eventType, 'new');
});

test('medium notifications stop at two per local week', () => {
  const decision = decideHealthIncidentDelivery({
    now: new Date('2026-09-10T03:00:00Z'),
    severity: 'medium',
    state: 'caution',
    score: 70,
    previous: snapshot({cautionNotificationsThisWeek: 2}),
    policy: policy(),
  });
  const critical = decideHealthIncidentDelivery({
    now: new Date('2026-09-10T03:00:00Z'),
    severity: 'high',
    state: 'alert',
    score: 30,
    previous: snapshot({cautionNotificationsThisWeek: 2}),
    policy: policy(),
  });

  assert.equal(decision.suppressionReason, 'weeklyLimit');
  assert.equal(critical.eventType, 'new');
});

test('weekly counter keys start on Monday in Japan', () => {
  assert.equal(
    healthNotificationWeekKey(
      new Date('2026-09-13T14:59:00Z'), // Sunday 23:59 JST
      'Asia/Tokyo',
    ),
    'week_2026-09-07',
  );
  assert.equal(
    healthNotificationWeekKey(
      new Date('2026-09-13T15:01:00Z'), // Monday 00:01 JST
      'Asia/Tokyo',
    ),
    'week_2026-09-14',
  );
});

test('dry-run shows repeated daily cautions collapsing into one notification', () => {
  const report = replayHealthNotificationHistory([
    assessment('2026-09-07'),
    assessment('2026-09-08'),
    assessment('2026-09-09'),
    assessment('2026-09-10'),
  ], {
    ...defaultHealthNotificationDryRunPolicy,
    quietHoursEnabled: false,
  });

  assert.equal(report.legacyCandidateCount, 4);
  assert.equal(report.notificationCount, 1);
  assert.equal(report.eventCounts.new, 1);
  assert.equal(report.suppressionCounts.disabledByPreference, 3);
});

test('dry-run emits a resolution only after a delivered incident', () => {
  const report = replayHealthNotificationHistory([
    assessment('2026-09-07'),
    stableAssessment('2026-09-08'),
  ], {
    ...defaultHealthNotificationDryRunPolicy,
    quietHoursEnabled: false,
  });

  assert.equal(report.notificationCount, 2);
  assert.equal(report.eventCounts.new, 1);
  assert.equal(report.eventCounts.resolved, 1);
  assert.equal(
    titleForResolvedHealthIncident('humidity_high'),
    'ケージの湿度が目安の範囲に戻りました',
  );
});

test('dry-run respects disabled notification categories', () => {
  const report = replayHealthNotificationHistory([
    assessment('2026-09-07'),
  ], {
    ...defaultHealthNotificationDryRunPolicy,
    quietHoursEnabled: false,
    notificationCategories: {
      ...defaultHealthNotificationDryRunPolicy.notificationCategories,
      environment: false,
    },
  });

  assert.equal(report.notificationCount, 0);
  assert.equal(report.suppressionCounts.categoryDisabled, 1);
});

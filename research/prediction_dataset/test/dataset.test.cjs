"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {load, T0, T1, LATER, BEFORE, at, anchor, observation, amendment, feature, fixture, policy, generate, findFeature, deepFreeze, CODE} = require("./helpers.cjs");

test("all prediction anchors produce audit rows including unanswered days", () => {
  const f = fixture({anchors: [anchor(), anchor({id: "synthetic_anchor_april02", referenceDateKey: "2030-04-02"})]});
  const r = generate(f, policy({labelFinalizedAt: LATER, dataAvailableThrough: LATER}));
  assert.equal(r.auditRows.length, 2);
  assert.equal(r.candidateRows.length, 1);
  const unanswered = r.auditRows.find(x => x.t0 === T1);
  assert.equal(unanswered.status, "label_missing");
  assert.equal(unanswered.labels.initial, null);
  assert.ok(unanswered.reasonCodes.includes("no_eligible_label"));
});
test("dataset not complete through explicit L is hold, not unanswered", () => {
  const r = generate(fixture({observations: []}), policy({dataAvailableThrough: "2030-04-01T23:59:59Z"}));
  assert.equal(r.auditRows[0].status, "hold");
  assert.ok(r.auditRows[0].reasonCodes.includes("data_not_complete_through_L"));
  assert.equal(r.candidateRows.length, 0);
});
test("L is mandatory and cannot precede the target window end", () => {
  assert.throws(() => generate(fixture(), policy({labelFinalizedAt: undefined})), /./);
  assert.throws(() => generate(fixture(), policy({labelFinalizedAt: T0})), /./);
});
test("same observation yields one candidate with an auditable label-policy difference", () => {
  const r = generate(fixture({observations: [observation("synthetic_changed", {amendments: [amendment()]})]}));
  assert.equal(r.candidateRows.length, 1);
  assert.equal(r.labelDifferences.length, 1);
  assert.equal(r.labelDifferences[0].observationId, "synthetic_changed");
  assert.equal(r.labelDifferences[0].initial, "normal");
  assert.equal(r.labelDifferences[0].corrected, "slightlyConcerned");
  assert.equal(r.auditRows[0].researchEligibility, "not_assessed");
  assert.equal(r.auditRows[0].predictionReady, "not_assessed");
});
test("cancellation keeps the selected observation in audit without learning label", () => {
  const r = generate(fixture({observations: [observation("synthetic_cancelled", {amendments: [amendment({kind: "cancel", condition: undefined})]})]}));
  assert.equal(r.auditRows[0].labels.selectedObservationId, "synthetic_cancelled");
  assert.equal(r.auditRows[0].status, "label_missing");
  assert.equal(r.candidateRows.length, 0);
  assert.ok(r.auditRows[0].reasonCodes.includes("cancelled_by_finalization"));
});
test("feature cutoff uses accepted and available revision before T0, not latest current", () => {
  const old = feature();
  const correction = feature({revisionId: "synthetic_weight_revision_2", revision: 2, acceptedAt: "2030-04-01T03:00:00Z", availableAt: "2030-04-01T03:00:00Z", value: 106});
  const delayed = feature({revisionId: "synthetic_weight_revision_3", revision: 3, acceptedAt: BEFORE, availableAt: "2030-04-01T02:00:00Z", value: 109});
  const r = generate(fixture({featureRevisions: [correction, delayed, old]}));
  const weight = findFeature(r.auditRows[0], "weight_last_g");
  assert.equal(weight.value, 101);
  assert.equal(weight.provenance.revisionId, old.revisionId);
  assert.equal(weight.status, "usable");
});
test("extending L never extends feature cutoff T0", () => {
  const later = feature({revisionId: "synthetic_future_weight", revision: 2, acceptedAt: T1, availableAt: T1, value: 107});
  const f = fixture({featureRevisions: [feature(), later]});
  const a = generate(f).auditRows[0];
  const b = generate(f, policy({labelFinalizedAt: LATER, dataAvailableThrough: LATER})).auditRows[0];
  assert.deepEqual(a.features, b.features);
  assert.equal(findFeature(b, "weight_last_g").value, 101);
});
test("actual zero survives while absent feature stays unknown", () => {
  const activity = feature({featureId: "activity_last_m", revisionId: "synthetic_zero_distance", logicalId: "synthetic_distance", value: 0, unit: "m"});
  const r = generate(fixture({featureRevisions: [activity]}), policy({featureIds: ["activity_last_m", "care_walk_minutes"]}));
  const row = r.auditRows[0];
  assert.equal(findFeature(row, "activity_last_m").value, 0);
  assert.equal(findFeature(row, "activity_last_m").status, "usable");
  assert.equal(findFeature(row, "care_walk_minutes").value, null);
  assert.equal(findFeature(row, "care_walk_minutes").status, "missing");
  assert.equal(row.status, "candidate");
});
test("missing subject is not inferred from a shared owner", () => {
  const unknown = feature({subjectId: null});
  const r = generate(fixture({featureRevisions: [unknown]}), policy({requiredFeatureIds: ["weight_last_g"]}));
  const row = r.auditRows[0];
  assert.equal(findFeature(row, "weight_last_g").value, null);
  assert.equal(row.status, "ineligible");
  assert.ok(row.reasonCodes.includes("required_feature_unavailable"));
});
test("PARTIAL sensor evidence is observed point evidence, not a daily count or coverage", () => {
  const sensorQuality = {status: "PARTIAL", observedCount: 1, wholeCount: null, expectedCount: null, ratio: null, deviceAssociation: "confirmed", subjectAssociation: "confirmed", freshness: "unknown"};
  const temperature = feature({featureId: "temperature_last_received_c", revisionId: "synthetic_temperature_1", logicalId: "synthetic_reading_1", value: 23.4, unit: "degC", quality: "partial", sensorQuality});
  const count = feature({featureId: "sensor_period_count", revisionId: "synthetic_partial_count", logicalId: "synthetic_sensor_window", value: null, unit: "count", quality: "partial", sensorQuality});
  const r = generate(fixture({featureRevisions: [feature(), temperature, count]}), policy({featureIds: ["weight_last_g", "temperature_last_received_c", "sensor_period_count"], allowPartialFeatureIds: ["temperature_last_received_c"]}));
  const row = r.auditRows[0];
  const point = findFeature(row, "temperature_last_received_c");
  assert.equal(point.status, "partial");
  assert.equal(point.value, 23.4);
  assert.equal(point.sensorQuality.observedCount, 1);
  assert.equal(point.sensorQuality.wholeCount, null);
  assert.equal(point.sensorQuality.ratio, null);
  assert.equal(point.sensorQuality.freshness, "unknown");
  assert.equal(findFeature(row, "sensor_period_count").value, null);
  assert.equal(findFeature(row, "weight_last_g").value, 101);
  assert.equal(row.status, "candidate");
});
test("unknown sensor device association does not discard valid weight", () => {
  const sensorQuality = {status: "PARTIAL", observedCount: 1, wholeCount: null, expectedCount: null, ratio: null, deviceAssociation: "unknown", subjectAssociation: "confirmed", freshness: "unknown"};
  const temperature = feature({featureId: "temperature_last_received_c", revisionId: "synthetic_unmapped_temp", logicalId: "synthetic_unmapped_reading", value: 22, unit: "degC", quality: "partial", sensorQuality});
  const r = generate(fixture({featureRevisions: [feature(), temperature]}), policy({featureIds: ["weight_last_g", "temperature_last_received_c"]}));
  const row = r.auditRows[0];
  assert.equal(findFeature(row, "weight_last_g").status, "usable");
  assert.equal(findFeature(row, "temperature_last_received_c").value, null);
  assert.equal(row.status, "candidate");
});
test("root grid unknown subject produces explicit ineligible row rather than disappearing", () => {
  const r = generate(fixture({anchors: [anchor({subjectId: null})]}));
  assert.equal(r.auditRows.length, 1);
  assert.equal(r.auditRows[0].status, "ineligible");
  assert.equal(r.candidateRows.length, 0);
});
test("repeated generation and permuted arrays retain identical semantic result and hashes", () => {
  const e = observation("synthetic_changed", {amendments: [amendment(), amendment({id: "synthetic_amendment_late", revision: 3, condition: "veryConcerned", acceptedAt: LATER, availableAt: LATER})]});
  const f = fixture({observations: [e, observation("synthetic_other")], featureRevisions: [feature(), feature({revisionId: "synthetic_prior_revision", revision: 0, value: 98, acceptedAt: "2030-03-31T20:00:00Z", availableAt: "2030-03-31T20:00:00Z"})]});
  const a = generate(f);
  const b = generate({...f, observations: [...f.observations].reverse().map(x => ({...x, amendments: [...x.amendments].reverse()})), featureRevisions: [...f.featureRevisions].reverse()});
  assert.deepEqual(a, b);
  assert.equal(a.manifest.contentHash, generate(f).manifest.contentHash);
  assert.equal(a.manifest.fixtureHash, b.manifest.fixtureHash);
});
test("generator never mutates even deeply frozen inputs and has no Date.now dependency", () => {
  const f = fixture(); const p = policy();
  const beforeF = JSON.stringify(f); const beforeP = JSON.stringify(p);
  deepFreeze(f); deepFreeze(p);
  const realNow = Date.now;
  let a; let b;
  try { Date.now = () => {throw new Error("ambient_clock_forbidden");}; a = generate(f, p); b = generate(f, p); }
  finally {Date.now = realNow;}
  assert.deepEqual(a, b);
  assert.equal(JSON.stringify(f), beforeF);
  assert.equal(JSON.stringify(p), beforeP);
});
test("manifest identifies policies, catalog, counts and synthetic-only nonapproval", () => {
  const p = policy(); const f = fixture(); const r = generate(f, p); const m = r.manifest;
  assert.equal(m.synthetic_only, true);
  assert.equal(m.fixtureId, f.id);
  assert.match(m.fixtureHash, /^[a-f0-9]{64}$/);
  assert.match(m.contentHash, /^[a-f0-9]{64}$/);
  assert.equal(m.codeIdentity, CODE);
  assert.equal(m.featurePolicyVersion, p.featurePolicyVersion);
  assert.deepEqual(m.labelPolicyVersions, p.labelPolicyVersions);
  assert.deepEqual(m.catalogVersions, f.catalogVersions);
  assert.equal(m.window.timeZone, "Asia/Tokyo");
  assert.equal(m.window.labelFinalizedAt, T1);
  assert.equal(m.anchorCount, 1);
  assert.equal(m.candidateCount, 1);
  assert.equal(m.stateCounts.candidate, 1);
  assert.equal(m.researchEligibility, "not_assessed");
  assert.equal(m.predictionReady, "not_assessed");
});
test("changing explicit L or policy creates a distinguishable dataset identity", () => {
  const f = fixture();
  const a = generate(f);
  const b = generate(f, policy({labelFinalizedAt: LATER, dataAvailableThrough: LATER}));
  const c = generate(f, policy({version: "synthetic_local_policy_v2"}));
  assert.notEqual(a.manifest.datasetId, b.manifest.datasetId);
  assert.notEqual(a.manifest.datasetId, c.manifest.datasetId);
});

test("optional partial evidence is audited but needs explicit feature-policy permission for candidate input", () => {
  const sensorQuality={status:'PARTIAL',observedCount:1,wholeCount:null,expectedCount:null,ratio:null,deviceAssociation:'confirmed',subjectAssociation:'confirmed',freshness:'unknown'};
  const temperature=feature({featureId:'temperature_last_received_c',revisionId:'synthetic_temp_partial',logicalId:'synthetic_temp',value:23.4,unit:'degC',quality:'partial',sensorQuality});
  const f=fixture({featureRevisions:[feature(),temperature]});
  const base=policy({featureIds:['weight_last_g','temperature_last_received_c']});
  const audited=generate(f,base).auditRows[0];
  assert.equal(audited.status,'candidate');
  assert.equal(audited.featureEligibility.weight_last_g,true);
  assert.equal(audited.featureEligibility.temperature_last_received_c,false);
  const permitted=generate(f,{...base,allowPartialFeatureIds:['temperature_last_received_c']}).auditRows[0];
  assert.equal(permitted.featureEligibility.temperature_last_received_c,true);
});

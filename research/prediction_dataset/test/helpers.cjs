"use strict";
const path = require("node:path");
const {loadTypeScript} = require("../tools/load-typescript.cjs");
const load = name => loadTypeScript(path.join(__dirname, "../src", name + ".ts"));
const T0 = "2030-04-01T00:00:00.000000000Z";
const T1 = "2030-04-02T00:00:00.000000000Z";
const LATER = "2030-04-03T00:00:00.000000000Z";
const BEFORE = "2030-03-31T23:00:00.000000000Z";
const DURING = "2030-04-01T04:00:00.000000000Z";
const SUBJECT = "synthetic_subject_amber";
const OWNER = "synthetic_owner_fern";
const at = value => ({precision: "instant", at: value, clock: "user_reported"});
const anchor = (overrides = {}) => ({id: "synthetic_anchor_april01", ownerId: OWNER, subjectId: SUBJECT, referenceDateKey: "2030-04-01", ...overrides});
const point = overrides => load("time").predictionPoint(anchor(overrides));
const observation = (id = "synthetic_observation_a", overrides = {}) => ({
  id, ownerId: OWNER, subjectId: SUBJECT,
  original: {id: `${id}_original`, revision: 1, acceptedAt: DURING, availableAt: DURING,
    condition: "normal", explicit: true, timing: at(DURING)},
  amendments: [], ...overrides,
});
const amendment = (overrides = {}) => ({
  id: "synthetic_revision_2", revision: 2, kind: "correction", acceptedAt: "2030-04-01T05:00:00Z", availableAt: "2030-04-01T05:00:00Z", condition: "slightlyConcerned", ...overrides,
});
const feature = (overrides = {}) => ({
  revisionId: "synthetic_weight_revision_1", logicalId: "synthetic_weight_measurement_a", ownerId: OWNER, subjectId: SUBJECT,
  featureId: "weight_last_g", revision: 1, operation: "upsert", acceptedAt: BEFORE, availableAt: BEFORE,
  timing: at(BEFORE), value: 101, unit: "g", quality: "verified", ...overrides,
});
const fixture = (overrides = {}) => ({schemaVersion: "synthetic_dataset_fixture_v1", id: "synthetic_dataset_expectations",
  syntheticOnly: true, catalogVersions: {observation: "observation_catalog_v1", care: "care_action_catalog_v2"},
  anchors: [anchor()], observations: [observation()], featureRevisions: [feature()], ...overrides,
});
const policy = (overrides = {}) => ({schemaVersion: "synthetic_dataset_policy_v1", version: "synthetic_local_policy_v1",
  datasetSchemaVersion: "synthetic_training_row_v1", featurePolicyVersion: "synthetic_feature_policy_v1",
  labelPolicyVersions: {initial: "synthetic_label_initial_v1", corrected: "synthetic_label_corrected_v1"},
  windowRule: "jst09_next09_open_closed_v1", timeZone: "Asia/Tokyo", labelFinalizedAt: T1, dataAvailableThrough: T1,
  featureIds: ["weight_last_g"], requiredFeatureIds: [], ...overrides,
});
const CODE = "synthetic_test_source_sha256_01";
const generate = (f = fixture(), p = policy()) => load("generate").generateDataset(f, p, CODE);
const findFeature = (row, id) => row.features.find(x => x.featureId === id);
const deepFreeze = value => {if (value && typeof value === "object" && !Object.isFrozen(value)) {Object.freeze(value); for (const next of Object.values(value)) deepFreeze(next);} return value;};
module.exports = {load, T0, T1, LATER, BEFORE, DURING, SUBJECT, OWNER, at, anchor, point, observation, amendment, feature, fixture, policy, generate, findFeature, CODE, deepFreeze};

'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const {loadTypeScript} = require('../tools/load-typescript.cjs');
const {selectFeatures} = loadTypeScript(path.join(__dirname, '../src/features.ts'));
const {predictionPoint} = loadTypeScript(path.join(__dirname, '../src/time.ts'));
const point = predictionPoint({id:'synthetic_anchor',ownerId:'synthetic_owner',subjectId:'synthetic_subject',referenceDateKey:'2030-04-01'});
const policy = {schemaVersion:'synthetic_dataset_policy_v1',version:'synthetic_policy_v1',datasetSchemaVersion:'synthetic_rows_v1',featurePolicyVersion:'synthetic_features_v1',labelPolicyVersions:{initial:'initial_v1',corrected:'corrected_v1'},windowRule:'jst09_next09_open_closed_v1',timeZone:'Asia/Tokyo',labelFinalizedAt:point.t1,dataAvailableThrough:point.t1,featureIds:['weight_last_g'],requiredFeatureIds:[]};
const t = at => ({precision:'instant',at,clock:'user_reported'});
function source(extra={}) {
  return {revisionId:'synthetic_weight_r1',logicalId:'synthetic_weight',ownerId:'synthetic_owner',subjectId:'synthetic_subject',featureId:'weight_last_g',revision:1,operation:'upsert',acceptedAt:'2030-03-31T10:01:00Z',availableAt:'2030-03-31T10:01:00Z',timing:t('2030-03-31T10:00:00Z'),value:42,unit:'g',quality:'verified',...extra};
}
function feature(revisions, featureId='weight_last_g', selectedId) {
  return selectFeatures(point,revisions,{...policy,featureIds:[featureId]},selectedId)[0];
}
const has = (f, code) => assert.ok(f.reasonCodes.includes(code), JSON.stringify(f));
function frozen(v) { if(v && typeof v==='object'){Object.values(v).forEach(frozen);Object.freeze(v);}return v; }

test('known original weight survives a correction received after T0', () => {
  const r=feature([source(),source({revisionId:'synthetic_weight_r2',revision:2,value:44,acceptedAt:'2030-04-01T01:00:00Z',availableAt:'2030-04-01T01:00:00Z'})]);
  assert.equal(r.value,42);assert.equal(r.provenance.revisionId,'synthetic_weight_r1');assert.deepEqual(r,feature([source()]));
});
test('accepted before T0 but available afterwards cannot leak into features', () => {
  const r=feature([source({availableAt:'2030-04-01T00:00:00.000000001Z'})]);
  assert.equal(r.value,null);assert.equal(r.status,'missing');has(r,'no_feature_known_at_cutoff');
});
test('cutoff is inclusive with nanosecond precision', () => {
  const r=feature([source({acceptedAt:point.t0,availableAt:point.t0,timing:t(point.t0)})]);
  assert.equal(r.status,'usable');assert.equal(r.value,42);
});
test('cancellation before cutoff never resurrects an older value', () => {
  const r=feature([source(),source({revisionId:'synthetic_weight_r2',revision:2,operation:'cancel',acceptedAt:'2030-03-31T11:00:00Z',availableAt:'2030-03-31T11:00:00Z'})]);
  assert.equal(r.value,null);has(r,'feature_cancelled');assert.equal(r.provenance.revision,2);
});
test('unknown and mismatching subject identities fail without account inference', () => {
  for(const subjectId of [null,'synthetic_other_subject']) {
    const r=feature([source({subjectId})]);assert.equal(r.status,'excluded');assert.equal(r.value,null);
    has(r,subjectId===null?'feature_subject_unknown':'feature_subject_mismatch');
  }
});
test('a new mismatching revision cannot fall back to the older same logical record', () => {
  const r=feature([source(),source({subjectId:'synthetic_other',revision:2,revisionId:'synthetic_weight_r2'})]);
  assert.equal(r.value,null);has(r,'feature_subject_mismatch');
});
test('other owner features cannot be read via matching subject text', () => {
  const r=feature([source({ownerId:'synthetic_other_owner'})]);assert.equal(r.provenance,null);has(r,'no_feature_known_at_cutoff');
});
test('date-only previous day is eligible but current date is not a completed period', () => {
  const old=feature([source({timing:{precision:'date_only',dateKey:'2030-03-31',timeZone:'Asia/Tokyo'}})]);
  assert.equal(old.value,42);assert.equal(old.provenance.timing.precision,'date_only');
  const current=feature([source({timing:{precision:'date_only',dateKey:'2030-04-01',timeZone:'Asia/Tokyo'}})]);
  assert.equal(current.value,null);has(current,'feature_date_window_not_complete');
});
test('unknown, invalid, or unfinished observation intervals never create times', () => {
  for(const timing of [{precision:'unknown'},t('not_an_instant'),{precision:'interval',start:'2030-03-31T10:00:00Z',end:'2030-04-01T01:00:00Z',clock:'user_reported'}]) {
    const r=feature([source({timing})]);assert.equal(r.value,null);assert.equal(r.status,'excluded');
  }
});
test('actual activity zero is numeric evidence; absent activity is missing', () => {
  const r=feature([source({featureId:'activity_last_m',value:0,unit:'m'})],'activity_last_m');assert.equal(r.status,'usable');assert.equal(r.value,0);
  const missing=feature([],'activity_last_m');assert.equal(missing.value,null);assert.equal(missing.status,'missing');
});
test('weight zero is not a valid weight measurement', () => {
  const r=feature([source({value:0})]);assert.equal(r.value,null);has(r,'invalid_weight_value_or_unit');
});
test('care false and declared zero are preserved with explicit provenance and scope', () => {
  const cleaning=feature([source({featureId:'care_cleaning',value:false,unit:null,answerProvenance:'batch_confirmation',declarationScope:'up_to_acceptance'})],'care_cleaning');
  assert.equal(cleaning.value,false);assert.equal(cleaning.declarationScope,'up_to_acceptance');has(cleaning,'declaration_only_through_acceptance_not_whole_day');
  const walk=feature([source({featureId:'care_walk_minutes',value:0,unit:'minutes',answerProvenance:'batch_confirmation',declarationScope:'completed_period'})],'care_walk_minutes');
  assert.equal(walk.value,0);assert.equal(walk.status,'usable');
});
test('care time unknown and unconfirmed default are not transformed into zero', () => {
  const unknown=feature([source({featureId:'care_walk_minutes',value:null,unit:'minutes',answerProvenance:'item_selection'})],'care_walk_minutes');
  assert.equal(unknown.value,null);has(unknown,'feature_value_missing');
  const automatic=feature([source({featureId:'care_walk_minutes',value:0,unit:'minutes',answerProvenance:'unanswered'})],'care_walk_minutes');
  assert.equal(automatic.value,null);has(automatic,'care_answer_not_explicitly_confirmed');
});
test('Catalog cleaning and bedding enums stay independent; legacy scope is not reclassified', () => {
  const cleaning=feature([source({featureId:'care_cleaning',value:'deep_cleaning',unit:null,answerProvenance:'item_selection'})],'care_cleaning');assert.equal(cleaning.value,'deep_cleaning');
  const bedding=feature([source({featureId:'care_bedding',value:'none',unit:null,answerProvenance:'item_selection'})],'care_bedding');assert.equal(bedding.value,'none');
  const legacy=feature([source({featureId:'care_cleaning',value:'full',unit:null,answerProvenance:'legacy_unspecified'})],'care_cleaning');assert.equal(legacy.value,null);has(legacy,'invalid_or_legacy_cleaning_type');
});
test('automatic item normal is not an explicit past condition response', () => {
  const r=feature([source({featureId:'past_condition',value:'normal',unit:null,answerProvenance:'automatic_normal'})],'past_condition');
  assert.equal(r.value,null);has(r,'past_condition_not_explicit');
});
test('selected target observation cannot reappear among features', () => {
  const r=feature([source({featureId:'past_condition',value:'normal',unit:null,answerProvenance:'explicit',sourceObservationId:'synthetic_target'})],'past_condition','synthetic_target');
  assert.equal(r.value,null);has(r,'feature_target_observation_leakage');
});
const sensor = {status:'PARTIAL',observedCount:1,wholeCount:null,expectedCount:null,ratio:null,deviceAssociation:'confirmed',subjectAssociation:'confirmed',freshness:'unknown'};
test('PARTIAL sensor keeps observed one without fabricating whole counts or averages', () => {
  const r=feature([source({featureId:'sensor_period_count',value:0,unit:'count',quality:'partial',sensorQuality:{...sensor,wholeCount:0,ratio:null}})],'sensor_period_count');
  assert.equal(r.status,'partial');assert.equal(r.value,null);assert.equal(r.sensorQuality.observedCount,1);assert.equal(r.sensorQuality.wholeCount,null);assert.equal(r.sensorQuality.ratio,null);has(r,'sensor_whole_period_quality_unconfirmed');
});
test('partial temperature is received point evidence and never a daily average', () => {
  const r=feature([source({featureId:'temperature_last_received_c',value:22.7,unit:'℃',quality:'partial',sensorQuality:sensor,timing:{precision:'instant',at:'2030-03-31T10:00:00Z',clock:'collection_process'}})],'temperature_last_received_c');
  assert.equal(r.status,'partial');assert.equal(r.value,22.7);has(r,'sensor_measurement_freshness_unknown');assert.equal(r.provenance.timing.clock,'collection_process');
  assert.equal(Object.hasOwn(r,'dailyAverage'),false);
});
test('unknown device blocks only the sensor feature, not valid other sources', () => {
  const out=selectFeatures(point,[source(),source({featureId:'temperature_last_received_c',value:22.7,unit:'℃',sensorQuality:{...sensor,deviceAssociation:'unknown'}})],{...policy,featureIds:['weight_last_g','temperature_last_received_c']});
  assert.equal(out.find(r=>r.featureId==='weight_last_g').value,42);
  const bad=out.find(r=>r.featureId==='temperature_last_received_c');assert.equal(bad.value,null);has(bad,'sensor_device_association_unknown');
});
test('COMPLETE period with actual zero returns zero while expected rate remains unknown', () => {
  const r=feature([source({featureId:'sensor_period_count',value:0,unit:'count',sensorQuality:{...sensor,status:'COMPLETE',observedCount:0,wholeCount:0}})],'sensor_period_count');
  assert.equal(r.status,'usable');assert.equal(r.value,0);assert.equal(r.sensorQuality.ratio,null);has(r,'sensor_expected_count_unknown');
});
test('late sensor reception cannot be backdated via an earlier collection timestamp', () => {
  const r=feature([source({featureId:'temperature_last_received_c',value:22.7,unit:'℃',sensorQuality:sensor,acceptedAt:'2030-04-01T01:00:00Z',availableAt:'2030-04-01T01:00:00Z'})],'temperature_last_received_c');
  assert.equal(r.value,null);has(r,'no_feature_known_at_cutoff');
});
test('profile missing birthday stays unknown, and future birthday is rejected', () => {
  const unknown=feature([source({featureId:'birth_date',value:null,unit:null})],'birth_date');assert.equal(unknown.value,null);has(unknown,'feature_value_missing');
  const future=feature([source({featureId:'birth_date',value:'2031-01-01',unit:null})],'birth_date');assert.equal(future.value,null);has(future,'birth_date_after_reference_day');
});
test('conflicting duplicate revisions do not pick a value based on input order', () => {
  const a=source(), b=source({value:44});
  const first=feature([a,b]),reverse=feature([b,a]);assert.deepEqual(first,reverse);assert.equal(first.value,null);has(first,'feature_revision_conflict');
});
test('input order and immutability do not affect chosen feature or evidence', () => {
  const rows=frozen([source(),source({revisionId:'synthetic_weight_new',logicalId:'synthetic_weight_new',timing:t('2030-03-31T11:00:00Z'),acceptedAt:'2030-03-31T11:01:00Z',availableAt:'2030-03-31T11:01:00Z',value:43})]);
  const before=JSON.stringify(rows);const first=feature(rows), reverse=feature([...rows].reverse());
  assert.equal(first.value,43);assert.deepEqual(first,reverse);assert.equal(JSON.stringify(rows),before);
});

test('unseen or future-only feature evidence is indistinguishable from no known evidence', () => {
  const future=source({acceptedAt:'2030-04-01T00:00:00.000000001Z',availableAt:'2030-04-01T00:00:00.000000001Z'});
  assert.deepEqual(feature([future]),feature([]));
});
test('known other-subject failures do not contaminate a chosen valid feature quality', () => {
  const valid=source();
  const alien=source({logicalId:'synthetic_alien',revisionId:'synthetic_alien_r1',subjectId:'synthetic_alien',quality:'unknown'});
  assert.deepEqual(feature([valid,alien]),feature([valid]));
});
test('current-day nonperformance is only an acceptance-time declaration, never a complete day', () => {
  const r=feature([source({featureId:'care_walk_minutes',value:0,unit:'minutes',answerProvenance:'batch_confirmation',declarationScope:'up_to_acceptance',timing:{precision:'date_only',dateKey:'2030-04-01',timeZone:'Asia/Tokyo'},acceptedAt:'2030-03-31T23:00:00Z',availableAt:'2030-03-31T23:00:00Z'})],'care_walk_minutes');
  assert.equal(r.value,0);assert.equal(r.declarationScope,'up_to_acceptance');has(r,'care_as_of_acceptance_declaration_not_completed_day');
});
test('point sensor values require an observed value, rather than a complete zero-reading period', () => {
  const r=feature([source({featureId:'temperature_last_received_c',value:22.7,unit:'℃',sensorQuality:{...sensor,status:'COMPLETE',observedCount:0,wholeCount:0}})],'temperature_last_received_c');
  assert.equal(r.value,null);has(r,'sensor_no_observed_values');
});
test('sensor complete count contradictions and malformed denominator/ratio are excluded', () => {
  for(const [extra,code] of [
    [{status:'COMPLETE',observedCount:1,wholeCount:2},'sensor_complete_observed_count_mismatch'],
    [{expectedCount:-1},'sensor_expected_count_invalid'],
    [{ratio:-0.1,expectedCount:24},'sensor_ratio_invalid'],
    [{ratio:0.5,expectedCount:0},'sensor_ratio_without_positive_denominator'],
    [{ratio:0.5,expectedCount:null},'sensor_ratio_without_positive_denominator'],
  ]) {
    const r=feature([source({featureId:'sensor_period_count',value:null,unit:'count',sensorQuality:{...sensor,...extra}})],'sensor_period_count');
    assert.equal(r.value,null);assert.equal(r.status,'excluded');has(r,code);
  }
});

test('known revision available before its acceptance is invalid and does not resurrect its predecessor', () => {
  const r=feature([source(),source({revisionId:'synthetic_weight_r2',revision:2,value:44,acceptedAt:'2030-03-31T11:00:00Z',availableAt:'2030-03-31T10:59:59Z'})]);
  assert.equal(r.status,'excluded');assert.equal(r.value,null);has(r,'feature_availability_before_acceptance');
  assert.notEqual(r.provenance?.revisionId,'synthetic_weight_r1');
});
test('known higher revision accepted before its predecessor invalidates the logical history', () => {
  const r=feature([source(),source({revisionId:'synthetic_weight_r2',revision:2,value:44,acceptedAt:'2030-03-31T09:00:00Z',availableAt:'2030-03-31T09:00:00Z'})]);
  assert.equal(r.status,'excluded');assert.equal(r.value,null);has(r,'feature_revision_acceptance_order_invalid');
  assert.notEqual(r.provenance?.revisionId,'synthetic_weight_r1');
});

'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {load,fixture,policy,observation,feature,at,deepFreeze,CODE,T0,T1,LATER}=require('./helpers.cjs');
const canonical=(f=fixture())=>({schemaVersion:'canonical_dataset_input_v1',id:f.id,sourceClassification:'synthetic',catalogVersions:f.catalogVersions,observations:f.observations,featureRevisions:f.featureRevisions});
const config=(overrides={})=>{
  const p=policy();
  return {schemaVersion:'canonical_dataset_config_v1',version:p.version,datasetSchemaVersion:p.datasetSchemaVersion,
    featurePolicyVersion:p.featurePolicyVersion,labelPolicyVersions:p.labelPolicyVersions,
    windowRule:'explicit_open_closed_v1',timeZone:'Asia/Tokyo',featureIds:p.featureIds,requiredFeatureIds:p.requiredFeatureIds,
    points:[{id:'synthetic_anchor_april01',ownerId:'synthetic_owner_fern',subjectId:'synthetic_subject_amber',t0:T0,t1:T1,labelFinalizedAt:T1,dataAvailableThrough:T1}],...overrides};
};
const generate=(f=canonical(),p=config())=>load('generate').generateCanonicalDataset(f,p,CODE);

test('canonical generator reuses exactly the synthetic wrapper row/label/feature core',()=>{
  const f=fixture(),p=policy();
  const legacy=load('generate').generateDataset(f,p,CODE);
  const actual=generate(canonical(f),config());
  assert.deepEqual(actual.auditRows,legacy.auditRows);
  assert.deepEqual(actual.candidateRows,legacy.candidateRows);
  assert.deepEqual(actual.labelDifferences,legacy.labelDifferences);
  assert.deepEqual(actual.manifest.stateCounts,legacy.manifest.stateCounts);
  assert.equal(actual.manifest.synthetic_only,true);
  assert.equal(actual.manifest.sourceClassification,'synthetic');
  assert.match(actual.manifest.sourceSnapshotHash,/^[a-f0-9]{64}$/);
});
test('canonical points accept explicit non-09:00 prediction boundaries with nanosecond precision',()=>{
  const t0='2030-04-01T17:30:00.000000000+09:00',t1='2030-04-02T17:30:00.000000000+09:00';
  const accepted='2030-04-01T17:30:00.000000001+09:00';
  const o=observation('synthetic_explicit_window');o.original.acceptedAt=accepted;o.original.availableAt=accepted;o.original.timing=at(accepted);
  const p=config();p.points[0]={...p.points[0],t0,t1,labelFinalizedAt:t1,dataAvailableThrough:t1};
  const r=generate({...canonical(),observations:[o]},p);
  assert.equal(r.auditRows[0].t0,'2030-04-01T08:30:00.000000000Z');
  assert.equal(r.auditRows[0].t1,'2030-04-02T08:30:00.000000000Z');
  assert.equal(r.auditRows[0].status,'candidate');
  assert.equal(r.auditRows[0].labels.selectedObservationId,o.id);
});
test('canonical per-point L and data-completeness clocks are independent',()=>{
  const p=config();p.points.push({...p.points[0],id:'synthetic_second_point',t0:T1,t1:LATER,labelFinalizedAt:LATER,dataAvailableThrough:T1});
  const r=generate(canonical(),p);
  assert.equal(r.auditRows[0].status,'candidate');
  assert.equal(r.auditRows[1].status,'hold');
  assert.ok(r.auditRows[1].reasonCodes.includes('data_not_complete_through_L'));
  assert.equal(r.manifest.window.points.length,2);
});
test('canonical rejects non-forward windows, L before end, and missing explicit clocks',()=>{
  const p=config();p.points[0].t1=T0;assert.throws(()=>generate(canonical(),p),/invalid_prediction_window/);
  const q=config();q.points[0].labelFinalizedAt=T0;assert.throws(()=>generate(canonical(),q),/L_before_T1/);
  const z=config();delete z.points[0].dataAvailableThrough;assert.throws(()=>generate(canonical(),z),/explicit_finalization/);
});
test('canonical duplicate row IDs or same subject and prediction time cannot silently replace rows',()=>{
  const p=config();p.points.push({...p.points[0],t1:LATER,labelFinalizedAt:LATER,dataAvailableThrough:LATER});
  assert.throws(()=>generate(canonical(),p),/conflicting_point_id/);
  const q=config();q.points.push({...q.points[0],id:'synthetic_duplicate_time'});
  assert.throws(()=>generate(canonical(),q),/duplicate_prediction_point/);
});
test('canonical input order, process clock and immutable input do not change rows or hashes',()=>{
  const f=canonical();f.featureRevisions.push(feature({revisionId:'synthetic_future_weight',revision:2,value:45,acceptedAt:T1,availableAt:T1}));
  f.observations.push(observation('synthetic_later_observation'));
  const p=config();p.points.push({...p.points[0],id:'synthetic_next_point',t0:T1,t1:LATER,labelFinalizedAt:LATER,dataAvailableThrough:LATER});
  const f2={...f,observations:[...f.observations].reverse(),featureRevisions:[...f.featureRevisions].reverse()};
  const p2={...p,points:[...p.points].reverse()};
  deepFreeze(f);deepFreeze(p);const before=JSON.stringify([f,p]);
  const originalNow=Date.now;
  try {Date.now=()=>{throw new Error('no_ambient_clock');};assert.deepEqual(generate(f,p),generate(f2,p2));}
  finally {Date.now=originalNow;}
  assert.equal(JSON.stringify([f,p]),before);
});
test('canonical source classification changes provenance identity without approving real-data use',()=>{
  const f=canonical();const a=generate(f),b=generate({...f,sourceClassification:'test'});
  assert.equal(b.manifest.synthetic_only,false);
  assert.equal(b.manifest.sourceClassification,'test');
  assert.notEqual(a.manifest.contentHash,b.manifest.contentHash);
  assert.equal(b.manifest.researchEligibility,'not_assessed');
  assert.equal(b.manifest.predictionReady,'not_assessed');
});
test('legacy synthetic wrapper keeps its strict fixture and identifier gates',()=>{
  const f=fixture();f.syntheticOnly=false;
  assert.throws(()=>load('generate').generateDataset(f,policy(),CODE),/synthetic_fixture_required/);
  const g=fixture();g.observations[0].ownerId='unclassified_owner';
  assert.throws(()=>load('generate').generateDataset(g,policy(),CODE),/synthetic_identifiers_required/);
});

test('partial observation history cannot establish a first label or a training candidate',()=>{
  const f={...canonical(),observationHistory:{status:'partial',reasonCodes:['synthetic_observation_page_missing']}};
  const r=generate(f),row=r.auditRows[0];
  assert.equal(row.status,'hold');
  assert.equal(r.candidateRows.length,0);
  assert.equal(row.labels.selectedObservationId,null);
  assert.equal(row.labels.initial,null);
  assert.equal(row.labels.corrected,null);
  assert.equal(row.labels.provenance,null);
  assert.ok(row.reasonCodes.includes('observation_history_partial'));
  assert.ok(row.reasonCodes.includes('synthetic_observation_page_missing'));
});
test('unknown observation completeness is hold, whereas complete empty history is label missing',()=>{
  const f={...canonical(),observations:[],observationHistory:{status:'unknown',reasonCodes:['synthetic_completeness_unavailable']}};
  const unknown=generate(f).auditRows[0];
  assert.equal(unknown.status,'hold');
  assert.ok(unknown.reasonCodes.includes('observation_history_unknown'));
  const complete=generate({...f,observationHistory:{status:'complete',reasonCodes:[]}}).auditRows[0];
  assert.equal(complete.status,'label_missing');
  assert.ok(complete.reasonCodes.includes('no_eligible_label'));
});
test('non-reconstructable observation history is ineligible despite an otherwise valid answer',()=>{
  const f={...canonical(),observationHistory:{status:'not_reconstructable',reasonCodes:['synthetic_legacy_history_missing']}};
  const row=generate(f).auditRows[0];
  assert.equal(row.status,'ineligible');
  assert.equal(row.labels.status,'ineligible');
  assert.equal(row.labels.selectedObservationId,null);
  assert.equal(row.labels.initial,null);
  assert.equal(row.labels.corrected,null);
  assert.equal(row.labels.provenance,null);
  assert.ok(row.reasonCodes.includes('observation_history_not_reconstructable'));
});

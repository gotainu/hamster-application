import {careActionCatalog, careActionDetailDefinitions} from '../../../functions/src/careActions/careActionCatalog';
import {addDaysToDateKey, isDateKey} from '../../../functions/src/health/dateKey';
import {compareInstants, epochNanos, normalizeInstant} from './time';
import {canonicalStringify} from './canonical';
import {FeatureSelectionPolicy, FeatureId, FeatureResult, FeatureRevision, PredictionPoint, SensorEvidence, TimeEvidence} from './types';

const CONDITIONS = new Set(['normal', 'slightlyConcerned', 'veryConcerned']);
const SENSOR_FEATURES = new Set<FeatureId>(['temperature_last_received_c', 'humidity_last_received_pct', 'sensor_period_count']);
const CARE_FEATURES = new Set<FeatureId>(['care_cleaning', 'care_bedding', 'care_walk_minutes']);
const sortedReasons = (values:string[]):string[] => [...new Set(values)].sort();

function catalogValues(key:string):Set<string> {
  const item = careActionCatalog.find(x => x.id === 'cageCleaning');
  return new Set(item ? careActionDetailDefinitions(item).find(x => x.key === key && !x.legacy)?.values?.map(x => x.id) ?? [] : []);
}
const CLEANING_TYPES = catalogValues('cleaningType');
const BEDDING_TYPES = catalogValues('beddingReplacement');
const WALK_DETAIL = careActionCatalog.find(x => x.id === 'roomWalk')?.detail;

/** An observation's possible end, never an invented actual measurement instant. */
function timingEnd(timing:TimeEvidence):bigint|null {
  if (timing.precision === 'instant') return epochNanos(timing.at);
  if (timing.precision === 'interval') {
    const start = epochNanos(timing.start), end = epochNanos(timing.end);
    return start <= end ? end : null;
  }
  if (timing.precision === 'date_only' && timing.timeZone === 'Asia/Tokyo' && isDateKey(timing.dateKey)) {
    return epochNanos(`${addDaysToDateKey(timing.dateKey, 1)}T00:00:00+09:00`);
  }
  return null;
}
function normalizedTiming(timing:TimeEvidence):TimeEvidence {
  try {
    if (timing.precision === 'instant') return {...timing, at:normalizeInstant(timing.at)};
    if (timing.precision === 'interval') return {...timing, start:normalizeInstant(timing.start), end:normalizeInstant(timing.end)};
  } catch { /* Preserve invalid source evidence for the explicit time gate, without inventing an instant. */ }
  return {...timing};
}
function provenance(r:FeatureRevision):NonNullable<FeatureResult['provenance']> {
  return {revisionId:r.revisionId, logicalId:r.logicalId, revision:r.revision,
    acceptedAt:normalizeInstant(r.acceptedAt), availableAt:normalizeInstant(r.availableAt), timing:normalizedTiming(r.timing)};
}
function safelyKnown(r:FeatureRevision, t0:string):boolean {
  try { return compareInstants(r.acceptedAt, t0) <= 0 && compareInstants(r.availableAt, t0) <= 0; }
  catch { return false; }
}
function valueReasons(r:FeatureRevision):string[] {
  const n = typeof r.value === 'number' && Number.isFinite(r.value);
  const unitIn = (...units:(string|null)[]) => units.includes(r.unit);
  switch (r.featureId) {
    case 'weight_last_g': return n && (r.value as number)>0 && unitIn('g') ? [] : ['invalid_weight_value_or_unit'];
    case 'activity_last_m': return n && (r.value as number)>=0 && unitIn('m') ? [] : ['invalid_activity_value_or_unit'];
    case 'care_walk_minutes': return n && Number.isInteger(r.value) && (r.value as number)>=0 &&
      (r.value as number)<=(WALK_DETAIL?.max ?? 1440) && unitIn('min','minutes') ? [] : ['invalid_walk_minutes_or_unit'];
    case 'care_cleaning': return (typeof r.value === 'boolean' || (typeof r.value === 'string' && CLEANING_TYPES.has(r.value))) && unitIn(null) ? [] : ['invalid_or_legacy_cleaning_type'];
    case 'care_bedding': return typeof r.value === 'string' && BEDDING_TYPES.has(r.value) && unitIn(null) ? [] : ['invalid_bedding_replacement'];
    case 'past_condition': return typeof r.value === 'string' && CONDITIONS.has(r.value) && unitIn(null) ? [] : ['invalid_past_condition'];
    case 'environment_wheel_cm': return n && (r.value as number)>0 && unitIn('cm') ? [] : ['invalid_wheel_value_or_unit'];
    case 'species': return typeof r.value === 'string' && r.value.trim().length>0 && unitIn(null) ? [] : ['species_unknown'];
    case 'birth_date': return typeof r.value === 'string' && isDateKey(r.value) && unitIn(null) ? [] : ['birth_date_unknown_or_invalid'];
    case 'temperature_last_received_c': return n && unitIn('℃','°C','C','degC') ? [] : ['invalid_temperature_value_or_unit'];
    case 'humidity_last_received_pct': return n && (r.value as number)>=0 && (r.value as number)<=100 && unitIn('%','%RH') ? [] : ['invalid_humidity_value_or_unit'];
    case 'sensor_period_count': return unitIn('count','records') && (r.value === null || (n && Number.isInteger(r.value) && (r.value as number)>=0)) ? [] : ['invalid_sensor_count_or_unit'];
  }
}
function sensorSummary(raw:SensorEvidence):SensorEvidence {
  // PARTIAL never carries a whole-period count/ratio. Observed is not a daily mean or coverage.
  return {...raw, wholeCount:raw.status==='COMPLETE' ? raw.wholeCount : null,
    ratio:raw.status==='COMPLETE' ? raw.ratio : null};
}
function evidenceSignature(r:FeatureRevision):string {
  // All field keys are fixed by this typed synthetic contract. No timestamp order is inferred from object insertion order.
  return canonicalStringify([r.featureId,r.logicalId,r.revision,r.revisionId,r.ownerId,r.subjectId,r.operation,
    normalizeInstant(r.acceptedAt),normalizeInstant(r.availableAt),normalizedTiming(r.timing),r.value,r.unit,r.quality,
    r.answerProvenance??null,r.declarationScope??null,r.sourceObservationId??null,
    r.sensorQuality ? [r.sensorQuality.status,r.sensorQuality.observedCount,r.sensorQuality.wholeCount,r.sensorQuality.expectedCount,
      r.sensorQuality.ratio,r.sensorQuality.deviceAssociation,r.sensorQuality.subjectAssociation,r.sensorQuality.freshness] : null]);
}

/**
 * Select only revisions known at T0, then gate identity, observation time and quality.
 * This module performs no aggregation, imputation, profile inference or SDK initialization.
 */
export function selectFeatures(point:PredictionPoint, revisions:FeatureRevision[], policy:FeatureSelectionPolicy,
  selectedObservationId?:string|null):FeatureResult[] {
  const cutoff = epochNanos(point.t0);
  return [...new Set(policy.featureIds)].sort().map(featureId => {
    const all = revisions.filter(r => r.featureId === featureId);
    const owned = all.filter(r => r.ownerId === point.ownerId);
    const known = owned.filter(r => safelyKnown(r, point.t0));
    const reasons:string[]=[];
    // Even the existence of a future revision must not become a T0 feature/quality input.
    if (!known.length) return {featureId, status:'missing', value:null, unit:null, reasonCodes:['no_feature_known_at_cutoff'], provenance:null};

    const groups = new Map<string,FeatureRevision[]>();
    for (const r of known) groups.set(r.logicalId, [...(groups.get(r.logicalId)??[]),r]);
    const latest:FeatureRevision[]=[];
    const historyErrors = new Map<string,string[]>();
    for (const list of groups.values()) {
      const byRevision = new Map<number,FeatureRevision[]>();
      for (const r of list) byRevision.set(r.revision,[...(byRevision.get(r.revision)??[]),r]);
      if ([...byRevision.values()].some(rs => new Set(rs.map(evidenceSignature)).size>1)) {
        reasons.push('feature_revision_conflict');
        continue;
      }
      const errors:string[]=[];
      // Validate clocks only within the knowledge-cutoff slice. A bad known
      // revision invalidates its logical history rather than reviving an older value.
      if (list.some(r => compareInstants(r.availableAt,r.acceptedAt)<0)) errors.push('feature_availability_before_acceptance');
      const sequence=[...byRevision.values()].map(rs => rs[0]).sort((a,b) => a.revision-b.revision);
      if (sequence.some((r,i) => i>0 && compareInstants(r.acceptedAt,sequence[i-1].acceptedAt)<0)) errors.push('feature_revision_acceptance_order_invalid');
      historyErrors.set(list[0].logicalId, errors);
      list.sort((a,b) => b.revision-a.revision || compareInstants(b.acceptedAt,a.acceptedAt) || a.revisionId.localeCompare(b.revisionId));
      latest.push(list[0]);
    }
    const usable:{r:FeatureRevision; status:'usable'|'partial'; reasons:string[]; sensor?:SensorEvidence}[]=[];
    for (const r of latest) {
      const excluded:string[]=[...(historyErrors.get(r.logicalId)??[])];
      const notes:string[]=[];
      if (!point.subjectId || !r.subjectId) excluded.push('feature_subject_unknown');
      else if (r.subjectId!==point.subjectId) excluded.push('feature_subject_mismatch');
      if (!Number.isInteger(r.revision) || r.revision<1) excluded.push('invalid_feature_revision');
      if (r.operation==='cancel') excluded.push('feature_cancelled');
      if (r.quality==='invalid') excluded.push('feature_value_invalid');
      if (r.quality==='unknown') excluded.push('feature_quality_unknown');
      let end:bigint|null=null;
      try { end=timingEnd(r.timing); } catch { excluded.push('feature_observation_time_invalid'); }
      if (end===null) excluded.push('feature_observation_time_unknown');
      else if (end>cutoff) {
        if (r.timing.precision==='date_only' && CARE_FEATURES.has(featureId) && r.declarationScope==='up_to_acceptance' &&
          r.timing.dateKey<=point.referenceDateKey) notes.push('care_as_of_acceptance_declaration_not_completed_day');
        else excluded.push(r.timing.precision==='date_only' ? 'feature_date_window_not_complete' : 'feature_observation_after_cutoff');
      }
      if (r.sourceObservationId && r.sourceObservationId===selectedObservationId) excluded.push('feature_target_observation_leakage');
      if (CARE_FEATURES.has(featureId) && !['item_selection','batch_confirmation'].includes(r.answerProvenance??'')) excluded.push('care_answer_not_explicitly_confirmed');
      if (featureId==='past_condition' && r.answerProvenance!=='explicit') excluded.push('past_condition_not_explicit');
      if (featureId==='birth_date' && typeof r.value==='string' && r.value>point.referenceDateKey) excluded.push('birth_date_after_reference_day');
      if (r.value===null && featureId!=='sensor_period_count') excluded.push('feature_value_missing');
      else excluded.push(...valueReasons(r));
      let sensor:SensorEvidence|undefined;
      if (SENSOR_FEATURES.has(featureId)) {
        if (!r.sensorQuality) excluded.push('sensor_quality_evidence_missing');
        else {
          sensor=sensorSummary(r.sensorQuality);
          if (sensor.deviceAssociation!=='confirmed') excluded.push('sensor_device_association_unknown');
          if (sensor.subjectAssociation!=='confirmed') excluded.push('sensor_subject_association_unknown');
          if (sensor.observedCount===null || !Number.isSafeInteger(sensor.observedCount) || sensor.observedCount<0) excluded.push('sensor_observed_count_unknown_or_invalid');
          if (featureId!=='sensor_period_count' && sensor.observedCount===0) excluded.push('sensor_no_observed_values');
          if (r.sensorQuality.expectedCount!==null && (!Number.isSafeInteger(r.sensorQuality.expectedCount) || r.sensorQuality.expectedCount<0)) excluded.push('sensor_expected_count_invalid');
          if (r.sensorQuality.wholeCount!==null && (!Number.isSafeInteger(r.sensorQuality.wholeCount) || r.sensorQuality.wholeCount<0)) excluded.push('sensor_whole_count_invalid');
          if (r.sensorQuality.ratio!==null && (!Number.isFinite(r.sensorQuality.ratio) || r.sensorQuality.ratio<0 || r.sensorQuality.ratio>1)) excluded.push('sensor_ratio_invalid');
          if (r.sensorQuality.ratio!==null && (r.sensorQuality.expectedCount===null || r.sensorQuality.expectedCount<=0)) excluded.push('sensor_ratio_without_positive_denominator');
          if (sensor.freshness==='unknown') notes.push('sensor_measurement_freshness_unknown');
          if (sensor.status==='PARTIAL') notes.push('sensor_whole_period_quality_unconfirmed');
          if (sensor.expectedCount===null) notes.push('sensor_expected_count_unknown');
          if (sensor.status==='COMPLETE' && (sensor.wholeCount===null || !Number.isSafeInteger(sensor.wholeCount) || sensor.wholeCount<0)) excluded.push('sensor_complete_count_invalid');
          if (sensor.status==='COMPLETE' && sensor.wholeCount!==sensor.observedCount) excluded.push('sensor_complete_observed_count_mismatch');
        }
      }
      if (r.declarationScope==='up_to_acceptance') notes.push('declaration_only_through_acceptance_not_whole_day');
      if (r.declarationScope==='unknown' && CARE_FEATURES.has(featureId)) notes.push('care_declaration_scope_unknown');
      if (featureId==='care_cleaning' && r.value===true) notes.push('cleaning_type_unspecified');
      if (excluded.length) {reasons.push(...excluded);continue;}
      const partial = r.quality==='partial' || sensor?.status==='PARTIAL' || notes.includes('cleaning_type_unspecified');
      usable.push({r,status:partial?'partial':'usable',reasons:notes,sensor});
    }
    usable.sort((a,b) => {
      const x=timingEnd(a.r.timing)!, y=timingEnd(b.r.timing)!;
      return x>y?-1:x<y?1:compareInstants(b.r.acceptedAt,a.r.acceptedAt)||a.r.logicalId.localeCompare(b.r.logicalId)||a.r.revisionId.localeCompare(b.r.revisionId);
    });
    if (!usable.length) {
      const last = [...latest].sort((a,b)=>compareInstants(b.acceptedAt,a.acceptedAt)||a.revisionId.localeCompare(b.revisionId))[0];
      return {featureId,status:'excluded',value:null,unit:last?.unit??null,reasonCodes:sortedReasons(reasons),
        provenance:last?provenance(last):null,...(last?.sensorQuality?{sensorQuality:sensorSummary(last.sensorQuality)}:{})};
    }
    const chosen=usable[0];
    const value = featureId==='sensor_period_count' ? chosen.sensor?.wholeCount??null : chosen.r.value;
    return {featureId,status:chosen.status,value,unit:chosen.r.unit,reasonCodes:sortedReasons(chosen.reasons),
      provenance:provenance(chosen.r),...(chosen.sensor?{sensorQuality:chosen.sensor}:{}),
      ...(chosen.r.declarationScope?{declarationScope:chosen.r.declarationScope}:{})};
  });
}

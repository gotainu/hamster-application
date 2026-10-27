import {addDaysToDateKey, isDateKey} from '../../../functions/src/health/dateKey';
import {canonicalStringify} from '../../prediction_dataset/src/canonical';
import {compareInstants, normalizeInstant} from '../../prediction_dataset/src/time';
import type {FeatureId, FeatureRevision, ObservationEvent, SensorEvidence, TimeEvidence} from '../../prediction_dataset/src/types';
import type {AcceptedTime, AdapterAudit, EnvironmentSource, NormalizationPoint, NormalizedSourceInput, ProfileSource,
  ResolutionEvidence, SourceEnvelope, SourceKind, SourceSnapshot, SourceSubjectBinding, SourceTiming} from './sourceTypes';

/** Public JSON Timestamp forms only. Never accepts a timestamp without an offset. */
export function sourceInstant(value:AcceptedTime):string {
  if(typeof value==='string') return normalizeInstant(value);
  if(!value || !Number.isSafeInteger(value.seconds) || !Number.isSafeInteger(value.nanoseconds) || value.nanoseconds<0 || value.nanoseconds>=1e9) throw new Error('invalid_source_timestamp');
  return normalizeInstant(new Date(value.seconds*1000).toISOString().slice(0,19)+'.'+String(value.nanoseconds).padStart(9,'0')+'Z');
}
function sameInstant(a:string,b:string):boolean {return compareInstants(a,b)===0;}
function knownBefore(a:string,b:string):boolean {return compareInstants(a,b)<=0;}
function timing(value:SourceTiming|null):TimeEvidence {
  if(!value || value.timePrecision==='unknown') return {precision:'unknown'};
  if(value.timePrecision==='instant') return value.observedAt ? {precision:'instant',at:normalizeInstant(value.observedAt),clock:value.clockSource??'unknown'} : {precision:'unknown'};
  return value.dateKey && isDateKey(value.dateKey) ? {precision:'date_only',dateKey:value.dateKey,timeZone:'Asia/Tokyo'} : {precision:'unknown'};
}
const conditions=new Set(['normal','slightlyConcerned','veryConcerned']);
const sourceFeatures:Record<SourceKind,FeatureId[]>={profiles:['species','birth_date'],observations:['past_condition'],weights:['weight_last_g'],distances:['activity_last_m'],careActions:['care_cleaning','care_bedding','care_walk_minutes'],environments:['environment_wheel_cm'],sensorQuality:['sensor_period_count'],sensorEvidence:['temperature_last_received_c','humidity_last_received_pct']};
const sorted=(x:string[])=>[...new Set(x)].sort();
const later=(x:string,y:string)=>compareInstants(x,y)>=0?x:y;
function stableRows<T extends SourceEnvelope<unknown>>(xs:T[]):T[] {return [...xs].sort((a,b)=>a.sourceId.localeCompare(b.sourceId)||canonicalStringify(a).localeCompare(canonicalStringify(b)));}

/** Normalize saved histories; row generation, feature selection and label selection remain in the generator. */
export function normalizeSnapshot(snapshot:SourceSnapshot,point:NormalizationPoint):NormalizedSourceInput {
  if(snapshot.schemaVersion!=='prediction_source_snapshot_v1') throw new Error('unsupported_source_snapshot_version');
  normalizeInstant(snapshot.capturedAt); normalizeInstant(snapshot.dataAvailableThrough);
  const observations:ObservationEvent[]=[], featureRevisions:FeatureRevision[]=[], audit:AdapterAudit[]=[];
  const note=(source:AdapterAudit['source'],sourceId:string|null,status:AdapterAudit['status'],reasonCodes:string[],featureIds:string[]=source==='subjects'?[]:sourceFeatures[source])=>audit.push({source,sourceId,status,reasonCodes:sorted(reasonCodes),featureIds});
  const scanReason=(source:SourceKind):string|null=>{const status=snapshot.sourceCompleteness?.[source]?.status;return status==='complete'?null:status==='partial'?'source_scan_partial':status==='not_reconstructable'?'source_scan_not_reconstructable':'source_scan_completeness_unknown';};
  for(const source of Object.keys(sourceFeatures) as SourceKind[]) {
    const state=snapshot.sourceCompleteness?.[source],reason=scanReason(source);
    if(reason) note(source,null,state?.status==='not_reconstructable'?'not_reconstructable':'unknown',[...(state?.reasonCodes??[]),reason]);
  }
  const identity=snapshot.subjects.filter(x=>x.ownerId===point.ownerId && x.subjectId===point.subjectId && knownBefore(x.identityAcceptedAt,point.t0));
  if(!point.subjectId || identity.length!==1) note('subjects',null,'unknown',[identity.length>1?'subject_identity_ambiguous':'subject_identity_not_confirmed_at_cutoff']);
  const identityKnown=identity.length===1;
  const owner=(r:{ownerId:string})=>r.ownerId===point.ownerId;
  function binding(value:SourceSubjectBinding|undefined,at:string):string|null {
    if(!value || !identityKnown || value.subjectId!==point.subjectId || !value.evidenceId || !knownBefore(value.acceptedAt,point.t0) || !knownBefore(value.validFrom,at) || (value.validThrough!==null && compareInstants(at,value.validThrough)>=0)) return null;
    return value.subjectId;
  }
  function push(source:SourceKind,envelope:SourceEnvelope<unknown>,r:FeatureRevision,reasons:string[]=[]):void {
    if(!identityKnown) r={...r,subjectId:null};
    const scan=scanReason(source);
    if(scan) {r={...r,quality:'unknown'};reasons=[...reasons,scan];}
    featureRevisions.push(r); note(source,envelope.sourceId,r.subjectId&&!scan?'normalized':'unknown',r.subjectId?reasons:[...reasons,'source_subject_unconfirmed'],[r.featureId]);
  }
  const base=(sourceId:string,ownerId:string,subjectId:string|null,revision:number,acceptedAt:AcceptedTime,availableAt:string)=>({revisionId:sourceId,ownerId,subjectId,revision,acceptedAt:sourceInstant(acceptedAt),availableAt:normalizeInstant(availableAt)});
  for(const source of ['weights','distances'] as const) for(const envelope of stableRows(snapshot.sources[source]).filter(owner)) {
    const d=envelope.data, featureId:FeatureId=source==='weights'?'weight_last_g':'activity_last_m';
    if((source==='weights'?'weight':'distance')!==d.kind) {note(source,envelope.sourceId,'excluded',['measurement_source_kind_mismatch'],[featureId]);continue;}
    const unsupported=d.origin==='legacy_unknown_original';
    push(source,envelope,{...base(envelope.sourceId,envelope.ownerId,d.subjectId,d.recordRevision,d.acceptedAt,envelope.availableAt),logicalId:`${source}:${d.recordId}`,
      featureId,operation:d.operation==='cancel'?'cancel':'upsert',timing:timing(d.timing),value:d.values?.[source==='weights'?'weightGrams':'distance']??null,unit:source==='weights'?'g':'m',quality:unsupported?'unknown':'verified'},
      unsupported?['legacy_history_not_reconstructable']:d.operation==='confirmed_legacy_snapshot'?['legacy_history_before_confirmation_not_reconstructable']:[]);
  }
  const grouped=new Map<string,typeof snapshot.sources.observations>();
  for(const e of stableRows(snapshot.sources.observations).filter(owner)) {const key=`${e.ownerId}\u0000${e.data.dayKey}\u0000${e.data.eventId}`;grouped.set(key,[...(grouped.get(key)??[]),e]);}
  for(const entries of grouped.values()) {
    const originals=entries.filter(e=>e.data.operation==='new_observation' && e.data.origin==='explicit_observation');
    if(originals.length!==1) {for(const e of entries) note('observations',e.sourceId,'not_reconstructable',[originals.length?'observation_original_conflict':'observation_original_not_reconstructable']);continue;}
    const original=originals[0],d=original.data;
    const amendments=entries.filter(e=>e!==original).map(e=>({id:e.sourceId,revision:e.data.revision,kind:e.data.operation==='cancel'?'cancel' as const:'correction' as const,
      acceptedAt:sourceInstant(e.data.acceptedAt),availableAt:normalizeInstant(e.availableAt),...(e.data.answer?{condition:e.data.answer.condition}:{}),...(e.data.timing?{timing:timing(e.data.timing)}:{}),subjectId:e.data.subjectId}));
    observations.push({id:d.eventId,ownerId:original.ownerId,subjectId:identityKnown?d.subjectId:null,
      original:{id:original.sourceId,revision:d.revision,acceptedAt:sourceInstant(d.acceptedAt),availableAt:normalizeInstant(original.availableAt),condition:d.answer?.condition??null,
        explicit:d.answer?.answerProvenance?.overall==='explicit_submission',timing:timing(d.timing)},amendments});
    for(const e of entries) {
      const value=e.data.answer?.condition??null;
      push('observations',e,{...base(e.sourceId,e.ownerId,e.data.subjectId,e.data.revision,e.data.acceptedAt,e.availableAt),logicalId:`observation:${d.eventId}`,featureId:'past_condition',
        operation:e.data.operation==='cancel'?'cancel':'upsert',timing:timing(e.data.timing),value:typeof value==='string'?value:null,unit:null,
        quality:typeof value==='string' && conditions.has(value)?'verified':'unknown',answerProvenance:e.data.answer?.answerProvenance?.overall==='explicit_submission'?'explicit':'legacy_unspecified',sourceObservationId:d.eventId});
    }
  }
  for(const e of stableRows(snapshot.sources.careActions).filter(owner)) {
    const d=e.data,at=sourceInstant(d.acceptedAt);
    const clean=d.actions.cageCleaning,walk=d.actions.roomWalk;
    const targets:[FeatureId,typeof clean|undefined,string|number|boolean|null,string|null][]=[
      ['care_cleaning',clean,clean?.answer==='not_performed'?false:typeof clean?.details.cleaningType==='string'?clean.details.cleaningType:clean?.answer==='performed'?true:null,null],
      ['care_bedding',clean,typeof clean?.details.beddingReplacement==='string'?clean.details.beddingReplacement:null,null],
      ['care_walk_minutes',walk,walk?.answer==='not_performed'?0:typeof walk?.details.durationMinutes==='number'?walk.details.durationMinutes:null,'min']];
    for(const [featureId,a,value,unit] of targets) {
      // These legacy care revisions have no subjectId. Confirm the registration
      // over the observation's possible period, not merely on the submission day.
      const dateKey=a?.occurredDateKey??d.dayKey;
      let boundSubject:string|null=null;
      if(isDateKey(dateKey)) {
        const start=normalizeInstant(`${dateKey}T00:00:00+09:00`),dayEnd=normalizeInstant(`${addDaysToDateKey(dateKey,1)}T00:00:00+09:00`);
        const end=a?.nonPerformanceScope==='up_to_acceptance' && compareInstants(at,dayEnd)<0?at:dayEnd;
        const s=binding(e.binding,start);
        if(s && compareInstants(start,end)<=0 && (!e.binding?.validThrough || compareInstants(end,e.binding.validThrough)<=0)) boundSubject=s;
      }
      push('careActions',e,{...base(`${e.sourceId}:${featureId}`,e.ownerId,boundSubject,d.revision,d.acceptedAt,e.availableAt),logicalId:`care:${e.binding?.subjectId??'unconfirmed'}:${d.dayKey}:${featureId}`,featureId,
      operation:d.status==='cancelled'?'cancel':'upsert',timing:a?.timePrecision==='date_only' && a.occurredDateKey?{precision:'date_only',dateKey:a.occurredDateKey,timeZone:'Asia/Tokyo'}:
        a?.answer==='not_performed'?{precision:'date_only',dateKey:d.dayKey,timeZone:'Asia/Tokyo'}:{precision:'unknown'},
      value,unit,quality:a?.answer==='unanswered' || !a?'unknown':'verified',answerProvenance:a?.answerProvenance??'unanswered',declarationScope:a?.nonPerformanceScope??'unknown'});
    }
  }
  function resolvedEvidence(source:'profiles'|'environments',e:ProfileSource|EnvironmentSource):{acceptedAt:string;availableAt:string;revision:number}|null {
    const requested=e.data.knowledgeCutoff;
    const pointMatches=requested!==null && sameInstant(requested,point.t0) && (source==='profiles'?(e as ProfileSource).data.evaluationDateKey===point.referenceDateKey:sameInstant((e as EnvironmentSource).data.observedAt,point.t0));
    if(!pointMatches) {note(source,e.sourceId,'excluded',['resolved_history_requested_point_mismatch']);return null;}
    if(!e.data.evidenceRevisionIds.length) {note(source,e.sourceId,'not_reconstructable',['history_before_initial_confirmation_or_missing']);return null;}
    const evidence=e.data.evidenceRevisionIds.map(id=>e.evidence.find(x=>x.revisionId===id));
    if(evidence.some(x=>!x)) {note(source,e.sourceId,'unknown',['resolved_history_evidence_missing']);return null;}
    const rows=evidence as ResolutionEvidence[];
    if(rows.some(r=>!knownBefore(sourceInstant(r.acceptedAt),point.t0)||!knownBefore(r.availableAt,point.t0)) || !knownBefore(e.availableAt,point.t0)) {note(source,e.sourceId,'excluded',['resolved_history_evidence_after_cutoff']);return null;}
    return rows.reduce((a,r)=>({acceptedAt:later(a.acceptedAt,sourceInstant(r.acceptedAt)),availableAt:later(a.availableAt,normalizeInstant(r.availableAt)),revision:Math.max(a.revision,r.revision)}),{acceptedAt:sourceInstant(rows[0].acceptedAt),availableAt:normalizeInstant(e.availableAt),revision:0});
  }
  for(const e of stableRows(snapshot.sources.profiles).filter(owner)) {
    if(!e.data.historyExists) {note('profiles',e.sourceId,'not_reconstructable',['profile_history_not_reconstructable']);continue;}
    const evidence=resolvedEvidence('profiles',e);if(!evidence)continue;
    for(const [featureId,value,verified] of [['species',e.data.values.species,e.data.values.species!==null],['birth_date',e.data.values.birthday.dateKey,e.data.values.birthday.quality==='known']] as const)
      push('profiles',e,{...base(`${e.sourceId}:${featureId}`,e.ownerId,e.data.subjectId,evidence.revision,evidence.acceptedAt,evidence.availableAt),logicalId:`profile:${e.data.subjectId}:${featureId}`,featureId,
        operation:'upsert',timing:{precision:'instant',at:point.t0,clock:'unknown'},value,unit:null,quality:verified?'verified':'unknown'},[...e.data.quality.reasons,'resolved_state_at_cutoff_not_observation']);
  }
  for(const e of stableRows(snapshot.sources.environments).filter(owner)) {
    const evidence=resolvedEvidence('environments',e);if(!evidence)continue;
    const field=e.data.values.wheelDiameter,ambiguous=e.data.quality.ambiguousFields.includes('wheelDiameter');
    push('environments',e,{...base(e.sourceId,e.ownerId,binding(e.binding,point.t0),evidence.revision,evidence.acceptedAt,evidence.availableAt),logicalId:`environment:${e.binding?.subjectId??e.sourceId}:wheelDiameter`,featureId:'environment_wheel_cm',operation:'upsert',
      timing:{precision:'instant',at:e.data.observedAt,clock:'unknown'},value:typeof field?.value==='number'?field.value:null,unit:'cm',quality:ambiguous?'unknown':field?.quality==='known'?'verified':field?.quality==='invalid'?'invalid':'unknown'},
      [...e.data.quality.reasons,'resolved_state_at_cutoff_not_observation',...(ambiguous?['environment_effective_time_ambiguous']:[])]);
  }
  for(const e of stableRows(snapshot.sources.sensorQuality).filter(owner)) {
    const q=e.data.quality,subjects=q.binding.subjectIds,matched=subjects.length===1 && subjects[0]===point.subjectId;
    if(!knownBefore(q.informationAsOf,point.t0) || !knownBefore(q.evaluatedThrough,point.t0)) {note('sensorQuality',e.sourceId,'excluded',['sensor_snapshot_information_after_cutoff']);continue;}
    const complete=q.completeness.attempts==='complete'&&q.completeness.readings==='complete'&&q.completeness.states==='complete'&&q.readings.countStatus==='available'&&typeof q.readings.validValueCount?.both==='number';
    const sensor:SensorEvidence={status:complete?'COMPLETE':'PARTIAL',observedCount:q.readings.observed.validValueCount.both,wholeCount:complete?q.readings.validValueCount!.both:null,
      expectedCount:q.opportunities.expectedCount,ratio:complete?q.ratios?.both?.value??null:null,deviceAssociation:e.deviceAssociation,subjectAssociation:matched?'confirmed':'unknown',freshness:'unknown'};
    push('sensorQuality',e,{...base(e.sourceId,e.ownerId,matched?subjects[0]:null,1,e.data.generatedAt,e.availableAt),logicalId:`sensor_quality_snapshot:${e.sourceId}`,featureId:'sensor_period_count',operation:'upsert',
      timing:{precision:'interval',start:q.window.start,end:q.evaluatedThrough,clock:'collection_process'},value:sensor.wholeCount,unit:'count',quality:complete?'verified':'partial',sensorQuality:sensor},q.completeness.reasons);
  }
  for(const e of stableRows(snapshot.sources.sensorEvidence).filter(owner)) {
    const d=e.data;
    if(d.terminal.status!=='reading_saved' || !d.reading) {note('sensorEvidence',e.sourceId,'unknown',['sensor_reading_save_not_confirmed']);continue;}
    const timingAt=d.terminal.responseReceivedAt;
    for(const [metric,featureId,unit] of [['temperature','temperature_last_received_c','°C'],['humidity','humidity_last_received_pct','%']] as const) {
      const valid=d.terminal.validity[metric]==='valid',sensor:SensorEvidence={status:'PARTIAL',observedCount:valid?1:0,wholeCount:null,expectedCount:null,ratio:null,
        deviceAssociation:d.deviceAssociation,subjectAssociation:d.subjectId===point.subjectId?'confirmed':'unknown',freshness:'unknown'};
      push('sensorEvidence',e,{...base(`${e.sourceId}:${metric}`,e.ownerId,d.subjectId,d.revision,d.terminal.acceptedAt,e.availableAt),logicalId:`sensor_attempt:${d.attemptId}:${metric}`,featureId,operation:'upsert',
        timing:timingAt?{precision:'instant',at:normalizeInstant(timingAt),clock:'collection_process'}:{precision:'unknown'},value:d.reading[metric],unit,quality:valid?'partial':'invalid',sensorQuality:sensor},['sensor_response_time_not_measurement_time']);
    }
  }
  return {subjectStatus:identityKnown?'confirmed':'unknown',observations:observations.sort((a,b)=>a.id.localeCompare(b.id)),featureRevisions:featureRevisions.sort((a,b)=>a.revisionId.localeCompare(b.revisionId)),audit:audit.sort((a,b)=>canonicalStringify(a).localeCompare(canonicalStringify(b)))};
}

import {Condition,LabelSelection,ObservationEvent,PredictionPoint} from './types';
import {compareInstants,epochNanos,normalizeInstant,timingInWindow} from './time';
import {canonicalStringify,normalizeInput} from './canonical';
export function isCondition(value:unknown):value is Condition {return ['normal','slightlyConcerned','veryConcerned'].includes(value as string);}
const unique=(a:string[])=>[...new Set(a)].sort();
export function selectLabels(point:PredictionPoint,observations:ObservationEvent[],labelFinalizedAt:string,dataAvailableThrough:string=labelFinalizedAt):LabelSelection {
  // Finalization policy and materialized-data completeness are independent clocks.
  epochNanos(labelFinalizedAt); epochNanos(dataAvailableThrough);
  if(compareInstants(labelFinalizedAt,point.t1)<0) throw new Error('L_before_T1');
  const effectiveCutoff=compareInstants(dataAvailableThrough,labelFinalizedAt)<0?dataAvailableThrough:labelFinalizedAt;
  const candidateExclusions:LabelSelection['candidateExclusions']=[];
  const candidates:ObservationEvent[]=[];
  for(const event of observations.filter(x=>x.ownerId===point.ownerId)) {
    const reasons:string[]=[];
    if(!point.subjectId || !event.subjectId) reasons.push('subject_unconfirmed');
    else if(event.subjectId!==point.subjectId) reasons.push('subject_mismatch');
    if(!event.original.explicit) reasons.push('not_explicit');
    if(!isCondition(event.original.condition)) reasons.push('invalid_initial_condition');
    if(!Number.isSafeInteger(event.original.revision) || event.original.revision<1) reasons.push('invalid_original_revision');
    try {
      if(!timingInWindow(event.original.timing,point.t0,point.t1)) reasons.push('observation_time_not_proven_in_window');
      if(compareInstants(event.original.acceptedAt,point.t0)<=0 || compareInstants(event.original.acceptedAt,point.t1)>0) reasons.push('original_receipt_outside_window');
      if(compareInstants(event.original.availableAt,effectiveCutoff)>0 || compareInstants(event.original.availableAt,event.original.acceptedAt)<0) reasons.push('original_not_available_by_finalization');
    } catch {reasons.push('invalid_observation_timestamp');}
    if(reasons.length) candidateExclusions.push({observationId:event.id,reasonCodes:unique(reasons)}); else candidates.push(event);
  }
  candidateExclusions.sort((a,b)=>a.observationId.localeCompare(b.observationId,'en'));
  const base:LabelSelection={selectedObservationId:null,initial:null,corrected:null,hasCorrection:false,cancelled:false,status:'missing',reasonCodes:[],ordering:'none',candidateExclusions};
  if(!candidates.length) return {...base,reasonCodes:unique(['no_eligible_label',...candidateExclusions.flatMap(x=>x.reasonCodes)])};
  candidates.sort((a,b)=>compareInstants(a.original.acceptedAt,b.original.acceptedAt)||a.id.localeCompare(b.id,'en'));
  const firstTime=candidates[0].original.acceptedAt;
  const tied=candidates.filter(x=>compareInstants(x.original.acceptedAt,firstTime)===0);
  let ordering:LabelSelection['ordering']='receipt';
  if(tied.length>1) {
    const scope=tied[0].originalOrder?.scope;
    if(typeof scope==='string' && scope.trim().length>0 && tied.every(x=>x.originalOrder?.scope===scope && Number.isSafeInteger(x.originalOrder.sequence) && x.originalOrder.sequence>=0) && new Set(tied.map(x=>x.originalOrder!.sequence)).size===tied.length) {
      tied.sort((a,b)=>a.originalOrder!.sequence-b.originalOrder!.sequence); ordering='trusted_sequence';
    } else {tied.sort((a,b)=>a.id.localeCompare(b.id,'en')); ordering='stable_id_fallback';}
  }
  const event=tied[0];
  const result:LabelSelection={...base,selectedObservationId:event.id,initial:event.original.condition as Condition,corrected:event.original.condition as Condition,status:'selected',ordering,reasonCodes:ordering==='stable_id_fallback'?['stable_id_fallback_not_observed_order']:[]};
  const amendments=event.amendments.filter(x=>compareInstants(x.acceptedAt,effectiveCutoff)<=0 && compareInstants(x.availableAt,effectiveCutoff)<=0)
    .sort((a,b)=>a.revision-b.revision||a.id.localeCompare(b.id,'en'));
  result.provenance={originalRevisionId:event.original.id,originalRevision:event.original.revision,
    originalAcceptedAt:normalizeInstant(event.original.acceptedAt),originalAvailableAt:normalizeInstant(event.original.availableAt),
    originalTiming:normalizeInput(event.original.timing) as typeof event.original.timing,
    appliedAmendments:amendments.map(x=>({id:x.id,revision:x.revision,kind:x.kind,
      acceptedAt:normalizeInstant(x.acceptedAt),availableAt:normalizeInstant(x.availableAt)}))};
  result.hasCorrection=amendments.some(x=>x.kind==='correction');
  const revisions=new Map<number,string>();
  let previousAccepted=event.original.acceptedAt;
  for(const amendment of amendments) {
    const content=canonicalStringify(normalizeInput(amendment));
    if(!Number.isSafeInteger(amendment.revision) || amendment.revision<=event.original.revision || (revisions.has(amendment.revision)&&revisions.get(amendment.revision)!==content) || compareInstants(amendment.acceptedAt,previousAccepted)<0 || compareInstants(amendment.availableAt,amendment.acceptedAt)<0) {
      return {...result,initial:null,corrected:null,status:'ineligible',reasonCodes:unique([...result.reasonCodes,'conflicting_revision'])};
    }
    revisions.set(amendment.revision,content); previousAccepted=amendment.acceptedAt;
  }
  if(amendments.some(x=>x.kind==='cancel')) return {...result,initial:null,corrected:null,cancelled:true,status:'missing',reasonCodes:unique([...result.reasonCodes,'cancelled_by_finalization'])};
  let timing=event.original.timing,subjectId=event.subjectId;
  for(const amendment of amendments) {
    if('condition' in amendment) result.corrected=isCondition(amendment.condition)?amendment.condition:null;
    if(amendment.timing) timing=amendment.timing;
    if('subjectId' in amendment) subjectId=amendment.subjectId??null;
  }
  const invalid:string[]=[];
  if(!subjectId || subjectId!==point.subjectId) invalid.push('corrected_subject_ineligible');
  if(!timingInWindow(timing,point.t0,point.t1)) invalid.push('corrected_timing_ineligible');
  if(!result.corrected) invalid.push('invalid_corrected_condition');
  if(invalid.length) return {...result,initial:null,corrected:null,status:'ineligible',reasonCodes:unique([...result.reasonCodes,...invalid])};
  if(result.hasCorrection) result.reasonCodes=unique([...result.reasonCodes,'correction_present_by_finalization']);
  return result;
}

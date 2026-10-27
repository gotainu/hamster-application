import {hash} from '../../prediction_dataset/src/canonical';
import {epochNanos} from '../../prediction_dataset/src/time';
import type {DatasetRow, FeatureId} from '../../prediction_dataset/src/types';
import type {FeatureMetadata,TableRow} from './types';
export const FEATURE_COLUMNS:Record<string,FeatureId>={
  weight_g:'weight_last_g',activity_m:'activity_last_m',past_condition:'past_condition',cleaning:'care_cleaning',
  bedding_replacement:'care_bedding',walk_minutes:'care_walk_minutes',environment_wheel_cm:'environment_wheel_cm',
  species:'species',birth_date:'birth_date',temperature_c:'temperature_last_received_c',humidity_pct:'humidity_last_received_pct',sensor_period_count:'sensor_period_count',
};
/** Stable local aliases avoid persisting UID/source path text; this is pseudonymization, not anonymization. */
export function alias(kind:string,value:string):string {return `${kind}_`+hash({namespace:'hamcare_local_materializer_v1',kind,value});}
export function tableRow(row:DatasetRow,requestedSubject:string|null=row.subjectId):TableRow {
  const feature_metadata:Partial<Record<FeatureId,FeatureMetadata>>={};
  const scalars:Record<string,unknown>={};
  for(const [column,id] of Object.entries(FEATURE_COLUMNS)) {
    const feature=row.features.find(x=>x.featureId===id);
    scalars[column]=feature && row.featureEligibility[id] ? feature.value : null;
    if(!feature) continue;
    const p=feature.provenance;
    feature_metadata[id]={is_missing:scalars[column]===null,eligible:row.featureEligibility[id]===true,quality:feature.status,unit:feature.unit,
      accepted_age_seconds:p?Number(epochNanos(row.t0)-epochNanos(p.acceptedAt))/1e9:null,freshness:'unknown',reason_codes:feature.reasonCodes,
      source_revision:p?{id:alias('revision',p.revisionId),logical_id:alias('record',p.logicalId),revision:p.revision,accepted_at:p.acceptedAt,available_at:p.availableAt,timing:p.timing}:null,
      declaration_scope:feature.declarationScope??null,sensor_quality:feature.sensorQuality??null};
  }
  return {row_id:alias('row',row.ownerId+'|'+(requestedSubject??'unknown')+'|'+row.t0),subject_id:row.subjectId===null?null:alias('subject',row.ownerId+'|'+row.subjectId),owner_group_id:alias('owner',row.ownerId),
    prediction_at:row.t0,target_window_start:row.t0,target_window_end:row.t1,label_finalized_at:row.labelFinalizedAt,...scalars,feature_metadata,
    label_initial:row.labels.initial,label_corrected:row.labels.corrected,label_status:row.labels.status,
    selected_observation_id:row.labels.selectedObservationId?alias('observation',row.labels.selectedObservationId):null,was_corrected:row.labels.hasCorrection,was_cancelled:row.labels.cancelled,
    row_status:row.status,exclusion_reason:row.reasonCodes,feature_spec_version:row.versions.feature,label_policy_version:{initial:row.versions.initialLabel,corrected:row.versions.correctedLabel},dataset_schema_version:row.versions.dataset,
    research_eligibility:'not_assessed',prediction_ready:'not_assessed'} as TableRow;
}
export function aliasAudit(value:unknown,key=''):unknown {
  if(key==='featureIds') return Array.isArray(value)?[...value]:value;
  if(Array.isArray(value)) return value.map(x=>aliasAudit(x,key));
  if(value && typeof value==='object') return Object.fromEntries(Object.entries(value).map(([k,v])=>[k,aliasAudit(v,k)]));
  if(typeof value==='string' && /(?:Id|Ids|ownerId|subjectId)$/.test(key)) return alias('source',value);
  return value;
}

export const TABLE_COLUMNS=(['row_id','subject_id','owner_group_id','prediction_at','target_window_start','target_window_end','label_finalized_at',...Object.keys(FEATURE_COLUMNS),'feature_metadata','label_initial','label_corrected','label_status','selected_observation_id','was_corrected','was_cancelled','row_status','exclusion_reason','feature_spec_version','label_policy_version','dataset_schema_version','research_eligibility','prediction_ready']) as (keyof TableRow)[];

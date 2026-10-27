import {formatDateKey} from '../../../functions/src/health/dateKey';
import {canonicalStringify,hash,normalizeInput} from '../../prediction_dataset/src/canonical';
import {generateCanonicalDataset} from '../../prediction_dataset/src/generate';
import {compareInstants,normalizeInstant} from '../../prediction_dataset/src/time';
import type {CanonicalDatasetConfig,DatasetRow} from '../../prediction_dataset/src/types';
import {normalizeSnapshot} from './adapters';
import type {SourceSnapshot,SnapshotRepository} from './sourceTypes';
import {alias,aliasAudit,FEATURE_COLUMNS,tableRow} from './table';
import type {Materialization,MaterializerAudit} from './types';

function syntheticOnly(snapshot:SourceSnapshot,config:CanonicalDatasetConfig):void {
  if(snapshot.classification!=='synthetic') throw new Error('non_synthetic_materialization_not_enabled');
  for(const point of config.points) for(const id of [point.ownerId,point.subjectId]) if(id!==null && !/^synthetic_[a-zA-Z0-9_-]+$/.test(id)) throw new Error('synthetic_identity_required');
  for(const subject of snapshot.subjects) for(const id of [subject.ownerId,subject.subjectId]) if(!/^synthetic_[a-zA-Z0-9_-]+$/.test(id)) throw new Error('synthetic_identity_required');
}
/** Local snapshot orchestration only; all label/feature/row decisions are delegated to the existing generator. */
export function materialize(source:SourceSnapshot,requested:CanonicalDatasetConfig,codeIdentity:string):Materialization {
  syntheticOnly(source,requested);
  const snapshot=normalizeInput(source) as SourceSnapshot;
  const config=normalizeInput(requested) as CanonicalDatasetConfig;
  if(compareInstants(snapshot.dataAvailableThrough,snapshot.capturedAt)>0) throw new Error('source_completion_after_snapshot_capture');
  const seenPoints=new Set<string>(),seenIds=new Set<string>();
  for(const p of config.points) {
    p.t0=normalizeInstant(p.t0);p.t1=normalizeInstant(p.t1);p.labelFinalizedAt=normalizeInstant(p.labelFinalizedAt);p.dataAvailableThrough=normalizeInstant(p.dataAvailableThrough);
    const key=canonicalStringify([p.ownerId,p.subjectId,p.t0]);
    if(seenPoints.has(key)||seenIds.has(p.id)) throw new Error('duplicate_prediction_point');
    seenPoints.add(key);seenIds.add(p.id);
    if(compareInstants(p.dataAvailableThrough,snapshot.dataAvailableThrough)>0) p.dataAvailableThrough=snapshot.dataAvailableThrough;
  }
  // Validate the complete explicit configuration once, including empty grids, in the shared engine.
  const empty={schemaVersion:'canonical_dataset_input_v1' as const,id:snapshot.snapshotId,sourceClassification:snapshot.classification,catalogVersions:snapshot.catalogVersions,observationHistory:snapshot.sourceCompleteness?.observations??{status:'unknown' as const,reasonCodes:['observation_source_completeness_not_declared']},observations:[],featureRevisions:[]};
  generateCanonicalDataset(empty,config,codeIdentity);
  const rows:Materialization['rows']=[],audit:MaterializerAudit[]=[],canonicalInputHashes:{row_id:string;hash:string}[]=[];
  for(const p of config.points) {
    const point={...p,referenceDateKey:formatDateKey(new Date(p.t0),config.timeZone)};
    const normalized=normalizeSnapshot(snapshot,point);
    const input={...empty,observations:normalized.observations,featureRevisions:normalized.featureRevisions};
    const generated=generateCanonicalDataset(input,{...config,points:[{...p,subjectId:normalized.subjectStatus==='confirmed'?p.subjectId:null}]},codeIdentity);
    const generatedRow=generated.auditRows[0];
    const row=tableRow(generatedRow,p.subjectId);
    // Missing source reconstruction is audit provenance, never a substitute value or a new feature.
    for(const a of normalized.audit.filter(x=>x.status!=='normalized')) for(const id of a.featureIds) {
      const meta=row.feature_metadata[id as keyof typeof row.feature_metadata];
      if(meta?.is_missing) meta.reason_codes=[...new Set([...meta.reason_codes,...(a.status==='not_reconstructable'?['source_not_reconstructable']:[]),...a.reasonCodes])].sort();
    }
    rows.push(row);
    canonicalInputHashes.push({row_id:row.row_id,hash:hash(normalizeInput(input))});
    audit.push({row_id:row.row_id,generator_reasons:generatedRow.reasonCodes,label_evidence:aliasAudit(generatedRow.labels.provenance??null),candidate_exclusions:aliasAudit(generatedRow.labels.candidateExclusions),source_audit:aliasAudit(normalized.audit) as MaterializerAudit['source_audit']});
  }
  rows.sort((a,b)=>a.row_id<b.row_id?-1:a.row_id>b.row_id?1:0);
  audit.sort((a,b)=>a.row_id<b.row_id?-1:a.row_id>b.row_id?1:0);
  canonicalInputHashes.sort((a,b)=>a.row_id<b.row_id?-1:a.row_id>b.row_id?1:0);
  if(new Set(rows.map(x=>x.row_id)).size!==rows.length) throw new Error('duplicate_materialized_row_id');
  const stateCounts:Record<string,number>={candidate:0,hold:0,label_missing:0,ineligible:0},reasonCounts:Record<string,number>={};
  for(const row of rows) {stateCounts[row.row_status]++;for(const reason of row.exclusion_reason)reasonCounts[reason]=(reasonCounts[reason]??0)+1;}
  const base={schema_version:'prediction_materialization_manifest_v1' as const,table_schema_version:'prediction_training_table_v1' as const,dataset_schema_version:config.datasetSchemaVersion,
    feature_policy_version:config.featurePolicyVersion,label_policy_version:config.labelPolicyVersions,source_classification:'synthetic' as const,synthetic_only:true as const,
    source_snapshot_id:alias('snapshot',snapshot.snapshotId),source_snapshot_hash:hash(snapshot),source_schema_version:snapshot.schemaVersion,input_config_hash:hash(normalizeInput(requested)),effective_config_hash:hash(config),
    canonical_input_hashes:canonicalInputHashes,catalog_versions:snapshot.catalogVersions,code_identity:codeIdentity,
    windows:rows.map(row=>{const p=config.points.find(x=>alias('row',x.ownerId+'|'+(x.subjectId??'unknown')+'|'+x.t0)===row.row_id)!;return {row_id:row.row_id,t0:p.t0,t1:p.t1,l:p.labelFinalizedAt,data_available_through:p.dataAvailableThrough};}),
    candidate_row_count:stateCounts.candidate,total_row_count:rows.length,state_counts:stateCounts,reason_counts:reasonCounts,feature_columns:FEATURE_COLUMNS,csv_encoding:'typed_json_cells_v1' as const,
    identity_policy_version:'local_alias_sha256_v1' as const,research_eligibility:'not_assessed' as const,prediction_ready:'not_assessed' as const};
  const contentHash=hash({rows,audit,config,manifest:base});
  return {rows,excludedRows:rows.filter(row=>row.row_status!=='candidate'),audit,config,manifest:{...base,content_hash:contentHash,dataset_id:'materialized_'+contentHash.slice(0,20)}};
}
export async function materializeRepository(repository:SnapshotRepository,config:CanonicalDatasetConfig,codeIdentity:string):Promise<Materialization> {
  return materialize(await repository.readSnapshot(),config,codeIdentity);
}

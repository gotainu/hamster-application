import {OBSERVATION_CATALOG_VERSION} from '../../../functions/src/health/observationCatalog';
import {CARE_ACTION_CATALOG_VERSION} from '../../../functions/src/careActions/careActionCatalog';
import {CanonicalDatasetConfig,CanonicalDatasetInput,CanonicalDatasetOutput,DatasetOutput,DatasetPolicy,DatasetRow,FeatureId,FeatureRevision,ObservationEvent,ObservationHistoryQuality,PredictionPoint,SyntheticFixture} from './types';
import {canonicalStringify,hash,normalizeInput} from './canonical';
import {canonicalPredictionPoint,compareInstants,normalizeInstant,predictionPoint} from './time';
import {selectLabels} from './labels';
import {selectFeatures} from './features';
const featureIds:FeatureId[]=['weight_last_g','activity_last_m','past_condition','care_cleaning','care_bedding','care_walk_minutes','environment_wheel_cm','species','birth_date','temperature_last_received_c','humidity_last_received_pct','sensor_period_count'];
const unique=(a:string[])=>[...new Set(a)].sort();
function validateSynthetic(value:unknown):void {
  if(Array.isArray(value)){for(const item of value) validateSynthetic(item);return;}
  if(value && typeof value==='object') for(const [key,item] of Object.entries(value)) {
    if(['id','ownerId','subjectId','revisionId','logicalId','sourceObservationId'].includes(key) && item!==null && (typeof item!=='string'||!/^synthetic_[a-zA-Z0-9_-]+$/.test(item))) throw new Error('synthetic_identifiers_required');
    validateSynthetic(item);
  }
}
function uniqueRecords<T extends {id:string}>(records:T[],kind:string):T[] {
  const result=new Map<string,T>();
  for(const record of records) {
    const previous=result.get(record.id);
    if(previous && canonicalStringify(previous)!==canonicalStringify(record)) throw new Error('conflicting_'+kind+'_id');
    result.set(record.id,record);
  }
  return [...result.values()];
}

type RowPolicy=Pick<DatasetPolicy,'datasetSchemaVersion'|'featurePolicyVersion'|'labelPolicyVersions'|'featureIds'|'requiredFeatureIds'|'allowPartialFeatureIds'>;
/** The sole row-generation path shared by synthetic wrapper and canonical materialization. */
function generateRows(points:{point:PredictionPoint;labelFinalizedAt:string;dataAvailableThrough:string}[],observations:ObservationEvent[],featureRevisions:FeatureRevision[],policy:RowPolicy,observationHistory?:ObservationHistoryQuality):DatasetRow[] {
  return points.map(({point,labelFinalizedAt,dataAvailableThrough})=>{
    const observedLabels=selectLabels(point,observations,labelFinalizedAt,dataAvailableThrough);
    const historyStatus=observationHistory?.status??'complete';
    const historyIncomplete=historyStatus!=='complete';
    // Partial source pages can hide the first observation or its correction/cancellation.
    // Selection stays in selectLabels; incomplete evidence prevents publishing its tentative result.
    const labels=historyIncomplete ? {...observedLabels,selectedObservationId:null,initial:null,corrected:null,
      hasCorrection:false,cancelled:false,status:historyStatus==='not_reconstructable'?'ineligible' as const:'missing' as const,
      ordering:'none' as const,provenance:null,
      reasonCodes:unique([...observedLabels.reasonCodes,'observation_history_'+historyStatus,...(observationHistory?.reasonCodes??[])])} : observedLabels;
    const features=selectFeatures(point,featureRevisions,policy,labels.selectedObservationId);
    const featureEligibility=Object.fromEntries(features.map(f=>[f.featureId,f.value!==null && (f.status==='usable' || (f.status==='partial' && (policy.allowPartialFeatureIds??[]).includes(f.featureId)))])) as Partial<Record<FeatureId,boolean>>;
    const requiredUnavailable=policy.requiredFeatureIds.filter(id=>!featureEligibility[id]);
    const reasonCodes=unique([...labels.reasonCodes,...(!point.subjectId?['subject_unconfirmed']:[]),...(requiredUnavailable.length?['required_feature_unavailable']:[]),...(compareInstants(dataAvailableThrough,labelFinalizedAt)<0?['data_not_complete_through_L']:[])]);
    let status:DatasetRow['status']='candidate';
    if(historyStatus==='not_reconstructable') status='ineligible';
    else if(historyIncomplete || compareInstants(dataAvailableThrough,labelFinalizedAt)<0) status='hold';
    else if(!point.subjectId || labels.status==='ineligible' || requiredUnavailable.length) status='ineligible';
    else if(labels.status==='missing') status='label_missing';
    return {id:point.id,ownerId:point.ownerId,subjectId:point.subjectId,t0:point.t0,t1:point.t1,labelFinalizedAt:labelFinalizedAt,features,featureEligibility,labels,status,reasonCodes,
      versions:{dataset:policy.datasetSchemaVersion,feature:policy.featurePolicyVersion,initialLabel:policy.labelPolicyVersions.initial,correctedLabel:policy.labelPolicyVersions.corrected},researchEligibility:'not_assessed',predictionReady:'not_assessed'};
  });

}
function summarizeRows(auditRows:DatasetRow[]) {
  const candidateRows=auditRows.filter(x=>x.status==='candidate');
  const labelDifferences=auditRows.filter(x=>x.labels.selectedObservationId!==null && x.labels.initial!==x.labels.corrected).map(x=>({rowId:x.id,observationId:x.labels.selectedObservationId!,initial:x.labels.initial,corrected:x.labels.corrected}));
  const stateCounts:Record<string,number>={candidate:0,hold:0,label_missing:0,ineligible:0},reasonCounts:Record<string,number>={};
  for(const row of auditRows){stateCounts[row.status]++;for(const reason of unique([...row.reasonCodes,...row.features.flatMap(x=>x.reasonCodes)])) reasonCounts[reason]=(reasonCounts[reason]??0)+1;}
  return {candidateRows,labelDifferences,stateCounts,reasonCounts};
}
function validateFeaturePolicy(policy:RowPolicy):void {
  if(policy.featureIds.some(x=>!featureIds.includes(x)) || policy.requiredFeatureIds.some(x=>!policy.featureIds.includes(x)) || (policy.allowPartialFeatureIds??[]).some(x=>!policy.featureIds.includes(x))) throw new Error('invalid_feature_policy');
}
function comparePoints(a:PredictionPoint,b:PredictionPoint):number {
  return a.ownerId.localeCompare(b.ownerId,'en')||(a.subjectId??'').localeCompare(b.subjectId??'','en')||compareInstants(a.t0,b.t0);
}

/** Pure, offline-only dataset derivation. No clock, file, credentials, SDK, or network access. */
export function generateDataset(input:SyntheticFixture,settings:DatasetPolicy,codeIdentity:string):DatasetOutput {
  if(input.syntheticOnly!==true || input.schemaVersion!=='synthetic_dataset_fixture_v1') throw new Error('synthetic_fixture_required');
  validateSynthetic(input);
  if(!codeIdentity.trim()) throw new Error('explicit_code_identity_required');
  if(settings.schemaVersion!=='synthetic_dataset_policy_v1' || settings.windowRule!=='jst09_next09_open_closed_v1' || settings.timeZone!=='Asia/Tokyo') throw new Error('unsupported_policy');
  const fixture=normalizeInput(input) as SyntheticFixture;
  const policy=normalizeInput(settings) as DatasetPolicy;
  if(fixture.catalogVersions.observation!==OBSERVATION_CATALOG_VERSION || fixture.catalogVersions.care!==CARE_ACTION_CATALOG_VERSION) throw new Error('catalog_version_mismatch');
  if(!policy.labelFinalizedAt || !policy.dataAvailableThrough) throw new Error('explicit_finalization_and_data_time_required');
  normalizeInstant(policy.labelFinalizedAt); normalizeInstant(policy.dataAvailableThrough);
  validateFeaturePolicy(policy);
  const anchors=uniqueRecords(fixture.anchors,'anchor');
  const observations=uniqueRecords(fixture.observations,'observation');
  const points=anchors.map(predictionPoint);
  const pointIdentities=new Set<string>();
  for(const point of points) {
    if(compareInstants(policy.labelFinalizedAt,point.t1)<0) throw new Error('L_before_T1');
    const key=canonicalStringify([point.ownerId,point.subjectId,point.t0]);
    if(pointIdentities.has(key)) throw new Error('duplicate_prediction_point');
    pointIdentities.add(key);
  }
  points.sort(comparePoints);
  const auditRows=generateRows(points.map(point=>({point,labelFinalizedAt:policy.labelFinalizedAt,dataAvailableThrough:policy.dataAvailableThrough})),observations,fixture.featureRevisions,policy);
  const {candidateRows,labelDifferences,stateCounts,reasonCounts}=summarizeRows(auditRows);
  const manifestBase={synthetic_only:true as const,fixtureId:fixture.id,fixtureHash:hash(fixture),codeIdentity,
    datasetSchemaVersion:policy.datasetSchemaVersion,featurePolicyVersion:policy.featurePolicyVersion,featurePolicy:{featureIds:policy.featureIds,requiredFeatureIds:policy.requiredFeatureIds,allowPartialFeatureIds:policy.allowPartialFeatureIds??[]},labelPolicyVersions:policy.labelPolicyVersions,policyVersion:policy.version,
    window:{rule:policy.windowRule,timeZone:policy.timeZone,labelFinalizedAt:policy.labelFinalizedAt,dataAvailableThrough:policy.dataAvailableThrough},catalogVersions:fixture.catalogVersions,anchorCount:auditRows.length,candidateCount:candidateRows.length,stateCounts,reasonCounts,researchEligibility:'not_assessed' as const,predictionReady:'not_assessed' as const};
  const contentHash=hash({auditRows,candidateRowIds:candidateRows.map(x=>x.id),labelDifferences,manifest:manifestBase,featurePolicy:{featureIds:policy.featureIds,requiredFeatureIds:policy.requiredFeatureIds,allowPartialFeatureIds:policy.allowPartialFeatureIds??[]}});
  return {auditRows,candidateRows,labelDifferences,manifest:{...manifestBase,datasetId:'synthetic_dataset_'+contentHash.slice(0,20),contentHash}};
}

/**
 * Pure canonical entry point. It never acquires data, authorizes research use, writes a table,
 * guesses prediction boundaries or creates features/labels outside the shared generator core.
 * sourceClassification declares provenance; it is not evidence of consent or authorization.
 */
export function generateCanonicalDataset(input:CanonicalDatasetInput,settings:CanonicalDatasetConfig,codeIdentity:string):CanonicalDatasetOutput {
  if(input.schemaVersion!=='canonical_dataset_input_v1' || !['synthetic','test','production'].includes(input.sourceClassification)) throw new Error('unsupported_canonical_input');
  if(!codeIdentity.trim()) throw new Error('explicit_code_identity_required');
  if(settings.schemaVersion!=='canonical_dataset_config_v1' || settings.windowRule!=='explicit_open_closed_v1' || settings.timeZone!=='Asia/Tokyo') throw new Error('unsupported_canonical_config');
  const source=normalizeInput(input) as CanonicalDatasetInput;
  const config=normalizeInput(settings) as CanonicalDatasetConfig;
  if(source.catalogVersions.observation!==OBSERVATION_CATALOG_VERSION || source.catalogVersions.care!==CARE_ACTION_CATALOG_VERSION) throw new Error('catalog_version_mismatch');
  validateFeaturePolicy(config);
  if(source.observationHistory && (!['complete','partial','not_reconstructable','unknown'].includes(source.observationHistory.status) || !Array.isArray(source.observationHistory.reasonCodes) || source.observationHistory.reasonCodes.some(x=>typeof x!=='string'))) throw new Error('invalid_observation_history_quality');
  const observations=uniqueRecords(source.observations,'observation');
  const points=uniqueRecords(config.points,'point');
  const pointIdentities=new Set<string>();
  const rows=points.map(point=>{
    if(!point.labelFinalizedAt || !point.dataAvailableThrough) throw new Error('explicit_finalization_and_data_time_required');
    if(!point.id || !point.ownerId || (point.subjectId!==null && !point.subjectId)) throw new Error('explicit_point_identity_required');
    const normalized=canonicalPredictionPoint(point,config.timeZone);
    const key=canonicalStringify([point.subjectId??point.ownerId,normalized.t0]);
    if(pointIdentities.has(key)) throw new Error('duplicate_prediction_point');
    pointIdentities.add(key);
    return {point:normalized,labelFinalizedAt:point.labelFinalizedAt,dataAvailableThrough:point.dataAvailableThrough};
  }).sort((a,b)=>comparePoints(a.point,b.point));
  const auditRows=generateRows(rows,observations,source.featureRevisions,config,source.observationHistory);
  const {candidateRows,labelDifferences,stateCounts,reasonCounts}=summarizeRows(auditRows);
  const featurePolicy={featureIds:config.featureIds,requiredFeatureIds:config.requiredFeatureIds,allowPartialFeatureIds:config.allowPartialFeatureIds??[]};
  const manifestBase={synthetic_only:source.sourceClassification==='synthetic',sourceClassification:source.sourceClassification,
    sourceSnapshotId:source.id,sourceSnapshotHash:hash(source),configHash:hash(config),codeIdentity,
    datasetSchemaVersion:config.datasetSchemaVersion,featurePolicyVersion:config.featurePolicyVersion,
    featurePolicy,labelPolicyVersions:config.labelPolicyVersions,policyVersion:config.version,
    window:{rule:config.windowRule,timeZone:config.timeZone,points:rows.map(({point,labelFinalizedAt,dataAvailableThrough})=>({id:point.id,ownerId:point.ownerId,subjectId:point.subjectId,t0:point.t0,t1:point.t1,labelFinalizedAt,dataAvailableThrough}))},
    catalogVersions:source.catalogVersions,anchorCount:auditRows.length,candidateCount:candidateRows.length,stateCounts,reasonCounts,
    researchEligibility:'not_assessed' as const,predictionReady:'not_assessed' as const};
  const contentHash=hash({auditRows,candidateRowIds:candidateRows.map(x=>x.id),labelDifferences,manifest:manifestBase,featurePolicy});
  return {auditRows,candidateRows,labelDifferences,manifest:{...manifestBase,datasetId:'canonical_dataset_'+contentHash.slice(0,20),contentHash}};
}

export type Instant = string;
export type Condition = 'normal' | 'slightlyConcerned' | 'veryConcerned';
export type TimeEvidence =
  | {precision:'instant'; at:Instant; clock:'user_reported'|'collection_process'|'server'|'unknown'}
  | {precision:'interval'; start:Instant; end:Instant; clock:'user_reported'|'collection_process'|'server'|'unknown'}
  | {precision:'date_only'; dateKey:string; timeZone:'Asia/Tokyo'}
  | {precision:'unknown'};
export interface PredictionAnchor { id:string; ownerId:string; subjectId:string|null; referenceDateKey:string }
export interface OriginalObservation {
  id:string; revision:number; acceptedAt:Instant; availableAt:Instant;
  condition:unknown; explicit:boolean; timing:TimeEvidence;
}
export interface ObservationAmendment {
  id:string; revision:number; kind:'correction'|'cancel'; acceptedAt:Instant; availableAt:Instant;
  condition?:unknown; timing?:TimeEvidence; subjectId?:string|null;
}
export interface ObservationEvent {
  id:string; ownerId:string; subjectId:string|null; original:OriginalObservation;
  originalOrder?:{scope:string; sequence:number}; amendments:ObservationAmendment[];
}
export type FeatureId = 'weight_last_g'|'activity_last_m'|'past_condition'|'care_cleaning'|'care_bedding'|'care_walk_minutes'|'environment_wheel_cm'|'species'|'birth_date'|'temperature_last_received_c'|'humidity_last_received_pct'|'sensor_period_count';
export interface SensorEvidence {
  status:'COMPLETE'|'PARTIAL'; observedCount:number|null; wholeCount:number|null;
  expectedCount:number|null; ratio:number|null; deviceAssociation:'confirmed'|'unknown';
  subjectAssociation:'confirmed'|'unknown'; freshness:'verified'|'unknown';
}
export interface FeatureRevision {
  revisionId:string; logicalId:string; ownerId:string; subjectId:string|null; featureId:FeatureId;
  revision:number; operation:'upsert'|'cancel'; acceptedAt:Instant; availableAt:Instant;
  timing:TimeEvidence; value:number|string|boolean|null; unit:string|null;
  quality:'verified'|'partial'|'unknown'|'invalid';
  answerProvenance?:'explicit'|'item_selection'|'batch_confirmation'|'unanswered'|'legacy_unspecified'|'automatic_normal';
  declarationScope?:'completed_period'|'up_to_acceptance'|'unknown';
  sourceObservationId?:string; sensorQuality?:SensorEvidence;
}
export interface FeatureResult {
  featureId:FeatureId; status:'usable'|'partial'|'missing'|'excluded'; value:number|string|boolean|null;
  unit:string|null; reasonCodes:string[];
  provenance:{revisionId:string; logicalId:string; revision:number; acceptedAt:Instant; availableAt:Instant; timing:TimeEvidence}|null;
  sensorQuality?:SensorEvidence; declarationScope?:FeatureRevision['declarationScope'];
}
export interface DatasetPolicy {
  schemaVersion:'synthetic_dataset_policy_v1'; version:string;
  datasetSchemaVersion:string; featurePolicyVersion:string;
  labelPolicyVersions:{initial:string; corrected:string};
  windowRule:'jst09_next09_open_closed_v1'; timeZone:'Asia/Tokyo';
  labelFinalizedAt:Instant; dataAvailableThrough:Instant;
  featureIds:FeatureId[]; requiredFeatureIds:FeatureId[]; allowPartialFeatureIds?:FeatureId[];
}
export type FeatureSelectionPolicy=Pick<DatasetPolicy,'featureIds'|'requiredFeatureIds'|'allowPartialFeatureIds'>;
export interface SyntheticFixture {
  schemaVersion:'synthetic_dataset_fixture_v1'; id:string; syntheticOnly:true;
  catalogVersions:{observation:string; care:string}; anchors:PredictionAnchor[];
  observations:ObservationEvent[]; featureRevisions:FeatureRevision[];
}
export interface PredictionPoint extends PredictionAnchor { t0:Instant; t1:Instant }
export interface LabelSelection {
  selectedObservationId:string|null; initial:Condition|null; corrected:Condition|null;
  hasCorrection:boolean; cancelled:boolean; status:'selected'|'missing'|'ineligible';
  reasonCodes:string[]; ordering:'receipt'|'trusted_sequence'|'stable_id_fallback'|'none';
  candidateExclusions:{observationId:string; reasonCodes:string[]}[];
  provenance?:{originalRevisionId:string; originalRevision:number; originalAcceptedAt:Instant; originalAvailableAt:Instant; originalTiming:TimeEvidence; appliedAmendments:{id:string; revision:number; kind:'correction'|'cancel'; acceptedAt:Instant; availableAt:Instant}[]}|null;
}
export interface DatasetRow {
  id:string; ownerId:string; subjectId:string|null; t0:Instant; t1:Instant;
  labelFinalizedAt:Instant; features:FeatureResult[]; featureEligibility:Partial<Record<FeatureId,boolean>>; labels:LabelSelection;
  status:'candidate'|'hold'|'label_missing'|'ineligible'; reasonCodes:string[];
  versions:{dataset:string; feature:string; initialLabel:string; correctedLabel:string};
  researchEligibility:'not_assessed'; predictionReady:'not_assessed';
}
export interface DatasetOutput {
  auditRows:DatasetRow[]; candidateRows:DatasetRow[];
  labelDifferences:{rowId:string; observationId:string; initial:Condition|null; corrected:Condition|null}[];
  manifest:{synthetic_only:true; datasetId:string; contentHash:string; fixtureId:string; fixtureHash:string;
    codeIdentity:string; datasetSchemaVersion:string; featurePolicyVersion:string;
    featurePolicy:{featureIds:FeatureId[]; requiredFeatureIds:FeatureId[]; allowPartialFeatureIds:FeatureId[]};
    labelPolicyVersions:{initial:string; corrected:string}; policyVersion:string;
    window:{rule:string; timeZone:string; labelFinalizedAt:Instant; dataAvailableThrough:Instant};
    catalogVersions:{observation:string; care:string}; anchorCount:number; candidateCount:number;
    stateCounts:Record<string,number>; reasonCounts:Record<string,number>;
    researchEligibility:'not_assessed'; predictionReady:'not_assessed'};
}

/** Canonical, detached source snapshot. Acquiring/authorizing a source is not a generator responsibility. */
export type SourceClassification = 'synthetic'|'test'|'production';
export interface ObservationHistoryQuality {
  status:'complete'|'partial'|'not_reconstructable'|'unknown'; reasonCodes:string[];
}
export interface CanonicalDatasetInput {
  schemaVersion:'canonical_dataset_input_v1'; id:string; sourceClassification:SourceClassification;
  catalogVersions:SyntheticFixture['catalogVersions'];
  observationHistory?:ObservationHistoryQuality;
  observations:ObservationEvent[]; featureRevisions:FeatureRevision[];
}
/** The caller supplies every boundary. No execution clock or fixed prediction hour is inferred. */
export interface CanonicalPredictionPoint {
  id:string; ownerId:string; subjectId:string|null;
  t0:Instant; t1:Instant; labelFinalizedAt:Instant; dataAvailableThrough:Instant;
}
export interface CanonicalDatasetConfig {
  schemaVersion:'canonical_dataset_config_v1'; version:string;
  datasetSchemaVersion:string; featurePolicyVersion:string;
  labelPolicyVersions:DatasetPolicy['labelPolicyVersions'];
  windowRule:'explicit_open_closed_v1'; timeZone:'Asia/Tokyo';
  featureIds:FeatureId[]; requiredFeatureIds:FeatureId[]; allowPartialFeatureIds?:FeatureId[];
  points:CanonicalPredictionPoint[];
}
export interface CanonicalDatasetOutput {
  auditRows:DatasetRow[]; candidateRows:DatasetRow[]; labelDifferences:DatasetOutput['labelDifferences'];
  manifest:{synthetic_only:boolean; sourceClassification:SourceClassification; datasetId:string; contentHash:string;
    sourceSnapshotId:string; sourceSnapshotHash:string; configHash:string; codeIdentity:string;
    datasetSchemaVersion:string; featurePolicyVersion:string;
    featurePolicy:DatasetOutput['manifest']['featurePolicy'];
    labelPolicyVersions:DatasetPolicy['labelPolicyVersions']; policyVersion:string;
    window:{rule:'explicit_open_closed_v1';timeZone:'Asia/Tokyo';points:CanonicalPredictionPoint[]};
    catalogVersions:SyntheticFixture['catalogVersions'];anchorCount:number;candidateCount:number;
    stateCounts:Record<string,number>;reasonCounts:Record<string,number>;
    researchEligibility:'not_assessed';predictionReady:'not_assessed'};
}

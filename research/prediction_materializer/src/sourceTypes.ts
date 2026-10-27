import type {FeatureRevision, ObservationEvent, PredictionPoint, TimeEvidence} from '../../prediction_dataset/src/types';

export type SourceKind = 'profiles'|'observations'|'weights'|'distances'|'careActions'|'environments'|'sensorQuality'|'sensorEvidence';
export type SourceClassification = 'synthetic'|'test'|'production';
/** JSON serialization of the existing history API: Timestamp precision is kept explicitly. */
export type AcceptedTime = string | {seconds:number; nanoseconds:number};
export interface SourceEnvelope<T> {sourceId:string; ownerId:string; availableAt:string; data:T}
export interface SourceTiming {
  timePrecision:'instant'|'date_only'|'unknown'; observedAt:string|null; dateKey:string|null;
  clockSource?:'user_reported'|'unknown'; timeZone?:'Asia/Tokyo';
  windowMeaning?:'selected_day'|'selected_night_to_next_morning'|'unknown';
}
export interface SubjectIdentitySource {ownerId:string; subjectId:string; identityAcceptedAt:string}
export interface ObservationSourceData {
  subjectId:string|null; dayKey:string; eventId:string; revision:number;
  operation:'new_observation'|'correction'|'cancel'; origin:'explicit_observation'|'legacy_unknown_original';
  targetRevision:number|null; acceptedAt:AcceptedTime; timing:SourceTiming|null;
  answer:{condition:unknown; answerProvenance?:{overall?:string}}|null;
}
export interface MeasurementSourceData {
  subjectId:string|null; kind:'weight'|'distance'; recordId:string; recordRevision:number; dayKey:string;
  operation:'create'|'correction'|'date_correction'|'cancel'|'confirmed_legacy_snapshot';
  origin:'explicit_measurement'|'confirmed_legacy_snapshot'|'legacy_unknown_original';
  acceptedAt:AcceptedTime; timing:SourceTiming|null;
  values:{weightGrams?:number; distance?:number; rotations?:number|null; wheelDiameterCm?:number|null; mode?:string; source?:string}|null;
}
export interface CareActionData {
  answer:'performed'|'not_performed'|'unanswered'; answerProvenance:'item_selection'|'batch_confirmation'|'unanswered'|'legacy_unspecified';
  details:Record<string,string|number>; occurredAt:null; occurredDateKey:string|null;
  timePrecision:'date_only'|'unknown'; nonPerformanceScope:'up_to_acceptance'|null;
}
/** Existing care revisions have no subjectId: a verified binding is an explicit separate input. */
/** Confirmed registration interval [validFrom, validThrough), never inferred physical placement. */
export interface SourceSubjectBinding {subjectId:string; evidenceId:string; acceptedAt:string; validFrom:string; validThrough:string|null}
export interface CareSourceData {dayKey:string; revision:number; status:'active'|'cancelled'; acceptedAt:AcceptedTime; actions:Record<string,CareActionData>}
export interface CareSource extends SourceEnvelope<CareSourceData> {binding?:SourceSubjectBinding}
export interface ResolutionEvidence {revisionId:string; revision:number; acceptedAt:AcceptedTime; availableAt:string}
/** Existing readMainPetProfileHistoryAt result, narrowed to the fields consumed here. */
export interface ProfileResolutionData {
  subjectId:string|null; evaluationDateKey:string; knowledgeCutoff:string;
  knowledgeCutoffEpochNanoseconds?:string; historyExists:boolean;
  values:{species:string|null; birthday:{dateKey:string|null; precision:string; quality:string}};
  evidenceRevisionIds:string[]; quality:{reasons:string[]};
}
export interface ProfileSource extends SourceEnvelope<ProfileResolutionData> {evidence:ResolutionEvidence[]}
/** Existing readEnvironmentAt result plus server acceptance metadata of its evidence revisions. */
export interface EnvironmentResolutionData {
  observedAt:string; knowledgeCutoff:string|null;
  values:Record<string,{value:number|string|string[]|null; unit:'cm'|'cm2'|null; quality:'known'|'unknown'|'invalid'}>;
  evidenceRevisionIds:string[]; quality:{unknownFields:string[]; ambiguousFields:string[]; reasons:string[]};
}
export interface EnvironmentSource extends SourceEnvelope<EnvironmentResolutionData> {evidence:ResolutionEvidence[]; binding?:SourceSubjectBinding}
export interface SensorQualityData {
  generatedAt:AcceptedTime; quality:{
    informationAsOf:string; window:{start:string; end:string; timeZone:string}; evaluatedThrough:string;
    readings:{count:number|null; countStatus:'available'|'unknown'; validValueCount?:{temperature:number|null; humidity:number|null; both:number|null}; observed:{count:number; validValueCount:{temperature:number; humidity:number; both:number}}};
    opportunities:{expectedCount:number|null}; ratios?:{both?:{numerator:number; denominator:number|null; value:number|null}};
    completeness:{attempts:'complete'|'partial'; readings:'complete'|'partial'; states:'complete'|'partial'; reasons:string[]};
    binding:{subjectIds:string[]; status:'registered_config'|'unknown'};
    freshness:{status:'unknown'};
  };
}
export interface SensorQualitySource extends SourceEnvelope<SensorQualityData> {deviceAssociation:'confirmed'|'unknown'}
export interface SensorEvidenceData {
  subjectId:string|null; attemptId:string; revision:number; deviceAssociation:'confirmed'|'unknown';
  terminal:{acceptedAt:AcceptedTime; status:'reading_saved'|'request_failed'; responseReceivedAt:string|null; freshness:'unknown'; validity:{temperature:'valid'|'missing'|'invalid'; humidity:'valid'|'missing'|'invalid'}};
  reading:{ts:string; temperature:number|null; humidity:number|null}|null;
}
export interface SourceSnapshot {
  schemaVersion:'prediction_source_snapshot_v1'; snapshotId:string; classification:SourceClassification;
  capturedAt:string; dataAvailableThrough:string; catalogVersions:{observation:string; care:string};
  subjects:SubjectIdentitySource[];
  sources:{profiles:ProfileSource[]; observations:SourceEnvelope<ObservationSourceData>[]; weights:SourceEnvelope<MeasurementSourceData>[];
    distances:SourceEnvelope<MeasurementSourceData>[]; careActions:CareSource[]; environments:EnvironmentSource[];
    sensorQuality:SensorQualitySource[]; sensorEvidence:SourceEnvelope<SensorEvidenceData>[]};
  sourceCompleteness?:Partial<Record<SourceKind,{status:'complete'|'partial'|'not_reconstructable'; reasonCodes:string[]}>>;
}
export interface AdapterAudit {
  source:SourceKind|'subjects'; sourceId:string|null; featureIds:string[];
  status:'normalized'|'unknown'|'excluded'|'not_reconstructable'; reasonCodes:string[];
}
export interface NormalizedSourceInput {subjectStatus:'confirmed'|'unknown'; observations:ObservationEvent[]; featureRevisions:FeatureRevision[]; audit:AdapterAudit[]}
/** Read-only by construction. Filesystem and credentials belong outside source normalization. */
export interface SnapshotRepository {readSnapshot():Promise<SourceSnapshot>}
export class JsonSnapshotRepository implements SnapshotRepository {
  constructor(private readonly snapshot:SourceSnapshot) {}
  async readSnapshot():Promise<SourceSnapshot> {return structuredClone(this.snapshot);}
}
export type NormalizationPoint = Pick<PredictionPoint,'id'|'ownerId'|'subjectId'|'t0'|'t1'|'referenceDateKey'>;
export type CanonicalTiming = TimeEvidence;

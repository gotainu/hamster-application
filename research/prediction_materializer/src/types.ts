import type {CanonicalDatasetConfig, Condition, DatasetRow, FeatureId, FeatureResult, SensorEvidence} from '../../prediction_dataset/src/types';
import type {AdapterAudit} from './sourceTypes';

export type MaterializerConfig = CanonicalDatasetConfig;
export interface FeatureMetadata {
  is_missing:boolean; eligible:boolean; quality:FeatureResult['status']; unit:string|null;
  accepted_age_seconds:number|null; freshness:'unknown'; reason_codes:string[];
  source_revision:{id:string; logical_id:string; revision:number; accepted_at:string; available_at:string; timing:unknown}|null;
  declaration_scope:string|null; sensor_quality:SensorEvidence|null;
}
/** Scalar model candidates are null unless the generator's featureEligibility says usable. */
export interface TableRow {
  row_id:string; subject_id:string|null; owner_group_id:string; prediction_at:string;
  target_window_start:string; target_window_end:string; label_finalized_at:string;
  weight_g:number|null; activity_m:number|null; past_condition:string|null;
  cleaning:string|boolean|null; bedding_replacement:string|null; walk_minutes:number|null;
  environment_wheel_cm:number|null; species:string|null; birth_date:string|null;
  temperature_c:number|null; humidity_pct:number|null; sensor_period_count:number|null;
  feature_metadata:Partial<Record<FeatureId,FeatureMetadata>>;
  label_initial:Condition|null; label_corrected:Condition|null; label_status:DatasetRow['labels']['status'];
  selected_observation_id:string|null; was_corrected:boolean; was_cancelled:boolean;
  row_status:DatasetRow['status']; exclusion_reason:string[];
  feature_spec_version:string; label_policy_version:{initial:string;corrected:string}; dataset_schema_version:string;
  research_eligibility:'not_assessed'; prediction_ready:'not_assessed';
}
export interface MaterializerAudit {
  row_id:string; generator_reasons:string[]; label_evidence:unknown;
  candidate_exclusions:unknown; source_audit:AdapterAudit[];
}
export interface Materialization {
  rows:TableRow[]; excludedRows:TableRow[]; audit:MaterializerAudit[]; config:CanonicalDatasetConfig;
  manifest:{schema_version:'prediction_materialization_manifest_v1'; table_schema_version:'prediction_training_table_v1';
    dataset_schema_version:string; feature_policy_version:string; label_policy_version:{initial:string;corrected:string};
    source_classification:'synthetic'; synthetic_only:true; source_snapshot_id:string; source_snapshot_hash:string;
    source_schema_version:string; input_config_hash:string; effective_config_hash:string;
    canonical_input_hashes:{row_id:string;hash:string}[]; catalog_versions:{observation:string;care:string};
    code_identity:string; content_hash:string; dataset_id:string;
    windows:{row_id:string;t0:string;t1:string;l:string;data_available_through:string}[];
    candidate_row_count:number; total_row_count:number; state_counts:Record<string,number>; reason_counts:Record<string,number>;
    feature_columns:Record<string,FeatureId>; csv_encoding:'typed_json_cells_v1';
    identity_policy_version:'local_alias_sha256_v1'; research_eligibility:'not_assessed';prediction_ready:'not_assessed'};
}

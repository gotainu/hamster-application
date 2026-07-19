export type HealthAssessmentState =
  | 'unknown'
  | 'good'
  | 'stable'
  | 'changed'
  | 'caution'
  | 'alert'
  | 'insufficientData';

export type HealthAssessmentConfidence =
  | 'insufficient'
  | 'low'
  | 'medium'
  | 'high';

export type EnvironmentFeatureSourceKind =
  | 'history'
  | 'latest'
  | 'none';

export type EnvironmentTrendDirection =
  | 'improving'
  | 'stable'
  | 'worsening'
  | 'unknown';

export interface EnvironmentHealthFeatures {
  sourceKind: EnvironmentFeatureSourceKind;
  sourceDateKey: string | null;
  status: string | null;
  level: string | null;
  headline: string | null;
  todayAction: string | null;
  why: string | null;
  avgTemp: number | null;
  avgHum: number | null;
  tempRatio: number | null;
  humRatio: number | null;
  dangerMinutes: number | null;
  spikesTemp: number | null;
  spikesHum: number | null;
  sourceDocCount: number | null;
  assessmentVersion: number | null;
  sourceEvaluatedAt: Date | null;
  windowDays: number;
  windowRecordCount: number;
  highTemperatureDays: number;
  lowTemperatureDays: number;
  highHumidityDays: number;
  lowHumidityDays: number;
  latestDailyTemp: number | null;
  latestDailyHum: number | null;
  temperatureTrend: EnvironmentTrendDirection;
  humidityTrend: EnvironmentTrendDirection;
}

export interface ActivityHealthFeatures {
  assessmentDateKey: string;
  sourceDateKey: string;
  lagDays: number;
  windowStartDateKey: string;
  windowEndDateKey: string;
  hasRecord: boolean;
  distanceMeters: number | null;
  rotations: number | null;
  wheelDiameterCm: number | null;
  avg7DistanceMeters: number | null;
  deltaPct: number | null;
  windowDays: number;
  windowRecordCount: number;
  recordDate: Date | null;
}

export interface BodyHealthFeatures {
  latestWeightGrams: number | null;
  latestWeightDate: Date | null;
  daysSinceMeasurement: number | null;
  previousWeightGrams: number | null;
  previousDifferenceGrams: number | null;
  previousChangeRate: number | null;
  windowDays: number;
  windowChangeRate: number | null;
  windowRecordCount: number;
  totalRecordCount: number;
}

export interface ConditionHealthFeatures {
  recorded: boolean;
  condition: string | null;
  concernTags: string[];
  memo: string;
  recordDate: Date | null;
}

export interface NutritionHealthFeatures {
  recorded: boolean;
  foodOfferedGrams: number | null;
  foodRemainingGrams: number | null;
  foodConsumedGrams: number | null;
  memo: string;
  recordDate: Date | null;
}

export interface HealthFeatureDataQuality {
  availableDomains: string[];
  missingDomains: string[];
  staleDomains: string[];
  completeness: number;
}

export interface DailyHealthFeatures {
  dateKey: string;
  environment: EnvironmentHealthFeatures;
  activity: ActivityHealthFeatures;
  body: BodyHealthFeatures;
  condition: ConditionHealthFeatures;
  nutrition: NutritionHealthFeatures;
  dataQuality: HealthFeatureDataQuality;
  schemaVersion: number;
  generatedAt: Date;
}

export interface HealthScoreComponent {
  score: number | null;
  state: HealthAssessmentState;
  summary: string;
  flags: string[];
}

export interface HealthDomainAssessment {
  state: HealthAssessmentState;
  score: number | null;
  flags: string[];
  summary: string;
  recommendedActions: string[];
  sourceUpdatedAt: Date | null;
  components?: Record<string, HealthScoreComponent>;
}

export interface HealthAssessmentDomains {
  environment: HealthDomainAssessment;
  activity: HealthDomainAssessment;
  body: HealthDomainAssessment;
  condition: HealthDomainAssessment;
  nutrition: HealthDomainAssessment;
}

export interface HealthOverallAssessment {
  state: HealthAssessmentState;
  score: number | null;
  observedState: HealthAssessmentState;
  observedScore: number | null;
  confidence: HealthAssessmentConfidence;
  isProvisional: boolean;
  flags: string[];
  summary: string;
  recommendedActions: string[];
  primaryFactor: string | null;
}

export interface HealthAssessmentDataQuality {
  completeness: number;
  availableDomains: string[];
  missingDomains: string[];
  staleDomains: string[];
}

export interface HealthAiAdvisorContext {
  status: 'available' | 'insufficient_data' | 'unavailable';
  priority: 'normal' | 'caution' | 'high';
  summary: string;
  promptText: string;
  version: number;
  generatedAt: Date;
}

export interface HealthAssessment {
  dateKey: string;
  featureDateKey: string;
  domains: HealthAssessmentDomains;
  overall: HealthOverallAssessment;
  dataQuality: HealthAssessmentDataQuality;
  aiAdvisorContext: HealthAiAdvisorContext | null;
  evaluatorVersion: number;
  evaluatedAt: Date;
}

export interface WeightRecordSource {
  dayKey: string;
  weightGrams: number;
  date?: Date | null;
}

export interface DistanceRecordSource {
  dayKey: string;
  exists: boolean;
  distanceMeters: number | null;
  rotations: number | null;
  wheelDiameterCm: number | null;
  date: Date | null;
}

export interface DailyCheckinSource {
  exists: boolean;
  dayKey: string;
  condition: string | null;
  concernTags: string[];
  memo: string;
  date: Date | null;
}

export interface NutritionRecordSource {
  exists: boolean;
  dayKey: string;
  foodOfferedGrams: number | null;
  foodRemainingGrams: number | null;
  foodConsumedGrams: number | null;
  memo: string;
  date: Date | null;
}

export interface EnvironmentAssessmentSource {
  sourceKind: EnvironmentFeatureSourceKind;
  sourceDateKey: string | null;
  status: string | null;
  level: string | null;
  headline: string | null;
  todayAction: string | null;
  why: string | null;
  avgTemp: number | null;
  avgHum: number | null;
  tempRatio: number | null;
  humRatio: number | null;
  dangerMinutes: number | null;
  spikesTemp: number | null;
  spikesHum: number | null;
  sourceDocCount: number | null;
  version: number | null;
  evaluatedAt: Date | null;
  windowDays: number;
  windowRecordCount: number;
  highTemperatureDays: number;
  lowTemperatureDays: number;
  highHumidityDays: number;
  lowHumidityDays: number;
  latestDailyTemp: number | null;
  latestDailyHum: number | null;
  temperatureTrend: EnvironmentTrendDirection;
  humidityTrend: EnvironmentTrendDirection;
}

export interface HealthSourceData {
  environment: EnvironmentAssessmentSource;
  activitySourceDateKey: string;
  distanceWindow: DistanceRecordSource[];
  weightRecords: WeightRecordSource[];
  dailyCheckin: DailyCheckinSource;
  nutrition: NutritionRecordSource;
}

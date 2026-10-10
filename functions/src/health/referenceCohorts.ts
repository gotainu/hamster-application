// Published population context only; never a healthy range or exact percentile.
export const REFERENCE_COHORT_VERSION = 'vetcompass_uk_2016_adult_weight_v1';
export const REFERENCE_SOURCE_VERSION = 'jsap_13527_table1_published_2022';
export type ReferenceSpecies = 'syrian' | 'djungarian' | 'roborovski' | 'chinese' | 'campbell';
export type ReferenceSpeciesCode = ReferenceSpecies;
export type PopulationPosition = 'below_iqr' | 'within_iqr' | 'above_iqr';
export interface ReferenceDataQuality {
  readonly weightSampleSizeReported: false;
  readonly speciesSampleSizeIsNotWeightSampleSize: true;
  readonly populationIncludesClinicalPatients: true;
  readonly exactPercentileAvailable: false;
  readonly healthyReferenceRange: false;
  readonly comparisonMeasureMismatch: true;
  readonly smallSpeciesPopulation: boolean;
}
export interface ReferenceCohort {
  readonly cohortId: string;
  readonly speciesCode: ReferenceSpecies;
  readonly metric: 'weight';
  readonly unit: 'g';
  readonly sourceType: 'published_research';
  readonly referenceVersion: string;
  readonly sourceVersion: string;
  readonly ageBand: 'adult_over_3_months';
  readonly adultDefinition: 'strictly_over_3_calendar_months';
  readonly measurementDefinition: 'mean_of_each_animals_recorded_weights_over_3_months';
  readonly median: number;
  readonly p25: number;
  readonly p75: number;
  readonly speciesPopulationN: number;
  readonly weightSampleN: null;
  readonly sourceDOI: string;
  readonly sourceURL: string;
  readonly sourceTitle: string;
  readonly sourceYear: number;
  readonly studyYear: number;
  readonly population: string;
  readonly sampleSizeCaution: boolean;
  readonly dataQuality: ReferenceDataQuality;
  readonly usableComparisonExpressions: readonly string[];
  readonly limitations: readonly string[];
}
export interface PopulationWeightContext {
  applicability: 'applicable' | 'not_applicable';
  reason: string | null;
  species: ReferenceSpecies | null;
  ageBand: 'adult_over_3_months' | 'not_adult' | 'unknown';
  cohort: ReferenceCohort | null;
  position: PopulationPosition | null;
  expressionJa: string;
  limitations: string[];
}
const SOURCE_DOI = '10.1111/jsap.13527';
const EXPRESSIONS = Object.freeze([
  '公開研究の中央50%の範囲より軽め',
  '公開研究の中央50%の範囲内',
  '公開研究の中央50%の範囲より重め',
]);
const COMMON_LIMITATIONS = Object.freeze([
  '2016年の英国の一次診療施設を受診したハムスターの記録であり、健康な個体だけの標準体重や日本の全個体を代表するものではありません。',
  '論文は各個体の3か月超の体重記録の平均を集計しています。比較する個体のベースライン中央値とは測定のまとめ方が異なります。',
  '表の種別総個体数は成人体重を解析した標本数ではありません。成人体重の種別解析数は公開表からは確認できません。',
  '中央値と四分位点だけでは正確なパーセンタイルは計算できず、中央50%の範囲を健康・異常の判定に使うことはできません。',
]);
function makeCohort(speciesCode: ReferenceSpecies, median: number, p25: number, p75: number, speciesPopulationN: number): ReferenceCohort {
  const small = speciesCode === 'campbell';
  return Object.freeze({
    cohortId: `${speciesCode}_adult_weight`, speciesCode, metric: 'weight' as const,
    unit: 'g' as const, sourceType: 'published_research' as const,
    referenceVersion: REFERENCE_COHORT_VERSION, sourceVersion: REFERENCE_SOURCE_VERSION,
    ageBand: 'adult_over_3_months' as const, adultDefinition: 'strictly_over_3_calendar_months' as const,
    measurementDefinition: 'mean_of_each_animals_recorded_weights_over_3_months' as const,
    median, p25, p75, speciesPopulationN, weightSampleN: null,
    sourceDOI: SOURCE_DOI, sourceURL: 'https://onlinelibrary.wiley.com/doi/10.1111/jsap.13527',
    sourceTitle: 'Demography, disorders and mortality of pet hamsters under primary veterinary care in the United Kingdom in 2016',
    sourceYear: 2022, studyYear: 2016, population: 'UK VetCompass primary veterinary care, 2016',
    sampleSizeCaution: small,
    dataQuality: Object.freeze({weightSampleSizeReported: false as const, speciesSampleSizeIsNotWeightSampleSize: true as const,
      populationIncludesClinicalPatients: true as const, exactPercentileAvailable: false as const,
      healthyReferenceRange: false as const, comparisonMeasureMismatch: true as const, smallSpeciesPopulation: small}),
    usableComparisonExpressions: EXPRESSIONS,
    limitations: Object.freeze([...COMMON_LIMITATIONS, ...(small ? ['キャンベルは種別総数52匹と少数です。成人体重の解析標本数は不明なので比較結果を慎重に扱ってください。'] : [])]),
  });
}
// Table 1 species frequencies are NOT adult-weight sample sizes. Chinese is
// recognized for identity but intentionally has no initial seeded dataset.
export const REFERENCE_COHORTS: readonly ReferenceCohort[] = Object.freeze([
  makeCohort('syrian', 133, 100, 160, 12197),
  makeCohort('djungarian', 45, 34.5, 58, 2286),
  makeCohort('roborovski', 25, 20, 30, 1054),
  makeCohort('campbell', 46, 38, 50, 52),
]);
const SPECIES_ALIASES: Readonly<Record<string, ReferenceSpecies>> = Object.freeze({
  syrian: 'syrian', 'シリアン': 'syrian', 'シリアンハムスター': 'syrian', 'ゴールデン': 'syrian',
  'ゴールデンハムスター': 'syrian', 'キンクマ': 'syrian', 'syrianhamster': 'syrian', 'goldenhamster': 'syrian', 'mesocricetusauratus': 'syrian',
  djungarian: 'djungarian', 'ジャンガリアン': 'djungarian', 'ジャンガリアンハムスター': 'djungarian',
  'ウィンターホワイト': 'djungarian', 'winterwhitedwarfhamster': 'djungarian', 'phodopussungorus': 'djungarian',
  roborovski: 'roborovski', 'ロボロフスキー': 'roborovski', 'ロボロフスキーハムスター': 'roborovski', 'phodopusroborovskii': 'roborovski',
  chinese: 'chinese', 'チャイニーズ': 'chinese', 'チャイニーズハムスター': 'chinese', 'chinesedwarfhamster': 'chinese', 'cricetulusgriseus': 'chinese',
  campbell: 'campbell', 'キャンベル': 'campbell', 'キャンベルハムスター': 'campbell', 'campbellrussianhamster': 'campbell', 'phodopuscampbelli': 'campbell',
});
export function normalizeReferenceSpecies(value: unknown): ReferenceSpecies | null {
  if (typeof value !== 'string') return null;
  const key = value.normalize('NFKC').trim().toLowerCase().replace(/[\s_\-]/g, '');
  return Object.prototype.hasOwnProperty.call(SPECIES_ALIASES, key) ? SPECIES_ALIASES[key] : null;
}
// Offline seed/fixture lookup. Production comparisons must receive a DB version.
export function getReferenceCohort(species: unknown): ReferenceCohort | null {
  const code = normalizeReferenceSpecies(species);
  return REFERENCE_COHORTS.find(c => c.speciesCode === code) ?? null;
}
function record(value: unknown): Record<string, unknown> | null {
  return value != null && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, unknown> : null;
}
function positive(value: unknown): value is number {return typeof value === 'number' && Number.isFinite(value) && value > 0;}
function text(value: unknown): value is string {return typeof value === 'string' && value.trim().length > 0;}
function strings(value: unknown): value is string[] {return Array.isArray(value) && value.every(text);}
export function parseReferenceCohort(value: unknown, expectedSpecies: ReferenceSpecies): ReferenceCohort | null {
  const c = record(value); if (!c) return null;
  if (c.speciesCode !== expectedSpecies || c.cohortId !== `${expectedSpecies}_adult_weight` || c.metric !== 'weight' || c.unit !== 'g' || c.sourceType !== 'published_research') return null;
  if (c.ageBand !== 'adult_over_3_months' || c.adultDefinition !== 'strictly_over_3_calendar_months' || c.measurementDefinition !== 'mean_of_each_animals_recorded_weights_over_3_months') return null;
  if (!positive(c.p25) || !positive(c.median) || !positive(c.p75) || c.p25 > c.median || c.median > c.p75) return null;
  if (!text(c.referenceVersion) || !text(c.sourceVersion) || c.referenceVersion.includes('/') || c.sourceVersion.includes('/')) return null;
  if (c.sourceDOI !== SOURCE_DOI || !text(c.sourceURL) || !c.sourceURL.startsWith('https://') || !text(c.sourceTitle) || !text(c.population)) return null;
  if (!positive(c.sourceYear) || !positive(c.studyYear) || !positive(c.speciesPopulationN) || !Number.isInteger(c.speciesPopulationN) || c.weightSampleN !== null || typeof c.sampleSizeCaution !== 'boolean') return null;
  if (!strings(c.limitations) || c.limitations.length === 0 || !strings(c.usableComparisonExpressions) || c.usableComparisonExpressions.length !== EXPRESSIONS.length || !EXPRESSIONS.every(e => (c.usableComparisonExpressions as string[]).includes(e))) return null;
  const q = record(c.dataQuality);
  if (!q || q.weightSampleSizeReported !== false || q.speciesSampleSizeIsNotWeightSampleSize !== true || q.populationIncludesClinicalPatients !== true || q.exactPercentileAvailable !== false || q.healthyReferenceRange !== false || q.comparisonMeasureMismatch !== true || typeof q.smallSpeciesPopulation !== 'boolean') return null;
  if (expectedSpecies === 'campbell' && (c.sampleSizeCaution !== true || q.smallSpeciesPopulation !== true)) return null;
  return Object.freeze({
    cohortId: c.cohortId, speciesCode: expectedSpecies, metric: 'weight', unit: 'g', sourceType: 'published_research',
    referenceVersion: c.referenceVersion, sourceVersion: c.sourceVersion, ageBand: 'adult_over_3_months',
    adultDefinition: 'strictly_over_3_calendar_months', measurementDefinition: 'mean_of_each_animals_recorded_weights_over_3_months',
    median: c.median, p25: c.p25, p75: c.p75, speciesPopulationN: c.speciesPopulationN, weightSampleN: null,
    sourceDOI: c.sourceDOI, sourceURL: c.sourceURL, sourceTitle: c.sourceTitle, sourceYear: c.sourceYear, studyYear: c.studyYear,
    population: c.population, sampleSizeCaution: c.sampleSizeCaution,
    dataQuality: Object.freeze({weightSampleSizeReported: false, speciesSampleSizeIsNotWeightSampleSize: true, populationIncludesClinicalPatients: true,
      exactPercentileAvailable: false, healthyReferenceRange: false, comparisonMeasureMismatch: true, smallSpeciesPopulation: q.smallSpeciesPopulation}),
    usableComparisonExpressions: Object.freeze([...c.usableComparisonExpressions]), limitations: Object.freeze([...c.limitations]),
  });
}
function parseDateKey(value: unknown): Date | null {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const [y, m, d] = value.split('-').map(Number);
  const date = new Date(Date.UTC(y, m - 1, d));
  return date.getUTCFullYear() === y && date.getUTCMonth() === m - 1 && date.getUTCDate() === d ? date : null;
}
function threeMonthBoundary(birth: Date): Date {
  const targetMonth = birth.getUTCMonth() + 3;
  const lastDay = new Date(Date.UTC(birth.getUTCFullYear(), targetMonth + 1, 0)).getUTCDate();
  return new Date(Date.UTC(birth.getUTCFullYear(), targetMonth, Math.min(birth.getUTCDate(), lastDay)));
}
export function buildPopulationWeightContext(params: {
  species: unknown; birthDateKey?: string | null; assessmentDateKey: string;
  observationStartDateKey: string | null; weightGrams: number | null; cohort: ReferenceCohort | null;
}): PopulationWeightContext {
  const species = normalizeReferenceSpecies(params.species);
  const assessment = parseDateKey(params.assessmentDateKey);
  const birth = parseDateKey(params.birthDateKey);
  let ageBand: PopulationWeightContext['ageBand'] = 'unknown';
  const no = (reason: string, explanation: string): PopulationWeightContext => ({
    applicability: 'not_applicable', reason, species, ageBand, cohort: null, position: null,
    expressionJa: explanation, limitations: [...COMMON_LIMITATIONS],
  });
  if (!species) return no('unknown_species', '種が特定できないため公開研究との体重比較を適用しません。');
  if (!assessment) return no('invalid_assessment_date', '評価日を確認できないため比較を適用しません。');
  if (!birth) return no('age_unknown', '誕生日が不明または無効なため成人期の体重比較を適用しません。');
  if (birth > assessment) return no('invalid_birth_date', '誕生日と評価日の整合性を確認できないため比較を適用しません。');
  const boundary = threeMonthBoundary(birth);
  ageBand = assessment > boundary ? 'adult_over_3_months' : 'not_adult';
  if (ageBand !== 'adult_over_3_months') return no('not_adult', '3か月超の成人期に達していないため公開研究との体重比較を適用しません。');
  const first = parseDateKey(params.observationStartDateKey);
  if (!first) return no('observation_age_unknown', '最古の観測日が不明または無効なため成人期の比較を適用しません。');
  if (first > assessment || first < birth) return no('invalid_observation_date', '観測期間と評価日の整合性を確認できないため比較を適用しません。');
  if (first <= boundary) return no('juvenile_observations', '幼齢期の観測が含まれるため成人期の公開研究との比較を適用しません。');
  if (!positive(params.weightGrams)) return no('weight_unavailable', '比較する体重を確認できないため公開研究との比較を適用しません。');
  if (!params.cohort) return no('reference_unavailable', '適用できる種別・成人期の比較データがないため公開研究との比較を適用しません。');
  if (params.cohort.speciesCode !== species) return no('reference_mismatch', '比較データの種が一致しないため比較を適用しません。');
  const cohort = parseReferenceCohort(params.cohort, species);
  if (!cohort) return no('reference_invalid', '比較データの定義や出典を確認できないため比較を適用しません。');
  const position: PopulationPosition = params.weightGrams < cohort.p25 ? 'below_iqr' : params.weightGrams > cohort.p75 ? 'above_iqr' : 'within_iqr';
  const phrase = EXPRESSIONS[position === 'below_iqr' ? 0 : position === 'within_iqr' ? 1 : 2];
  return {applicability: 'applicable', reason: null, species, ageBand, cohort, position,
    expressionJa: `${phrase}です（中央値${cohort.median}g、中央50%の範囲${cohort.p25}〜${cohort.p75}g）。健康状態や正確な順位を示すものではありません。`,
    limitations: [...new Set([...COMMON_LIMITATIONS, ...cohort.limitations])],
  };
}

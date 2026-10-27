import {createHash} from 'node:crypto';
import {addDaysToDateKey, enumerateDateKeys, isDateKey, normalizeDateKey} from './dateKey';
import {OBSERVATION_CATALOG_VERSION, observationCatalog, resolveObservationId, type ObservationCatalogItem} from './observationCatalog';

export const CHECKIN_INSIGHT_SPEC_VERSION = 'checkin_insights_v1';
export interface CheckinRecordInput {
  id: string;
  data: Record<string, unknown>;
  updatedAt?: Date | null;
}
export type ObservationAnswerOrigin = 'selected_tag' | 'automatic_normal' | 'explicit_answer' | 'legacy_level' | 'unanswered' | 'invalid';
export interface CheckinObservationRecord {
  dateKey: string;
  sourceDocumentId: string;
  sourceUpdatedAt: Date | null;
  schemaVersion: number | null;
  catalogVersion: string | null;
  legacy: boolean;
  condition: 'normal' | 'slightlyConcerned' | 'veryConcerned';
  selectedItemIds: string[];
  selectionVerified: boolean;
  invalidObservationData: boolean;
  items: Record<string, {level: 'normal' | 'changed' | 'concerning' | null; origin: ObservationAnswerOrigin}>;
}
export interface CheckinInsightEvidence {
  schemaVersion: 1;
  calculationSpecVersion: typeof CHECKIN_INSIGHT_SPEC_VERSION;
  catalogVersion: string;
  evaluationDateKey: string;
  windowStartDateKey: string;
  windowEndDateKey: string;
  windowDays: 14;
  records: CheckinObservationRecord[];
  validRecordDayCount: number;
  selectionVerifiedDayCount: number;
  itemAnsweredDayCount: null;
  concernDayCount: number;
  missingDayCount: number;
  invalidDayCount: number;
  duplicateRecordCount: number;
  invalidObservationRecordDayCount: number;
  evidenceHash: string;
}
export interface CheckinInsight {
  id: string;
  kind: 'checkin_item_repetition' | 'checkin_concern_frequency' | 'checkin_record_continuity';
  metric: 'condition';
  evaluationDateKey: string;
  observationStartDateKey: string;
  observationEndDateKey: string;
  validRecordCount: number;
  unit: 'days';
  evidence: {
    windowDays: 14;
    validRecordDayCount: number;
    selectionVerifiedDayCount: number;
    concernDayCount: number;
    matchingDayCount: number;
    missingDayCount: number;
    invalidDayCount: number;
    itemAnsweredDayCount: null;
    itemId?: string;
    itemLabel?: string;
  };
  dataQuality: {missingDaysNotImputed: true; normalDefaultsAreNotAnswers: true};
  interpretationCode: 'checkin_item_repeated' | 'checkin_concern_recorded' | 'checkin_records_continued';
  eligible: true;
  priority: number;
  discovery: boolean;
  semanticFingerprint: string;
  sourceGeneratedAt: Date;
  limitations: string[];
}
export interface CheckinInsights {
  schemaVersion: 1;
  calculationSpecVersion: typeof CHECKIN_INSIGHT_SPEC_VERSION;
  catalogVersion: string;
  evaluationDateKey: string;
  windowStartDateKey: string;
  windowEndDateKey: string;
  sourceGeneratedAt: Date;
  evidenceHash: string;
  insights: CheckinInsight[];
}
const CONDITIONS = ['normal', 'slightlyConcerned', 'veryConcerned'];
const LEVELS = ['normal', 'changed', 'concerning'];
const own = (value: Record<string, unknown>, key: string) => Object.prototype.hasOwnProperty.call(value, key);
const object = (value: unknown): Record<string, unknown> | null => value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, unknown> : null;
function dateKey(input: CheckinRecordInput): string | null {
  let id: string | null = null;
  try {id = normalizeDateKey(input.id);} catch { /* legacy random ID requires an explicit canonical dayKey */ }
  if (own(input.data, 'dayKey')) {
    if (typeof input.data.dayKey !== 'string' || !isDateKey(input.data.dayKey)) return null;
    return id && id !== input.data.dayKey ? null : input.data.dayKey;
  }
  return id;
}
function normalizedRecord(input: CheckinRecordInput, day: string, catalog: readonly ObservationCatalogItem[]): CheckinObservationRecord | null {
  const data = input.data;
  if (typeof data.condition !== 'string' || !CONDITIONS.includes(data.condition)) return null;
  const schema = Number.isInteger(data.schemaVersion) ? data.schemaVersion as number : null;
  if (own(data, 'schemaVersion') && schema !== 1 && schema !== 2) return null;
  if (own(data, 'date')) {
    const value = data.date as any;
    let date: Date | null = null;
    try {date = value instanceof Date ? value : typeof value?.toDate === 'function' ? value.toDate() : null;} catch {}
    // Validate a stored Timestamp, not its UTC day: Bronze's dayKey is local.
    if (!(date instanceof Date) || !Number.isFinite(date.getTime())) return null;
  }
  const levelsObject = object(data.observationLevels);
  const levels = levelsObject ?? {};
  const tagsValid = Array.isArray(data.concernTags) && data.concernTags.every(value => typeof value === 'string' && resolveObservationId(value, catalog) != null);
  const selected = tagsValid ? [...new Set((data.concernTags as string[]).map(value => resolveObservationId(value, catalog)!))] : [];
  if (data.condition === 'normal' && selected.length > 0) return null;
  const levelValues = new Map<string, unknown>();
  const invalidLevelIds = new Set<string>();
  let levelsValid = !own(data, 'observationLevels') || levelsObject != null;
  for (const [key, value] of Object.entries(levels)) {
    const id = resolveObservationId(key, catalog);
    if (!id || typeof value !== 'string' || !LEVELS.includes(value)) {levelsValid = false; if (id) invalidLevelIds.add(id); continue;}
    if (levelValues.has(id) && levelValues.get(id) !== value) {levelsValid = false; invalidLevelIds.add(id);}
    levelValues.set(id, value);
  }
  const explicitMode = data.observationResponseMode === 'explicit_items_v1';
  const explicitIdsValid = Array.isArray(data.answeredObservationIds) && data.answeredObservationIds.every(value => typeof value === 'string' && resolveObservationId(value, catalog) != null);
  const explicit = explicitMode && explicitIdsValid
    ? new Set((data.answeredObservationIds as string[]).map(value => resolveObservationId(value,catalog)!)) : new Set<string>();
  if (explicitMode && !explicitIdsValid) levelsValid = false;
  const contradictory = new Set<string>();
  if (schema === 2 && !explicitMode) for (const [id, level] of levelValues) {
    const expected = selected.includes(id) ? (data.condition === 'veryConcerned' ? 'concerning' : 'changed') : 'normal';
    if (level !== expected) {levelsValid = false; contradictory.add(id);}
  }
  const selectionVerified = tagsValid && levelsValid;
  const items: CheckinObservationRecord['items'] = {};
  for (const item of catalog) {
    const level = levelValues.get(item.id);
    if (invalidLevelIds.has(item.id) || contradictory.has(item.id) || (own(data,'observationLevels') && !levelsObject) || (explicitMode && !explicitIdsValid)) items[item.id] = {level: typeof level==='string' && LEVELS.includes(level) ? level as 'normal' | 'changed' | 'concerning' : null, origin:'invalid'};
    else if (selected.includes(item.id)) items[item.id] = {level: data.condition === 'veryConcerned' ? 'concerning' : 'changed', origin: 'selected_tag'};
    else if (explicit.has(item.id) && typeof level === 'string' && LEVELS.includes(level)) items[item.id] = {level: level as 'normal' | 'changed' | 'concerning', origin: 'explicit_answer'};
    else if (level === 'normal' && schema === 2) items[item.id] = {level: 'normal', origin: 'automatic_normal'};
    else if (typeof level === 'string' && LEVELS.includes(level)) items[item.id] = {level: level as 'normal' | 'changed' | 'concerning', origin: 'legacy_level'};
    else items[item.id] = {level: null, origin: own(levels, item.id) ? 'invalid' : 'unanswered'};
  }
  return {dateKey: day, sourceDocumentId: input.id, sourceUpdatedAt: Number.isFinite(input.updatedAt?.getTime()) ? input.updatedAt! : null, schemaVersion: schema,
    catalogVersion: typeof data.observationCatalogVersion === 'string' ? data.observationCatalogVersion : null,
    legacy: schema !== 2, condition: data.condition as CheckinObservationRecord['condition'],
    selectedItemIds: selected.sort((a,b) => (catalog.find(x=>x.id===a)?.order ?? 0) - (catalog.find(x=>x.id===b)?.order ?? 0) || a.localeCompare(b)),
    selectionVerified, invalidObservationData: !levelsValid || !tagsValid, items};
}
export function buildCheckinInsightEvidence(params: {
  records: CheckinRecordInput[]; evaluationDateKey: string; windowEndDateKey?: string;
  catalog?: readonly ObservationCatalogItem[];
}): CheckinInsightEvidence {
  const evaluationDateKey = normalizeDateKey(params.evaluationDateKey);
  const windowEndDateKey = normalizeDateKey(params.windowEndDateKey ?? evaluationDateKey);
  if (windowEndDateKey !== evaluationDateKey && windowEndDateKey !== addDaysToDateKey(evaluationDateKey, -1)) throw new Error('Observation cutoff must be evaluation day or previous day');
  const windowStartDateKey = addDaysToDateKey(windowEndDateKey, -13);
  const catalog = params.catalog ?? observationCatalog;
  const grouped = new Map<string, CheckinRecordInput[]>();
  const invalidDays = new Set<string>();
  for (const input of params.records) {
    const key = dateKey(input);
    if (!key) {try {const id = normalizeDateKey(input.id); if (id >= windowStartDateKey && id <= windowEndDateKey) invalidDays.add(id);} catch {} continue;}
    if (key < windowStartDateKey || key > windowEndDateKey) continue;
    grouped.set(key, [...(grouped.get(key) ?? []), input]);
  }
  const records: CheckinObservationRecord[] = [];
  let duplicateRecordCount = 0;
  for (const [day, inputs] of [...grouped].sort(([a],[b])=>a.localeCompare(b))) {
    duplicateRecordCount += inputs.length - 1;
    // Updates replace a day; do not union tags from two versions of that day.
    const ordered = [...inputs].sort((a,b)=>(Number.isFinite(b.updatedAt?.getTime())?b.updatedAt!.getTime():0)-(Number.isFinite(a.updatedAt?.getTime())?a.updatedAt!.getTime():0) || (a.id===day?-1:b.id===day?1:a.id.localeCompare(b.id)));
    const record = normalizedRecord(ordered[0], day, catalog);
    if (record) {records.push(record); invalidDays.delete(day);} else invalidDays.add(day);
  }
  const validRecordDayCount = records.length;
  const value = {schemaVersion: 1 as const, calculationSpecVersion: CHECKIN_INSIGHT_SPEC_VERSION as typeof CHECKIN_INSIGHT_SPEC_VERSION,
    catalogVersion: OBSERVATION_CATALOG_VERSION, evaluationDateKey, windowStartDateKey, windowEndDateKey, windowDays: 14 as const,
    records, validRecordDayCount, selectionVerifiedDayCount: records.filter(x=>x.selectionVerified).length,
    itemAnsweredDayCount: null, concernDayCount: records.filter(x=>x.condition!=='normal').length,
    missingDayCount: 14-validRecordDayCount-invalidDays.size, invalidDayCount: invalidDays.size, duplicateRecordCount,
    invalidObservationRecordDayCount: records.filter(record=>record.invalidObservationData).length};
  return {...value, evidenceHash: checkinFingerprint(value)};
}
export function buildCheckinInsights(params: {evidence: CheckinInsightEvidence; generatedAt: Date; catalog?: readonly ObservationCatalogItem[]}): CheckinInsights | null {
  const e = params.evidence;
  if (e.schemaVersion !== 1 || e.calculationSpecVersion !== CHECKIN_INSIGHT_SPEC_VERSION || !Number.isFinite(params.generatedAt.getTime()) ||
      !isDateKey(e.evaluationDateKey) || !isDateKey(e.windowEndDateKey) || e.windowStartDateKey !== addDaysToDateKey(e.windowEndDateKey,-13) ||
      (e.windowEndDateKey !== e.evaluationDateKey && e.windowEndDateKey !== addDaysToDateKey(e.evaluationDateKey,-1))) return null;
  const {evidenceHash, ...unhashed} = e;
  if (evidenceHash !== checkinFingerprint(unhashed)) return null;
  const catalog = params.catalog ?? observationCatalog;
  const insights: CheckinInsight[] = [];
  if (e.validRecordDayCount >= 7) {
    const matching = catalog.filter(item=>item.active && item.insightEligible).map(item=>({item,
      records:e.records.filter(record=>record.selectionVerified && record.selectedItemIds.includes(item.id))})).filter(x=>x.records.length>=3)
      .sort((a,b)=>b.records.length-a.records.length || b.records[b.records.length-1].dateKey.localeCompare(a.records[a.records.length-1].dateKey) || a.item.order-b.item.order || a.item.id.localeCompare(b.item.id));
    const repetition = e.selectionVerifiedDayCount>=7 ? matching[0] : undefined;
    const kind: CheckinInsight['kind'] = repetition ? 'checkin_item_repetition' : e.concernDayCount>=2 ? 'checkin_concern_frequency' : 'checkin_record_continuity';
    const count = repetition?.records.length ?? (kind==='checkin_concern_frequency'?e.concernDayCount:e.validRecordDayCount);
    const evidence: CheckinInsight['evidence'] = {windowDays:14,validRecordDayCount:e.validRecordDayCount,selectionVerifiedDayCount:e.selectionVerifiedDayCount,
      concernDayCount:e.concernDayCount,matchingDayCount:count,missingDayCount:e.missingDayCount,invalidDayCount:e.invalidDayCount,itemAnsweredDayCount:null,
      ...(repetition?{itemId:repetition.item.id,itemLabel:repetition.item.label}:{})};
    const semanticRecords = (repetition?.records ?? e.records).map(record=>({dateKey:record.dateKey,
      ...(kind==='checkin_concern_frequency'?{condition:record.condition}:{}), ...(repetition?{itemId:repetition.item.id}:{})}));
    insights.push({id: repetition?`${kind}_${repetition.item.id}`:kind,kind,metric:'condition',evaluationDateKey:e.evaluationDateKey,
      observationStartDateKey:e.windowStartDateKey,observationEndDateKey:e.windowEndDateKey,validRecordCount:e.validRecordDayCount,unit:'days',evidence,
      dataQuality:{missingDaysNotImputed:true,normalDefaultsAreNotAnswers:true},
      interpretationCode: repetition?'checkin_item_repeated':kind==='checkin_concern_frequency'?'checkin_concern_recorded':'checkin_records_continued',
      eligible:true,priority:repetition?40:kind==='checkin_concern_frequency'?50:60,discovery:kind!=='checkin_record_continuity',
      semanticFingerprint:checkinFingerprint({kind,records:semanticRecords,count}),sourceGeneratedAt:params.generatedAt,
      limitations:['記録された様子の頻度です。実際の発生頻度や健康状態・病気・原因は判断できません。','未回答・欠測を変化なしとして補っていません。']});
  }
  return {schemaVersion:1,calculationSpecVersion:CHECKIN_INSIGHT_SPEC_VERSION,catalogVersion:e.catalogVersion,evaluationDateKey:e.evaluationDateKey,
    windowStartDateKey:e.windowStartDateKey,windowEndDateKey:e.windowEndDateKey,sourceGeneratedAt:params.generatedAt,evidenceHash:e.evidenceHash,insights};
}
export function affectedCheckinEvaluationDates(sourceDateKey: string, todayDateKey: string): string[] {
  const start = normalizeDateKey(sourceDateKey); const today = normalizeDateKey(todayDateKey);
  const last = addDaysToDateKey(start,13);
  return enumerateDateKeys({startDateKey:start,endDateKey:last<today?last:today,maxDays:14});
}
export function checkinFingerprint(value: unknown): string {
  const canonical = (x:any):any => x instanceof Date?x.toISOString():Array.isArray(x)?x.map(canonical):x&&typeof x==='object'?Object.fromEntries(Object.keys(x).sort().map(k=>[k,canonical(x[k])])):x;
  return createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');
}

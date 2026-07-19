import * as admin from 'firebase-admin';

import {
  DailyCheckinSource,
  DistanceRecordSource,
  EnvironmentAssessmentSource,
  HealthSourceData,
  NutritionRecordSource,
  WeightRecordSource,
} from './healthTypes';
import {
  addDaysToDateKey,
  compactDateKey,
  formatDateKey,
  normalizeDateKey,
} from './dateKey';

type Json = Record<string, unknown>;

export async function fetchHealthSourceData(params: {
  db: FirebaseFirestore.Firestore;
  uid: string;
  dateKey: string;
}): Promise<HealthSourceData> {
  const dateKey = normalizeDateKey(params.dateKey);
  // Activity entered in the app is the completed previous-day total.
  // Therefore the assessment for D uses distance_records/{D - 1}.
  const activitySourceDateKey = addDaysToDateKey(
    dateKey,
    -1,
  );

  const [
    environment,
    distanceWindow,
    weightRecords,
    dailyCheckin,
    nutrition,
  ] = await Promise.all([
    fetchEnvironmentAssessment({
      db: params.db,
      uid: params.uid,
      dateKey,
    }),
    fetchDistanceWindow({
      db: params.db,
      uid: params.uid,
      dateKey: activitySourceDateKey,
      days: 7,
    }),
    fetchWeightRecords({
      db: params.db,
      uid: params.uid,
      referenceDateKey: dateKey,
    }),
    fetchDailyCheckin({
      db: params.db,
      uid: params.uid,
      dateKey,
    }),
    fetchNutritionRecord({
      db: params.db,
      uid: params.uid,
      dateKey,
    }),
  ]);

  return {
    environment,
    activitySourceDateKey,
    distanceWindow,
    weightRecords,
    dailyCheckin,
    nutrition,
  };
}

export async function fetchWeightRecords(params: {
  db: FirebaseFirestore.Firestore;
  uid: string;
  referenceDateKey: string;
}): Promise<WeightRecordSource[]> {
  const referenceDateKey = normalizeDateKey(
    params.referenceDateKey,
  );

  const snapshot = await params.db
    .collection('users')
    .doc(params.uid)
    .collection('weight_records')
    .orderBy(admin.firestore.FieldPath.documentId())
    .endAt(referenceDateKey)
    .get();

  const records: WeightRecordSource[] = [];

  for (const document of snapshot.docs) {
    const data = document.data() as Json;
    const dayKey = safeDateKey(
      asString(data.dayKey) ?? document.id,
    );
    const weightGrams = asNumber(data.weightGrams);

    if (!dayKey || weightGrams == null || weightGrams <= 0) {
      continue;
    }

    records.push({
      dayKey,
      weightGrams,
      date: asDate(data.date),
    });
  }

  return records.sort((a, b) =>
    a.dayKey.localeCompare(b.dayKey),
  );
}

export async function fetchDistanceWindow(params: {
  db: FirebaseFirestore.Firestore;
  uid: string;
  dateKey: string;
  days: number;
}): Promise<DistanceRecordSource[]> {
  const dateKey = normalizeDateKey(params.dateKey);
  const days = Math.max(1, Math.min(31, params.days));
  const startDateKey = addDaysToDateKey(
    dateKey,
    -(days - 1),
  );

  const dateKeys: string[] = [];
  let current = startDateKey;

  for (let index = 0; index < days; index += 1) {
    dateKeys.push(current);
    current = addDaysToDateKey(current, 1);
  }

  const collection = params.db
    .collection('users')
    .doc(params.uid)
    .collection('distance_records');

  const snapshots = await Promise.all(
    dateKeys.map((key) => collection.doc(key).get()),
  );

  return snapshots.map((snapshot, index) => {
    const key = dateKeys[index];
    const data = snapshot.exists
      ? snapshot.data() as Json
      : {};

    return {
      dayKey: key,
      exists: snapshot.exists,
      distanceMeters: asNumber(data.distance),
      rotations: asInteger(data.rotations),
      wheelDiameterCm: asNumber(data.wheelDiameterCm),
      date: asDate(data.date),
    };
  });
}

export async function fetchDailyCheckin(params: {
  db: FirebaseFirestore.Firestore;
  uid: string;
  dateKey: string;
}): Promise<DailyCheckinSource> {
  const dateKey = normalizeDateKey(params.dateKey);
  const snapshot = await params.db
    .collection('users')
    .doc(params.uid)
    .collection('daily_checkins')
    .doc(dateKey)
    .get();

  const data = snapshot.exists
    ? snapshot.data() as Json
    : {};

  return {
    exists: snapshot.exists,
    dayKey: dateKey,
    condition: asString(data.condition),
    concernTags: asStringList(data.concernTags),
    memo: asString(data.memo) ?? '',
    date: asDate(data.date),
  };
}

export async function fetchNutritionRecord(params: {
  db: FirebaseFirestore.Firestore;
  uid: string;
  dateKey: string;
}): Promise<NutritionRecordSource> {
  const dateKey = normalizeDateKey(params.dateKey);
  const snapshot = await params.db
    .collection('users')
    .doc(params.uid)
    .collection('feeding_records')
    .doc(dateKey)
    .get();

  const data = snapshot.exists
    ? snapshot.data() as Json
    : {};

  const offered = asNumber(data.foodOfferedGrams);
  const remaining = asNumber(data.foodRemainingGrams);
  const explicitConsumed = asNumber(data.foodConsumedGrams);
  const derivedConsumed =
    explicitConsumed ??
    (
      offered != null &&
      remaining != null &&
      offered >= remaining
        ? offered - remaining
        : null
    );

  return {
    exists: snapshot.exists,
    dayKey: dateKey,
    foodOfferedGrams: offered,
    foodRemainingGrams: remaining,
    foodConsumedGrams: derivedConsumed,
    memo: asString(data.memo) ?? '',
    date: asDate(data.date),
  };
}

export async function fetchEnvironmentAssessment(params: {
  db: FirebaseFirestore.Firestore;
  uid: string;
  dateKey: string;
}): Promise<EnvironmentAssessmentSource> {
  const dateKey = normalizeDateKey(params.dateKey);
  const todayDateKey = formatDateKey(new Date());

  const [latestSnapshot, historyRows] = await Promise.all([
    params.db
      .collection('users')
      .doc(params.uid)
      .collection('environment_assessments')
      .doc('latest')
      .get(),
    fetchEnvironmentHistoryWindow({
      db: params.db,
      uid: params.uid,
      dateKey,
      days: 7,
    }),
  ]);

  const latestData = latestSnapshot.exists
    ? latestSnapshot.data() as Json
    : null;
  const latestEvaluatedAt = latestData
    ? asDate(latestData.evaluatedAt)
    : null;
  const latestDateKey = latestEvaluatedAt
    ? formatDateKey(latestEvaluatedAt)
    : null;

  const useLatest =
    dateKey === todayDateKey &&
    latestData != null &&
    latestDateKey === dateKey &&
    hasEnvironmentData(latestData);

  if (useLatest) {
    return buildEnvironmentSource({
      baseData: latestData!,
      sourceKind: 'latest',
      sourceDateKey: dateKey,
      historyRows,
    });
  }

  if (historyRows.length > 0) {
    return buildEnvironmentSourceFromHistory({
      dateKey,
      historyRows,
    });
  }

  return emptyEnvironmentAssessment();
}

type EnvironmentHistoryRow = {
  dateKey: string;
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
};

async function fetchEnvironmentHistoryWindow(params: {
  db: FirebaseFirestore.Firestore;
  uid: string;
  dateKey: string;
  days: number;
}): Promise<EnvironmentHistoryRow[]> {
  const dateKey = normalizeDateKey(params.dateKey);
  const days = Math.max(1, Math.min(14, params.days));
  const collection = params.db
    .collection('users')
    .doc(params.uid)
    .collection('environment_assessments_history');

  const dateKeys = Array.from(
    {length: days},
    (_, index) => addDaysToDateKey(
      dateKey,
      -(days - 1 - index),
    ),
  );

  const snapshots = await Promise.all(
    dateKeys.flatMap((key) => [
      collection.doc(compactDateKey(key)).get(),
      collection.doc(key).get(),
    ]),
  );

  const rows: EnvironmentHistoryRow[] = [];

  for (let index = 0; index < dateKeys.length; index++) {
    const compactSnapshot = snapshots[index * 2];
    const hyphenSnapshot = snapshots[index * 2 + 1];
    const snapshot = compactSnapshot.exists
      ? compactSnapshot
      : hyphenSnapshot.exists
        ? hyphenSnapshot
        : null;

    if (!snapshot) continue;

    const data = snapshot.data() as Json;
    if (!hasEnvironmentData(data)) continue;

    rows.push(mapEnvironmentHistoryRow({
      data,
      fallbackDateKey: dateKeys[index],
    }));
  }

  return rows.sort((a, b) =>
    a.dateKey.localeCompare(b.dateKey),
  );
}

function mapEnvironmentHistoryRow(params: {
  data: Json;
  fallbackDateKey: string;
}): EnvironmentHistoryRow {
  return {
    dateKey:
      safeDateKey(
        asString(params.data.dateKey) ??
        asString(params.data.date) ??
        params.fallbackDateKey,
      ) ?? params.fallbackDateKey,
    status: asString(params.data.status),
    level: asString(params.data.level),
    headline: asString(params.data.headline),
    todayAction: asString(params.data.todayAction),
    why: asString(params.data.why),
    avgTemp: asNumber(params.data.avgTemp),
    avgHum: asNumber(params.data.avgHum),
    tempRatio: asNumber(params.data.tempRatio),
    humRatio: asNumber(params.data.humRatio),
    dangerMinutes: asInteger(params.data.dangerMinutes),
    spikesTemp: asInteger(params.data.spikesTemp),
    spikesHum: asInteger(params.data.spikesHum),
    sourceDocCount: asInteger(params.data.sourceDocCount),
    version: asInteger(params.data.version),
    evaluatedAt:
      asDate(params.data.lastEvaluatedAt) ??
      asDate(params.data.evaluatedAt) ??
      asDate(params.data.updatedAt),
  };
}

function buildEnvironmentSource(params: {
  baseData: Json;
  sourceKind: 'latest';
  sourceDateKey: string;
  historyRows: EnvironmentHistoryRow[];
}): EnvironmentAssessmentSource {
  const dailyStats = buildEnvironmentWindowStats(
    params.historyRows,
  );

  return {
    sourceKind: params.sourceKind,
    sourceDateKey: params.sourceDateKey,
    status: asString(params.baseData.status),
    level: asString(params.baseData.level),
    headline: asString(params.baseData.headline),
    todayAction: asString(params.baseData.todayAction),
    why: asString(params.baseData.why),
    avgTemp: asNumber(params.baseData.avgTemp),
    avgHum: asNumber(params.baseData.avgHum),
    tempRatio: asNumber(params.baseData.tempRatio),
    humRatio: asNumber(params.baseData.humRatio),
    dangerMinutes: asInteger(
      params.baseData.dangerMinutes,
    ),
    spikesTemp: asInteger(params.baseData.spikesTemp),
    spikesHum: asInteger(params.baseData.spikesHum),
    sourceDocCount: asInteger(
      params.baseData.sourceDocCount,
    ),
    version: asInteger(params.baseData.version),
    evaluatedAt:
      asDate(params.baseData.evaluatedAt) ??
      asDate(params.baseData.updatedAt),
    windowDays: 7,
    windowRecordCount: dailyStats.windowRecordCount,
    highTemperatureDays:
      dailyStats.highTemperatureDays,
    lowTemperatureDays:
      dailyStats.lowTemperatureDays,
    highHumidityDays: dailyStats.highHumidityDays,
    lowHumidityDays: dailyStats.lowHumidityDays,
    latestDailyTemp: dailyStats.latestDailyTemp,
    latestDailyHum: dailyStats.latestDailyHum,
    temperatureTrend: dailyStats.temperatureTrend,
    humidityTrend: dailyStats.humidityTrend,
  };
}

function buildEnvironmentSourceFromHistory(params: {
  dateKey: string;
  historyRows: EnvironmentHistoryRow[];
}): EnvironmentAssessmentSource {
  const target =
    params.historyRows.find(
      (row) => row.dateKey === params.dateKey,
    ) ??
    params.historyRows[params.historyRows.length - 1];

  const stats = buildEnvironmentWindowStats(
    params.historyRows,
  );

  return {
    sourceKind: 'history',
    sourceDateKey: params.dateKey,
    status: target.status ?? 'ok',
    level: target.level,
    headline: target.headline,
    todayAction: target.todayAction,
    why: target.why,
    avgTemp: averageNullable(
      params.historyRows.map((row) => row.avgTemp),
    ),
    avgHum: averageNullable(
      params.historyRows.map((row) => row.avgHum),
    ),
    tempRatio: averageNullable(
      params.historyRows.map((row) => row.tempRatio),
    ),
    humRatio: averageNullable(
      params.historyRows.map((row) => row.humRatio),
    ),
    dangerMinutes: sumNullable(
      params.historyRows.map(
        (row) => row.dangerMinutes,
      ),
    ),
    spikesTemp: sumNullable(
      params.historyRows.map((row) => row.spikesTemp),
    ),
    spikesHum: sumNullable(
      params.historyRows.map((row) => row.spikesHum),
    ),
    sourceDocCount: sumNullable(
      params.historyRows.map(
        (row) => row.sourceDocCount,
      ),
    ),
    version: Math.max(
      ...params.historyRows.map((row) => row.version ?? 0),
    ),
    evaluatedAt: target.evaluatedAt,
    windowDays: 7,
    windowRecordCount: stats.windowRecordCount,
    highTemperatureDays: stats.highTemperatureDays,
    lowTemperatureDays: stats.lowTemperatureDays,
    highHumidityDays: stats.highHumidityDays,
    lowHumidityDays: stats.lowHumidityDays,
    latestDailyTemp: stats.latestDailyTemp,
    latestDailyHum: stats.latestDailyHum,
    temperatureTrend: stats.temperatureTrend,
    humidityTrend: stats.humidityTrend,
  };
}

function buildEnvironmentWindowStats(
  rows: EnvironmentHistoryRow[],
): {
  windowRecordCount: number;
  highTemperatureDays: number;
  lowTemperatureDays: number;
  highHumidityDays: number;
  lowHumidityDays: number;
  latestDailyTemp: number | null;
  latestDailyHum: number | null;
  temperatureTrend:
    EnvironmentAssessmentSource['temperatureTrend'];
  humidityTrend:
    EnvironmentAssessmentSource['humidityTrend'];
} {
  const TEMP_MIN = 20;
  const TEMP_MAX = 26;
  const HUM_MIN = 40;
  const HUM_MAX = 60;

  const temperatures = rows
    .map((row) => row.avgTemp)
    .filter((value): value is number => value != null);
  const humidities = rows
    .map((row) => row.avgHum)
    .filter((value): value is number => value != null);

  return {
    windowRecordCount: rows.length,
    highTemperatureDays: temperatures.filter(
      (value) => value > TEMP_MAX,
    ).length,
    lowTemperatureDays: temperatures.filter(
      (value) => value < TEMP_MIN,
    ).length,
    highHumidityDays: humidities.filter(
      (value) => value > HUM_MAX,
    ).length,
    lowHumidityDays: humidities.filter(
      (value) => value < HUM_MIN,
    ).length,
    latestDailyTemp:
      rows.length > 0
        ? rows[rows.length - 1].avgTemp
        : null,
    latestDailyHum:
      rows.length > 0
        ? rows[rows.length - 1].avgHum
        : null,
    temperatureTrend: rangeTrend({
      values: temperatures,
      minimum: TEMP_MIN,
      maximum: TEMP_MAX,
      meaningfulDelta: 0.5,
    }),
    humidityTrend: rangeTrend({
      values: humidities,
      minimum: HUM_MIN,
      maximum: HUM_MAX,
      meaningfulDelta: 2,
    }),
  };
}

function rangeTrend(params: {
  values: number[];
  minimum: number;
  maximum: number;
  meaningfulDelta: number;
}): EnvironmentAssessmentSource['temperatureTrend'] {
  if (params.values.length < 2) return 'unknown';

  const splitIndex = Math.max(
    1,
    Math.floor(params.values.length / 2),
  );
  const previous = averageNullable(
    params.values.slice(0, splitIndex),
  );
  const recent = averageNullable(
    params.values.slice(splitIndex),
  );

  if (previous == null || recent == null) {
    return 'unknown';
  }

  const previousDeviation = rangeDeviation(
    previous,
    params.minimum,
    params.maximum,
  );
  const recentDeviation = rangeDeviation(
    recent,
    params.minimum,
    params.maximum,
  );
  const delta =
    previousDeviation - recentDeviation;

  if (delta >= params.meaningfulDelta) {
    return 'improving';
  }
  if (delta <= -params.meaningfulDelta) {
    return 'worsening';
  }
  return 'stable';
}

function rangeDeviation(
  value: number,
  minimum: number,
  maximum: number,
): number {
  if (value < minimum) return minimum - value;
  if (value > maximum) return value - maximum;
  return 0;
}

function averageNullable(
  values: Array<number | null>,
): number | null {
  const available = values.filter(
    (value): value is number => value != null,
  );

  if (available.length === 0) return null;

  return available.reduce(
    (sum, value) => sum + value,
    0,
  ) / available.length;
}

function sumNullable(
  values: Array<number | null>,
): number | null {
  const available = values.filter(
    (value): value is number => value != null,
  );

  if (available.length === 0) return null;

  return available.reduce(
    (sum, value) => sum + value,
    0,
  );
}

function hasEnvironmentData(data: Json): boolean {
  return (
    asNumber(data.avgTemp) != null ||
    asNumber(data.avgHum) != null ||
    asNumber(data.tempRatio) != null ||
    asNumber(data.humRatio) != null
  );
}

function emptyEnvironmentAssessment():
  EnvironmentAssessmentSource {
  return {
    sourceKind: 'none',
    sourceDateKey: null,
    status: null,
    level: null,
    headline: null,
    todayAction: null,
    why: null,
    avgTemp: null,
    avgHum: null,
    tempRatio: null,
    humRatio: null,
    dangerMinutes: null,
    spikesTemp: null,
    spikesHum: null,
    sourceDocCount: null,
    version: null,
    evaluatedAt: null,
    windowDays: 7,
    windowRecordCount: 0,
    highTemperatureDays: 0,
    lowTemperatureDays: 0,
    highHumidityDays: 0,
    lowHumidityDays: 0,
    latestDailyTemp: null,
    latestDailyHum: null,
    temperatureTrend: 'unknown',
    humidityTrend: 'unknown',
  };
}

function safeDateKey(value: string): string | null {
  try {
    return normalizeDateKey(value);
  } catch {
    return null;
  }
}

function asString(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function asStringList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];

  return value
    .map((item) => String(item).trim())
    .filter((item) => item.length > 0);
}

function asNumber(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }

  if (
    typeof value === 'string' &&
    value.trim().length > 0
  ) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }

  return null;
}

function asInteger(value: unknown): number | null {
  const number = asNumber(value);
  return number == null ? null : Math.trunc(number);
}

function asDate(value: unknown): Date | null {
  if (value instanceof Date) {
    return value;
  }

  if (
    value &&
    typeof value === 'object' &&
    'toDate' in value &&
    typeof (value as {toDate?: unknown}).toDate === 'function'
  ) {
    return (value as {toDate: () => Date}).toDate();
  }

  if (typeof value === 'string') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }

  return null;
}

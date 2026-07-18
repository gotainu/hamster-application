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
      dateKey,
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
  const historyCollection = params.db
    .collection('users')
    .doc(params.uid)
    .collection('environment_assessments_history');

  const compactId = compactDateKey(dateKey);
  const [compactSnapshot, hyphenSnapshot] = await Promise.all([
    historyCollection.doc(compactId).get(),
    historyCollection.doc(dateKey).get(),
  ]);

  const historySnapshot = compactSnapshot.exists
    ? compactSnapshot
    : hyphenSnapshot.exists
      ? hyphenSnapshot
      : null;

  if (historySnapshot) {
    return mapEnvironmentAssessment({
      data: historySnapshot.data() as Json,
      sourceKind: 'history',
      fallbackDateKey: dateKey,
    });
  }

  const latestSnapshot = await params.db
    .collection('users')
    .doc(params.uid)
    .collection('environment_assessments')
    .doc('latest')
    .get();

  if (latestSnapshot.exists) {
    const data = latestSnapshot.data() as Json;
    const evaluatedAt = asDate(data.evaluatedAt);
    const latestDateKey = evaluatedAt
      ? formatDateKey(evaluatedAt)
      : null;

    if (latestDateKey === dateKey) {
      return mapEnvironmentAssessment({
        data,
        sourceKind: 'latest',
        fallbackDateKey: dateKey,
      });
    }
  }

  return emptyEnvironmentAssessment();
}

function mapEnvironmentAssessment(params: {
  data: Json;
  sourceKind: 'history' | 'latest';
  fallbackDateKey: string;
}): EnvironmentAssessmentSource {
  const sourceDateKey = safeDateKey(
    asString(params.data.dateKey) ??
    asString(params.data.date) ??
    params.fallbackDateKey,
  );

  return {
    sourceKind: params.sourceKind,
    sourceDateKey,
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

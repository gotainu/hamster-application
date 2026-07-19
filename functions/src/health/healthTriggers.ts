import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import * as logger from 'firebase-functions/logger';

import {
  addDaysToDateKey,
  enumerateDateKeys,
  formatDateKey,
  normalizeDateKey,
} from './dateKey';
import {
  HealthPipelineResult,
  rebuildHealthForDate,
} from './healthPipeline';

const REGION = 'asia-northeast1';

export const healthWeightRecordWritten = onDocumentWritten(
  {
    document: 'users/{uid}/weight_records/{sourceDateKey}',
    region: REGION,
    timeoutSeconds: 300,
    memory: '512MiB',
  },
  async (event) => {
    const uid = event.params.uid;
    const sourceDateKey = normalizeDateKey(
      event.params.sourceDateKey,
    );
    const todayDateKey = formatDateKey(new Date());
    const lastAffectedDateKey =
      sourceDateKey < todayDateKey
        ? (
            addDaysToDateKey(sourceDateKey, 29) <
            todayDateKey
              ? addDaysToDateKey(sourceDateKey, 29)
              : todayDateKey
          )
        : sourceDateKey;

    const affectedDateKeys = enumerateDateKeys({
      startDateKey: sourceDateKey,
      endDateKey: lastAffectedDateKey,
      maxDays: 30,
    });

    if (!affectedDateKeys.includes(todayDateKey)) {
      affectedDateKeys.push(todayDateKey);
    }

    await rebuildDates({
      uid,
      dateKeys: affectedDateKeys,
      reason: 'weight_record_written',
    });
  },
);

export const healthDistanceRecordWritten = onDocumentWritten(
  {
    document:
      'users/{uid}/distance_records/{sourceDateKey}',
    region: REGION,
    timeoutSeconds: 180,
    memory: '512MiB',
  },
  async (event) => {
    const uid = event.params.uid;
    const sourceDateKey = normalizeDateKey(
      event.params.sourceDateKey,
    );
    const todayDateKey = formatDateKey(new Date());
    // distance_records/S is the completed activity for day S.
    // It becomes the primary activity input for assessment S+1 and
    // remains inside that assessment's rolling window through S+7.
    const firstAffectedDateKey =
      addDaysToDateKey(sourceDateKey, 1);
    const lastAffectedCandidate =
      addDaysToDateKey(sourceDateKey, 7);

    if (firstAffectedDateKey > todayDateKey) {
      logger.info(
        'Distance record saved before its assessment date',
        {
          uid,
          sourceDateKey,
          firstAffectedDateKey,
          todayDateKey,
        },
      );
      return;
    }

    const lastAffectedDateKey =
      lastAffectedCandidate < todayDateKey
        ? lastAffectedCandidate
        : todayDateKey;

    const affectedDateKeys = enumerateDateKeys({
      startDateKey: firstAffectedDateKey,
      endDateKey: lastAffectedDateKey,
      maxDays: 7,
    });

    await rebuildDates({
      uid,
      dateKeys: affectedDateKeys,
      reason: 'distance_record_written',
    });
  },
);

export const healthDailyCheckinWritten = onDocumentWritten(
  {
    document:
      'users/{uid}/daily_checkins/{sourceDateKey}',
    region: REGION,
    timeoutSeconds: 120,
    memory: '256MiB',
  },
  async (event) => {
    await rebuildHealthForDate({
      uid: event.params.uid,
      dateKey: normalizeDateKey(
        event.params.sourceDateKey,
      ),
      reason: 'daily_checkin_written',
    });
  },
);

export const healthEnvironmentHistoryWritten =
  onDocumentWritten(
    {
      document:
        'users/{uid}/environment_assessments_history/{sourceDateKey}',
      region: REGION,
      timeoutSeconds: 120,
      memory: '256MiB',
    },
    async (event) => {
      await rebuildHealthForDate({
        uid: event.params.uid,
        dateKey: normalizeDateKey(
          event.params.sourceDateKey,
        ),
        reason: 'environment_history_written',
      });
    },
  );

export const healthEnvironmentLatestWritten =
  onDocumentWritten(
    {
      document:
        'users/{uid}/environment_assessments/latest',
      region: REGION,
      timeoutSeconds: 120,
      memory: '256MiB',
    },
    async (event) => {
      await rebuildHealthForDate({
        uid: event.params.uid,
        dateKey: formatDateKey(new Date()),
        reason: 'environment_latest_written',
      });
    },
  );

export const rebuildMyHealthArchitecture = onCall(
  {
    region: REGION,
    timeoutSeconds: 540,
    memory: '1GiB',
  },
  async (request) => {
    const uid = request.auth?.uid;

    if (!uid) {
      throw new HttpsError(
        'unauthenticated',
        'ログインが必要です。',
      );
    }

    const todayDateKey = formatDateKey(new Date());
    const requestedDateKey =
      typeof request.data?.dateKey === 'string' &&
      request.data.dateKey.trim().length > 0
        ? normalizeDateKey(request.data.dateKey)
        : null;

    const requestedDays = Number(request.data?.days ?? 1);
    const days = Number.isFinite(requestedDays)
      ? Math.max(1, Math.min(90, Math.trunc(requestedDays)))
      : 1;

    const dateKeys = requestedDateKey
      ? [requestedDateKey]
      : enumerateDateKeys({
          startDateKey: addDaysToDateKey(
            todayDateKey,
            -(days - 1),
          ),
          endDateKey: todayDateKey,
          maxDays: 90,
        });

    const results = await rebuildDates({
      uid,
      dateKeys,
      reason: 'manual_rebuild',
    });

    return {
      ok: true,
      uid,
      requestedDateKey,
      requestedDays: requestedDateKey ? null : days,
      rebuiltCount: results.length,
      firstDateKey: results[0]?.dateKey ?? null,
      lastDateKey:
        results[results.length - 1]?.dateKey ?? null,
      results,
    };
  },
);

async function rebuildDates(params: {
  uid: string;
  dateKeys: string[];
  reason: string;
}): Promise<HealthPipelineResult[]> {
  const uniqueDateKeys = [
    ...new Set(
      params.dateKeys.map((dateKey) =>
        normalizeDateKey(dateKey),
      ),
    ),
  ].sort();

  const results: HealthPipelineResult[] = [];

  for (const dateKey of uniqueDateKeys) {
    try {
      results.push(
        await rebuildHealthForDate({
          uid: params.uid,
          dateKey,
          reason: params.reason,
        }),
      );
    } catch (error: unknown) {
      logger.error('Health architecture rebuild failed', {
        uid: params.uid,
        dateKey,
        reason: params.reason,
        error:
          error instanceof Error
            ? error.message
            : String(error),
      });

      throw error;
    }
  }

  return results;
}

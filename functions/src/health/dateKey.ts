const DEFAULT_TIME_ZONE = 'Asia/Tokyo';
const DATE_KEY_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const COMPACT_DATE_KEY_PATTERN = /^\d{8}$/;

export function isDateKey(value: string): boolean {
  if (!DATE_KEY_PATTERN.test(value)) return false;

  const [year, month, day] = value
    .split('-')
    .map((part) => Number(part));

  const utc = new Date(Date.UTC(year, month - 1, day));

  return (
    utc.getUTCFullYear() === year &&
    utc.getUTCMonth() === month - 1 &&
    utc.getUTCDate() === day
  );
}

export function normalizeDateKey(value: string): string {
  const trimmed = value.trim();

  if (isDateKey(trimmed)) {
    return trimmed;
  }

  if (COMPACT_DATE_KEY_PATTERN.test(trimmed)) {
    const normalized =
      `${trimmed.slice(0, 4)}-${trimmed.slice(4, 6)}-${trimmed.slice(6, 8)}`;

    if (isDateKey(normalized)) {
      return normalized;
    }
  }

  throw new Error(`Invalid date key: ${value}`);
}

export function compactDateKey(value: string): string {
  return normalizeDateKey(value).replace(/-/g, '');
}

export function assertDateKey(value: string): string {
  return normalizeDateKey(value);
}

export function formatDateKey(
  date: Date,
  timeZone = DEFAULT_TIME_ZONE,
): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);

  const values = new Map(
    parts.map((part) => [part.type, part.value]),
  );

  const year = values.get('year');
  const month = values.get('month');
  const day = values.get('day');

  if (!year || !month || !day) {
    throw new Error('Failed to format date key.');
  }

  return `${year}-${month}-${day}`;
}

export function dateKeyToUtcDate(dateKey: string): Date {
  const normalized = normalizeDateKey(dateKey);

  const [year, month, day] = normalized
    .split('-')
    .map((part) => Number(part));

  return new Date(Date.UTC(year, month - 1, day));
}

export function addDaysToDateKey(
  dateKey: string,
  days: number,
): string {
  const date = dateKeyToUtcDate(dateKey);
  date.setUTCDate(date.getUTCDate() + days);

  return [
    date.getUTCFullYear().toString().padStart(4, '0'),
    (date.getUTCMonth() + 1).toString().padStart(2, '0'),
    date.getUTCDate().toString().padStart(2, '0'),
  ].join('-');
}

export function differenceInDateKeyDays(
  laterDateKey: string,
  earlierDateKey: string,
): number {
  const later = dateKeyToUtcDate(laterDateKey);
  const earlier = dateKeyToUtcDate(earlierDateKey);

  return Math.floor(
    (later.getTime() - earlier.getTime()) /
      (24 * 60 * 60 * 1000),
  );
}

export function isDateKeyWithinWindow(params: {
  targetDateKey: string;
  referenceDateKey: string;
  windowDays: number;
}): boolean {
  const {
    targetDateKey,
    referenceDateKey,
    windowDays,
  } = params;

  const normalizedTarget = normalizeDateKey(targetDateKey);
  const normalizedReference = normalizeDateKey(referenceDateKey);
  const firstDateKey = addDaysToDateKey(
    normalizedReference,
    -(Math.max(1, windowDays) - 1),
  );

  return (
    normalizedTarget >= firstDateKey &&
    normalizedTarget <= normalizedReference
  );
}

export function enumerateDateKeys(params: {
  startDateKey: string;
  endDateKey: string;
  maxDays?: number;
}): string[] {
  const start = normalizeDateKey(params.startDateKey);
  const end = normalizeDateKey(params.endDateKey);
  const maxDays = Math.max(1, params.maxDays ?? 366);

  if (start > end) {
    return [];
  }

  const result: string[] = [];
  let current = start;

  while (current <= end && result.length < maxDays) {
    result.push(current);
    current = addDaysToDateKey(current, 1);
  }

  return result;
}

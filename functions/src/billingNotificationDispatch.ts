/** A scheduled deployment is not permission to send mail. Keep this gate
 * outside runtime construction so disabled/missing settings do not read the
 * shared mail Secret, Auth, queue, counters or Gmail. The approved cutoff is
 * fixed across retries and redeploys; it is never inferred from the clock. */
export async function dispatchLiveBillingNotifications<T>(input: {
  enabled: unknown;
  notBeforeMillis: unknown;
  nowMillis: number;
  run(notBeforeMillis: number): Promise<T>;
}): Promise<{state: 'disabled'} | {state: 'processed'; summary: T}> {
  if (input.enabled === undefined || input.enabled === '' || input.enabled === 'false') return {state: 'disabled'};
  if (input.enabled !== 'true' || typeof input.notBeforeMillis !== 'string' ||
      !/^[1-9]\d{0,15}$/.test(input.notBeforeMillis) ||
      !Number.isSafeInteger(input.nowMillis) || input.nowMillis <= 0) throw new Error('Billing notification dispatch configuration unavailable.');
  const start = Number(input.notBeforeMillis);
  // Stripe event creation time has whole-second precision. A fractional
  // millisecond cutoff would wrongly hold new events from the same second.
  if (!Number.isSafeInteger(start) || start <= 0 || start % 1000 !== 0 || start > input.nowMillis) throw new Error('Billing notification dispatch configuration unavailable.');
  return {state: 'processed', summary: await input.run(start)};
}

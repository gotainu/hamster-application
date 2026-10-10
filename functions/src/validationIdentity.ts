/** Identifies the narrowly-scoped owner test accounts without sending PII. */
export function isValidationUid(uid: string): boolean {
  const allowed = new Set(
    (process.env.TRIAL_TEST_UIDS ?? '')
      .split(',')
      .map((value) => value.trim())
      .filter(Boolean),
  );
  return allowed.has(uid);
}

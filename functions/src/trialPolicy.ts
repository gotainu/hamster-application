export const INITIAL_TRIAL_POLICY_VERSION = 'initial_trial_v2';
export const INITIAL_TRIAL_DURATION_DAYS = 21;

/** Approved launch-candidate policy. Reservation is not actual-cost settlement. */
export const INITIAL_TRIAL_AI_REQUEST_LIMIT = 20;
export const INITIAL_TRIAL_AI_RESERVATION_MICROS = 50_000;
export const INITIAL_TRIAL_AI_COST_MICROS_LIMIT =
  INITIAL_TRIAL_AI_REQUEST_LIMIT * INITIAL_TRIAL_AI_RESERVATION_MICROS;

export type InitialTrialStatus = 'active' | 'expired';
export type InitialTrialMigrationDisposition =
  | 'paid_no_trial'
  | 'preserve_legacy_end'
  | 'needs_explicit_migration_offer'
  | 'already_expired';

export interface InitialTrialPolicy {
  policyVersion: string;
  durationDays: number;
  aiRequestLimit: number;
  aiReservationCostMicros: number;
  aiCostMicrosLimit: number;
}

export const initialTrialPolicy: InitialTrialPolicy = {
  policyVersion: INITIAL_TRIAL_POLICY_VERSION,
  durationDays: INITIAL_TRIAL_DURATION_DAYS,
  aiRequestLimit: INITIAL_TRIAL_AI_REQUEST_LIMIT,
  aiReservationCostMicros: INITIAL_TRIAL_AI_RESERVATION_MICROS,
  aiCostMicrosLimit: INITIAL_TRIAL_AI_COST_MICROS_LIMIT,
};

export function calculateInitialTrialEndsAt(params: {
  startedAt: Date;
  policy?: InitialTrialPolicy;
}): Date {
  const policy = params.policy ?? initialTrialPolicy;
  return new Date(
    params.startedAt.getTime() + policy.durationDays * 24 * 60 * 60 * 1000,
  );
}

export function isInitialTrialActive(params: {
  status: unknown;
  endsAt: Date | null;
  now: Date;
}): boolean {
  return params.status === 'active' &&
    params.endsAt != null &&
    params.now.getTime() < params.endsAt.getTime();
}

export function classifyLegacyTrialMigration(params: {
  isPaid: boolean;
  legacyEndsAt: Date | null;
  now: Date;
}): InitialTrialMigrationDisposition {
  if (params.isPaid) return 'paid_no_trial';
  if (params.legacyEndsAt == null) {
    return 'needs_explicit_migration_offer';
  }
  if (params.now.getTime() >= params.legacyEndsAt.getTime()) {
    return 'already_expired';
  }
  return 'preserve_legacy_end';
}

import { classifyLegacyTrialMigration, InitialTrialMigrationDisposition } from './trialPolicy';

export interface InitialTrialMigrationDryRun {
  uid: string;
  disposition: InitialTrialMigrationDisposition;
  reason: string;
  proposedAction: 'none' | 'preserve_legacy_expiry' | 'offer_once';
}

/** Pure dry-run classifier. A separate admin-only runner may write results; it is not deployed or invoked here. */
export function buildInitialTrialMigrationDryRun(params: {uid: string; isPaid: boolean; legacyEndsAt: Date | null; now: Date}): InitialTrialMigrationDryRun {
  const disposition = classifyLegacyTrialMigration(params);
  switch (disposition) {
    case 'paid_no_trial': return {uid: params.uid, disposition, reason: 'paid_subscription', proposedAction: 'none'};
    case 'already_expired': return {uid: params.uid, disposition, reason: 'legacy_trial_expired', proposedAction: 'none'};
    case 'preserve_legacy_end': return {uid: params.uid, disposition, reason: 'legacy_end_reconstructable', proposedAction: 'preserve_legacy_expiry'};
    case 'needs_explicit_migration_offer': return {uid: params.uid, disposition, reason: 'legacy_start_or_end_unrecoverable', proposedAction: 'offer_once'};
  }
}

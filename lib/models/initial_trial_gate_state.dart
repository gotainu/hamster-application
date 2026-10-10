enum InitialTrialGateState {
  loading,
  unavailable,
  paid,
  activeTrial,
  canStart,
  locked,
}

/// Resolves the initial-trial gate only after entitlement snapshots are known.
/// Missing stream data is not evidence that the user has no active access.
InitialTrialGateState resolveInitialTrialGateState({
  required bool billingHasData,
  required bool billingHasError,
  required bool trialHasData,
  required bool trialHasError,
  required bool hasPaidAccess,
  required bool hasActiveTrial,
  required String? trialStatus,
  required bool canStart,
}) {
  if (billingHasError || trialHasError) {
    return InitialTrialGateState.unavailable;
  }
  if (!billingHasData || !trialHasData) {
    return InitialTrialGateState.loading;
  }
  if (hasPaidAccess) return InitialTrialGateState.paid;
  if (hasActiveTrial) return InitialTrialGateState.activeTrial;
  if (canStart && trialStatus == null) return InitialTrialGateState.canStart;
  return InitialTrialGateState.locked;
}

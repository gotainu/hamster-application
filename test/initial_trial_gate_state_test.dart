import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/initial_trial_gate_state.dart';

void main() {
  group('resolveInitialTrialGateState', () {
    InitialTrialGateState resolve({
      bool billingHasData = true,
      bool billingHasError = false,
      bool trialHasData = true,
      bool trialHasError = false,
      bool hasPaidAccess = false,
      bool hasActiveTrial = false,
      String? trialStatus,
      bool canStart = true,
    }) =>
        resolveInitialTrialGateState(
          billingHasData: billingHasData,
          billingHasError: billingHasError,
          trialHasData: trialHasData,
          trialHasError: trialHasError,
          hasPaidAccess: hasPaidAccess,
          hasActiveTrial: hasActiveTrial,
          trialStatus: trialStatus,
          canStart: canStart,
        );

    test('does not show the start action while either stream is pending', () {
      expect(
        resolve(billingHasData: false),
        InitialTrialGateState.loading,
      );
      expect(
        resolve(trialHasData: false),
        InitialTrialGateState.loading,
      );
    });

    test('shows start only after both sources confirm no prior trial', () {
      expect(resolve(), InitialTrialGateState.canStart);
      expect(
        resolve(trialStatus: 'expired'),
        InitialTrialGateState.locked,
      );
    });

    test('active entitlements open the feature after snapshots are known', () {
      expect(resolve(hasPaidAccess: true), InitialTrialGateState.paid);
      expect(resolve(hasActiveTrial: true), InitialTrialGateState.activeTrial);
    });

    test('read failures never turn into a start action or free access', () {
      expect(
        resolve(billingHasError: true, hasPaidAccess: false),
        InitialTrialGateState.unavailable,
      );
      expect(
        resolve(trialHasError: true),
        InitialTrialGateState.unavailable,
      );
    });
  });
}

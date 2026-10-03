import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/services/onboarding_state_repo.dart';

void main() {
  test('legacy onboarding state keeps the AI consultation step incomplete', () {
    final state = OnboardingState.fromJson({
      'introCompleted': true,
      'setupChecklistViewed': true,
    });

    expect(state.introCompleted, isTrue);
    expect(state.setupChecklistViewed, isTrue);
    expect(state.firstAiConsultationCompleted, isFalse);
    expect(state.setupCoachMarkSeen, isFalse);
  });

  test('AI consultation completion is read from onboarding state', () {
    final state = OnboardingState.fromJson({
      'firstAiConsultationCompleted': true,
    });

    expect(state.firstAiConsultationCompleted, isTrue);
  });

  test('onboarding entitlement expires seven days after the first record', () {
    final now = DateTime(2026, 10, 3, 12);
    final state = OnboardingState(
      introCompleted: true,
      setupChecklistViewed: true,
      firstAiConsultationCompleted: true,
      setupCoachMarkStep: 0,
      homeAiOnboardingPending: false,
      completedSetupSteps: const <String>{},
      firstMonitoringDataRecordedAt: now.subtract(const Duration(days: 7)),
    );

    expect(state.hasActiveOnboardingEntitlement(now), isFalse);
  });

  test('onboarding entitlement remains active before first monitoring data',
      () {
    final state = OnboardingState.initial();

    expect(state.hasActiveOnboardingEntitlement(), isTrue);
  });
}

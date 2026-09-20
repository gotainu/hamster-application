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
}

import 'dart:async';
import 'package:hamster_project/models/care_continuity.dart';
import 'package:hamster_project/models/daily_star_progress.dart';
import 'package:hamster_project/services/care_continuity_repo.dart';

CareContinuityState continuityFixture(
        {CareContinuityPhase phase = CareContinuityPhase.active,
        bool achieved = true,
        int earned = 8,
        bool confirmationPending = false,
        String serverDateKey = '2026-10-14',
        int lifetimeAchievementDays = 12}) =>
    CareContinuityState(
        serverDateKey: serverDateKey,
        phase: phase,
        confirmationPending: confirmationPending,
        todayAchieved: achieved,
        periodEarned: earned,
        lifetimeAchievementDays: lifetimeAchievementDays,
        periodId: 'fixture-period',
        periodStartedOn: '2026-10-01',
        lastAchievementDateKey: achieved ? '2026-10-14' : '2026-10-12',
        expiresAt: DateTime.utc(2026, 10, 14, 15));

class ContinuityTestSource implements CareContinuitySource {
  ContinuityTestSource(this.state);
  CareContinuityState state;
  final changes = StreamController<CareContinuityState>.broadcast(sync: true);
  int refreshes = 0, retries = 0;
  String rewardStatus = 'processed';
  bool rewardPending = false;
  List<CareContinuityDay>? recordedDays;
  final calendarRequests = <(String?, String?)>[];
  @override
  Stream<CareContinuityState> watch() => Stream.multi((sink) {
        sink.add(state);
        final sub = changes.stream.listen(sink.add, onError: sink.addError);
        sink.onCancel = sub.cancel;
      });
  @override
  Future<CareContinuityState> refresh() async {
    refreshes++;
    changes.add(state);
    return state;
  }

  @override
  Future<List<CareContinuityDay>> calendar(
      {String? startDateKey, String? endDateKey}) async {
    calendarRequests.add((startDateKey, endDateKey));
    return recordedDays ??
        [
          const CareContinuityDay(
              dayKey: '2026-10-12',
              achieved: true,
              sourceKind: 'care',
              sourceDateKey: '2026-10-01'),
          if (state.todayAchieved)
            CareContinuityDay(
                dayKey: state.serverDateKey,
                achieved: true,
                sourceKind: 'weight',
                sourceDateKey: state.serverDateKey),
        ];
  }

  @override
  Future<CareRewardRetryResult> retryCareReward(
      {required String dayKey, required String mutationId}) async {
    retries++;
    return CareRewardRetryResult(
        status: rewardStatus, confirmationPending: rewardPending);
  }

  Future<void> close() => changes.close();
}

const continuityGraceProgressFixture = DailyStarProgress([
  DailyStarSlot(kind: DailyStarSlotKind.openApp, label: 'アプリを開く', filled: true),
  DailyStarSlot(
      kind: DailyStarSlotKind.wheel, label: '昨日の走った記録', filled: false),
  DailyStarSlot(
      kind: DailyStarSlotKind.condition, label: '今日の様子', filled: false),
]);

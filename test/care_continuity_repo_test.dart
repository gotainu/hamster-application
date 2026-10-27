import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/care_continuity.dart';
import 'package:hamster_project/services/care_continuity_repo.dart';

Map<String, dynamic> _state({bool pending = false}) => {
      'serverDateKey': '2026-10-14',
      'phase': 'expired',
      'todayAchieved': false,
      'periodEarned': 0,
      'lifetimeAchievementDays': 12,
      'confirmationPending': pending,
    };
void main() {
  test('server refresh retains provisional reconciliation flag', () async {
    final repo = CareContinuityRepo(
        owner: () => 'owner', refreshServer: () async => _state(pending: true));
    expect((await repo.refresh()).confirmationPending, isTrue);
  });
  test(
      'failed RPC after listeners are gone does not emit an unhandled stream error',
      () async {
    final repo = CareContinuityRepo(
        owner: () => 'owner',
        refreshServer: () async => throw StateError('offline'));
    await expectLater(repo.refresh(), throwsStateError);
    await Future<void>.delayed(Duration.zero);
  });
  test('parallel refresh callers share one request', () async {
    final completion = Completer<Map<String, dynamic>>();
    var calls = 0;
    final repo = CareContinuityRepo(
        owner: () => 'owner',
        refreshServer: () {
          calls++;
          return completion.future;
        });
    final first = repo.refresh(), second = repo.refresh();
    expect(calls, 1);
    completion.complete(_state());
    expect(identical(await first, await second), isTrue);
  });
  test('response from a previous owner cannot become displayed state',
      () async {
    var owner = 'ownerA';
    final completion = Completer<Map<String, dynamic>>();
    final repo = CareContinuityRepo(
        owner: () => owner, refreshServer: () => completion.future);
    final response = repo.refresh();
    owner = 'ownerB';
    completion.complete(_state());
    await expectLater(response, throwsStateError);
  });
  test('reward retry sends only receipt identity and respects pending outcome',
      () async {
    Map<String, dynamic>? payload;
    final repo = CareContinuityRepo(
        owner: () => 'owner',
        retryServer: (data) async {
          payload = data;
          return {
            'reward': {'status': 'processed'},
            'continuity': _state(pending: true)
          };
        });
    final result = await repo.retryCareReward(
        dayKey: '2026-10-01', mutationId: 'fixed-mutation');
    expect(payload, {'dayKey': '2026-10-01', 'mutationId': 'fixed-mutation'});
    expect(result.confirmationPending, isTrue);
    expect(result.confirmed, isFalse);
  });
  test(
      'legacy reply without continuity remains confirmed only for processed status',
      () async {
    final repo = CareContinuityRepo(
        owner: () => 'owner',
        retryServer: (_) async => {
              'reward': {'status': 'processed'}
            });
    expect(
        (await repo.retryCareReward(dayKey: '2026-10-14', mutationId: 'fixed'))
            .confirmed,
        isTrue);
    expect(const CareRewardRetryResult(status: 'not_processed').confirmed,
        isFalse);
  });
  test('malformed server state never becomes a confirmed balance', () async {
    final repo =
        CareContinuityRepo(owner: () => 'owner', refreshServer: () async => {});
    await expectLater(repo.refresh(), throwsStateError);
  });
}

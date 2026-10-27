import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/daily_care_actions.dart';
import 'package:hamster_project/services/daily_care_actions_repo.dart';

class _Pending implements CareActionPendingStore {
  final data = <String, CareActionMutation>{};
  @override
  Future<CareActionMutation?> read(String owner, String dayKey) async =>
      data['$owner:$dayKey'];
  @override
  Future<void> write(String owner, CareActionMutation value) async {
    data['$owner:${value.dayKey}'] = value;
  }

  @override
  Future<void> remove(String owner, String dayKey) async {
    data.remove('$owner:$dayKey');
  }
}

CareActionMutation _mutation(
        [String id = '00000000-0000-4000-8000-000000000001']) =>
    CareActionMutation(
        dayKey: '2026-10-12',
        expectedRevision: 0,
        mutationId: id,
        actions: {
          'cageCleaning':
              const CareActionResponse(answer: CareActionAnswer.notPerformed),
          'roomWalk': const CareActionResponse()
        });
void main() {
  test('confirmed server response clears pending and preserves reward outcome',
      () async {
    final pending = _Pending();
    Map<String, dynamic>? payload;
    final repo = DailyCareActionsRepo(
        owner: () => 'ownerA',
        pendingStore: pending,
        submit: (data) async {
          payload = data;
          return {
            'saved': true,
            'revision': 1,
            'replayed': false,
            'reward': {'status': 'failed'}
          };
        });
    final result = await repo.save(_mutation());
    expect(result.confirmed, isTrue);
    expect(result.rewardStatus, 'failed');
    expect(pending.data, isEmpty);
    expect(payload!['expectedRevision'], 0);
    expect(payload!['mutationId'], _mutation().mutationId);
    expect(payload!['actions']['cageCleaning'], {'answer': 'not_performed'});
  });
  test(
      'save carries authoritative achievement metadata without guessing awards',
      () async {
    final repo = DailyCareActionsRepo(
        owner: () => 'ownerA',
        pendingStore: _Pending(),
        submit: (_) async => {
              'saved': true,
              'revision': 1,
              'reward': {'status': 'processed'},
              'continuity': {
                'achievementRecorded': true,
                'mirroredAwardCount': 1,
                'confirmationPending': true
              }
            });
    final result = await repo.save(_mutation());
    expect(result.confirmed, isTrue);
    expect(result.achievementRecorded, isTrue);
    expect(result.mirroredAwardCount, 1);
    expect(result.confirmationPending, isTrue);
  });
  test(
      'offline save is durable and restart retry has exactly the original payload',
      () async {
    final pending = _Pending();
    final mutation = _mutation();
    final offline = DailyCareActionsRepo(
        owner: () => 'ownerA',
        pendingStore: pending,
        submit: (_) async => throw FirebaseFunctionsException(
            code: 'unavailable', message: 'offline'));
    final result = await offline.save(mutation);
    expect(result.confirmed, isFalse);
    expect(pending.data.length, 1);
    Map<String, dynamic>? sent;
    final restarted = DailyCareActionsRepo(
        owner: () => 'ownerA',
        pendingStore: pending,
        read: (_) async => null,
        submit: (data) async {
          sent = data;
          return {'saved': true, 'revision': 1, 'replayed': true};
        });
    final load = await restarted.load(mutation.dayKey);
    expect(load.pending!.mutationId, mutation.mutationId);
    final saved = await restarted.save(load.pending!);
    expect(saved.confirmed, isTrue);
    expect(saved.replayed, isTrue);
    expect(sent, mutation.toMap());
    expect(pending.data, isEmpty);
  });
  test('offline read without current data does not confirm a guessed absence',
      () async {
    final repo = DailyCareActionsRepo(
        owner: () => 'ownerA',
        pendingStore: _Pending(),
        read: (_) async => throw FirebaseFunctionsException(
            code: 'unavailable', message: 'offline'));
    final result = await repo.load('2026-10-12');
    expect(result.serverConfirmed, isFalse);
    expect(result.record, isNull);
  });
  test('pending is owner scoped and cannot be overwritten by a second mutation',
      () async {
    final pending = _Pending();
    await pending.write('ownerA', _mutation());
    final repo = DailyCareActionsRepo(
        owner: () => 'ownerA',
        pendingStore: pending,
        submit: (_) async => throw StateError('must not call'));
    await expectLater(
        repo.save(_mutation('00000000-0000-4000-8000-000000000002')),
        throwsStateError);
    expect(pending.data.values.single.mutationId, _mutation().mutationId);
    final other = DailyCareActionsRepo(
        owner: () => 'ownerB', pendingStore: pending, read: (_) async => null);
    expect((await other.load('2026-10-12')).pending, isNull);
  });
  test('same mutation ID cannot replace pending request content', () async {
    final pending = _Pending();
    await pending.write('ownerA', _mutation());
    final repo = DailyCareActionsRepo(
        owner: () => 'ownerA',
        pendingStore: pending,
        submit: (_) async => throw StateError('must not call'));
    final changed = CareActionMutation(
        dayKey: '2026-10-12',
        expectedRevision: 0,
        mutationId: _mutation().mutationId,
        actions: {});
    await expectLater(repo.save(changed), throwsStateError);
    expect(pending.data.values.single.toMap(), _mutation().toMap());
  });
  test(
      'revision conflict stays distinct from offline and retains no transport retry',
      () async {
    final pending = _Pending();
    final repo = DailyCareActionsRepo(
        owner: () => 'ownerA',
        pendingStore: pending,
        submit: (_) async => throw FirebaseFunctionsException(
            code: 'aborted', message: 'conflict'));
    await expectLater(
        repo.save(_mutation()), throwsA(isA<FirebaseFunctionsException>()));
    expect(pending.data, isEmpty);
  });
  test('concurrent same-day retries are serialized and replay safely',
      () async {
    final pending = _Pending();
    var inFlight = 0, maxInFlight = 0, calls = 0;
    final repo = DailyCareActionsRepo(
        owner: () => 'ownerA',
        pendingStore: pending,
        submit: (_) async {
          inFlight++;
          if (inFlight > maxInFlight) maxInFlight = inFlight;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          calls++;
          inFlight--;
          return {'saved': true, 'revision': 1, 'replayed': calls > 1};
        });
    final results =
        await Future.wait([repo.save(_mutation()), repo.save(_mutation())]);
    expect(maxInFlight, 1);
    expect(results.last.replayed, isTrue);
    expect(results.every((r) => r.revision == 1), isTrue);
    expect(pending.data, isEmpty);
  });
  test('owner switch after submission cannot confirm another account in the UI',
      () async {
    var owner = 'ownerA';
    final pending = _Pending();
    final repo = DailyCareActionsRepo(
        owner: () => owner,
        pendingStore: pending,
        submit: (_) async {
          owner = 'ownerB';
          return {'saved': true, 'revision': 1};
        });
    await expectLater(repo.save(_mutation()), throwsStateError);
    expect(pending.data.keys, ['ownerA:2026-10-12']);
  });
  test('backend response corruption is never shown as confirmed', () async {
    final pending = _Pending();
    final repo = DailyCareActionsRepo(
        owner: () => 'ownerA',
        pendingStore: pending,
        submit: (_) async => {'saved': false});
    final result = await repo.save(_mutation());
    expect(result.confirmed, isFalse);
    expect(result.mutation.mutationId, _mutation().mutationId);
    expect(pending.data.length, 1,
        reason: 'lost outcome can retry same mutation safely');
  });
}

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/environment_history.dart';
import 'package:hamster_project/services/breeding_environment_repo.dart';

class MemoryEnvironmentPending implements EnvironmentPendingStore {
  final records = <String, EnvironmentMutation>{};
  @override
  Future<EnvironmentMutation?> read(String owner) async => records[owner];
  @override
  Future<void> write(String owner, EnvironmentMutation mutation) async {
    records[owner] = mutation;
  }

  @override
  Future<void> remove(String owner) async {
    records.remove(owner);
  }
}

EnvironmentMutation mutation(
        [String id = '00000000-0000-4000-8000-000000000001']) =>
    EnvironmentMutation(
        mutationId: id,
        expectedRevision: 2,
        operation: EnvironmentOperation.change,
        values: const {'wheelDiameter': '28'},
        effective: const EnvironmentEffective.unknown());
void main() {
  test(
      'all saves use callable, preserve revision and receipt; server acknowledgement clears pending',
      () async {
    final pending = MemoryEnvironmentPending();
    Map<String, dynamic>? sent;
    final repo = BreedingEnvironmentRepo(
        owner: () => 'owner',
        pendingStore: pending,
        submit: (data) async {
          sent = data;
          return {
            'saved': true,
            'acceptedAt': '2026-10-12T03:00:00.000Z',
            'revision': 3,
            'mutationId': data['mutationId'],
            'changed': true
          };
        });
    expect((await repo.save(mutation())).confirmed, isTrue);
    expect(sent, mutation().toMap());
    expect(pending.records, isEmpty);
  });
  test('restart keeps exact pending payload when offline or response lost',
      () async {
    final pending = MemoryEnvironmentPending();
    final offline = BreedingEnvironmentRepo(
        owner: () => 'owner',
        pendingStore: pending,
        submit: (_) async => throw FirebaseFunctionsException(
            code: 'unavailable', message: 'offline'));
    expect((await offline.save(mutation())).confirmed, isFalse);
    final restarted = BreedingEnvironmentRepo(
        owner: () => 'owner',
        pendingStore: pending,
        read: () async => {'revision': 2},
        submit: (data) async => {
              'saved': true,
              'acceptedAt': '2026-10-12T03:00:00.000Z',
              'revision': 3,
              'mutationId': data['mutationId'],
              'replayed': true
            });
    final load = await restarted.load();
    expect(load.pending!.toMap(), mutation().toMap());
    expect((await restarted.save(load.pending!)).replayed, isTrue);
    expect(pending.records, isEmpty);
  });
  test(
      'unknown acknowledgement or internal error never claims save confirmation',
      () async {
    final pending = MemoryEnvironmentPending();
    final repo = BreedingEnvironmentRepo(
        owner: () => 'owner',
        pendingStore: pending,
        submit: (_) async => {'saved': true});
    expect((await repo.save(mutation())).confirmed, isFalse);
    expect(pending.records.length, 1);
    final internal = BreedingEnvironmentRepo(
        owner: () => 'owner',
        pendingStore: pending,
        submit: (_) async => throw FirebaseFunctionsException(
            code: 'internal', message: 'unknown'));
    await expectLater(
        internal.save(mutation()), throwsA(isA<FirebaseFunctionsException>()));
    expect(pending.records.length, 1);
  });
  test(
      'missing acceptance time, stale revision and wrong receipt never confirm',
      () async {
    for (final reply in [
      {'saved': true, 'revision': 3, 'mutationId': mutation().mutationId},
      {
        'saved': true,
        'revision': 1,
        'mutationId': mutation().mutationId,
        'acceptedAt': '2026-10-12T03:00:00.000Z'
      },
      {
        'saved': true,
        'revision': 3,
        'mutationId': 'wrong',
        'acceptedAt': '2026-10-12T03:00:00.000Z'
      },
    ]) {
      final pending = MemoryEnvironmentPending();
      final repo = BreedingEnvironmentRepo(
          owner: () => 'owner',
          pendingStore: pending,
          submit: (_) async => reply);
      expect((await repo.save(mutation())).confirmed, isFalse);
      expect(pending.records.length, 1);
    }
  });
  test(
      'pending payload cannot silently change; ownership and conflict remain explicit',
      () async {
    final pending = MemoryEnvironmentPending();
    await pending.write('owner', mutation());
    final repo = BreedingEnvironmentRepo(
        owner: () => 'owner',
        pendingStore: pending,
        submit: (_) async => throw StateError('must not send'));
    await expectLater(
        repo.save(mutation('00000000-0000-4000-8000-000000000002')),
        throwsStateError);
    final conflict = BreedingEnvironmentRepo(
        owner: () => 'owner',
        pendingStore: pending,
        submit: (_) async => throw FirebaseFunctionsException(
            code: 'aborted', message: 'conflict'));
    await expectLater(
        conflict.save(mutation()), throwsA(isA<FirebaseFunctionsException>()));
    expect(pending.records, isEmpty);
  });
  test(
      'owner changed during request cannot report success or clear original pending',
      () async {
    final pending = MemoryEnvironmentPending();
    var owner = 'ownerA';
    final repo = BreedingEnvironmentRepo(
        owner: () => owner,
        pendingStore: pending,
        submit: (data) async {
          owner = 'ownerB';
          return {
            'saved': true,
            'acceptedAt': '2026-10-12T03:00:00.000Z',
            'revision': 3,
            'mutationId': data['mutationId']
          };
        });
    await expectLater(repo.save(mutation()), throwsStateError);
    expect(pending.records.containsKey('ownerA'), isTrue);
  });
  test(
      'concurrent retries are serialized, and offline read does not invent revision',
      () async {
    final pending = MemoryEnvironmentPending();
    var inFlight = 0, max = 0;
    final repo = BreedingEnvironmentRepo(
        owner: () => 'owner',
        pendingStore: pending,
        submit: (data) async {
          inFlight++;
          if (inFlight > max) max = inFlight;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          inFlight--;
          return {
            'saved': true,
            'acceptedAt': '2026-10-12T03:00:00.000Z',
            'revision': 3,
            'mutationId': data['mutationId']
          };
        });
    await Future.wait([repo.save(mutation()), repo.save(mutation())]);
    expect(max, 1);
    final offline = BreedingEnvironmentRepo(
        owner: () => 'owner',
        pendingStore: pending,
        read: () async => throw FirebaseFunctionsException(
            code: 'unavailable', message: 'offline'));
    expect((await offline.load()).serverConfirmed, isFalse);
  });
}

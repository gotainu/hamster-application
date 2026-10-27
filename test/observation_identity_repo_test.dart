import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/daily_observation_history.dart';
import 'package:hamster_project/models/pet_profile.dart';
import 'package:hamster_project/services/daily_checkin_repo.dart';
import 'package:hamster_project/services/pet_profile_repo.dart';
import 'package:hamster_project/viewmodels/observation_input_view_model.dart';

class MemoryObservationPending implements ObservationPendingStore {
  final values = <String, ObservationMutation>{};
  String key(String owner, String day) => '$owner:$day';
  @override
  Future<ObservationMutation?> read(String owner, String day) async =>
      values[key(owner, day)];
  @override
  Future<void> write(String owner, ObservationMutation mutation) async {
    values[key(owner, mutation.dayKey)] = mutation;
  }

  @override
  Future<void> remove(String owner, String day) async {
    values.remove(key(owner, day));
  }
}

class MemoryProfilePending implements ProfilePendingStore {
  final values = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(String owner) async => values[owner];
  @override
  Future<void> write(String owner, Map<String, dynamic> value) async {
    values[owner] = value;
  }

  @override
  Future<void> remove(String owner) async {
    values.remove(owner);
  }
}

ObservationMutation observation(
        {String? subject = 'subject_one', String id = 'mutation-one'}) =>
    ObservationMutation(
        mutationId: id,
        dayKey: '2026-10-13',
        date: DateTime(2026, 10, 13),
        expectedRevision: 3,
        subjectId: subject,
        operation: ObservationOperation.correction,
        timing: ObservationTiming.instant(DateTime.utc(2026, 10, 13, 4)),
        targetEventId: 'event-one',
        targetRevision: 3,
        condition: 'slightlyConcerned',
        concernTags: const ['appetite'],
        catalogVersion: 'observation_catalog_v1');
Map<String, dynamic> reply(Map<String, dynamic> input) => {
      'saved': true,
      'dayKey': input['dayKey'],
      'mutationId': input['mutationId'],
      'subjectId': 'subject_one',
      'revision': 4,
      'acceptedAt': '2026-10-13T04:05:00Z',
      'eventId': 'event-one',
      'recordStatus': 'active',
      'changed': true,
      'projection': {
        'dayKey': '2026-10-13',
        'date': '2026-10-12T15:00:00Z',
        'condition': 'slightlyConcerned',
        'concernTags': ['appetite'],
        'memo': '',
        'revision': 4,
        'eventId': 'event-one',
        'subjectId': 'subject_one'
      },
    };
PetProfile pet(
        {String? subject = 'subject_one',
        int revision = 3,
        String name = 'ハム'}) =>
    PetProfile(
        name: name,
        birthday: null,
        species: 'シリアン',
        color: null,
        imageUrl: null,
        subjectId: subject,
        revision: revision);
void main() {
  test(
      'ambiguous legacy production save cannot infer new or correction, or write',
      () async {
    final repo = DailyCheckinRepo(
        owner: () => 'owner',
        pendingStore: MemoryObservationPending(),
        read: (_) async => throw StateError('must not read'),
        submit: (_) async => throw StateError('must not write'));
    await expectLater(
        repo.saveDailyCheckin(
            date: DateTime(2026, 10, 13),
            condition: DailyCondition.normal,
            concernTags: const []),
        throwsA(isA<StateError>().having((e) => e.message, 'reason',
            'observation_explicit_intent_required')));
  });
  test(
      'wire timing/ISO dates and cancellation preserve precision without inventing receipt time',
      () {
    final timing = ObservationTiming.fromMap({
      'timePrecision': 'instant',
      'observedAt': '2026-10-13T04:00:00Z',
      'confirmation': 'time_confirmed'
    });
    expect(timing.toMap(), {
      'precision': 'instant',
      'observedAt': '2026-10-13T04:00:00.000Z',
      'confirmation': 'time_confirmed'
    });
    final current = DailyCheckin.fromJson({
      'dayKey': '2026-10-13',
      'date': '2026-10-12T15:00:00Z',
      'condition': 'normal',
      'timing': {
        'timePrecision': 'date_only',
        'dateKey': '2026-10-13',
        'confirmation': 'date_confirmed'
      }
    }, fallbackDayKey: '2026-10-13');
    expect(current.date.toUtc(), DateTime.utc(2026, 10, 12, 15));
    expect(current.timing!.observedAt, isNull);
    final cancelled = ObservationMutation(
        mutationId: 'cancel',
        dayKey: '2026-10-13',
        date: DateTime(2026, 10, 13),
        expectedRevision: 4,
        subjectId: 'subject_one',
        operation: ObservationOperation.cancel,
        targetEventId: 'event-one',
        targetRevision: 2,
        timing: const ObservationTiming.unknown(),
        catalogVersion: 'unused');
    final wire = cancelled.toMap();
    expect(wire.containsKey('timing'), false);
    expect(wire.containsKey('condition'), false);
    expect(ObservationMutation.fromMap(wire).targetRevision, 2);
  });
  test(
      'PIT response preserves unrecoverable original, nanosecond receipt and research not assessed',
      () {
    final response = ObservationHistoryAtResult.fromMap({
      'dayKey': '2026-10-13',
      'subjectId': 'subject_one',
      'historyExists': true,
      'latestRevision': 2,
      'knowledgeCutoff': '2026-10-13T05:00:00Z',
      'quality': {
        'reasons': ['legacy_original_unavailable'],
        'researchConsentStatus': 'not_assessed'
      },
      'events': [
        {
          'eventId': 'event-one',
          'cancelled': false,
          'original': null,
          'effective': {
            'revision': 2,
            'eventId': 'event-one',
            'subjectId': 'subject_one',
            'operation': 'correction',
            'origin': 'legacy_unknown_original',
            'acceptedAt': '2026-10-13T04:05:00Z',
            'acceptedAtEpochNanoseconds': '1791864300123456789',
            'answer': {'condition': 'slightlyConcerned'},
            'timing': {'timePrecision': 'unknown', 'confirmation': 'unknown'}
          }
        }
      ]
    });
    expect(response.events.single.original, isNull);
    expect(response.events.single.effective.acceptedAtEpochNanoseconds,
        '1791864300123456789');
    expect(response.researchConsentStatus, 'not_assessed');
    expect(response.reasons, ['legacy_original_unavailable']);
  });
  test(
      'timing needs confirmation; correction does not become a new observation by answer change',
      () {
    final vm = ObservationInputViewModel(
        date: DateTime(2026, 10, 13), dayKey: '2026-10-13');
    vm.load(const ObservationLoadResult(
        hasProfile: true, subjectId: 'subject_one'));
    expect(vm.canSave, false);
    vm.confirmDate();
    expect(vm.canSave, true);
    expect(vm.timing!.toMap(), {
      'precision': 'date_only',
      'confirmation': 'date_confirmed',
      'dateKey': '2026-10-13'
    });
    vm.load(ObservationLoadResult(
        hasProfile: true,
        subjectId: 'subject_one',
        revision: 3,
        current: DailyCheckin(
            dayKey: '2026-10-13',
            date: DateTime(2026, 10, 13),
            condition: DailyCondition.normal,
            concernTags: const [],
            memo: '',
            eventId: 'event-one',
            revision: 3)));
    vm.confirmNow(DateTime.utc(2026, 10, 13, 4));
    expect(vm.canSave, false);
    vm.chooseOperation(ObservationOperation.correction);
    expect(vm.timing, isNull);
    vm.confirmUnknown();
    final m = vm.mutation(
        condition: DailyCondition.slightlyConcerned,
        tags: ['appetite'],
        memo: '');
    expect(m.operation, ObservationOperation.correction);
    expect(m.targetEventId, 'event-one');
    expect(m.timing.precision, ObservationTimePrecision.unknown);
  });
  test(
      'callable save validates receipt, preserves exact pending request and never sends generated normals',
      () async {
    final pending = MemoryObservationPending();
    Map<String, dynamic>? sent;
    final repo = DailyCheckinRepo(
        owner: () => 'owner',
        pendingStore: pending,
        submit: (data) async {
          sent = data;
          return reply(data);
        });
    final result = await repo.saveObservation(observation());
    expect(result.confirmed, true);
    expect(result.acceptedAt, DateTime.utc(2026, 10, 13, 4, 5));
    expect(sent!['targetEventId'], 'event-one');
    expect(sent!.containsKey('observationLevels'), false);
    expect(pending.values, isEmpty);
  });
  test(
      'mixed ledger/projection snapshots are retried and never confirmed as fresh',
      () async {
    final pending = MemoryObservationPending();
    var reads = 0;
    final stale = {
      'profile': {'subjectId': 'subject_one'},
      'ledger': {
        'revision': 4,
        'subjectId': 'subject_one',
        'currentEventId': 'event-new',
        'currentEventRevision': 4
      },
      'current': {
        'dayKey': '2026-10-13',
        'date': '2026-10-13T00:00:00Z',
        'condition': 'normal',
        'subjectId': 'subject_one',
        'revision': 3,
        'eventId': 'event-old',
        'eventRevision': 3
      }
    };
    final repo = DailyCheckinRepo(
        owner: () => 'owner',
        pendingStore: pending,
        read: (_) async {
          reads++;
          return stale;
        });
    final loaded = await repo.loadObservation(DateTime(2026, 10, 13));
    expect(loaded.serverConfirmed, false);
    expect(loaded.current, isNull);
    expect(reads, 2);
    reads = 0;
    final recovered = DailyCheckinRepo(
        owner: () => 'owner',
        pendingStore: pending,
        read: (_) async {
          reads++;
          return reads == 1
              ? stale
              : {
                  'profile': {'subjectId': 'subject_one'},
                  'ledger': {
                    'revision': 4,
                    'subjectId': 'subject_one',
                    'currentEventId': null,
                    'currentEventRevision': null
                  }
                };
        });
    expect(
        (await recovered.loadObservation(DateTime(2026, 10, 13)))
            .serverConfirmed,
        true);
    expect(reads, 2);
  });
  test(
      'definitive capped-day rejection clears pending, unknown internal failure retains it',
      () async {
    for (final code in ['resource-exhausted', 'internal']) {
      final pending = MemoryObservationPending();
      final repo = DailyCheckinRepo(
          owner: () => 'owner',
          pendingStore: pending,
          submit: (_) async =>
              throw FirebaseFunctionsException(code: code, message: 'error'));
      await expectLater(repo.saveObservation(observation()),
          throwsA(isA<FirebaseFunctionsException>()));
      expect(pending.values.isEmpty, code == 'resource-exhausted');
    }
  });
  test(
      'nullable subject boundary is sent for atomic first registration only after explicit save',
      () async {
    final pending = MemoryObservationPending();
    var submits = 0;
    final repo = DailyCheckinRepo(
        owner: () => 'owner',
        pendingStore: pending,
        read: (_) async => {
              'profile': {'name': 'ハム'}
            },
        submit: (data) async {
          submits++;
          expect(data['subjectId'], isNull);
          return reply(data);
        });
    final loaded = await repo.loadObservation(DateTime(2026, 10, 13));
    expect(loaded.hasProfile, true);
    expect(loaded.subjectId, isNull);
    expect(submits, 0);
    final result = await repo.saveObservation(observation(subject: null));
    expect(result.confirmed, true);
    expect(result.subjectId, 'subject_one');
  });
  test(
      'offline and lost acknowledgement retain immutable mutation; replay after restart',
      () async {
    final pending = MemoryObservationPending();
    final offline = DailyCheckinRepo(
        owner: () => 'owner',
        pendingStore: pending,
        submit: (_) async => throw FirebaseFunctionsException(
            code: 'unavailable', message: 'offline'));
    expect((await offline.saveObservation(observation())).confirmed, false);
    final retry = DailyCheckinRepo(
        owner: () => 'owner',
        pendingStore: pending,
        read: (_) async => {
              'profile': {'subjectId': 'subject_one'},
              'ledger': {
                'revision': 3,
                'subjectId': 'subject_one',
                'currentEventId': null,
                'currentEventRevision': null
              }
            },
        submit: (data) async => {...reply(data), 'replayed': true});
    final restored = await retry.loadObservation(DateTime(2026, 10, 13));
    expect(restored.pending!.toMap(), observation().toMap());
    expect((await retry.saveObservation(restored.pending!)).replayed, true);
    expect(pending.values, isEmpty);
  });
  test(
      'wrong receipt/subject, missing server time and old revision cannot confirm',
      () async {
    for (final defect in [
      {'mutationId': 'wrong'},
      {'subjectId': 'other'},
      {'acceptedAt': null},
      {'revision': 2}
    ]) {
      final pending = MemoryObservationPending();
      final repo = DailyCheckinRepo(
          owner: () => 'owner',
          pendingStore: pending,
          submit: (data) async => {...reply(data), ...defect});
      expect((await repo.saveObservation(observation())).confirmed, false);
      expect(pending.values.length, 1);
    }
  });
  test(
      'owner changes and differing pending saves are blocked; concurrent retries serialize',
      () async {
    var owner = 'one';
    final pending = MemoryObservationPending();
    final repo = DailyCheckinRepo(
        owner: () => owner,
        pendingStore: pending,
        submit: (data) async {
          owner = 'two';
          return reply(data);
        });
    await expectLater(repo.saveObservation(observation()), throwsStateError);
    expect(pending.values.containsKey('one:2026-10-13'), true);
    owner = 'one';
    await expectLater(
        repo.saveObservation(observation(id: 'different')), throwsStateError);
    var inFlight = 0, maximum = 0;
    final concurrent = DailyCheckinRepo(
        owner: () => owner,
        pendingStore: pending,
        submit: (data) async {
          inFlight++;
          if (inFlight > maximum) maximum = inFlight;
          await Future<void>.delayed(const Duration(milliseconds: 2));
          inFlight--;
          return reply(data);
        });
    await Future.wait([
      concurrent.saveObservation(observation()),
      concurrent.saveObservation(observation())
    ]);
    expect(maximum, 1);
  });
  test(
      'profile edit carries loaded ID and revision; repeated same payload reuses mutation',
      () async {
    final pending = MemoryProfilePending();
    final requests = <Map<String, dynamic>>[];
    var offline = true;
    final repo = PetProfileRepo(
        owner: () => 'owner',
        pendingStore: pending,
        submit: (data) async {
          requests.add(data);
          if (offline) {
            throw FirebaseFunctionsException(
                code: 'unavailable', message: 'offline');
          }
          return {
            'subjectId': 'subject_one',
            'revision': 4,
            'acceptedAt': '2026-10-13T04:05:00Z',
            'mutationId': data['mutationId']
          };
        });
    await expectLater(repo.saveMainPet(pet(name: '別の名前')),
        throwsA(isA<FirebaseFunctionsException>()));
    final restored = await repo.fetchPendingProfile();
    expect(restored!.subjectId, 'subject_one');
    expect(restored.revision, 3);
    offline = false;
    final result = await repo.saveMainPet(restored);
    expect(requests[0]['mutationId'], requests[1]['mutationId']);
    expect(requests.last['expectedSubjectId'], 'subject_one');
    expect(requests.last['expectedRevision'], 3);
    expect(result.subjectId, 'subject_one');
    expect(pending.values, isEmpty);
  });
  test(
      'legacy profile parse never invents identity; image removal uses same guarded callable',
      () async {
    expect(PetProfile.fromMap({'name': 'old'}).subjectId, isNull);
    Map<String, dynamic>? sent;
    final repo = PetProfileRepo(
        owner: () => 'owner',
        pendingStore: MemoryProfilePending(),
        submit: (data) async {
          sent = data;
          return {
            'subjectId': 'subject_one',
            'revision': 4,
            'acceptedAt': '2026-10-13T04:05:00Z',
            'mutationId': data['mutationId']
          };
        });
    await repo.deleteImageUrl(expectedProfile: pet());
    expect(sent!['operation'], 'save');
    expect(sent!['values']['imageUrl'], isNull);
    expect(sent!['expectedSubjectId'], 'subject_one');
  });
}

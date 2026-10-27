import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/pet_profile.dart';
import 'package:hamster_project/services/measurement_history_client.dart';
import 'package:hamster_project/services/pet_profile_repo.dart';
import 'measurement_history_test_support.dart';
import 'observation_identity_repo_test.dart' show MemoryProfilePending;

class SwitchingMeasurementPending extends MemoryMeasurementPending {
  SwitchingMeasurementPending(this.switchOwner);
  final void Function() switchOwner;
  @override
  Future<void> write(
      String owner, String kind, Map<String, dynamic> value) async {
    await super.write(owner, kind, value);
    switchOwner();
  }
}

class SwitchingProfilePending extends MemoryProfilePending {
  SwitchingProfilePending(this.switchOwner);
  final void Function() switchOwner;
  @override
  Future<void> write(String owner, Map<String, dynamic> value) async {
    await super.write(owner, value);
    switchOwner();
  }
}

void main() {
  test(
      'weight correction/date move preserve expected identity and original date, receipt projection',
      () async {
    Map<String, dynamic>? sent;
    final repo = WeightHistoryUiRepo(
        client: testMeasurementClient(submit: (value) async {
      sent = value;
      return measurementReply(value);
    }));
    final result = await repo.saveRecord(
        date: DateTime(2026, 10, 13),
        weightGrams: 123,
        memo: ' 入力 ',
        expectedRecord: historyWeight(),
        originalDayKey: '2026-10-12',
        timing: measurementDateTiming('2026-10-13'));
    expect(sent!['expectedRevision'], 2);
    expect(sent!['subjectId'], 'subject-one');
    expect(sent!['originalDayKey'], '2026-10-12');
    expect(sent!['memo'], '入力');
    expect(result.revision, 3);
    expect(result.recordId, 'record-one');
    expect(result.date, DateTime(2026, 10, 13));
    expect(sent!.containsKey('updatedAt'), false);
  });
  test(
      'unknown timing remains unknown; cancellation contains no measurement answer or fabricated time',
      () async {
    Map<String, dynamic>? sent;
    final repo = WeightHistoryUiRepo(
        client: testMeasurementClient(submit: (value) async {
      sent = value;
      return measurementReply(value);
    }));
    await repo.saveRecord(
        date: DateTime(2026, 10, 12),
        weightGrams: 123,
        expectedRecord: historyWeight(subject: null, revision: 0),
        legacyConfirmed: true,
        timing: {...unknownMeasurementTiming});
    expect(sent!['legacyConfirmed'], true);
    expect(sent!['timing'], unknownMeasurementTiming);
    await repo.cancelRecord(historyWeight());
    expect(sent!['operation'], 'cancel');
    expect(sent!.containsKey('timing'), false);
    expect(sent!.containsKey('weightGrams'), false);
  });
  test('fresh record following cancellation uses day route revision', () async {
    Map<String, dynamic>? sent;
    final repo = WeightHistoryUiRepo(
        client: testMeasurementClient(
            dayRevision: 7,
            submit: (value) async {
              sent = value;
              return measurementReply(value);
            }));
    await repo.saveRecord(
        date: DateTime(2026, 10, 12),
        weightGrams: 120,
        timing: measurementDateTiming('2026-10-12'));
    expect(sent!['expectedRevision'], 7);
  });
  test(
      'lost acknowledgement retains exact payload; altered save blocked and restart replay clears pending',
      () async {
    final store = MemoryMeasurementPending();
    final requests = <Map<String, dynamic>>[];
    final offline = testMeasurementClient(
        pending: store,
        submit: (r) async {
          requests.add(r);
          throw FirebaseFunctionsException(
              code: 'unavailable', message: 'offline');
        });
    final repo = WeightHistoryUiRepo(client: offline);
    Future<void> save(double weight) async {
      await repo.saveRecord(
          date: DateTime(2026, 10, 12),
          weightGrams: weight,
          expectedRecord: historyWeight());
    }

    await expectLater(save(121), throwsA(isA<FirebaseFunctionsException>()));
    await expectLater(save(122), throwsStateError);
    expect(requests.length, 1);
    final retry = testMeasurementClient(
        pending: store,
        submit: (r) async {
          requests.add(r);
          return measurementReply(r, replayed: true);
        });
    expect((await retry.retryPending())['replayed'], true);
    expect(requests[0], requests[1]);
    expect(store.values, isEmpty);
  });
  for (final defect in [
    'wrong_mutation',
    'wrong_subject',
    'missing_time',
    'stale_revision',
    'wrong_projection'
  ]) {
    test('malformed receipt $defect keeps pending and does not confirm save',
        () async {
      final store = MemoryMeasurementPending();
      final client = testMeasurementClient(
          pending: store,
          submit: (r) async {
            final result = measurementReply(r);
            if (defect == 'wrong_mutation') result['mutationId'] = 'wrong';
            if (defect == 'wrong_subject') result['subjectId'] = 'other';
            if (defect == 'missing_time') result['acceptedAt'] = null;
            if (defect == 'stale_revision') result['revision'] = 0;
            if (defect == 'wrong_projection') {
              result['projection'] = {'revision': 3};
            }
            return result;
          });
      await expectLater(
          WeightHistoryUiRepo(client: client).saveRecord(
              date: DateTime(2026, 10, 12),
              weightGrams: 121,
              expectedRecord: historyWeight()),
          throwsStateError);
      expect(store.values.length, 1);
    });
  }
  test(
      'definite collision clears uncertain pending and preserves user input outside repository',
      () async {
    final store = MemoryMeasurementPending();
    final client = testMeasurementClient(
        pending: store,
        submit: (_) async => throw FirebaseFunctionsException(
            code: 'already-exists', message: 'collision'));
    await expectLater(
        WeightHistoryUiRepo(client: client).saveRecord(
            date: DateTime(2026, 10, 12),
            weightGrams: 121,
            expectedRecord: historyWeight()),
        throwsA(isA<FirebaseFunctionsException>()));
    expect(store.values, isEmpty);
  });
  test(
      'owner switch cannot accept another owner receipt; original pending kept',
      () async {
    var owner = 'one';
    final store = MemoryMeasurementPending();
    final client = testMeasurementClient(
        owner: () => owner,
        pending: store,
        submit: (r) async {
          owner = 'two';
          return measurementReply(r);
        });
    await expectLater(
        WeightHistoryUiRepo(client: client).saveRecord(
            date: DateTime(2026, 10, 12),
            weightGrams: 121,
            expectedRecord: historyWeight()),
        throwsStateError);
    expect(store.values.containsKey('one:weight'), true);
  });
  test(
      'rotation edit omits diameter replacement, zero is measured, explicit correction distinct, overnight preserved',
      () async {
    final requests = <Map<String, dynamic>>[];
    final repo = DistanceHistoryUiRepo(
        client: testMeasurementClient(
            kind: 'distance',
            submit: (r) async {
              requests.add(r);
              return measurementReply(r);
            }));
    await repo.saveRotationRecord(
        date: DateTime(2026, 10, 12),
        rotations: 0,
        expectedRecord: historyDistance());
    expect(requests.last['rotations'], 0);
    expect(requests.last.containsKey('wheelDiameterCm'), false);
    expect((requests.last['timing'] as Map)['windowMeaning'],
        'selected_night_to_next_morning');
    await repo.saveRotationRecord(
        date: DateTime(2026, 10, 12),
        rotations: 100,
        expectedRecord: historyDistance(),
        diameterCorrection: true,
        wheelDiameterCm: 22);
    expect(requests.last['diameterCorrection'], true);
    expect(requests.last['wheelDiameterCm'], 22);
  });
  test(
      'direct distance route uses history callable and no stale rotations metadata is submitted',
      () async {
    Map<String, dynamic>? sent;
    final repo = DistanceHistoryUiRepo(
        client: testMeasurementClient(
            kind: 'distance',
            submit: (r) async {
              sent = r;
              return measurementReply(r);
            }));
    await repo.addDistanceRecord(date: DateTime(2026, 10, 12), distance: 0);
    expect(sent!['mode'], 'direct_distance');
    expect(sent!['distance'], 0);
    expect(sent!.containsKey('rotations'), false);
  });
  test(
      'profile preserves birthday precision and id across save and image deletion',
      () async {
    final requests = <Map<String, dynamic>>[];
    final pending = MemoryProfilePending();
    final repo = PetProfileRepo(
        owner: () => 'owner',
        pendingStore: pending,
        submit: (r) async {
          requests.add(r);
          return {
            'subjectId': 'subject-one',
            'revision': 3,
            'historyRevision': 4,
            'mutationId': r['mutationId'],
            'acceptedAt': '2026-10-13T01:00:00Z'
          };
        });
    final pet = PetProfile(
        name: 'ハム',
        birthday: DateTime(2026, 1, 1),
        species: 'シリアン',
        color: null,
        imageUrl: null,
        subjectId: 'subject-one',
        revision: 2,
        birthdayPrecision: 'approximate_date');
    final saved = await repo.saveMainPet(pet);
    expect(saved.profileHistoryRevision, 4);
    expect(saved.birthdayPrecision, 'approximate_date');
    await repo.deleteImageUrl(expectedProfile: pet);
    expect(requests.last['values']['birthdayPrecision'], 'approximate_date');
    expect(requests.last['expectedSubjectId'], 'subject-one');
    expect(PetProfile.fromMap({'birthday': '2026-01-01'}).birthdayPrecision,
        'legacy_unspecified');
    expect(PetProfile.fromMap({}).birthdayPrecision, 'unknown');
  });
  test(
      'server timing projection converts to accepted wire without inventing instant',
      () {
    expect(
        measurementWireTiming({
          'timePrecision': 'unknown',
          'confirmation': 'unknown',
          'dateKey': null,
          'observedAt': null,
          'clockSource': 'unknown',
          'timeZone': 'Asia/Tokyo',
          'windowMeaning': 'selected_night_to_next_morning'
        }),
        {
          ...unknownMeasurementTiming,
          'windowMeaning': 'selected_night_to_next_morning'
        });
    expect(
        measurementWireTiming({
          'timePrecision': 'instant',
          'confirmation': 'time_confirmed',
          'observedAt': '2026-10-12T03:00:00Z',
          'dateKey': '2026-10-12',
          'clockSource': 'user_reported'
        }),
        {
          'precision': 'instant',
          'confirmation': 'time_confirmed',
          'observedAt': '2026-10-12T03:00:00Z'
        });
  });
  test(
      'history read forwards nanosecond cutoff and keeps unrecoverable quality',
      () async {
    Map<String, dynamic>? sent;
    final client = MeasurementHistoryClient(
        kind: 'weight',
        owner: () => 'owner',
        pendingStore: MemoryMeasurementPending(),
        readHistory: (r) async {
          sent = r;
          return {
            'quality': {
              'reasons': ['legacy_original_unavailable'],
              'researchConsentStatus': 'not_assessed'
            },
            'revisions': [
              {'acceptedAtEpochNanoseconds': '1791853200123456789'}
            ]
          };
        });
    final result = await client.historyAt(
        dayKey: '2026-10-12',
        knowledgeCutoffEpochNanoseconds: '1791853200123456789');
    expect(sent!['knowledgeCutoffEpochNanoseconds'], '1791853200123456789');
    expect(result['quality']['reasons'], ['legacy_original_unavailable']);
  });
  test(
      'profile cancellation carries target and revision, refreshes current without changing subject',
      () async {
    Map<String, dynamic>? sent;
    final repo = PetProfileRepo(
        owner: () => 'owner',
        pendingStore: MemoryProfilePending(),
        read: () async => {
              'name': 'ハム',
              'species': 'シリアン',
              'birthday': null,
              'subjectId': 'subject-one',
              'revision': 3,
              'profileHistoryRevision': 4
            },
        submit: (r) async {
          sent = r;
          return {
            'subjectId': 'subject-one',
            'revision': 3,
            'historyRevision': 4,
            'mutationId': r['mutationId'],
            'acceptedAt': '2026-10-13T01:00:00Z'
          };
        });
    final result = await repo.cancelAttributeCorrection(
        PetProfile(
            name: 'ハム',
            birthday: null,
            species: 'ジャンガリアン',
            color: null,
            imageUrl: null,
            subjectId: 'subject-one',
            revision: 2),
        targetHistoryRevision: 3);
    expect(sent!['operation'], 'cancel_profile_correction');
    expect(sent!['targetHistoryRevision'], 3);
    expect(sent!['expectedRevision'], 2);
    expect(sent!.containsKey('values'), false);
    expect(result.species, 'シリアン');
    expect(result.subjectId, 'subject-one');
  });
  test(
      'uncertain profile cancellation retains target and replays after restart without blank attributes',
      () async {
    final pending = MemoryProfilePending();
    final requests = <Map<String, dynamic>>[];
    Map<String, dynamic> current() => {
          'name': 'ハム',
          'species': 'シリアン',
          'subjectId': 'subject-one',
          'revision': 2
        };
    final offline = PetProfileRepo(
        owner: () => 'owner',
        pendingStore: pending,
        read: () async => current(),
        submit: (r) async {
          requests.add(r);
          throw FirebaseFunctionsException(
              code: 'unavailable', message: 'offline');
        });
    await expectLater(
        offline.cancelAttributeCorrection(PetProfile.fromMap(current()),
            targetHistoryRevision: 3),
        throwsA(isA<FirebaseFunctionsException>()));
    expect((await offline.fetchPendingProfile())!.name, 'ハム');
    final retry = PetProfileRepo(
        owner: () => 'owner',
        pendingStore: pending,
        read: () async => {...current(), 'revision': 3},
        submit: (r) async {
          requests.add(r);
          return {
            'subjectId': 'subject-one',
            'revision': 3,
            'historyRevision': 4,
            'mutationId': r['mutationId'],
            'acceptedAt': '2026-10-13T01:00:00Z'
          };
        });
    await retry.retryPending();
    expect(requests[0], requests[1]);
    expect(pending.values, isEmpty);
  });
  test('name-only legacy profile edit never manufactures missing species',
      () async {
    final legacy = PetProfile.fromMap({'name': '旧プロフィール', 'revision': 0});
    expect(legacy.species, '');
    Map<String, dynamic>? sent;
    final repo = PetProfileRepo(
        owner: () => 'owner',
        pendingStore: MemoryProfilePending(),
        submit: (r) async {
          sent = r;
          return {
            'subjectId': 'subject-one',
            'revision': 1,
            'historyRevision': 1,
            'mutationId': r['mutationId'],
            'acceptedAt': '2026-10-13T01:00:00Z'
          };
        });
    await repo.saveMainPet(PetProfile(
        name: '新しい名前',
        birthday: legacy.birthday,
        species: legacy.species,
        color: legacy.color,
        imageUrl: legacy.imageUrl,
        revision: legacy.revision));
    expect(sent!['values']['species'], '');
    expect(sent!['values']['birthdayPrecision'], 'unknown');
  });
  test(
      'owner switch during secure measurement write sends nothing and retains original owner pending',
      () async {
    var owner = 'one', submits = 0;
    final pending = SwitchingMeasurementPending(() => owner = 'two');
    final client = testMeasurementClient(
        owner: () => owner,
        pending: pending,
        submit: (r) async {
          submits++;
          return measurementReply(r);
        });
    await expectLater(
        WeightHistoryUiRepo(client: client).saveRecord(
            date: DateTime(2026, 10, 12),
            weightGrams: 123,
            expectedRecord: historyWeight()),
        throwsStateError);
    expect(submits, 0);
    expect(pending.values.containsKey('one:weight'), true);
  });
  test(
      'owner switch during secure profile write sends nothing and retains original owner pending',
      () async {
    var owner = 'one', submits = 0;
    final pending = SwitchingProfilePending(() => owner = 'two');
    final repo = PetProfileRepo(
        owner: () => owner,
        pendingStore: pending,
        submit: (r) async {
          submits++;
          return {
            'subjectId': 'subject-one',
            'revision': 3,
            'mutationId': r['mutationId'],
            'acceptedAt': '2026-10-13T01:00:00Z'
          };
        });
    await expectLater(
        repo.saveMainPet(PetProfile(
            name: 'ハム',
            birthday: null,
            species: 'シリアン',
            color: null,
            imageUrl: null,
            subjectId: 'subject-one',
            revision: 2)),
        throwsStateError);
    expect(submits, 0);
    expect(pending.values.containsKey('one'), true);
  });
}

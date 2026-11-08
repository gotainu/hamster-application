import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/daily_care_actions.dart';
import 'package:hamster_project/models/daily_observation_history.dart';
import 'package:hamster_project/services/daily_checkin_repo.dart';
import 'package:hamster_project/viewmodels/care_action_input_view_model.dart';
import 'package:hamster_project/viewmodels/observation_input_view_model.dart';

class _MemoryPartialPending implements ObservationPendingStore {
  final values = <String, Map<String, dynamic>>{};
  @override
  Future<ObservationMutation?> read(String owner, String dayKey) async {
    final value = values['$owner:$dayKey'];
    return value == null ? null : ObservationMutation.fromMap(value);
  }

  @override
  Future<void> write(String owner, ObservationMutation mutation) async {
    values['$owner:${mutation.dayKey}'] =
        Map<String, dynamic>.from(jsonDecode(jsonEncode(mutation.toMap())));
  }

  @override
  Future<void> remove(String owner, String dayKey) async {
    values.remove('$owner:$dayKey');
  }
}

ObservationInputViewModel _draft({DailyCheckin? current}) =>
    ObservationInputViewModel(
      date: DateTime(2026, 11, 8),
      dayKey: '2026-11-08',
      allowPartial: true,
    )..load(ObservationLoadResult(
        current: current,
        revision: current?.revision ?? 0,
        hasProfile: true,
        subjectId: 'synthetic-partial-pet'));

void main() {
  test('missing and invalid overall answers never become normal or concern',
      () {
    for (final value in [null, '', 'unknown', 0, false]) {
      final checkin = DailyCheckin.fromJson(
        {
          if (value != null) 'condition': value,
          'memo': '合成確認メモ',
        },
        fallbackDayKey: '2026-11-08',
      );
      expect(checkin.condition, isNull);
      expect(checkin.hasConcern, isFalse);
      expect(checkin.observationLevels, isEmpty);
      expect(checkin.memo, '合成確認メモ');
      expect(checkin.timing, isNull);
    }
  });

  test('explicit concern items remain concerns without an overall answer', () {
    for (final data in [
      {
        'concernTags': ['appetite']
      },
      {
        'observationLevels': {'elimination': 'changed'}
      },
      {
        'observationLevels': {'breathing': 'concerning'}
      },
    ]) {
      final checkin = DailyCheckin.fromJson(data, fallbackDayKey: '2026-11-08');
      expect(checkin.condition, isNull);
      expect(checkin.hasConcern, isTrue);
    }
  });

  test('legacy complete condition and stored timing remain readable', () {
    final checkin = DailyCheckin.fromJson({
      'dayKey': '2026-11-08',
      'condition': 'veryConcerned',
      'concernTags': ['poop'],
      'observationLevels': {'poop': 'concerning', 'appetite': 'normal'},
      'memo': '以前の合成記録',
      'schemaVersion': 2,
      'timing': {
        'timePrecision': 'instant',
        'observedAt': '2026-11-08T01:02:00Z',
        'confirmation': 'time_confirmed',
      },
    }, fallbackDayKey: '2026-11-08');
    expect(checkin.condition, DailyCondition.veryConcerned);
    expect(checkin.hasConcern, isTrue);
    expect(checkin.concernTags, ['elimination']);
    expect(checkin.observationLevels, {
      'elimination': DailyObservationLevel.concerning,
      'appetite': DailyObservationLevel.normal,
    });
    expect(checkin.timing!.precision, ObservationTimePrecision.instant);
    expect(checkin.timing!.observedAt, DateTime.utc(2026, 11, 8, 1, 2));
    expect(checkin.memo, '以前の合成記録');
  });

  test('partial selected items never populate unselected normal levels', () {
    expect(
        buildDailyObservationLevels(condition: null, concernTags: []), isEmpty);
    expect(
      buildDailyObservationLevels(
          condition: DailyCondition.normal, concernTags: [], partial: true),
      isEmpty,
    );
    expect(
      buildDailyObservationLevels(
          condition: null, concernTags: ['appetite'], partial: true),
      {'appetite': DailyObservationLevel.changed},
    );
    expect(
      buildDailyObservationLevels(
          condition: DailyCondition.veryConcerned,
          concernTags: ['poop'],
          partial: true),
      {'elimination': DailyObservationLevel.concerning},
    );
    // The old helper remains available for decoding/replaying schema2 meaning.
    expect(
      buildDailyObservationLevels(
          condition: DailyCondition.normal, concernTags: []).values,
      everyElement(DailyObservationLevel.normal),
    );
  });

  test('partial overall-only mutation needs no observation timing', () {
    final draft = _draft();
    expect(draft.timing, isNull);
    expect(draft.canSave, isTrue);
    final mutation =
        draft.mutation(condition: DailyCondition.normal, tags: [], memo: '');
    final wire = mutation.toMap();
    expect(wire['inputUiVersion'], 'daily_checkin_partial_v1');
    expect(wire['condition'], 'normal');
    expect(wire.containsKey('concernTags'), isFalse);
    expect(wire.containsKey('memo'), isFalse);
    expect(wire.containsKey('observationLevels'), isFalse);
    expect(mutation.timing.precision, ObservationTimePrecision.unknown);
    expect(mutation.timing.observedAt, isNull);
    expect(mutation.timing.dateKey, isNull);
  });

  test('selected item or memo alone is meaningful without invented condition',
      () {
    final selected =
        _draft().mutation(condition: null, tags: ['appetite'], memo: '');
    expect(selected.toMap()['concernTags'], ['appetite']);
    expect(selected.toMap().containsKey('condition'), isFalse);
    expect(selected.toMap().containsKey('memo'), isFalse);
    final memo =
        _draft().mutation(condition: null, tags: [], memo: '  合成の気になること  ');
    expect(memo.toMap()['memo'], '合成の気になること');
    expect(memo.toMap().containsKey('condition'), isFalse);
    expect(memo.toMap().containsKey('concernTags'), isFalse);
    expect(jsonEncode(ObservationMutation.fromMap(memo.toMap()).toMap()),
        jsonEncode(memo.toMap()));
  });

  test('all-empty partial answer cannot create a mutation', () {
    final draft = _draft();
    for (final memo in ['', '  ', '\n\t']) {
      expect(() => draft.mutation(condition: null, tags: [], memo: memo),
          throwsStateError);
    }
  });

  test('partial support does not bypass profile confirmation or pending guards',
      () {
    for (final state in [
      const ObservationLoadResult(serverConfirmed: false, hasProfile: true),
      const ObservationLoadResult(hasProfile: false),
    ]) {
      final draft = _draft()..load(state);
      expect(draft.canSave, isFalse);
      expect(
          () => draft.mutation(
              condition: DailyCondition.normal, tags: [], memo: ''),
          throwsStateError);
    }
    final pending =
        _draft().mutation(condition: DailyCondition.normal, tags: [], memo: '');
    final draft = _draft()
      ..load(ObservationLoadResult(
          pending: pending,
          hasProfile: true,
          subjectId: 'synthetic-partial-pet'));
    expect(draft.canSave, isFalse);
  });

  test('correction keeps old stored timing while new observation stays unknown',
      () {
    final current = DailyCheckin(
        dayKey: '2026-11-08',
        date: DateTime(2026, 11, 8),
        condition: DailyCondition.normal,
        concernTags: const [],
        memo: '',
        eventId: 'synthetic-old-event',
        eventRevision: 2,
        revision: 4,
        timing: const ObservationTiming.dateOnly('2026-11-08'));
    final draft = _draft(current: current);
    expect(draft.canSave, isFalse, reason: 'Existing intent must be explicit');
    draft.chooseOperation(ObservationOperation.correction);
    final correction =
        draft.mutation(condition: null, tags: [], memo: '訂正の合成メモ');
    expect(correction.operation, ObservationOperation.correction);
    expect(correction.targetEventId, 'synthetic-old-event');
    expect(correction.targetRevision, 2);
    expect(correction.timing.toMap(), current.timing!.toMap());
    draft.chooseOperation(ObservationOperation.newObservation);
    final fresh = draft.mutation(condition: null, tags: [], memo: '別の合成観察');
    expect(fresh.timing.precision, ObservationTimePrecision.unknown);
    expect(fresh.targetEventId, isNull);
  });

  test('old history pending round trip keeps version timing and empty fields',
      () {
    final old = ObservationMutation(
      mutationId: 'synthetic-legacy-mutation',
      dayKey: '2026-11-08',
      date: DateTime(2026, 11, 8),
      expectedRevision: 2,
      subjectId: 'synthetic-partial-pet',
      operation: ObservationOperation.correction,
      targetEventId: 'old-event',
      targetRevision: 1,
      timing: const ObservationTiming.dateOnly('2026-11-08'),
      condition: 'normal',
      catalogVersion: 'observation_catalog_v1',
    );
    final wire = old.toMap();
    expect(wire['inputUiVersion'], 'daily_checkin_history_v1');
    expect(wire['concernTags'], isEmpty);
    expect(wire['memo'], '');
    expect(jsonEncode(ObservationMutation.fromMap(wire).toMap()),
        jsonEncode(wire));
  });

  test('offline partial pending retries the same sparse request after restart',
      () async {
    final pending = _MemoryPartialPending();
    final mutation =
        _draft().mutation(condition: null, tags: ['appetite'], memo: '');
    final offline = DailyCheckinRepo(
      owner: () => 'synthetic-owner',
      pendingStore: pending,
      submit: (_) async => throw FirebaseFunctionsException(
          code: 'unavailable', message: 'synthetic offline'),
    );
    final result = await offline.saveObservation(mutation);
    expect(result.confirmed, isFalse);
    final originalWire = jsonEncode(mutation.toMap());
    expect(jsonEncode(pending.values.values.single), originalWire);
    Map<String, dynamic>? submitted;
    final restarted = DailyCheckinRepo(
      owner: () => 'synthetic-owner',
      pendingStore: pending,
      submit: (data) async {
        submitted = data;
        return {
          'saved': true,
          'revision': 1,
          'dayKey': data['dayKey'],
          'mutationId': data['mutationId'],
          'subjectId': 'synthetic-partial-pet',
          'acceptedAt': '2026-11-08T01:02:00Z',
          'eventId': 'synthetic-partial-event',
          'recordStatus': 'active',
          'projection': {
            'dayKey': data['dayKey'],
            'concernTags': data['concernTags'],
          },
        };
      },
    );
    final retry = await pending.read('synthetic-owner', mutation.dayKey);
    expect((await restarted.saveObservation(retry!)).confirmed, isTrue);
    expect(jsonEncode(submitted), originalWire);
    expect(submitted!.containsKey('condition'), isFalse);
    expect(submitted!.containsKey('memo'), isFalse);
    expect(pending.values, isEmpty);
  });

  test('untouched care stays unanswered and cannot save an empty record', () {
    final draft = CareActionInputViewModel(dayKey: '2026-11-08');
    expect(draft.cleaningChoice('cageCleaning'), isNull);
    expect(draft.minutes('roomWalk'), isNull);
    expect(draft.hasExplicitAnswer, isFalse);
    expect(draft.canSave, isFalse);
    expect(draft.canConfirmAndSave, isFalse);
    expect(() => draft.mutation(), throwsStateError);
  });

  test('one care answer saves only its explicit field without default facts',
      () {
    final cleaning = CareActionInputViewModel(dayKey: '2026-11-08')
      ..selectCleaning('cageCleaning', 'spot_removal');
    expect(cleaning.canSave, isTrue);
    expect(cleaning.minutes('roomWalk'), isNull);
    expect(cleaning.mutation().actions.keys, ['cageCleaning']);
    expect(cleaning.mutation().actions['cageCleaning']!.details,
        {'cleaningType': 'spot_removal'});
    final walk = CareActionInputViewModel(dayKey: '2026-11-08')
      ..selectMinutes('roomWalk', 20);
    expect(walk.canSave, isTrue);
    expect(walk.cleaningChoice('cageCleaning'), isNull);
    expect(walk.mutation().actions.keys, ['roomWalk']);
    expect(
        walk.mutation().actions['roomWalk']!.details, {'durationMinutes': 20});
  });

  test('explicit none and zero differ from an unanswered item', () {
    final draft = CareActionInputViewModel(dayKey: '2026-11-08')
      ..selectCleaning('cageCleaning', 'none')
      ..selectMinutes('roomWalk', 0);
    expect(draft.cleaningChoice('cageCleaning'), 'none');
    expect(draft.minutes('roomWalk'), 0);
    expect(draft.canSave, isTrue);
    expect(draft.mutation().actions.values.map((a) => a.answer),
        everyElement(CareActionAnswer.notPerformed));
    draft.select('cageCleaning', CareActionAnswer.unanswered);
    expect(draft.cleaningChoice('cageCleaning'), isNull);
    expect(draft.mutation().actions.keys, ['roomWalk']);
    draft.select('roomWalk', CareActionAnswer.unanswered);
    expect(draft.minutes('roomWalk'), isNull);
    expect(draft.canSave, isFalse);
    expect(() => draft.mutation(), throwsStateError);
    expect(draft.mutation(cancel: true).operation, 'cancel');
  });

  test('legacy queued care payload is replayed without sparse conversion', () {
    final wire = {
      'dayKey': '2026-11-08',
      'expectedRevision': 1,
      'mutationId': 'synthetic-legacy-care',
      'operation': 'save',
      'actions': {
        'cageCleaning': {'answer': 'unanswered'},
        'roomWalk': {
          'answer': 'performed',
          'details': {'durationMinutes': 10},
        },
      },
      'inputUiVersion': 'care_actions_input_v1',
      'inputRoute': 'daily_checkin',
    };
    final draft = CareActionInputViewModel(dayKey: '2026-11-08')
      ..load(CareActionLoadResult(pending: CareActionMutation.fromMap(wire)));
    expect(draft.mutation().toMap(), wire);
    expect(draft.cleaningChoice('cageCleaning'), isNull);
    expect(draft.minutes('roomWalk'), 10);
    expect(draft.canSave, isFalse);
  });
}

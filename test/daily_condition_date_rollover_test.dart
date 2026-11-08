// No device-clock changes or production writes: actual input card with an
// injected clock and day-keyed synthetic stores.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/care_continuity.dart';
import 'package:hamster_project/models/daily_care_actions.dart';
import 'package:hamster_project/models/daily_observation_history.dart';
import 'package:hamster_project/services/daily_checkin_repo.dart';
import 'package:hamster_project/viewmodels/care_continuity_view_model.dart';
import 'package:hamster_project/widgets/care_continuity_panel.dart';
import 'package:hamster_project/widgets/daily_condition_input_card.dart';

import 'care_action_test_support.dart';
import 'care_continuity_test_support.dart' show continuityFixture;

class _NoRolloverNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('No external HTTP in date rollover tests');
}

class _Clock {
  DateTime value = DateTime(2026, 11, 8, 23, 59);
  DateTime now() => value;
  void crossMidnight() => value = DateTime(2026, 11, 9, 0, 1);
}

class _HealthStore implements DailyCheckinStore, DailyObservationStore {
  final records = <String, DailyCheckin>{};
  final submitted = <ObservationMutation>[];
  final loads = <String>[];
  final pending = <String, ObservationMutation>{};
  bool confirmedLoad = true;
  Completer<ObservationLoadResult>? nextDayLoad;
  @override
  String dateKeyLocal(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  @override
  DateTime normalizeLocalDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);
  @override
  Future<DailyCheckin?> fetchByDate(DateTime date) async =>
      records[dateKeyLocal(date)];
  @override
  Stream<DailyCheckin?> watchByDate(DateTime date) =>
      Stream.value(records[dateKeyLocal(date)]);
  @override
  Future<ObservationLoadResult> loadObservation(DateTime date) async {
    final key = dateKeyLocal(date);
    loads.add(key);
    if (key == '2026-11-09' && nextDayLoad != null) {
      return nextDayLoad!.future;
    }
    return ObservationLoadResult(
        current: records[key],
        pending: pending[key],
        revision: records[key]?.revision ?? 0,
        hasProfile: true,
        subjectId: 'synthetic-rollover-pet',
        serverConfirmed: confirmedLoad);
  }

  @override
  Future<ObservationSaveResult> saveObservation(
      ObservationMutation mutation) async {
    submitted.add(mutation);
    final projection = <String, dynamic>{
      'dayKey': mutation.dayKey,
      'date': mutation.date,
      'condition': mutation.condition,
      'concernTags': mutation.concernTags,
      'memo': mutation.memo,
      'timing': mutation.timing.toMap(),
      'revision': mutation.expectedRevision + 1,
      'eventRevision': 1,
      'eventId': 'synthetic-rollover-event',
      'subjectId': 'synthetic-rollover-pet',
    };
    records[mutation.dayKey] =
        DailyCheckin.fromJson(projection, fallbackDayKey: mutation.dayKey);
    return ObservationSaveResult(
        confirmed: true,
        mutation: mutation,
        revision: mutation.expectedRevision + 1,
        subjectId: 'synthetic-rollover-pet',
        eventId: 'synthetic-rollover-event',
        projection: projection,
        changed: true);
  }

  @override
  Future<void> saveDailyCheckin({
    required DateTime date,
    required DailyCondition condition,
    required List<String> concernTags,
    required Map<String, DailyObservationLevel> observationLevels,
    String memo = '',
  }) async =>
      throw StateError('History acceptance path required');
}

class _CareStore extends CareTestStore {
  final byDay = <String, CareActionLoadResult>{};
  @override
  Future<CareActionLoadResult> load(String dayKey) async =>
      byDay[dayKey] ?? const CareActionLoadResult();
}

Future<void> _show(
    WidgetTester tester, _Clock clock, _HealthStore health, _CareStore care,
    {DateTime? date}) async {
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: SingleChildScrollView(
              child: DailyConditionInputCard(
                  repo: health, careRepo: care, now: clock.now, date: date)))));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async =>
    _tap(tester, find.text('この内容で記録'));

String _targetDate(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('daily-condition-target-date')))
    .data!;

DailyCheckin _existing(String key) => DailyCheckin(
      dayKey: key,
      date: DateTime.parse(key),
      condition: DailyCondition.normal,
      concernTags: const [],
      memo: 'existing synthetic answer',
      subjectId: 'synthetic-rollover-pet',
      eventId: 'existing-event',
      revision: 3,
      timing: ObservationTiming.dateOnly(key),
    );

void main() {
  HttpOverrides? previous;
  setUpAll(() {
    previous = HttpOverrides.current;
    HttpOverrides.global = _NoRolloverNetwork();
  });
  tearDownAll(() => HttpOverrides.global = previous);

  testWidgets('same-day draft saves normally with the visible target day',
      (tester) async {
    final clock = _Clock(), health = _HealthStore(), care = _CareStore();
    await _show(tester, clock, health, care);
    expect(_targetDate(tester), '記録日：2026年11月8日');
    await _tap(tester, find.text('いつも通り'));
    await _save(tester);
    expect(health.submitted.single.dayKey, '2026-11-08');
    expect(find.byType(AlertDialog), findsNothing);
    expect(care.saved, isEmpty);
  });

  testWidgets('midnight blocks save; cancel preserves date and complete draft',
      (tester) async {
    final clock = _Clock(), health = _HealthStore(), care = _CareStore();
    await _show(tester, clock, health, care);
    await _tap(tester, find.text('少し違う'));
    await _tap(tester, find.text('食欲'));
    await _tap(tester, find.text('メモ（任意）'));
    await tester.enterText(find.byType(TextField).first, 'synthetic draft');
    clock.crossMidnight();
    await _save(tester);
    expect(find.text('日付が変わりました'), findsOneWidget);
    expect(health.submitted, isEmpty);
    expect(care.saved, isEmpty);
    await _tap(tester, find.text('キャンセル'));
    expect(_targetDate(tester), '記録日：2026年11月8日');
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'synthetic draft');
    expect(health.submitted, isEmpty);
    // A second press still asks; cancelling never silently changes the target.
    await _save(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await _tap(tester, find.text('キャンセル'));
  });

  testWidgets(
      'approval retains health and care draft; next explicit save uses today',
      (tester) async {
    final clock = _Clock(), health = _HealthStore(), care = _CareStore();
    await _show(tester, clock, health, care);
    await _tap(tester, find.text('少し違う'));
    await _tap(tester, find.text('食欲'));
    await _tap(tester, find.text('メモ（任意）'));
    await tester.enterText(find.byType(TextField).first, 'synthetic draft');
    await _tap(tester, find.byKey(const ValueKey('care-cageCleaning-none')));
    clock.crossMidnight();
    await _save(tester);
    await _tap(tester, find.text('今日へ切り替える'));
    expect(_targetDate(tester), '記録日：2026年11月9日');
    expect(health.submitted, isEmpty, reason: 'date approval is not a save');
    expect(care.saved, isEmpty);
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'synthetic draft');
    await _save(tester);
    final mutation = health.submitted.single;
    expect(mutation.dayKey, '2026-11-09');
    expect(mutation.date, DateTime(2026, 11, 9));
    expect(mutation.condition, 'slightlyConcerned');
    expect(mutation.concernTags, ['appetite']);
    expect(mutation.memo, 'synthetic draft');
    expect(mutation.timing.precision, ObservationTimePrecision.unknown);
    expect(mutation.expectedRevision, 0);
    expect(care.saved.single.dayKey, '2026-11-09');
    expect(care.saved.single.actions['cageCleaning']!.answer,
        CareActionAnswer.notPerformed);
    expect(care.saved.single.actions.containsKey('roomWalk'), false);
    expect(health.records.containsKey('2026-11-08'), false);
    expect((await health.watchByDate(DateTime(2026, 11, 9)).first)!.dayKey,
        '2026-11-09');
    expect(await health.watchByDate(DateTime(2026, 11, 8)).first, isNull);

    // Existing calendar component uses server-accepted days, not guessed input
    // dates. A synthetic accepted-day response for this save marks only 11/9.
    final cells = CareContinuityViewModel(
            continuityFixture(serverDateKey: mutation.dayKey))
        .monthCells([
      CareContinuityDay(
          dayKey: mutation.dayKey,
          sourceDateKey: mutation.dayKey,
          achieved: true)
    ]);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CareAchievementCalendar(cells: cells))));
    await tester.pumpAndSettle();
    expect(cells.singleWhere((cell) => cell.achieved).dayKey, '2026-11-09');
    expect(find.byKey(const ValueKey('care-achievement-band-2026-11-09')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('care-achievement-band-2026-11-08')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'care-only draft also waits for rollover approval and explicit save',
      (tester) async {
    final clock = _Clock(), health = _HealthStore(), care = _CareStore();
    await _show(tester, clock, health, care);
    await _tap(tester, find.byKey(const ValueKey('care-cageCleaning-none')));
    clock.crossMidnight();
    await _save(tester);
    await _tap(tester, find.text('今日へ切り替える'));
    expect(care.saved, isEmpty);
    await _save(tester);
    expect(health.submitted, isEmpty);
    expect(care.saved.single.dayKey, '2026-11-09');
  });

  testWidgets('explicit past-day new entry stays on its selected date',
      (tester) async {
    final clock = _Clock(), health = _HealthStore(), care = _CareStore();
    await _show(tester, clock, health, care, date: DateTime(2026, 11, 7));
    await _tap(tester, find.text('いつも通り'));
    clock.crossMidnight();
    await _save(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(health.submitted.single.dayKey, '2026-11-07');
    expect(_targetDate(tester), '記録日：2026年11月7日');
  });

  testWidgets('existing record correction is not moved across midnight',
      (tester) async {
    final clock = _Clock(), health = _HealthStore(), care = _CareStore();
    health.records['2026-11-08'] = _existing('2026-11-08');
    await _show(tester, clock, health, care);
    await _tap(tester, find.text('編集'));
    await _tap(tester, find.text('少し違う'));
    await _tap(
        tester, find.byKey(const ValueKey('observation-intent-correction')));
    clock.crossMidnight();
    await _save(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(health.submitted.single.dayKey, '2026-11-08');
    expect(health.submitted.single.operation, ObservationOperation.correction);
    expect(health.submitted.single.targetEventId, 'existing-event');
    expect(health.submitted.single.timing.toMap(),
        const ObservationTiming.dateOnly('2026-11-08').toMap());
  });

  testWidgets('new-day existing answer is not overwritten by a date switch',
      (tester) async {
    final clock = _Clock(), health = _HealthStore(), care = _CareStore();
    health.records['2026-11-09'] = _existing('2026-11-09');
    await _show(tester, clock, health, care);
    await _tap(tester, find.text('心配'));
    clock.crossMidnight();
    await _save(tester);
    await _tap(tester, find.text('今日へ切り替える'));
    expect(_targetDate(tester), '記録日：2026年11月8日');
    expect(find.textContaining('今日の記録または同期待ちの記録が既にあります'), findsOneWidget);
    expect(health.submitted, isEmpty);
    expect(health.records['2026-11-09']!.memo, 'existing synthetic answer');
  });

  testWidgets('new-day pending care is not retargeted or overwritten',
      (tester) async {
    final clock = _Clock(), health = _HealthStore(), care = _CareStore();
    care.byDay['2026-11-09'] = CareActionLoadResult(
        pending: const CareActionMutation(
            dayKey: '2026-11-09',
            expectedRevision: 0,
            mutationId: 'existing-pending',
            operation: 'save',
            actions: {}));
    await _show(tester, clock, health, care);
    await _tap(tester, find.text('いつも通り'));
    clock.crossMidnight();
    await _save(tester);
    await _tap(tester, find.text('今日へ切り替える'));
    expect(_targetDate(tester), '記録日：2026年11月8日');
    expect(health.submitted, isEmpty);
    expect(care.saved, isEmpty);
    expect(care.byDay['2026-11-09']!.pending!.mutationId, 'existing-pending');
  });

  testWidgets('unconfirmed target-day read preserves original draft and date',
      (tester) async {
    final clock = _Clock(), health = _HealthStore(), care = _CareStore();
    await _show(tester, clock, health, care);
    await _tap(tester, find.text('少し違う'));
    health.confirmedLoad = false;
    clock.crossMidnight();
    await _save(tester);
    await _tap(tester, find.text('今日へ切り替える'));
    expect(_targetDate(tester), '記録日：2026年11月8日');
    expect(find.textContaining('今日の保存先を確認できません'), findsOneWidget);
    expect(health.submitted, isEmpty);
    health.confirmedLoad = true;
    await _save(tester);
    await _tap(tester, find.text('今日へ切り替える'));
    await _save(tester);
    expect(health.submitted.single.condition, 'slightlyConcerned');
    expect(health.submitted.single.dayKey, '2026-11-09');
  });

  testWidgets('date can cross again after approval without silently saving',
      (tester) async {
    final clock = _Clock(), health = _HealthStore(), care = _CareStore();
    await _show(tester, clock, health, care);
    await _tap(tester, find.text('いつも通り'));
    clock.crossMidnight();
    await _save(tester);
    await _tap(tester, find.text('今日へ切り替える'));
    clock.value = DateTime(2026, 11, 10, 0, 1);
    await _save(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(health.submitted, isEmpty);
    await _tap(tester, find.text('今日へ切り替える'));
    expect(_targetDate(tester), '記録日：2026年11月10日');
    await _save(tester);
    expect(health.submitted.single.dayKey, '2026-11-10');
  });
  testWidgets(
      'pending retry after midnight keeps its original day and mutation',
      (tester) async {
    final clock = _Clock(), health = _HealthStore(), care = _CareStore();
    final mutation = ObservationMutation(
        mutationId: 'synthetic-existing-pending',
        dayKey: '2026-11-08',
        date: DateTime(2026, 11, 8),
        expectedRevision: 0,
        subjectId: 'synthetic-rollover-pet',
        operation: ObservationOperation.newObservation,
        timing: const ObservationTiming.unknown(),
        condition: 'normal',
        concernTags: const [],
        catalogVersion: 'synthetic-catalog');
    health.pending[mutation.dayKey] = mutation;
    await _show(tester, clock, health, care);
    clock.crossMidnight();
    await _tap(tester, find.text('今日の様子を再送する'));
    expect(find.byType(AlertDialog), findsNothing);
    expect(health.submitted.single.toMap(), mutation.toMap());
    expect(health.submitted.single.dayKey, '2026-11-08');
    expect(_targetDate(tester), '記録日：2026年11月8日');
  });
  testWidgets('existing care does not bypass rollover for a new health answer',
      (tester) async {
    final clock = _Clock(), health = _HealthStore(), care = _CareStore();
    final original = CareActionLoadResult(
        record:
            DailyCareActions(dayKey: '2026-11-08', revision: 2, actions: const {
      'cageCleaning': CareActionResponse(answer: CareActionAnswer.notPerformed)
    }));
    care.byDay['2026-11-08'] = original;
    await _show(tester, clock, health, care);
    await _tap(tester, find.text('編集'));
    await _tap(tester, find.text('少し違う'));
    clock.crossMidnight();
    await _save(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(health.submitted, isEmpty);
    await _tap(tester, find.text('今日へ切り替える'));
    expect(_targetDate(tester), '記録日：2026年11月9日');
    expect(care.saved, isEmpty);
    await _save(tester);
    expect(health.submitted.single.dayKey, '2026-11-09');
    expect(care.saved, isEmpty,
        reason: 'old saved care is not copied to today');
    expect(care.byDay['2026-11-08'], same(original));
  });

  testWidgets('new observation on an existing day moves only after approval',
      (tester) async {
    final clock = _Clock(), health = _HealthStore(), care = _CareStore();
    final previous = _existing('2026-11-08');
    health.records['2026-11-08'] = previous;
    await _show(tester, clock, health, care);
    await _tap(tester, find.text('編集'));
    await _tap(tester, find.byKey(const ValueKey('observation-intent-new')));
    await _tap(tester, find.text('少し違う'));
    clock.crossMidnight();
    await _save(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await _tap(tester, find.text('今日へ切り替える'));
    expect(health.submitted, isEmpty);
    await _save(tester);
    final mutation = health.submitted.single;
    expect(mutation.dayKey, '2026-11-09');
    expect(mutation.operation, ObservationOperation.newObservation);
    expect(mutation.targetEventId, isNull);
    expect(mutation.expectedRevision, 0);
    expect(health.records['2026-11-08'], same(previous));
  });

  testWidgets('pending confirmation followed by correction keeps original day',
      (tester) async {
    final clock = _Clock(), health = _HealthStore(), care = _CareStore();
    final mutation = ObservationMutation(
        mutationId: 'synthetic-pending-before-correction',
        dayKey: '2026-11-08',
        date: DateTime(2026, 11, 8),
        expectedRevision: 0,
        subjectId: 'synthetic-rollover-pet',
        operation: ObservationOperation.newObservation,
        timing: const ObservationTiming.dateOnly('2026-11-08'),
        condition: 'normal',
        concernTags: const [],
        catalogVersion: 'synthetic-catalog');
    health.pending[mutation.dayKey] = mutation;
    await _show(tester, clock, health, care);
    await _tap(tester, find.text('今日の様子を再送する'));
    await _tap(tester, find.text('編集'));
    await _tap(tester, find.text('少し違う'));
    await _tap(
        tester, find.byKey(const ValueKey('observation-intent-correction')));
    clock.crossMidnight();
    await _save(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(health.submitted.last.operation, ObservationOperation.correction);
    expect(health.submitted.last.dayKey, '2026-11-08');
    expect(health.submitted.last.timing.toMap(), mutation.timing.toMap());
    expect(_targetDate(tester), '記録日：2026年11月8日');
  });

  testWidgets('mixed existing correction and new care cannot silently move',
      (tester) async {
    final clock = _Clock(), health = _HealthStore(), care = _CareStore();
    health.records['2026-11-08'] = _existing('2026-11-08');
    await _show(tester, clock, health, care);
    await _tap(tester, find.text('編集'));
    await _tap(tester, find.text('少し違う'));
    await _tap(
        tester, find.byKey(const ValueKey('observation-intent-correction')));
    await _tap(tester, find.byKey(const ValueKey('care-cageCleaning-none')));
    clock.crossMidnight();
    await _save(tester);
    await _tap(tester, find.text('今日へ切り替える'));
    expect(find.textContaining('保存済み記録の編集または同期待ちの記録が含まれています'), findsOneWidget);
    expect(_targetDate(tester), '記録日：2026年11月8日');
    expect(health.submitted, isEmpty);
    expect(care.saved, isEmpty);
  });
  testWidgets(
      'date switch read blocks edits until the preserved draft is ready',
      (tester) async {
    final clock = _Clock(), health = _HealthStore(), care = _CareStore();
    await _show(tester, clock, health, care);
    await _tap(tester, find.byKey(const ValueKey('care-cageCleaning-none')));
    health.nextDayLoad = Completer<ObservationLoadResult>();
    clock.crossMidnight();
    await _save(tester);
    await _tap(tester, find.text('今日へ切り替える'));
    expect(
        tester
            .widget<AbsorbPointer>(
                find.byKey(const ValueKey('daily-condition-date-check-block')))
            .absorbing,
        true);
    await tester.ensureVisible(find.text('メモ（任意）'));
    await tester.tap(find.text('メモ（任意）'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing,
        reason:
            'the date-switch read must not accept edits it could overwrite');
    health.nextDayLoad!.complete(const ObservationLoadResult(
        hasProfile: true, subjectId: 'synthetic-rollover-pet'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<AbsorbPointer>(
                find.byKey(const ValueKey('daily-condition-date-check-block')))
            .absorbing,
        false);
    expect(_targetDate(tester), '記録日：2026年11月9日');
    expect(health.submitted, isEmpty);
    expect(care.saved, isEmpty);
    await _save(tester);
    expect(care.saved.single.dayKey, '2026-11-09');
    expect(health.submitted, isEmpty);
  });
}

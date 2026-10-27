import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/daily_observation_history.dart';
import 'package:hamster_project/services/daily_checkin_repo.dart';
import 'package:hamster_project/viewmodels/observation_input_view_model.dart';
import 'package:hamster_project/widgets/observation_timing_input.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'care_action_test_support.dart';

class ObservationUiStore extends CareHealthTestStore
    implements DailyObservationStore {
  final mutations = <ObservationMutation>[];
  bool offline = false, confirmedLoad = true;
  int revision = 0;
  ObservationMutation? pending;
  ObservationSaveResult? nextReply;
  DailyCheckin? afterReply;
  @override
  Future<ObservationLoadResult> loadObservation(DateTime date) async =>
      ObservationLoadResult(
          current: initial,
          pending: pending,
          revision: revision,
          hasProfile: true,
          subjectId: 'subject_one',
          serverConfirmed: confirmedLoad);
  @override
  Future<ObservationSaveResult> saveObservation(
      ObservationMutation mutation) async {
    mutations.add(mutation);
    if (nextReply != null) {
      final reply = nextReply!;
      nextReply = null;
      pending = null;
      initial = afterReply;
      return reply;
    }
    if (offline) {
      pending = mutation;
      return ObservationSaveResult(confirmed: false, mutation: mutation);
    }
    pending = null;
    revision++;
    final cancel = mutation.operation == ObservationOperation.cancel;
    final projection = cancel
        ? null
        : {
            'dayKey': dateKeyLocal(mutation.date),
            'date': mutation.date.toUtc().toIso8601String(),
            'condition': mutation.condition,
            'concernTags': mutation.concernTags,
            'memo': mutation.memo,
            'subjectId': 'subject_one',
            'revision': revision,
            'eventRevision': revision,
            'eventId': mutation.targetEventId ?? 'new_event',
            'timing': mutation.timing.toMap(),
          };
    initial = projection == null
        ? null
        : DailyCheckin.fromJson(projection,
            fallbackDayKey: dateKeyLocal(mutation.date));
    return ObservationSaveResult(
        confirmed: true,
        mutation: mutation,
        revision: revision,
        eventId: initial?.eventId,
        subjectId: 'subject_one',
        acceptedAt: DateTime.utc(2026, 10, 12, 4),
        changed: true,
        projection: projection);
  }
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'opening confirms nothing; care-only save creates no health answer',
      (tester) async {
    final health = ObservationUiStore(), care = CareTestStore();
    await tester.pumpWidget(careInputTestApp(health, care));
    await tester.pumpAndSettle();
    expect(health.mutations, isEmpty);
    expect(find.text('観察したタイミング'), findsNothing);
    await tapVisible(tester, find.text('この内容で記録'));
    expect(health.mutations, isEmpty);
    expect(care.saved.length, 1);
  });
  testWidgets(
      'health needs explicit timing; date-only answer keeps current schema2 rendering',
      (tester) async {
    final health = ObservationUiStore(), care = CareTestStore();
    var callback = 0;
    await tester
        .pumpWidget(careInputTestApp(health, care, onHealth: () => callback++));
    await tester.pumpAndSettle();
    await tester.tap(find.text('いつも通り'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('health-only-save')))
            .onPressed,
        isNull);
    await tapVisible(
        tester, find.byKey(const ValueKey('observation-time-date')));
    await tapVisible(tester, find.text('様子だけ記録'));
    expect(health.mutations.length, 1);
    expect(health.saves, 0, reason: 'no old direct write path');
    expect(health.mutations.single.timing.precision,
        ObservationTimePrecision.dateOnly);
    expect(
        health.mutations.single.operation, ObservationOperation.newObservation);
    expect(callback, 1);
    expect(care.saved, isEmpty);
    expect(find.text('記録しました'), findsOneWidget);
  });
  testWidgets(
      'answer change does not infer intent; corrections and explicit new observation stay separate',
      (tester) async {
    final health = ObservationUiStore()
      ..revision = 3
      ..initial = DailyCheckin(
          dayKey: '2026-10-12',
          date: DateTime(2026, 10, 12),
          condition: DailyCondition.normal,
          concernTags: const [],
          memo: '',
          subjectId: 'subject_one',
          eventId: 'event_one',
          revision: 3,
          timing: const ObservationTiming.dateOnly('2026-10-12'));
    final care = CareTestStore();
    await tester.pumpWidget(careInputTestApp(health, care));
    await tester.pumpAndSettle();
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('少し違う'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('食欲'));
    expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('health-only-save')))
            .onPressed,
        isNull);
    await tapVisible(
        tester, find.byKey(const ValueKey('observation-intent-correction')));
    await tapVisible(tester, find.text('様子だけ記録'));
    expect(health.mutations.single.operation, ObservationOperation.correction);
    expect(health.mutations.single.targetEventId, 'event_one');
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
    await tapVisible(
        tester, find.byKey(const ValueKey('observation-intent-new')));
    await tapVisible(
        tester, find.byKey(const ValueKey('observation-time-unknown')));
    await tapVisible(tester, find.text('様子だけ記録'));
    expect(
        health.mutations.last.operation, ObservationOperation.newObservation);
    expect(health.mutations.last.targetEventId, isNull);
  });
  testWidgets(
      'pending answer never reports saved or invokes progress; retry retains same mutation',
      (tester) async {
    final health = ObservationUiStore()..offline = true, care = CareTestStore();
    var callback = 0;
    await tester
        .pumpWidget(careInputTestApp(health, care, onHealth: () => callback++));
    await tester.pumpAndSettle();
    await tester.tap(find.text('いつも通り'));
    await tester.pumpAndSettle();
    await tapVisible(
        tester, find.byKey(const ValueKey('observation-time-unknown')));
    await tapVisible(tester, find.text('様子だけ記録'));
    expect(callback, 0);
    expect(find.textContaining('まだ保存確定'), findsOneWidget);
    final mutation = health.mutations.single.mutationId;
    health.offline = false;
    await tapVisible(tester, find.text('今日の様子を再送する'));
    expect(health.mutations.last.mutationId, mutation);
    expect(callback, 1);
  });
  testWidgets(
      'cancel health does not cancel care; server-unconfirmed loading blocks health',
      (tester) async {
    final health = ObservationUiStore()
      ..revision = 1
      ..initial = DailyCheckin(
          dayKey: '2026-10-12',
          date: DateTime(2026, 10, 12),
          condition: DailyCondition.normal,
          concernTags: const [],
          memo: '',
          subjectId: 'subject_one',
          eventId: 'event_one',
          revision: 1);
    final care = CareTestStore();
    await tester.pumpWidget(careInputTestApp(health, care));
    await tester.pumpAndSettle();
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('今日の様子を取り消す'));
    expect(health.mutations.single.operation, ObservationOperation.cancel);
    expect(care.saved, isEmpty);
    expect(find.text('今日の様子を取り消しました。'), findsOneWidget);
  });
  testWidgets(
      'restart pending draft is visible; replay acknowledgement reloads later cancellation',
      (tester) async {
    final health = ObservationUiStore(), care = CareTestStore();
    final mutation = ObservationMutation(
        mutationId: 'pending',
        dayKey: '2026-10-12',
        date: DateTime(2026, 10, 12),
        expectedRevision: 0,
        subjectId: 'subject_one',
        operation: ObservationOperation.newObservation,
        timing: const ObservationTiming.dateOnly('2026-10-12'),
        condition: 'slightlyConcerned',
        concernTags: const ['appetite'],
        memo: '保留中のメモ',
        catalogVersion: 'observation_catalog_v1');
    health.pending = mutation;
    health.nextReply = ObservationSaveResult(
        confirmed: true,
        mutation: mutation,
        replayed: true,
        revision: 1,
        subjectId: 'subject_one',
        acceptedAt: DateTime.utc(2026, 10, 12, 4),
        projection: {
          'dayKey': '2026-10-12',
          'condition': 'slightlyConcerned',
          'concernTags': ['appetite'],
          'memo': '古い受理済み内容',
          'revision': 1,
          'eventRevision': 1,
          'eventId': 'event-one',
          'subjectId': 'subject_one'
        });
    health.afterReply = null;
    health.revision = 2;
    await tester.pumpWidget(careInputTestApp(health, care));
    await tester.pumpAndSettle();
    expect(find.textContaining('まだ保存確定'), findsOneWidget);
    expect(find.text('今日の様子を再送する'), findsOneWidget);
    await tapVisible(tester, find.text('今日の様子を再送する'));
    expect(find.text('記録しました'), findsNothing);
    expect(find.text('編集'), findsNothing);
    expect(find.text('気になるところ'), findsNothing);
  });
  testWidgets(
      'cancellation fallback restores tags/memo and target event revision',
      (tester) async {
    final health = ObservationUiStore()
      ..revision = 3
      ..initial = DailyCheckin(
          dayKey: '2026-10-12',
          date: DateTime(2026, 10, 12),
          condition: DailyCondition.normal,
          concernTags: const [],
          memo: '',
          subjectId: 'subject_one',
          eventId: 'new-event',
          revision: 3,
          eventRevision: 3);
    final previous = {
      'dayKey': '2026-10-12',
      'date': '2026-10-12T00:00:00Z',
      'condition': 'slightlyConcerned',
      'concernTags': ['water'],
      'memo': '前の観察メモ',
      'subjectId': 'subject_one',
      'eventId': 'old-event',
      'revision': 4,
      'eventRevision': 1,
      'timing': {
        'timePrecision': 'date_only',
        'dateKey': '2026-10-12',
        'confirmation': 'date_confirmed'
      }
    };
    final placeholder = ObservationMutation(
        mutationId: 'cancel',
        dayKey: '2026-10-12',
        date: DateTime(2026, 10, 12),
        expectedRevision: 3,
        subjectId: 'subject_one',
        operation: ObservationOperation.cancel,
        timing: const ObservationTiming.unknown(),
        catalogVersion: '');
    health.nextReply = ObservationSaveResult(
        confirmed: true,
        mutation: placeholder,
        revision: 4,
        subjectId: 'subject_one',
        acceptedAt: DateTime.utc(2026, 10, 12, 5),
        projection: previous);
    health.afterReply =
        DailyCheckin.fromJson(previous, fallbackDayKey: '2026-10-12');
    final care = CareTestStore();
    await tester.pumpWidget(careInputTestApp(health, care));
    await tester.pumpAndSettle();
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('今日の様子を取り消す'));
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '前の観察メモ');
    await tapVisible(
        tester, find.byKey(const ValueKey('observation-intent-correction')));
    await tester.enterText(find.byType(TextField), '訂正したメモ');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('様子だけ記録'));
    expect(health.mutations.last.concernTags, ['water']);
    expect(health.mutations.last.targetEventId, 'old-event');
    expect(health.mutations.last.expectedRevision, 4);
    expect(health.mutations.last.targetRevision, 1);
  });
  for (final dark in [false, true]) {
    testWidgets(
        'timing selected contrast and confirmed date semantics in ${dark ? "dark" : "light"}',
        (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final model = ObservationInputViewModel(
            date: DateTime(2026, 10, 12), dayKey: '2026-10-12')
          ..load(const ObservationLoadResult(hasProfile: true))
          ..confirmDate();
        await tester.pumpWidget(MaterialApp(
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            home: Scaffold(
                body: ObservationTimingInput(
                    model: model,
                    onChanged: () {},
                    now: () => DateTime(2026, 10, 13)))));
        final chip = tester.widget<ChoiceChip>(
            find.byKey(const ValueKey('observation-time-date')));
        final bg = chip.selectedColor!, fg = chip.labelStyle!.color!;
        final high = bg.computeLuminance() > fg.computeLuminance()
            ? bg.computeLuminance()
            : fg.computeLuminance();
        final low = bg.computeLuminance() < fg.computeLuminance()
            ? bg.computeLuminance()
            : fg.computeLuminance();
        expect((high + 0.05) / (low + 0.05), greaterThanOrEqualTo(4.5));
        expect(chip.checkmarkColor, fg);
        expect(find.text('10/12 · 日付のみ'), findsOneWidget);
        expect(find.bySemanticsLabel('2026年10月12日の観察、時刻は未確認'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });
  }
}

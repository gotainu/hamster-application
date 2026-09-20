import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/services/daily_checkin_repo.dart';
import 'package:hamster_project/widgets/daily_condition_input_card.dart';

void main() {
  test('normal observation levels cover all standard items', () {
    final levels = buildDailyObservationLevels(
      condition: DailyCondition.normal,
      concernTags: const [],
    );

    expect(levels.keys, containsAll(dailyObservationIds));
    expect(
      levels.values,
      everyElement(DailyObservationLevel.normal),
    );
  });

  test('concern tags become structured observation levels', () {
    final levels = buildDailyObservationLevels(
      condition: DailyCondition.slightlyConcerned,
      concernTags: const ['appetite', 'breathing'],
    );

    expect(levels['appetite'], DailyObservationLevel.changed);
    expect(levels['breathing'], DailyObservationLevel.changed);
    expect(levels['movement'], DailyObservationLevel.normal);
  });

  testWidgets('normal path can be completed with one choice and one action',
      (tester) async {
    final store = _FakeDailyCheckinStore();
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();

    expect(find.text('今日の様子は？'), findsOneWidget);
    expect(find.textContaining('正解はありません'), findsNothing);
    expect(find.text('いつもと比べる'), findsNothing);
    expect(find.text('特に気になる変化はない'), findsNothing);
    await tester.tap(find.text('いつも通り'));
    await tester.pumpAndSettle();

    expect(find.text('記録する'), findsOneWidget);
    await tester.tap(find.text('記録する'));
    await tester.pumpAndSettle();

    expect(store.saved?.condition, DailyCondition.normal);
    expect(
      store.saved?.observationLevels.values,
      everyElement(DailyObservationLevel.normal),
    );
    expect(find.text('記録しました'), findsOneWidget);
  });

  testWidgets('concern path requires a location and stores its severity',
      (tester) async {
    final store = _FakeDailyCheckinStore();
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('少し違う'));
    await tester.pumpAndSettle();

    expect(find.text('気になるところ'), findsOneWidget);
    final buttonFinder = find.byWidgetPredicate(
      (widget) => widget is FilledButton,
    );
    expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNull);

    await tester.ensureVisible(find.text('呼吸'));
    await tester.tap(find.text('呼吸'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('動物病院へ'));
    expect(find.textContaining('動物病院へ'), findsOneWidget);

    await tester.ensureVisible(find.text('記録する'));
    await tester.tap(find.text('記録する'));
    await tester.pumpAndSettle();

    expect(store.saved?.condition, DailyCondition.slightlyConcerned);
    expect(store.saved?.concernTags, ['breathing']);
    expect(
      store.saved?.observationLevels['breathing'],
      DailyObservationLevel.changed,
    );
  });
}

Widget _testApp(DailyCheckinStore store) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: DailyConditionInputCard(
          repo: store,
          date: DateTime(2026, 9, 14),
        ),
      ),
    ),
  );
}

class _FakeDailyCheckinStore implements DailyCheckinStore {
  DailyCheckin? saved;

  @override
  String dateKeyLocal(DateTime dayLocal) => '2026-09-14';

  @override
  DateTime normalizeLocalDay(DateTime dt) => DateTime(2026, 9, 14);

  @override
  Future<DailyCheckin?> fetchByDate(DateTime dayLocal) async => null;

  @override
  Stream<DailyCheckin?> watchByDate(DateTime dayLocal) =>
      const Stream<DailyCheckin?>.empty();

  @override
  Future<void> saveDailyCheckin({
    required DateTime date,
    required DailyCondition condition,
    required List<String> concernTags,
    required Map<String, DailyObservationLevel> observationLevels,
    String memo = '',
  }) async {
    saved = DailyCheckin(
      dayKey: dateKeyLocal(date),
      date: normalizeLocalDay(date),
      condition: condition,
      concernTags: concernTags,
      observationLevels: observationLevels,
      memo: memo,
    );
  }
}

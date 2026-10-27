import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/services/daily_checkin_repo.dart';
import 'package:hamster_project/models/observation_catalog.dart';
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

  testWidgets('all eight current catalog choices are displayed and saved',
      (tester) async {
    final store = _FakeDailyCheckinStore();
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();
    expect(store.saved, isNull,
        reason: 'opening the form never auto-saves defaults');
    await tester.tap(find.text('少し違う'));
    await tester.pumpAndSettle();
    for (final item in activeObservationItems()) {
      expect(find.text(item.label), findsOneWidget);
      await tester.ensureVisible(find.text(item.label));
      await tester.tap(find.text(item.label));
      await tester.pumpAndSettle();
    }
    expect(find.text('かじり方'), findsNothing);
    await tester.ensureVisible(find.text('様子だけ記録'));
    await tester.tap(find.text('様子だけ記録'));
    await tester.pumpAndSettle();
    expect(store.saved?.concernTags,
        activeObservationItems().map((item) => item.id).toList());
    expect(store.saved?.observationLevels.values,
        everyElement(DailyObservationLevel.changed));
  });

  testWidgets('catalog addition, display order, rename and retirement reach UI',
      (tester) async {
    final items = [
      ...observationCatalog.where((item) => item.id != 'appetite'),
      const ObservationCatalogItem(
          id: 'appetite',
          label: '食欲の様子',
          order: 90,
          active: false,
          insightEligible: true,
          defaultNormal: true,
          aliases: [],
          legacyNames: ['食欲']),
      const ObservationCatalogItem(
          id: 'futureObservation',
          label: '追加項目',
          order: 0,
          active: true,
          insightEligible: true,
          defaultNormal: false,
          aliases: [],
          legacyNames: []),
    ];
    final store = _FakeDailyCheckinStore();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: DailyConditionInputCard(repo: store, catalog: items)))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('少し違う'));
    await tester.pumpAndSettle();
    expect(find.text('食欲'), findsNothing);
    expect(find.text('食欲の様子'), findsNothing);
    expect(find.text('追加項目'), findsOneWidget);
    expect(tester.getTopLeft(find.text('追加項目')).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.text('飲水')).dy));
    await tester.tap(find.text('追加項目'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('様子だけ記録'));
    await tester.tap(find.text('様子だけ記録'));
    await tester.pumpAndSettle();
    expect(store.saved?.concernTags, ['futureObservation']);
  });

  testWidgets('retired and alias observations remain readable in past records',
      (tester) async {
    final store = _FakeDailyCheckinStore(
        initial: DailyCheckin.fromJson({
      'condition': 'slightlyConcerned',
      'concernTags': ['poop', 'chewing'],
      'schemaVersion': 1,
    }, fallbackDayKey: '2026-09-14'));
    await tester.pumpWidget(_testApp(store));
    await tester.pumpAndSettle();
    expect(find.text('少し違う・排泄・かじり方'), findsOneWidget);
    expect(store.saved, isNull);
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
    expect(find.text('排泄'), findsOneWidget);
    expect(find.text('かじり方'), findsNothing);
    // Opening the editor alone must not resave an unchanged health record.
    // A real condition edit still preserves retired observations and aliases.
    await tester.tap(find.text('心配'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('様子だけ記録'));
    await tester.tap(find.text('様子だけ記録'));
    await tester.pumpAndSettle();
    expect(store.saved?.concernTags, ['elimination', 'chewing']);
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

    expect(find.text('様子だけ記録'), findsOneWidget);
    await tester.ensureVisible(find.text('様子だけ記録'));
    await tester.tap(find.text('様子だけ記録'));
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

    await tester.ensureVisible(find.text('様子だけ記録'));
    await tester.tap(find.text('様子だけ記録'));
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
  _FakeDailyCheckinStore({this.initial});

  final DailyCheckin? initial;
  DailyCheckin? saved;

  @override
  String dateKeyLocal(DateTime dayLocal) => '2026-09-14';

  @override
  DateTime normalizeLocalDay(DateTime dt) => DateTime(2026, 9, 14);

  @override
  Future<DailyCheckin?> fetchByDate(DateTime dayLocal) async => initial;

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

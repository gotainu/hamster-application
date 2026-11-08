// Actual observation UI with synthetic in-memory stores. No Firebase, HTTP,
// account, AI request, notification, billing or existing record is touched.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/daily_care_actions.dart';
import 'package:hamster_project/models/daily_observation_history.dart';
import 'package:hamster_project/services/daily_checkin_repo.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/widgets/daily_condition_input_card.dart';

import 'care_action_test_support.dart' show CareTestStore;

const _day = '2026-10-12';
const _subject = 'synthetic-partial-observation-pet';
const _captureKey = ValueKey('partial-observation-local-preview');
const _font = 'HamCarePartialObservationJapanese';

class _NoObservationNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('No external HTTP in partial observation UI tests');
}

class _PartialObservationStore
    implements DailyCheckinStore, DailyObservationStore {
  DailyCheckin? current;
  ObservationMutation? pending;
  bool offline = false;
  int revision = 0;
  final submitted = <ObservationMutation>[];

  @override
  String dateKeyLocal(DateTime dayLocal) => _day;
  @override
  DateTime normalizeLocalDay(DateTime dt) => DateTime(2026, 10, 12);
  @override
  Future<DailyCheckin?> fetchByDate(DateTime dayLocal) async => current;
  @override
  Stream<DailyCheckin?> watchByDate(DateTime dayLocal) => Stream.value(current);
  @override
  Future<ObservationLoadResult> loadObservation(DateTime date) async =>
      ObservationLoadResult(
        current: current,
        pending: pending,
        revision: revision,
        subjectId: _subject,
        hasProfile: true,
      );
  @override
  Future<ObservationSaveResult> saveObservation(
      ObservationMutation mutation) async {
    submitted.add(mutation);
    if (offline) {
      pending = mutation;
      return ObservationSaveResult(confirmed: false, mutation: mutation);
    }
    revision++;
    pending = null;
    if (mutation.operation == ObservationOperation.cancel) {
      current = null;
      return ObservationSaveResult(
        confirmed: true,
        mutation: mutation,
        revision: revision,
        subjectId: _subject,
        changed: true,
      );
    }
    final condition = switch (mutation.condition) {
      'normal' => DailyCondition.normal,
      'slightlyConcerned' => DailyCondition.slightlyConcerned,
      'veryConcerned' => DailyCondition.veryConcerned,
      _ => null,
    };
    final levels = buildDailyObservationLevels(
      condition: condition,
      concernTags: mutation.concernTags,
      partial: true,
    );
    final projection = <String, dynamic>{
      'dayKey': _day,
      'date': DateTime(2026, 10, 12),
      'subjectId': _subject,
      'eventId': 'synthetic-event-$revision',
      'revision': revision,
      'eventRevision': revision,
      'condition': mutation.condition,
      'concernTags': mutation.concernTags,
      'observationLevels':
          levels.map((key, value) => MapEntry(key, value.name)),
      'memo': mutation.memo,
      'timing': mutation.timing.toMap(),
      'schemaVersion': 2,
      'observationResponseMode': 'partial_overall_with_selected_tags',
    };
    current = DailyCheckin.fromJson(projection, fallbackDayKey: _day);
    return ObservationSaveResult(
      confirmed: true,
      mutation: mutation,
      revision: revision,
      subjectId: _subject,
      eventId: projection['eventId'] as String,
      projection: projection,
      changed: true,
    );
  }

  @override
  Future<void> saveDailyCheckin({
    required DateTime date,
    required DailyCondition condition,
    required List<String> concernTags,
    required Map<String, DailyObservationLevel> observationLevels,
    String memo = '',
  }) async =>
      throw StateError('Partial UI must use the history acceptance path');
}

Future<void> _show(
  WidgetTester tester,
  _PartialObservationStore health,
  CareTestStore care, {
  double width = 390,
  bool dark = false,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  var theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
  if (Platform.environment['HAMCARE_PARTIAL_OBSERVATION_CAPTURE_DIR'] != null &&
      Platform.isMacOS) {
    theme = theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: _font),
      primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: _font),
    );
  }
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    home: Scaffold(
      body: RepaintBoundary(
        key: _captureKey,
        child: ColoredBox(
          // Include the real theme surface behind the translucent production
          // card in captures; an isolated transparent boundary loses it.
          color: theme.scaffoldBackgroundColor,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: DailyConditionInputCard(
              repo: health,
              careRepo: care,
              date: DateTime(2026, 10, 12),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  expect(find.text('観察したタイミング'), findsNothing);
  expect(find.byKey(const ValueKey('observation-time-now')), findsNothing);
  expect(find.byKey(const ValueKey('observation-time-date')), findsNothing);
  expect(find.byKey(const ValueKey('observation-time-unknown')), findsNothing);
  expect(find.byKey(const ValueKey('observation-time-select')), findsNothing);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async =>
    _tap(tester, find.text('この内容で記録'));
Finder _saveButton() => find.widgetWithText(FilledButton, 'この内容で記録');

void _expectUnknownTiming(ObservationMutation mutation) {
  expect(mutation.inputUiVersion, 'daily_checkin_partial_v1');
  expect(mutation.timing.precision, ObservationTimePrecision.unknown);
  expect(mutation.timing.observedAt, isNull);
  expect(mutation.timing.dateKey, isNull);
}

Future<void> _capture(WidgetTester tester, String filename) async {
  final directory =
      Platform.environment['HAMCARE_PARTIAL_OBSERVATION_CAPTURE_DIR'];
  if (directory == null) return;
  await tester.runAsync(() async {
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(_captureKey));
    final image = await boundary.toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$directory/$filename.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides? previousHttp;
  setUpAll(() async {
    previousHttp = HttpOverrides.current;
    HttpOverrides.global = _NoObservationNetwork();
    if (Platform.environment['HAMCARE_PARTIAL_OBSERVATION_CAPTURE_DIR'] !=
            null &&
        Platform.isMacOS) {
      final japanese =
          await File('/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc').readAsBytes();
      await (FontLoader(_font)
            ..addFont(Future.value(ByteData.sublistView(japanese))))
          .load();
      final icons = await File(
              '/Users/gota/tools/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
          .readAsBytes();
      await (FontLoader('MaterialIcons')
            ..addFont(Future.value(ByteData.sublistView(icons))))
          .load();
    }
  });
  tearDownAll(() => HttpOverrides.global = previousHttp);

  for (final entry in const {
    'いつも通り': DailyCondition.normal,
    '少し違う': DailyCondition.slightlyConcerned,
    '心配': DailyCondition.veryConcerned,
  }.entries) {
    testWidgets(
        'overall ${entry.key} alone saves without timing or care defaults',
        (tester) async {
      final health = _PartialObservationStore(), care = CareTestStore();
      await _show(tester, health, care);
      await _tap(tester, find.text(entry.key));
      await _save(tester);
      final mutation = health.submitted.single;
      expect(mutation.condition, entry.value.name);
      expect(mutation.concernTags, isEmpty);
      expect(mutation.memo, isEmpty);
      expect(health.current!.observationLevels, isEmpty);
      _expectUnknownTiming(mutation);
      expect(care.saved, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  for (final entry in const {'食欲': 'appetite', '排泄': 'elimination'}.entries) {
    testWidgets(
        '${entry.value} alone saves with unanswered overall and other items',
        (tester) async {
      final health = _PartialObservationStore(), care = CareTestStore();
      await _show(tester, health, care);
      await _tap(tester, find.text(entry.key));
      await _save(tester);
      final mutation = health.submitted.single;
      expect(mutation.condition, isNull);
      expect(mutation.concernTags, [entry.value]);
      expect(mutation.toMap().containsKey('condition'), isFalse);
      expect(health.current!.condition, isNull);
      expect(health.current!.observationLevels,
          {entry.value: DailyObservationLevel.changed});
      _expectUnknownTiming(mutation);
      expect(care.saved, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('memo alone saves trimmed text without an invented normal',
      (tester) async {
    final health = _PartialObservationStore(), care = CareTestStore();
    await _show(tester, health, care);
    await _tap(tester, find.text('メモ（任意）'));
    await tester.enterText(find.byType(TextField), '  合成の観察メモ  ');
    await tester.pumpAndSettle();
    await _save(tester);
    expect(health.submitted.single.memo, '合成の観察メモ');
    expect(health.submitted.single.condition, isNull);
    expect(health.submitted.single.concernTags, isEmpty);
    expect(health.current!.observationLevels, isEmpty);
    expect(care.saved, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cleaning alone saves only explicit care with no health write',
      (tester) async {
    final health = _PartialObservationStore(), care = CareTestStore();
    await _show(tester, health, care);
    await _tap(
        tester, find.byKey(const ValueKey('care-cageCleaning-spot_removal')));
    await _save(tester);
    expect(health.submitted, isEmpty);
    final actions = care.saved.single.actions;
    expect(actions.keys, ['cageCleaning']);
    expect(actions['cageCleaning']!.answer, CareActionAnswer.performed);
    expect(actions['cageCleaning']!.details, {'cleaningType': 'spot_removal'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('walk alone saves selected minutes without filling cleaning',
      (tester) async {
    final health = _PartialObservationStore(), care = CareTestStore();
    await _show(tester, health, care);
    await _tap(
        tester, find.byKey(const ValueKey('care-duration-value-roomWalk')));
    await tester.enterText(
        find.byKey(const ValueKey('care-detail-roomWalk')), '20');
    await _tap(tester, find.text('入力する'));
    await _save(tester);
    expect(health.submitted, isEmpty);
    expect(care.saved.single.actions.keys, ['roomWalk']);
    expect(care.saved.single.actions['roomWalk']!.details,
        {'durationMinutes': 20});
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected concern and care save independently in one action',
      (tester) async {
    final health = _PartialObservationStore(), care = CareTestStore();
    await _show(tester, health, care);
    await _tap(tester, find.text('食欲'));
    await _tap(tester,
        find.byKey(const ValueKey('care-cageCleaning-partial_cleaning')));
    await _save(tester);
    expect(health.submitted.single.condition, isNull);
    expect(health.submitted.single.concernTags, ['appetite']);
    expect(care.saved.single.actions.keys, ['cageCleaning']);
    expect(health.current!.observationLevels.keys, ['appetite']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty, whitespace memo and cleared answers cannot save',
      (tester) async {
    final health = _PartialObservationStore(), care = CareTestStore();
    await _show(tester, health, care);
    expect(tester.widget<FilledButton>(_saveButton()).onPressed, isNull);
    await _tap(tester, find.text('メモ（任意）'));
    await tester.enterText(find.byType(TextField), '  \n  ');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(_saveButton()).onPressed, isNull);
    await _tap(tester, find.text('食欲'));
    expect(tester.widget<FilledButton>(_saveButton()).onPressed, isNotNull);
    await _tap(tester, find.text('食欲'));
    expect(tester.widget<FilledButton>(_saveButton()).onPressed, isNull);
    expect(health.submitted, isEmpty);
    expect(care.saved, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'legacy complete record loads and correction keeps historical timing',
      (tester) async {
    final health = _PartialObservationStore(), care = CareTestStore();
    final oldTiming = ObservationTiming.instant(DateTime.utc(2026, 10, 12, 1));
    health.current = DailyCheckin(
      dayKey: _day,
      date: DateTime(2026, 10, 12),
      condition: DailyCondition.slightlyConcerned,
      concernTags: const ['appetite'],
      observationLevels: const {'appetite': DailyObservationLevel.changed},
      memo: '以前の合成メモ',
      revision: 1,
      eventId: 'synthetic-original-event',
      eventRevision: 1,
      subjectId: _subject,
      timing: oldTiming,
    );
    health.revision = 1;
    await _show(tester, health, care);
    expect(find.text('少し違う・食欲'), findsOneWidget);
    expect(health.submitted, isEmpty);
    await _tap(tester, find.text('編集'));
    await _tap(tester, find.text('入力の訂正'));
    await _tap(tester, find.text('心配'));
    await _save(tester);
    final mutation = health.submitted.single;
    expect(mutation.operation, ObservationOperation.correction);
    expect(mutation.targetEventId, 'synthetic-original-event');
    expect(mutation.targetRevision, 1);
    expect(mutation.timing.toMap(), oldTiming.toMap());
    expect(mutation.memo, '以前の合成メモ');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'partial pending retry preserves the original mutation and absent values',
      (tester) async {
    final health = _PartialObservationStore()..offline = true;
    final care = CareTestStore();
    await _show(tester, health, care);
    await _tap(tester, find.text('排泄'));
    await _save(tester);
    final pendingWire = health.submitted.single.toMap();
    expect(health.current, isNull);
    expect(find.text('今日の様子は同期待ちです。まだ保存確定ではありません。'), findsWidgets);
    health.offline = false;
    await _tap(tester, find.text('今日の様子を再送する'));
    expect(health.submitted.length, 2);
    expect(health.submitted.last.toMap(), pendingWire);
    expect(health.current!.condition, isNull);
    expect(health.current!.observationLevels.keys, ['elimination']);
    expect(care.saved, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'partial form preview keeps labels visible without timing prompts',
      (tester) async {
    final health = _PartialObservationStore(), care = CareTestStore();
    await _show(tester, health, care);
    await _capture(tester, 'partial_observation_light_390');
    await tester.pumpWidget(const SizedBox.shrink());
    await _show(tester, health, care, width: 320, dark: true);
    await _capture(tester, 'partial_observation_dark_320');
    expect(tester.takeException(), isNull);
    expect(health.submitted, isEmpty);
    expect(care.saved, isEmpty);
  });
}

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/services/distance_records_repo.dart';
import 'package:hamster_project/services/measurement_history_client.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/widgets/wheel_rotation_input_card.dart';

import 'measurement_history_test_support.dart';

const _day = '2026-10-12';
const _nextDay = '2026-10-13';
const _unknownWire = <String, dynamic>{
  ...unknownMeasurementTiming,
  'windowMeaning': 'unknown',
};

const _nightTiming = <String, dynamic>{
  'timePrecision': 'unknown',
  'confirmation': 'unknown',
  'windowMeaning': 'selected_night_to_next_morning',
  'dateKey': null,
  'observedAt': null,
  'clockSource': 'unknown',
};
const _nightWire = <String, dynamic>{
  'precision': 'unknown',
  'confirmation': 'unknown',
  'windowMeaning': 'selected_night_to_next_morning',
};
const _dateTiming = <String, dynamic>{
  'timePrecision': 'date_only',
  'confirmation': 'date_confirmed',
  'dateKey': _day,
  'windowMeaning': 'selected_day',
  'clockSource': 'unknown',
};
const _dateWire = <String, dynamic>{
  'precision': 'date_only',
  'confirmation': 'date_confirmed',
  'dateKey': _day,
  'windowMeaning': 'selected_day',
};
const _instantTiming = <String, dynamic>{
  'timePrecision': 'instant',
  'confirmation': 'time_confirmed',
  'observedAt': '2026-10-12T03:00:00Z',
  'dateKey': _day,
  'clockSource': 'user_reported',
};
const _instantWire = <String, dynamic>{
  'precision': 'instant',
  'confirmation': 'time_confirmed',
  'observedAt': '2026-10-12T03:00:00Z',
};

String _dayKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DailyDistanceRecord _record({
  String day = _day,
  required Map<String, dynamic>? timing,
  int revision = 2,
  int rotations = 100,
}) =>
    DailyDistanceRecord(
      dayKey: day,
      date: DateTime.parse(day),
      distance: 62.8,
      rotations: rotations,
      wheelDiameterCm: 20,
      subjectId: 'subject-one',
      recordId: 'record-one',
      revision: revision,
      timing: timing,
    );

class _DayDistanceRepo extends DistanceHistoryUiRepo {
  _DayDistanceRepo({
    required MeasurementHistoryClient client,
    Iterable<DailyDistanceRecord> records = const [],
  })  : records = {for (final record in records) record.dayKey: record},
        super(client: client);

  final Map<String, DailyDistanceRecord> records;

  @override
  Future<DailyDistanceRecord?> fetchDailyRecord(DateTime value) async =>
      records[_dayKey(value)];
}

Map<String, dynamic> _confirm(
    _DayDistanceRepo repo, Map<String, dynamic> request,
    {bool replayed = false}) {
  final receipt = measurementReply(request, replayed: replayed);
  final day = request['dayKey'] as String;
  final projection = receipt['projection'];
  if (projection == null) {
    repo.records.remove(day);
  } else {
    repo.records[day] = DailyDistanceRecord.fromJson(
      Map<String, dynamic>.from(projection as Map),
      fallbackDayKey: day,
      fallbackDate: DateTime.parse(day),
    );
  }
  return receipt;
}

Future<void> _showDistance(
    WidgetTester tester, DistanceRecordsRepo repo) async {
  tester.view.physicalSize = const Size(393, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('ja')],
    locale: const Locale('ja'),
    home: Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          WheelRotationInputCard(
              distanceRepo: repo, initialDate: DateTime(2026, 10, 12)),
        ],
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void _expectNoPeriodSelector() {
  expect(find.byKey(const ValueKey('distance-timing')), findsNothing);
  expect(find.text('回転数を測った期間'), findsNothing);
  expect(find.byType(DropdownButtonFormField<String>), findsNothing);
}

Future<void> _edit(WidgetTester tester) async {
  await tester.tap(find.text('編集'));
  await tester.pumpAndSettle();
  _expectNoPeriodSelector();
}

Future<void> _saveRotations(WidgetTester tester, int rotations) async {
  await tester.enterText(find.byType(TextField), '$rotations');
  await tester.pumpAndSettle();
  final save = find.byWidgetPredicate((widget) => widget is FilledButton);
  expect(find.descendant(of: save, matching: find.text('この日付で保存')),
      findsOneWidget);
  expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

Future<void> _selectNextDay(WidgetTester tester) async {
  await tester.tap(find.text('2026/10/12'));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(
      of: find.byType(DatePickerDialog), matching: find.text('13')));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(
      of: find.byType(DatePickerDialog), matching: find.text('OK')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('positive rotations save unknown timing with no period selection',
      (tester) async {
    final requests = <Map<String, dynamic>>[];
    late _DayDistanceRepo repo;
    repo = _DayDistanceRepo(
      client: testMeasurementClient(
        kind: 'distance',
        submit: (request) async {
          requests.add(request);
          return _confirm(repo, request);
        },
      ),
    );
    await _showDistance(tester, repo);
    _expectNoPeriodSelector();
    await _saveRotations(tester, 234);
    expect(requests.single['dayKey'], _day);
    expect(requests.single['rotations'], 234);
    expect(requests.single['timing'], _unknownWire);
    expect(repo.records[_day]!.timing, _unknownWire);
    expect(find.text('編集'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final timing in [
    ('night', _nightTiming, _nightWire),
    ('date_only', _dateTiming, _dateWire),
    ('instant', _instantTiming, _instantWire),
  ]) {
    testWidgets(
        'same-day ${timing.$1} timing survives editing and confirmed record reload',
        (tester) async {
      final requests = <Map<String, dynamic>>[];
      late _DayDistanceRepo repo;
      repo = _DayDistanceRepo(
        records: [_record(timing: timing.$2)],
        client: testMeasurementClient(
          kind: 'distance',
          submit: (request) async {
            requests.add(request);
            return _confirm(repo, request);
          },
        ),
      );
      await _showDistance(tester, repo);
      await _edit(tester);
      expect(find.text('この記録の車輪直径: 20.0 cm'), findsOneWidget);
      await _saveRotations(tester, 123);
      expect(requests.single['timing'], timing.$3);
      expect(requests.single['expectedRevision'], 2);
      expect(requests.single.containsKey('wheelDiameterCm'), false);

      await tester.pumpWidget(const SizedBox.shrink());
      await _showDistance(tester, repo);
      await _edit(tester);
      await _saveRotations(tester, 124);
      expect(requests.last['timing'], timing.$3);
      expect(requests.last['expectedRevision'], 3);
      expect(repo.records[_day]!.timing, timing.$3);
      expect(tester.takeException(), isNull);
    });

    test('different record day never inherits ${timing.$1} source timing',
        () async {
      Map<String, dynamic>? sent;
      final repo = DistanceHistoryUiRepo(
        client: testMeasurementClient(
          kind: 'distance',
          submit: (request) async {
            sent = request;
            return measurementReply(request);
          },
        ),
      );
      final saved = await repo.saveRotationRecord(
        date: DateTime(2026, 10, 13),
        rotations: 101,
        expectedRecord: _record(timing: timing.$2),
      );
      expect(sent!['dayKey'], _nextDay);
      expect(sent!['timing'], _unknownWire);
      expect(saved.timing, _unknownWire);
    });
  }

  for (final targetExists in [false, true]) {
    testWidgets(
        'selecting ${targetExists ? 'an existing' : 'an empty'} day discards source-day timing',
        (tester) async {
      final requests = <Map<String, dynamic>>[];
      const targetTiming = <String, dynamic>{
        'precision': 'date_only',
        'confirmation': 'date_confirmed',
        'dateKey': _nextDay,
        'windowMeaning': 'selected_day',
      };
      late _DayDistanceRepo repo;
      repo = _DayDistanceRepo(
        records: [
          _record(timing: _instantTiming),
          if (targetExists) _record(day: _nextDay, timing: targetTiming),
        ],
        client: testMeasurementClient(
          kind: 'distance',
          submit: (request) async {
            requests.add(request);
            return _confirm(repo, request);
          },
        ),
      );
      await _showDistance(tester, repo);
      await _edit(tester);
      await tester.enterText(find.byType(TextField), '999');
      await _selectNextDay(tester);
      if (targetExists) await _edit(tester);
      _expectNoPeriodSelector();
      await _saveRotations(tester, 222);
      expect(requests.single['dayKey'], _nextDay);
      expect(requests.single['timing'],
          targetExists ? targetTiming : _unknownWire);
      expect(repo.records[_day]!.timing, _instantTiming);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('confirmed cancellation permits a fresh unknown-timing zero save',
      (tester) async {
    final requests = <Map<String, dynamic>>[];
    late _DayDistanceRepo repo;
    repo = _DayDistanceRepo(
      records: [_record(timing: _instantTiming)],
      client: testMeasurementClient(
        kind: 'distance',
        dayRevision: 3,
        submit: (request) async {
          requests.add(request);
          return _confirm(repo, request);
        },
      ),
    );
    await _showDistance(tester, repo);
    await _edit(tester);
    await tester.ensureVisible(find.text('この記録を取り消す'));
    await tester.tap(find.text('この記録を取り消す'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取り消す'));
    await tester.pumpAndSettle();
    expect(requests.single['operation'], 'cancel');
    expect(requests.single.containsKey('timing'), false);
    expect(repo.records, isEmpty);
    _expectNoPeriodSelector();

    await _saveRotations(tester, 0);
    expect(requests.last['operation'], 'save');
    expect(requests.last['rotations'], 0);
    expect(requests.last['timing'], _unknownWire);
    expect(requests.last['expectedRevision'], 3);
    expect(find.text('編集'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending retry after reload keeps original timing and mutation',
      (tester) async {
    final store = MemoryMeasurementPending();
    final requests = <Map<String, dynamic>>[];
    var offline = true;
    late _DayDistanceRepo repo;
    repo = _DayDistanceRepo(
      records: [_record(timing: _instantTiming)],
      client: testMeasurementClient(
        kind: 'distance',
        pending: store,
        submit: (request) async {
          requests.add(request);
          if (offline) {
            throw FirebaseFunctionsException(
                code: 'unavailable', message: 'offline');
          }
          return _confirm(repo, request, replayed: true);
        },
      ),
    );
    await _showDistance(tester, repo);
    await _edit(tester);
    await _saveRotations(tester, 125);
    expect(requests.single['timing'], _instantWire);
    expect(requests.single['mutationId'], isA<String>());
    expect(store.values.length, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await _showDistance(tester, repo);
    _expectNoPeriodSelector();
    expect(find.text('125'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);

    offline = false;
    await tester.ensureVisible(find.text('同じ内容を再送'));
    await tester.tap(find.text('同じ内容を再送'));
    await tester.pumpAndSettle();
    expect(requests, hasLength(2));
    expect(requests.last, requests.first);
    expect(store.values, isEmpty);
    expect(repo.records[_day]!.timing, _instantWire);
    expect(find.text('編集'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final latestExists in [true, false]) {
    testWidgets(
        'reviewing ${latestExists ? 'a newer record' : 'a cancelled record'} uses latest timing while keeping rotations',
        (tester) async {
      final requests = <Map<String, dynamic>>[];
      var conflicting = true;
      late _DayDistanceRepo repo;
      repo = _DayDistanceRepo(
        records: [_record(timing: _nightTiming)],
        client: testMeasurementClient(
          kind: 'distance',
          dayRevision: 3,
          submit: (request) async {
            requests.add(request);
            if (conflicting) {
              throw FirebaseFunctionsException(
                  code: 'aborted', message: 'stale');
            }
            return _confirm(repo, request);
          },
        ),
      );
      await _showDistance(tester, repo);
      await _edit(tester);
      await _saveRotations(tester, 211);
      expect(requests.single['timing'], _nightWire);
      expect(find.text('211'), findsOneWidget);
      if (latestExists) {
        repo.records[_day] = _record(timing: _instantTiming, revision: 3);
      } else {
        repo.records.remove(_day);
      }
      await tester.ensureVisible(find.text('入力を残して最新の記録を確認'));
      await tester.tap(find.text('入力を残して最新の記録を確認'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('入力を残して続ける'));
      await tester.pumpAndSettle();
      expect(find.text('211'), findsOneWidget);
      _expectNoPeriodSelector();

      conflicting = false;
      await _saveRotations(tester, 211);
      expect(requests.last['expectedRevision'], 3);
      expect(requests.last['rotations'], 211);
      expect(
          requests.last['timing'], latestExists ? _instantWire : _unknownWire);
      expect(tester.takeException(), isNull);
    });
  }
}

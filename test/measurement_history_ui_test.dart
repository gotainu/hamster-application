import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/widgets/weight_input_card.dart';
import 'package:hamster_project/widgets/wheel_rotation_input_card.dart';
import 'package:hamster_project/services/measurement_history_client.dart';
import 'measurement_history_test_support.dart';
import 'package:hamster_project/services/pet_profile_repo.dart';
import 'package:hamster_project/models/weight_record.dart';
import 'package:hamster_project/screens/pet_profile_edit_screen.dart';
import 'package:hamster_project/screens/breeding_environment_edit_screen.dart';
import 'observation_identity_repo_test.dart' show MemoryProfilePending;

Future<void> showMeasurementUi(WidgetTester tester, Widget child,
    {bool dark = false, double width = 393, double scale = 1}) async {
  tester.view.physicalSize = Size(width, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: Scaffold(
          body:
              ListView(padding: const EdgeInsets.all(16), children: [child]))));
  await tester.pumpAndSettle();
}

Future<void> chooseTiming(WidgetTester tester, String key, String label) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

class _SetupDiameterRepo extends DistanceHistoryUiRepo {
  double? diameter;
  int refreshes = 0;
  @override
  Future<double?> refreshWheelDiameter() async {
    refreshes++;
    return diameter;
  }

  @override
  double? get cachedWheelDiameterCm => diameter;
}

void main() {
  testWidgets(
      'missing wheel diameter opens focused settings and refreshes on return',
      (tester) async {
    final repo = _SetupDiameterRepo();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ListView(children: [
      WheelRotationInputCard(
          distanceRepo: repo, initialDate: DateTime(2026, 10, 12)),
    ]))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('wheel-diameter-guide')), findsOneWidget);
    await tester.ensureVisible(find.text('車輪の直径を設定する'));
    await tester.tap(find.text('車輪の直径を設定する'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
        tester
            .widget<BreedingEnvironmentEditScreen>(
                find.byType(BreedingEnvironmentEditScreen))
            .focusWheelDiameter,
        isTrue);
    repo.diameter = 28;
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(repo.refreshes, 2);
    expect(find.byKey(const ValueKey('wheel-diameter-guide')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
      'weight legacy edit requires explicit subject and timing confirmation',
      (tester) async {
    await showMeasurementUi(
        tester,
        WeightInputCard(
            repo: WeightHistoryUiRepo(
                record: historyWeight(subject: null, revision: 0)),
            initialDate: DateTime(2026, 10, 12)));
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
    FilledButton button() => tester.widget<FilledButton>(
        find.byWidgetPredicate((widget) => widget is FilledButton));
    expect(button().onPressed, isNull);
    await chooseTiming(tester, 'weight-timing', '測定時期は不明');
    expect(button().onPressed, isNull);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(button().onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'weight confirmed receipt completes save, no fabricated record before receipt',
      (tester) async {
    final requests = <Map<String, dynamic>>[];
    var callbacks = 0;
    await showMeasurementUi(
        tester,
        WeightInputCard(
            repo: WeightHistoryUiRepo(
                client: testMeasurementClient(submit: (r) async {
              requests.add(r);
              return measurementReply(r);
            })),
            initialDate: DateTime(2026, 10, 12),
            onSaved: (_) => callbacks++));
    await tester.enterText(find.byType(TextField).first, '122');
    await chooseTiming(tester, 'weight-timing', '選んだ日に測定（時刻は不要）');
    await tester.ensureVisible(find.text('体重を保存'));
    await tester.tap(find.text('体重を保存'));
    await tester.pumpAndSettle();
    expect(requests.length, 1);
    expect(callbacks, 1);
    expect(find.text('122g'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'weight offline keeps same request and edited input; retry confirms same mutation',
      (tester) async {
    final store = MemoryMeasurementPending();
    final requests = <Map<String, dynamic>>[];
    var offline = true;
    late WeightHistoryUiRepo repo;
    final client = testMeasurementClient(
        pending: store,
        submit: (r) async {
          requests.add(r);
          if (offline) {
            throw FirebaseFunctionsException(
                code: 'unavailable', message: 'offline');
          }
          final result = measurementReply(r);
          repo.initial = WeightRecord.fromJson(
              Map<String, dynamic>.from(result['projection'] as Map),
              fallbackDayKey: r['dayKey'] as String);
          return result;
        });
    repo = WeightHistoryUiRepo(client: client);
    await showMeasurementUi(tester,
        WeightInputCard(repo: repo, initialDate: DateTime(2026, 10, 12)));
    await tester.enterText(find.byType(TextField).first, '122');
    await chooseTiming(tester, 'weight-timing', '測定時期は不明');
    await tester.ensureVisible(find.text('体重を保存'));
    await tester.tap(find.text('体重を保存'));
    await tester.pumpAndSettle();
    expect(find.text('122'), findsOneWidget);
    expect(find.text('同じ内容を再送'), findsOneWidget);
    expect(store.values.length, 1);
    offline = false;
    await tester.ensureVisible(find.text('同じ内容を再送'));
    await tester.tap(find.text('同じ内容を再送'));
    await tester.pumpAndSettle();
    expect(requests[0], requests[1]);
    expect(store.values, isEmpty);
    expect(find.text('122g'), findsOneWidget);
  });
  testWidgets(
      'weight cancellation clears displayed answer only after confirmed receipt',
      (tester) async {
    final requests = <Map<String, dynamic>>[];
    await showMeasurementUi(
        tester,
        WeightInputCard(
            repo: WeightHistoryUiRepo(
                record: historyWeight(),
                client: testMeasurementClient(submit: (r) async {
                  requests.add(r);
                  return measurementReply(r);
                })),
            initialDate: DateTime(2026, 10, 12)));
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('この記録を取り消す'));
    await tester.tap(find.text('この記録を取り消す'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取り消す'));
    await tester.pumpAndSettle();
    expect(requests.single['operation'], 'cancel');
    expect(find.text('120'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'rotation correction preview uses saved wheel diameter rather than current environment',
      (tester) async {
    await showMeasurementUi(
        tester,
        WheelRotationInputCard(
            distanceRepo: DistanceHistoryUiRepo(record: historyDistance()),
            initialDate: DateTime(2026, 10, 12)));
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '100');
    await tester.pumpAndSettle();
    expect(find.text('63 m'), findsOneWidget);
    expect(find.text('この記録の車輪直径: 20.0 cm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'unknown original diameter blocks save until explicit confirmation',
      (tester) async {
    await showMeasurementUi(
        tester,
        WheelRotationInputCard(
            distanceRepo:
                DistanceHistoryUiRepo(record: historyDistance(diameter: null)),
            initialDate: DateTime(2026, 10, 12)));
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.byWidgetPredicate((widget) => widget is FilledButton))
            .onPressed,
        isNull);
    await tester.ensureVisible(find.text('直径を確認して入力'));
    await tester.tap(find.text('直径を確認して入力'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '22');
    await tester.tap(find.text('確認した直径を使う'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.byWidgetPredicate((widget) => widget is FilledButton))
            .onPressed,
        isNotNull);
    expect(find.text('この記録の車輪直径: 22.0 cm'), findsOneWidget);
  });
  testWidgets('measured zero saves unknown timing without a period selector',
      (tester) async {
    Map<String, dynamic>? sent;
    await showMeasurementUi(
        tester,
        WheelRotationInputCard(
            distanceRepo: DistanceHistoryUiRepo(
                client: testMeasurementClient(
                    kind: 'distance',
                    submit: (r) async {
                      sent = r;
                      return measurementReply(r);
                    })),
            initialDate: DateTime(2026, 10, 12)));
    await tester.enterText(find.byType(TextField), '0');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('distance-timing')), findsNothing);
    expect(find.text('回転数を測った期間'), findsNothing);
    await tester.ensureVisible(find.text('この日付で保存'));
    await tester.tap(find.text('この日付で保存'));
    await tester.pumpAndSettle();
    expect(sent!['rotations'], 0);
    expect(sent!['dayKey'], '2026-10-12');
    expect(sent!['timing'],
        {...unknownMeasurementTiming, 'windowMeaning': 'unknown'});
    expect(find.text('編集'), findsOneWidget);
  });
  testWidgets('narrow and large text keeps measurement controls usable',
      (tester) async {
    await showMeasurementUi(
        tester,
        WheelRotationInputCard(
            distanceRepo: DistanceHistoryUiRepo(
                record: historyDistance(diameter: null, subject: null)),
            initialDate: DateTime(2026, 10, 12)),
        dark: true,
        width: 320,
        scale: 1.5);
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('直径を確認して入力'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('distance editing has no unsupported date correction operation',
      (tester) async {
    await showMeasurementUi(
        tester,
        WheelRotationInputCard(
            distanceRepo: DistanceHistoryUiRepo(record: historyDistance()),
            initialDate: DateTime(2026, 10, 12)));
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
    expect(find.text('日付を訂正'), findsNothing);
    expect(find.text('2026/10/12'), findsOneWidget);
  });
  testWidgets(
      'weight conflict keeps draft while explicitly reviewing new revision',
      (tester) async {
    final requests = <Map<String, dynamic>>[];
    var conflicting = true;
    final repo = WeightHistoryUiRepo(
        record: historyWeight(),
        client: testMeasurementClient(submit: (r) async {
          requests.add(r);
          if (conflicting) {
            throw FirebaseFunctionsException(code: 'aborted', message: 'stale');
          }
          return measurementReply(r);
        }));
    await showMeasurementUi(tester,
        WeightInputCard(repo: repo, initialDate: DateTime(2026, 10, 12)));
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '124');
    await tester.ensureVisible(find.text('体重を保存'));
    await tester.tap(find.text('体重を保存'));
    await tester.pumpAndSettle();
    expect(find.text('124'), findsOneWidget);
    repo.initial = historyWeight(revision: 3);
    await tester.ensureVisible(find.text('入力を残して最新の記録を確認'));
    await tester.tap(find.text('入力を残して最新の記録を確認'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('入力を残して続ける'));
    await tester.pumpAndSettle();
    expect(find.text('124'), findsOneWidget);
    conflicting = false;
    await tester.ensureVisible(find.text('体重を保存'));
    await tester.tap(find.text('体重を保存'));
    await tester.pumpAndSettle();
    expect(requests.last['expectedRevision'], 3);
    expect(requests.last['weightGrams'], 124);
  });
  testWidgets(
      'legacy profile edit shows missing species as unconfirmed without selecting a species',
      (tester) async {
    final repo = PetProfileRepo(
        owner: () => 'owner',
        pendingStore: MemoryProfilePending(),
        read: () async => {'name': '旧プロフィール'});
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme, home: PetProfileEditScreen(repo: repo)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('種類は不明（未確認）'), findsOneWidget);
    expect(find.text('生年月日は不明'), findsOneWidget);
    expect((await repo.fetchMainPet())!.species, '');
    expect(tester.takeException(), isNull);
  });
  for (final cancelled in [false, true]) {
    testWidgets(
        'pending weight retry displays ${cancelled ? 'cancelled current' : 'newer correction'} rather than original receipt',
        (tester) async {
      final store = MemoryMeasurementPending();
      final request = {
        'dayKey': '2026-10-12',
        'date': DateTime(2026, 10, 12).toUtc().toIso8601String(),
        'subjectId': 'subject-one',
        'expectedRevision': 2,
        'operation': 'save',
        'inputUiVersion': 'measurement_history_v1',
        'weightGrams': 122.0,
        'memo': '保留中',
        'timing': measurementDateTiming('2026-10-12'),
        'mutationId': 'pending-old-receipt'
      };
      await store.write('owner', 'weight', request);
      final current = cancelled
          ? null
          : WeightRecord(
              dayKey: '2026-10-12',
              date: DateTime(2026, 10, 12),
              weightGrams: 130,
              memo: '後の訂正',
              subjectId: 'subject-one',
              recordId: 'record-one',
              revision: 4,
              timing: measurementDateTiming('2026-10-12'));
      var callbackRevision = 0;
      final repo = WeightHistoryUiRepo(
          record: current,
          client: testMeasurementClient(
              pending: store,
              submit: (r) async => measurementReply(r, replayed: true)));
      await showMeasurementUi(
          tester,
          WeightInputCard(
              repo: repo,
              initialDate: DateTime(2026, 10, 12),
              onSaved: (r) => callbackRevision = r.revision));
      await tester.ensureVisible(find.text('同じ内容を再送'));
      await tester.tap(find.text('同じ内容を再送'));
      await tester.pumpAndSettle();
      expect(store.values, isEmpty);
      expect(find.text('122g'), findsNothing);
      if (cancelled) {
        expect(find.text('130g'), findsNothing);
        expect(callbackRevision, 0);
        expect(find.text('編集'), findsNothing);
      } else {
        expect(find.text('130g'), findsOneWidget);
        expect(callbackRevision, 4);
      }
    });
  }
  testWidgets(
      'pending rotation retry reloads cancellation and does not resurrect measured value',
      (tester) async {
    final store = MemoryMeasurementPending();
    await store.write('owner', 'distance', {
      'dayKey': '2026-10-12',
      'date': DateTime(2026, 10, 12).toUtc().toIso8601String(),
      'subjectId': 'subject-one',
      'expectedRevision': 2,
      'operation': 'save',
      'inputUiVersion': 'measurement_history_v1',
      'mode': 'rotations',
      'rotations': 100,
      'source': 'wheel_manual',
      'timing': {
        ...unknownMeasurementTiming,
        'windowMeaning': 'selected_night_to_next_morning'
      },
      'mutationId': 'pending-old-distance'
    });
    await showMeasurementUi(
        tester,
        WheelRotationInputCard(
            distanceRepo: DistanceHistoryUiRepo(
                client: testMeasurementClient(
                    kind: 'distance',
                    pending: store,
                    submit: (r) async => measurementReply(r, replayed: true))),
            initialDate: DateTime(2026, 10, 12)));
    await tester.ensureVisible(find.text('同じ内容を再送'));
    await tester.tap(find.text('同じ内容を再送'));
    await tester.pumpAndSettle();
    expect(store.values, isEmpty);
    expect(find.text('編集'), findsNothing);
    expect(find.text('100'), findsNothing);
  });
}

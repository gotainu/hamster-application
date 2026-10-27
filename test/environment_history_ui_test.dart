import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/breeding_environment.dart';
import 'package:hamster_project/models/environment_history.dart';
import 'package:hamster_project/screens/breeding_environment_edit_screen.dart';
import 'package:hamster_project/screens/environment_history_screen.dart';
import 'package:hamster_project/widgets/shine_border.dart';
import 'environment_history_test_support.dart';
import 'health_individual_analysis_ui_support.dart';

Finder field(String label) => find.byKey(ValueKey('environment-$label'));
Future<void> bottom(WidgetTester tester) async {
  await tester.scrollUntilVisible(
      find.byKey(const ValueKey('environment-save')), 450,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

Future<void> showForm(WidgetTester tester, EnvironmentTestStore store,
        {Future<void> Function()? onSaved}) =>
    showHealthAnalysisUi(
        tester,
        BreedingEnvironmentEditScreen(
            store: store,
            now: () => DateTime(2026, 10, 12, 12),
            onSaved: onSaved ?? () async {}));
void main() {
  testWidgets(
      'wheel entry focuses only the needed field without saving settings',
      (tester) async {
    final store = EnvironmentTestStore()
      ..initial = const EnvironmentLoadResult();
    await tester.pumpWidget(MaterialApp(
        home: BreedingEnvironmentEditScreen(
            store: store, onSaved: () async {}, focusWheelDiameter: true)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(field('車輪の直径'), findsOneWidget);
    final wheel = tester.widget<TextField>(
        find.descendant(of: field('車輪の直径'), matching: find.byType(TextField)));
    expect(wheel.focusNode!.hasFocus, isTrue);
    expect(
        find.byWidgetPredicate((w) => w is AnimatedShiningBorder && w.active),
        findsOneWidget);
    expect(store.saved, isEmpty);
    await tester.enterText(field('車輪の直径'), '28');
    await tester.pump();
    expect(
        find.byWidgetPredicate((w) => w is AnimatedShiningBorder && w.active),
        findsNothing);
    expect(store.saved, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
      'opening settings only reads, does not save or manufacture height, method, tags',
      (tester) async {
    final store = EnvironmentTestStore()
      ..initial = EnvironmentLoadResult(
          environment: BreedingEnvironment.fromMap(
              {'cageWidth': '60', 'accessories': '旧グッズ'}));
    await showForm(tester, store);
    expect(store.saved, isEmpty);
    expect(store.loads, 1);
    await tester.scrollUntilVisible(field('高さ'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<TextFormField>(field('高さ')).controller!.text, isEmpty);
    await bottom(tester);
    await tester.tap(find.byKey(const ValueKey('environment-date-unknown')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('environment-save')));
    await tester.pumpAndSettle();
    expect(store.saved.single.values['cageHeight'], isNull);
    expect(store.saved.single.values['temperatureControl'], isNull);
    expect(store.saved.single.values.containsKey('accessoryTags'), isFalse);
  });
  testWidgets('prefilled date is not confirmed; explicit unknown permits save',
      (tester) async {
    final store = EnvironmentTestStore();
    await showForm(tester, store);
    await bottom(tester);
    await tester.tap(find.byKey(const ValueKey('environment-save')));
    await tester.pumpAndSettle();
    expect(store.saved, isEmpty);
    await tester.tap(find.byKey(const ValueKey('environment-date-unknown')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('environment-save')));
    await tester.pumpAndSettle();
    expect(store.saved.single.expectedRevision, 3);
    expect(
        store.saved.single.effective!.precision, EnvironmentPrecision.unknown);
    expect(store.saved.single.values['wheelDiameter'], '20');
  });
  testWidgets(
      'custom legacy temperature method is not silently converted to other',
      (tester) async {
    final store = EnvironmentTestStore()
      ..initial = EnvironmentLoadResult(
          environment: BreedingEnvironment.fromMap(
              {...environmentFixture(), 'temperatureControl': '手動の温度管理'}));
    await showForm(tester, store);
    await bottom(tester);
    await tester.tap(find.byKey(const ValueKey('environment-date-confirm')));
    await tester.pumpAndSettle();
    await bottom(tester);
    await tester.tap(find.byKey(const ValueKey('environment-save')));
    await tester.pumpAndSettle();
    expect(store.saved.single.values['temperatureControl'], '手動の温度管理');
  });
  testWidgets('unconfirmed server read blocks saves and offers reload',
      (tester) async {
    final store = EnvironmentTestStore()
      ..initial = const EnvironmentLoadResult(serverConfirmed: false);
    await showForm(tester, store);
    await bottom(tester);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('environment-save')))
            .onPressed,
        isNull);
    expect(store.saved, isEmpty);
  });
  testWidgets(
      'lost acknowledgement retries the original mutation without claiming success',
      (tester) async {
    var completions = 0;
    final store = EnvironmentTestStore()..offline = true;
    await showForm(tester, store, onSaved: () async {
      completions++;
    });
    await bottom(tester);
    await tester.tap(find.byKey(const ValueKey('environment-date-unknown')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('environment-save')));
    await tester.pumpAndSettle();
    expect(completions, 0);
    expect(store.saved.length, 1);
    final first = store.saved.first.toMap();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('environment-retry')), -400,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 350));
    await tester.pumpAndSettle();
    store.offline = false;
    await tester.tap(find.byKey(const ValueKey('environment-retry')));
    await tester.pumpAndSettle();
    expect(store.saved.last.toMap(), first);
    expect(completions, 1);
  });
  testWidgets(
      'concurrent revision conflict stays visible until explicit reload',
      (tester) async {
    final store = EnvironmentTestStore()
      ..saveError =
          FirebaseFunctionsException(code: 'aborted', message: 'conflict');
    await showForm(tester, store);
    await bottom(tester);
    await tester.tap(find.byKey(const ValueKey('environment-date-unknown')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('environment-save')));
    await tester.pumpAndSettle();
    await bottom(tester);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('environment-save')))
            .onPressed,
        isNull);
    expect(store.loads, 1);
  });
  testWidgets(
      'post-save onboarding failure does not turn a confirmed environment into a pending retry',
      (tester) async {
    final store = EnvironmentTestStore();
    await showForm(tester, store,
        onSaved: () async => throw StateError('synthetic onboarding failure'));
    await bottom(tester);
    await tester.tap(find.byKey(const ValueKey('environment-date-unknown')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('environment-save')));
    await tester.pumpAndSettle();
    expect(store.saved.length, 1);
    expect(find.byKey(const ValueKey('environment-retry')), findsNothing);
  });
  testWidgets(
      'history correction only submits target fields, preserving current other fields',
      (tester) async {
    final store = EnvironmentTestStore();
    await showForm(tester, store);
    await tester.tap(find.byKey(const ValueKey('environment-open-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('environment-correct-3')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(field('床材の深さ'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(field('床材の深さ'), '20');
    await tester.pumpAndSettle();
    await bottom(tester);
    await tester.tap(find.byKey(const ValueKey('environment-save')));
    await tester.pumpAndSettle();
    final saved = store.saved.single;
    expect(saved.operation, EnvironmentOperation.correction);
    expect(saved.targetRevision, 3);
    expect(saved.values.keys.toSet(), {'beddingThickness', 'wheelDiameter'});
    expect(saved.values['beddingThickness'], '20');
    expect(saved.values.containsKey('cageWidth'), isFalse);
  });
  testWidgets(
      'history pagination retains prior page and cancellation appends mutation',
      (tester) async {
    final store = EnvironmentTestStore()
      ..pages.addAll([
        EnvironmentHistoryPage(
            entries: [environmentHistoryFixture(revision: 3)],
            hasMore: true,
            beforeRevision: 3),
        EnvironmentHistoryPage(entries: [
          environmentHistoryFixture(revision: 2, precision: 'unknown')
        ]),
      ]);
    await showHealthAnalysisUi(tester, EnvironmentHistoryScreen(store: store));
    await tester.tap(find.byKey(const ValueKey('environment-history-more')));
    await tester.pumpAndSettle();
    expect(store.historyReads, 2);
    expect(find.text('変更時期不明 · 環境の変更'), findsOneWidget);
    await tester.tap(find.text('変更を取り消す').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '取り消す'));
    await tester.pumpAndSettle();
    expect(store.saved.single.operation, EnvironmentOperation.cancel);
    expect(store.saved.single.targetRevision, 3);
    expect(store.saved.single.values, isEmpty);
  });
  testWidgets(
      'only latest corrected input is editable and unchanged target fields remain available',
      (tester) async {
    final active = EnvironmentHistoryEntry.fromMap({
      'revision': 4,
      'kind': 'correction',
      'targetRevision': 2,
      'effective': {'precision': 'date_only', 'dateKey': '2026-10-10'},
      'rawValues': {'beddingThickness': '20', 'wheelDiameter': '28'},
      'values': {
        'beddingThickness': {'value': 20, 'unit': 'cm', 'quality': 'known'},
        'wheelDiameter': {'value': 28, 'unit': 'cm', 'quality': 'known'}
      },
      'changes': {
        'beddingThickness': {
          'before': {'value': 25, 'unit': 'cm', 'quality': 'known'},
          'after': {'value': 20, 'unit': 'cm', 'quality': 'known'}
        }
      },
    });
    final store = EnvironmentTestStore()
      ..entries = [active, environmentHistoryFixture(revision: 2)]
      ..initial = EnvironmentLoadResult(
          environment:
              BreedingEnvironment.fromMap(environmentFixture(revision: 4)));
    await showForm(tester, store);
    await tester.tap(find.byKey(const ValueKey('environment-open-history')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('environment-correct-2')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('environment-correct-4')));
    await tester.pumpAndSettle();
    await bottom(tester);
    await tester.tap(find.byKey(const ValueKey('environment-save')));
    await tester.pumpAndSettle();
    expect(store.saved.single.targetRevision, 2);
    expect(store.saved.single.values,
        {'beddingThickness': '20', 'wheelDiameter': '28'});
  });
  testWidgets(
      'memo-only environment change is not described as a date correction',
      (tester) async {
    final store = EnvironmentTestStore()
      ..entries = [
        EnvironmentHistoryEntry.fromMap({
          'revision': 3,
          'kind': 'change',
          'effective': {'precision': 'unknown'},
          'changes': {},
          'auxiliaryFieldsChanged': ['accessoryNote'],
        })
      ];
    await showHealthAnalysisUi(tester, EnvironmentHistoryScreen(store: store));
    expect(find.text('グッズのメモを更新'), findsOneWidget);
    expect(find.text('変更日の入力を訂正しました'), findsNothing);
    expect(find.text('環境の変更を記録しました'), findsNothing);
  });
}

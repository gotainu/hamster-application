import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/care_action_catalog.dart';
import 'package:hamster_project/models/daily_care_actions.dart';
import 'package:hamster_project/services/daily_checkin_repo.dart';
import 'package:hamster_project/viewmodels/care_action_input_view_model.dart';
import 'package:hamster_project/widgets/daily_condition_input_card.dart';
import 'care_action_test_support.dart';

Future<void> tapSave(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('この内容で記録'));
  await tester.tap(find.text('この内容で記録'));
  await tester.pumpAndSettle();
}

Future<void> tapHealthOnly(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('様子だけ記録'));
  await tester.tap(find.text('様子だけ記録'));
  await tester.pumpAndSettle();
}

Future<void> selectRoomMinutes(WidgetTester tester, int minutes) async {
  tester
      .widget<Slider>(
          find.byKey(const ValueKey('care-duration-slider-roomWalk')))
      .onChanged!(minutes.toDouble());
  await tester.pumpAndSettle();
}

void main() {
  test('catalog-backed defaults and clearing do not infer an answer', () {
    final vm = CareActionInputViewModel(dayKey: '2026-10-12');
    expect(vm.actions.keys, activeCareActionItems().map((i) => i.id));
    expect(vm.hasExplicitAnswer, isFalse);
    expect(vm.canSave, isFalse);
    vm.select('roomWalk', CareActionAnswer.performed);
    vm.detail('roomWalk', 30);
    expect(vm.actions['roomWalk']!.details, {'durationMinutes': 30});
    vm.select('roomWalk', CareActionAnswer.notPerformed);
    expect(vm.actions['roomWalk']!.details, isEmpty);
    vm.select('roomWalk', CareActionAnswer.performed);
    expect(vm.actions['roomWalk']!.details, isEmpty);
    vm.select('roomWalk', CareActionAnswer.unanswered);
    expect(vm.hasExplicitAnswer, isFalse);
  });
  test('invalid duration blocks saving; optional detail is not required', () {
    final vm = CareActionInputViewModel(dayKey: '2026-10-12');
    vm.select('roomWalk', CareActionAnswer.performed);
    expect(vm.canSave, isTrue);
    vm.detail('roomWalk', 0);
    expect(vm.canSave, isFalse);
    vm.detail('roomWalk', null);
    expect(vm.canSave, isTrue);
    expect(vm.mutation().toMap()['actions']['roomWalk'],
        {'answer': 'performed', 'answerProvenance': 'item_selection'});
  });
  test('retired and unknown saved actions remain readable but not new inputs',
      () {
    final record = DailyCareActions.fromMap({
      'revision': 2,
      'actions': {
        'retiredCare': {
          'answer': 'performed',
          'answerProvenance': 'item_selection'
        },
        'roomWalk': {
          'answer': 'not_performed',
          'details': {'durationMinutes': 45}
        }
      }
    }, dayKey: '2026-10-01');
    expect(record.actions['retiredCare']!.answer, CareActionAnswer.performed);
    expect(record.actions['roomWalk']!.details, isEmpty);
    expect(record.actions['roomWalk']!.timePrecision, 'unknown');
    final vm = CareActionInputViewModel(dayKey: '2026-10-01')
      ..load(CareActionLoadResult(record: record));
    expect(vm.actions.containsKey('retiredCare'), isTrue);
    expect(vm.mutation().actions.containsKey('retiredCare'), isFalse);
    expect(vm.mutation(cancel: true).actions, isEmpty);
  });
  testWidgets('initial visual defaults remain unanswered until explicit save',
      (tester) async {
    final health = CareHealthTestStore(), care = CareTestStore();
    await tester.pumpWidget(careInputTestApp(health, care));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ChoiceChip>(
                find.byKey(const ValueKey('care-cageCleaning-none')))
            .selected,
        isTrue);
    expect(find.text('0 分'), findsOneWidget);
    expect(find.text('掃除なし・散歩0分'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.byWidgetPredicate((w) => w is FilledButton))
            .onPressed,
        isNotNull);
    expect(health.saves, 0);
    expect(care.saved, isEmpty);
  });
  testWidgets(
      'care-only explicit non-performance never creates normal or health success',
      (tester) async {
    final health = CareHealthTestStore(), care = CareTestStore();
    var hs = 0, cs = 0;
    await tester.pumpWidget(careInputTestApp(health, care,
        onHealth: () => hs++, onCare: () => cs++));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('care-cageCleaning-none')));
    await tapSave(tester);
    expect(health.saves, 0);
    expect(health.saved, isNull);
    expect(hs, 0);
    expect(cs, 1);
    expect(care.saved.single.actions['cageCleaning']!.answer,
        CareActionAnswer.notPerformed);
    expect(care.saved.single.actions['roomWalk']!.answer,
        CareActionAnswer.notPerformed);
    expect(find.text('ケア記録を保存しました。'), findsOneWidget);
  });
  testWidgets(
      'health-only save keeps care unanswered and performs no care mutation',
      (tester) async {
    final health = CareHealthTestStore(), care = CareTestStore();
    await tester.pumpWidget(careInputTestApp(health, care));
    await tester.pumpAndSettle();
    await tester.tap(find.text('いつも通り'));
    await tapHealthOnly(tester);
    expect(health.saves, 1);
    expect(care.saved, isEmpty);
    expect(find.text('記録しました'), findsOneWidget);
  });
  testWidgets(
      'editing care on a day with health saved never resaves unchanged health',
      (tester) async {
    final health = CareHealthTestStore()
      ..initial = DailyCheckin(
          dayKey: '2026-10-12',
          date: DateTime(2026, 10, 12),
          condition: DailyCondition.normal,
          concernTags: const [],
          memo: '');
    final care = CareTestStore();
    var healthCallbacks = 0;
    await tester.pumpWidget(
        careInputTestApp(health, care, onHealth: () => healthCallbacks++));
    await tester.pumpAndSettle();
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
    await selectRoomMinutes(tester, 0);
    await tapSave(tester);
    expect(health.saves, 0);
    expect(healthCallbacks, 0);
    expect(care.saved.length, 1);
  });
  testWidgets(
      'opening an existing health editor or reselecting unchanged condition performs no write',
      (tester) async {
    final health = CareHealthTestStore()
      ..initial = DailyCheckin(
          dayKey: '2026-10-12',
          date: DateTime(2026, 10, 12),
          condition: DailyCondition.normal,
          concernTags: const [],
          memo: '');
    final care = CareTestStore();
    await tester.pumpWidget(careInputTestApp(health, care));
    await tester.pumpAndSettle();
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('いつも通り'));
    await tester.pumpAndSettle();
    final button = tester
        .widget<TextButton>(find.byKey(const ValueKey('health-only-save')));
    expect(button.onPressed, isNull);
    expect(health.saves, 0);
    expect(care.saved, isEmpty);
  });
  testWidgets(
      'editing only the health memo enables health save without a care mutation',
      (tester) async {
    final health = CareHealthTestStore()
      ..initial = DailyCheckin(
          dayKey: '2026-10-12',
          date: DateTime(2026, 10, 12),
          condition: DailyCondition.slightlyConcerned,
          concernTags: const ['appetite'],
          memo: 'before');
    final care = CareTestStore();
    await tester.pumpWidget(careInputTestApp(health, care));
    await tester.pumpAndSettle();
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'after');
    await tapHealthOnly(tester);
    expect(health.saves, 1);
    expect(health.saved!.memo, 'after');
    expect(care.saved, isEmpty);
  });
  testWidgets('care succeeds when health fails; health draft remains',
      (tester) async {
    final health = CareHealthTestStore()..fail = true, care = CareTestStore();
    await tester.pumpWidget(careInputTestApp(health, care));
    await tester.pumpAndSettle();
    await tester.tap(find.text('いつも通り'));
    await selectRoomMinutes(tester, 20);
    await tapSave(tester);
    expect(health.saves, 1);
    expect(care.saved.length, 1);
    expect(find.textContaining('今日の様子の保存に失敗'), findsOneWidget);
    health.fail = false;
    await tapSave(tester);
    expect(health.saves, 2);
    expect(care.saved.length, 1, reason: 'confirmed care is not sent again');
  });
  testWidgets('care failure does not resend the successful health record',
      (tester) async {
    final health = CareHealthTestStore(), care = CareTestStore()..fail = true;
    await tester.pumpWidget(careInputTestApp(health, care));
    await tester.pumpAndSettle();
    await tester.tap(find.text('いつも通り'));
    await selectRoomMinutes(tester, 0);
    await tapSave(tester);
    expect(health.saves, 1);
    expect(find.textContaining('ケア記録の保存に失敗'), findsOneWidget);
    care.fail = false;
    await tapSave(tester);
    expect(health.saves, 1);
    expect(care.saved.length, 2);
  });
  testWidgets('offline pending remains provisional and retries same mutation',
      (tester) async {
    final health = CareHealthTestStore(),
        care = CareTestStore()..offline = true;
    var events = 0;
    await tester
        .pumpWidget(careInputTestApp(health, care, onCare: () => events++));
    await tester.pumpAndSettle();
    await selectRoomMinutes(tester, 20);
    await tapSave(tester);
    expect(find.text('同期待ち'), findsOneWidget);
    expect(events, 0);
    final mutation = care.saved.single.mutationId;
    await tester.pumpWidget(const SizedBox());
    await tester
        .pumpWidget(careInputTestApp(health, care, onCare: () => events++));
    await tester.pumpAndSettle();
    expect(find.text('同期待ち'), findsOneWidget);
    care.offline = false;
    await tester.tap(find.text('ケア記録を再送する'));
    await tester.pumpAndSettle();
    expect(care.saved.last.mutationId, mutation);
    expect(events, 1);
  });
  testWidgets('saved reward failure is distinct from record failure',
      (tester) async {
    final health = CareHealthTestStore(),
        care = CareTestStore()..rewardStatus = 'failed';
    await tester.pumpWidget(careInputTestApp(health, care));
    await tester.pumpAndSettle();
    await selectRoomMinutes(tester, 20);
    await tapSave(tester);
    expect(find.text('ケア記録は保存済みです。報酬だけ再確認できます。'), findsOneWidget);
    expect(find.textContaining('ケア記録の保存に失敗'), findsNothing);
  });
  testWidgets('catalog addition rename order retirement uses the same form',
      (tester) async {
    final catalog = [
      const CareActionCatalogItem(
          id: 'newAction',
          label: '新しい行動',
          order: 0,
          active: true,
          inputType: 'tri_state'),
      ...careActionCatalog.map((i) => CareActionCatalogItem(
          id: i.id,
          label: i.id == 'roomWalk' ? '新しい名称' : i.label,
          order: i.order,
          active: i.id != 'cageCleaning',
          inputType: i.inputType,
          detail: i.detail,
          details: i.details))
    ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: DailyConditionInputCard(
                    repo: CareHealthTestStore(),
                    careRepo: CareTestStore(),
                    careCatalog: catalog)))));
    await tester.pumpAndSettle();
    expect(find.text('ケージ掃除'), findsNothing);
    expect(find.text('新しい名称'), findsOneWidget);
    expect(tester.getTopLeft(find.text('新しい行動')).dy,
        lessThan(tester.getTopLeft(find.text('新しい名称')).dy));
  });
  testWidgets('care cancellation leaves health untouched', (tester) async {
    final health = CareHealthTestStore(),
        care = CareTestStore()
          ..initial = CareActionLoadResult(
              record: DailyCareActions(
                  dayKey: '2026-10-12',
                  revision: 1,
                  actions: {
                'roomWalk':
                    const CareActionResponse(answer: CareActionAnswer.performed)
              }));
    await tester.pumpWidget(careInputTestApp(health, care));
    await tester.pumpAndSettle();
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ケア記録を取り消す'));
    await tester.tap(find.text('ケア記録を取り消す'));
    await tester.pumpAndSettle();
    expect(care.saved.single.operation, 'cancel');
    expect(care.saved.single.actions, isEmpty);
    expect(care.saved.single.expectedRevision, 1);
    expect(health.saves, 0);
  });
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/daily_care_actions.dart';
import 'package:hamster_project/viewmodels/care_action_input_view_model.dart';
import 'care_action_test_support.dart';

CareActionInputViewModel loaded(Map<String, CareActionResponse> actions) =>
    CareActionInputViewModel(dayKey: '2026-10-12')
      ..load(CareActionLoadResult(
          record: DailyCareActions(
              dayKey: '2026-10-12', revision: 1, actions: actions)));
Future<void> save(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('この内容で記録'));
  await tester.tap(find.text('この内容で記録'));
  await tester.pumpAndSettle();
}

void main() {
  test(
      'visual defaults are not evidence; batch save explicitly confirms defaults',
      () {
    final vm = CareActionInputViewModel(dayKey: '2026-10-12');
    expect(vm.cleaningChoice('cageCleaning'), 'none');
    expect(vm.minutes('roomWalk'), 0);
    expect(vm.hasExplicitAnswer, isFalse);
    vm.confirmDefaults();
    expect(vm.mutation().inputUiVersion, 'care_actions_input_v2');
    for (final action in vm.mutation().actions.values) {
      expect(action.answer, CareActionAnswer.notPerformed);
      expect(action.answerProvenance, 'batch_confirmation');
      expect(action.details, isEmpty);
    }
  });
  test('item selection and batch confirmation stay distinct', () {
    final vm = CareActionInputViewModel(dayKey: '2026-10-12')
      ..selectCleaning('cageCleaning', 'none')
      ..confirmDefaults();
    expect(vm.actions['cageCleaning']!.answerProvenance, 'item_selection');
    expect(vm.actions['roomWalk']!.answerProvenance, 'batch_confirmation');
  });
  test('explicit unanswered is not filled by batch confirmation', () {
    final vm = CareActionInputViewModel(dayKey: '2026-10-12')
      ..selectMinutes('roomWalk', 20)
      ..select('roomWalk', CareActionAnswer.unanswered)
      ..confirmDefaults();
    expect(vm.actions['roomWalk']!.answer, CareActionAnswer.unanswered);
    expect(vm.actions['roomWalk']!.answerProvenance, 'unanswered');
    expect(vm.actions['roomWalk']!.details, isEmpty);
  });
  test(
      'cleaning categories and independent bedding preserve only applicable selections',
      () {
    final vm = CareActionInputViewModel(dayKey: '2026-10-12')
      ..selectCleaning('cageCleaning', 'deep_cleaning');
    expect(
        vm.actions['cageCleaning']!.details, {'cleaningType': 'deep_cleaning'});
    vm.detail('cageCleaning', 'partial', key: 'beddingReplacement');
    vm.selectCleaning('cageCleaning', 'partial_cleaning');
    expect(
        vm.actions['cageCleaning']!.details['beddingReplacement'], 'partial');
    vm.selectCleaning('cageCleaning', 'spot_removal');
    expect(
        vm.actions['cageCleaning']!.details, {'cleaningType': 'spot_removal'});
    vm.detail('cageCleaning', 'almost_all', key: 'beddingReplacement');
    expect(
        vm.actions['cageCleaning']!.details.containsKey('beddingReplacement'),
        isFalse);
    vm.selectCleaning('cageCleaning', 'none');
    expect(vm.actions['cageCleaning']!.details, isEmpty);
  });
  test('zero, positive, unknown and more than two hours remain different', () {
    final vm = CareActionInputViewModel(dayKey: '2026-10-12');
    vm.selectMinutes('roomWalk', 0);
    expect(vm.actions['roomWalk']!.answer, CareActionAnswer.notPerformed);
    vm.selectMinutes('roomWalk', 150);
    expect(vm.minutes('roomWalk'), 150);
    vm.selectMinutes('roomWalk', null);
    expect(vm.actions['roomWalk']!.answer, CareActionAnswer.performed);
    expect(vm.minutes('roomWalk'), isNull);
    vm.selectMinutes('roomWalk', 1440);
    expect(vm.minutes('roomWalk'), 1440);
    vm.selectMinutes('roomWalk', 1441);
    expect(vm.canSave, isFalse);
    expect(vm.minutes('roomWalk'), 1440);
  });
  test(
      'legacy full/spot or performed unknown are never inferred or batch overwritten',
      () {
    for (final details in [
      {},
      {'scope': 'full'},
      {'scope': 'spot'}
    ]) {
      final vm = loaded({
        'cageCleaning': CareActionResponse(
            answer: CareActionAnswer.performed,
            details: Map<String, dynamic>.from(details)),
        'roomWalk': const CareActionResponse(answer: CareActionAnswer.performed)
      });
      expect(vm.cleaningChoice('cageCleaning'), isNull);
      expect(vm.minutes('roomWalk'), isNull);
      vm.confirmDefaults();
      expect(vm.actions['cageCleaning']!.details, details);
      expect(vm.actions['roomWalk']!.answer, CareActionAnswer.performed);
      expect(vm.actions['roomWalk']!.effectiveProvenance, 'legacy_unspecified');
    }
  });
  test('queued v1 mutation round-trips original wire without adding provenance',
      () {
    final wire = {
      'dayKey': '2026-10-12',
      'expectedRevision': 0,
      'mutationId': '00000000-0000-4000-8000-000000000001',
      'operation': 'save',
      'inputUiVersion': 'care_actions_input_v1',
      'inputRoute': 'daily_checkin',
      'actions': {
        'roomWalk': {
          'answer': 'performed',
          'details': {'durationMinutes': 150}
        }
      }
    };
    final pending = CareActionMutation.fromMap(wire);
    final vm = CareActionInputViewModel(dayKey: '2026-10-12')
      ..load(CareActionLoadResult(pending: pending, serverConfirmed: false));
    vm.selectMinutes('roomWalk', 0);
    vm.confirmDefaults();
    expect(vm.mutation().toMap(), wire);
    expect(vm.minutes('roomWalk'), 150);
  });
  testWidgets('main save confirms defaults without creating a health normal',
      (tester) async {
    final health = CareHealthTestStore(), care = CareTestStore();
    await tester.pumpWidget(careInputTestApp(health, care));
    await tester.pumpAndSettle();
    await save(tester);
    expect(health.saves, 0);
    expect(
        care.saved.single.actions.values
            .every((a) => a.answerProvenance == 'batch_confirmation'),
        isTrue);
  });
  testWidgets(
      'health-only action never writes care even after local draft changes',
      (tester) async {
    final health = CareHealthTestStore(), care = CareTestStore();
    await tester.pumpWidget(careInputTestApp(health, care));
    await tester.pumpAndSettle();
    await tester.tap(find.text('いつも通り'));
    await tester
        .tap(find.byKey(const ValueKey('care-cageCleaning-deep_cleaning')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('様子だけ記録'));
    await tester.tap(find.text('様子だけ記録'));
    await tester.pumpAndSettle();
    expect(health.saves, 1);
    expect(care.saved, isEmpty);
    expect(
        tester
            .widget<ChoiceChip>(
                find.byKey(const ValueKey('care-cageCleaning-deep_cleaning')))
            .selected,
        isTrue);
  });
  testWidgets(
      'cleaning and optional bedding choices are direct and independent',
      (tester) async {
    final health = CareHealthTestStore(), care = CareTestStore();
    await tester.pumpWidget(careInputTestApp(health, care));
    await tester.pumpAndSettle();
    for (final id in [
      'none',
      'spot_removal',
      'partial_cleaning',
      'deep_cleaning'
    ]) {
      expect(find.byKey(ValueKey('care-cageCleaning-$id')), findsOneWidget);
    }
    await tester
        .tap(find.byKey(const ValueKey('care-cageCleaning-deep_cleaning')));
    await tester.pumpAndSettle();
    for (final id in ['none', 'partial', 'almost_all']) {
      expect(
          tester
              .widget<ChoiceChip>(find
                  .byKey(ValueKey('care-cageCleaning-beddingReplacement-$id')))
              .selected,
          isFalse);
    }
    expect(care.saved, isEmpty);
    await tester.tap(find
        .byKey(const ValueKey('care-cageCleaning-beddingReplacement-none')));
    await save(tester);
    expect(care.saved.single.actions['cageCleaning']!.details,
        {'cleaningType': 'deep_cleaning', 'beddingReplacement': 'none'});
  });
  testWidgets(
      'slider changes local number immediately and direct input preserves 150',
      (tester) async {
    final health = CareHealthTestStore(), care = CareTestStore();
    await tester.pumpWidget(careInputTestApp(health, care));
    await tester.pumpAndSettle();
    final slider = find.byKey(const ValueKey('care-duration-slider-roomWalk'));
    await tester.ensureVisible(slider);
    await tester.tapAt(tester.getCenter(slider));
    await tester.pumpAndSettle();
    expect(find.text('60 分'), findsOneWidget);
    expect(care.saved, isEmpty);
    await tester
        .tap(find.byKey(const ValueKey('care-duration-value-roomWalk')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('care-detail-roomWalk')), '150');
    await tester.tap(find.text('入力する'));
    await tester.pumpAndSettle();
    expect(find.text('150 分'), findsOneWidget);
    expect(tester.widget<Slider>(slider).value, 120);
    await save(tester);
    expect(care.saved.single.actions['roomWalk']!.details,
        {'durationMinutes': 150});
  });
  testWidgets('fresh performed but unknown time is not zero or unanswered',
      (tester) async {
    final health = CareHealthTestStore(), care = CareTestStore();
    await tester.pumpWidget(careInputTestApp(health, care));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('散歩した（時間不明）'));
    await tester.tap(find.text('散歩した（時間不明）'));
    await tester.pumpAndSettle();
    expect(find.text('時間不明'), findsOneWidget);
    await save(tester);
    final answer = care.saved.single.actions['roomWalk']!;
    expect(answer.answer, CareActionAnswer.performed);
    expect(answer.details, isEmpty);
    expect(answer.answerProvenance, 'item_selection');
  });
  testWidgets('reloaded 150 is not truncated by an unchanged slider contact',
      (tester) async {
    final care = CareTestStore()
      ..initial = CareActionLoadResult(
          record: DailyCareActions(dayKey: '2026-10-12', revision: 1, actions: {
        'roomWalk': const CareActionResponse(
            answer: CareActionAnswer.performed,
            details: {'durationMinutes': 150})
      }));
    await tester.pumpWidget(careInputTestApp(CareHealthTestStore(), care));
    await tester.pumpAndSettle();
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
    final finder = find.byKey(const ValueKey('care-duration-slider-roomWalk'));
    final slider = tester.widget<Slider>(finder);
    expect(slider.value, 120);
    expect(slider.onChangeStart, isNull);
    await tester.ensureVisible(finder);
    final bounds = tester.getRect(finder);
    await tester.tapAt(Offset(bounds.right - 1, bounds.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('150 分'), findsOneWidget);
    // No changed gesture value means no mutation. A normal save may confirm another untouched item.
    await save(tester);
    expect(care.saved.single.actions['roomWalk']!.details,
        {'durationMinutes': 150});
  });
  testWidgets(
      'legacy detail/time remain unknown and survive another action change',
      (tester) async {
    final care = CareTestStore()
      ..initial = CareActionLoadResult(
          record: DailyCareActions(dayKey: '2026-10-12', revision: 1, actions: {
        'roomWalk':
            const CareActionResponse(answer: CareActionAnswer.performed),
        'cageCleaning': const CareActionResponse(
            answer: CareActionAnswer.performed, details: {'scope': 'full'})
      }));
    await tester.pumpWidget(careInputTestApp(CareHealthTestStore(), care));
    await tester.pumpAndSettle();
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
    expect(find.text('時間不明'), findsOneWidget);
    expect(
        tester
            .widget<ChoiceChip>(
                find.byKey(const ValueKey('care-cageCleaning-none')))
            .selected,
        isFalse);
    await tester
        .tap(find.byKey(const ValueKey('care-cageCleaning-spot_removal')));
    await save(tester);
    expect(care.saved.single.actions['roomWalk']!.answer,
        CareActionAnswer.performed);
    expect(care.saved.single.actions['roomWalk']!.details, isEmpty);
    expect(care.saved.single.actions['roomWalk']!.answerProvenance, isNull);
  });
  testWidgets('clear response is saved as unanswered instead of batch default',
      (tester) async {
    final care = CareTestStore();
    await tester.pumpWidget(careInputTestApp(CareHealthTestStore(), care));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('care-cageCleaning-partial_cleaning')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('care-clear-cageCleaning')));
    await save(tester);
    expect(care.saved.single.actions['cageCleaning']!.answer,
        CareActionAnswer.unanswered);
    expect(care.saved.single.actions['cageCleaning']!.answerProvenance,
        'unanswered');
  });
  testWidgets(
      'direct input zero is explicit and invalid totals are not accepted',
      (tester) async {
    final care = CareTestStore();
    await tester.pumpWidget(careInputTestApp(CareHealthTestStore(), care));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('care-duration-value-roomWalk')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('care-detail-roomWalk')), '1441');
    await tester.tap(find.text('入力する'));
    await tester.pumpAndSettle();
    expect(find.text('範囲内の整数を入力してください'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('care-detail-roomWalk')), '0');
    await tester.tap(find.text('入力する'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(care.saved.single.actions['roomWalk']!.answer,
        CareActionAnswer.notPerformed);
    expect(care.saved.single.actions['roomWalk']!.answerProvenance,
        'item_selection');
  });
  testWidgets('rapid duplicate save gesture submits one mutation',
      (tester) async {
    final care = _BlockingCareStore();
    await tester.pumpWidget(careInputTestApp(CareHealthTestStore(), care));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('この内容で記録'));
    await tester.tap(find.text('この内容で記録'));
    await tester.tap(find.text('この内容で記録'));
    expect(care.calls, 1);
    care.release.complete();
    await tester.pumpAndSettle();
    expect(care.saved.length, 1);
  });
}

class _BlockingCareStore extends CareTestStore {
  final release = Completer<void>();
  int calls = 0;
  @override
  Future<CareActionSaveResult> save(CareActionMutation mutation) async {
    calls++;
    await release.future;
    return super.save(mutation);
  }
}

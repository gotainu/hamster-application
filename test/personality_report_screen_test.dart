import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/personality_report.dart';
import 'package:hamster_project/screens/personality_report_screen.dart';
import 'package:hamster_project/services/personality_reports_repo.dart';
import 'package:hamster_project/widgets/metric_comparison_bar.dart';

import 'personality_report_fixtures.dart';

class _Source implements PersonalityReportsSource {
  _Source(this.current);
  PersonalityReportState current;
  final changes =
      StreamController<PersonalityReportState>.broadcast(sync: true);
  int listens = 0;
  @override
  Stream<PersonalityReportState> watchLatest() => Stream.multi((sink) {
        listens++;
        sink.add(current);
        final sub = changes.stream.listen(sink.add);
        sink.onCancel = sub.cancel;
      });
  void emit(PersonalityReportState state) {
    current = state;
    changes.add(state);
  }
}

PersonalityReportState _ready(String type,
        {Map<String, dynamic>? population}) =>
    PersonalityReportState.available(
        'owner-a',
        PersonalityReport.fromMap(
            personalityFixture(type: type, population: population)));

Future<void> _show(WidgetTester tester, _Source source,
    {FutureOr<void> Function(PersonalityReport)? onViewed,
    String? expectedOwnerUid}) async {
  await tester.pumpWidget(MaterialApp(
      home: PersonalityReportScreen(
          repo: source,
          expectedOwnerUid: expectedOwnerUid,
          onReportViewed: onViewed)));
  await tester.pump();
}

void main() {
  testWidgets('weight-only shows body and explains activity is not included',
      (tester) async {
    final source = _Source(_ready('weight_only'));
    addTearDown(source.changes.close);
    await _show(tester, source);
    expect(find.text('体重'), findsOneWidget);
    expect(find.text('活動量はこれから'), findsOneWidget);
    expect(find.text('活動量'), findsNothing);
    expect(find.text('100'), findsOneWidget);
    expect(find.textContaining('中央値'), findsNothing);
    expect(find.textContaining('MAD'), findsNothing);
  });
  testWidgets('activity-only shows activity and explains missing body',
      (tester) async {
    final source = _Source(_ready('activity_only'));
    addTearDown(source.changes.close);
    await _show(tester, source);
    expect(find.text('活動量'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('体重はこれから'), 200);
    expect(find.text('体重はこれから'), findsOneWidget);
    expect(find.text('体重'), findsNothing);
  });
  testWidgets('both includes the two metric cards and generated date',
      (tester) async {
    final source = _Source(_ready('both'));
    addTearDown(source.changes.close);
    await _show(tester, source);
    expect(find.text('体重'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('活動量'), 200);
    expect(find.text('活動量'), findsOneWidget);
    expect(find.textContaining('2026/10/8'), findsWidgets);
  });
  testWidgets('loading withholds all report content and A3', (tester) async {
    final source = _Source(const PersonalityReportState.loading('owner-a'));
    var views = 0;
    addTearDown(source.changes.close);
    await _show(tester, source, onViewed: (_) {
      views++;
    });
    expect(find.text('個性レポートを確認しています'), findsOneWidget);
    expect(find.text('体重'), findsNothing);
    expect(views, 0);
  });
  testWidgets('confirmed learning explains preparation without paid or AI CTA',
      (tester) async {
    final source = _Source(const PersonalityReportState.learning('owner-a'));
    addTearDown(source.changes.close);
    await _show(tester, source);
    expect(find.text('うちの子らしさを集めています'), findsOneWidget);
    expect(find.textContaining('有料プラン'), findsNothing);
    expect(find.textContaining('AI相談'), findsNothing);
    expect(find.textContaining('順位'), findsNothing);
  });
  testWidgets('unavailable shows retry and does not fall back to learning',
      (tester) async {
    final source = _Source(const PersonalityReportState.unavailable('owner-a'));
    addTearDown(source.changes.close);
    await _show(tester, source);
    expect(find.text('個性レポートを確認できませんでした'), findsOneWidget);
    expect(find.text('うちの子らしさを集めています'), findsNothing);
    source.current = _ready('weight_only');
    await tester.tap(find.text('再試行'));
    await tester.pump();
    await tester.pump();
    expect(source.listens, 2);
    expect(find.text('体重'), findsOneWidget);
  });
  testWidgets('report remains readable without subscription or trial SDK',
      (tester) async {
    // Firebase is deliberately not initialized: expired trial does not add a gate.
    final source = _Source(_ready('weight_only'));
    addTearDown(source.changes.close);
    await _show(tester, source);
    expect(find.text('体重'), findsOneWidget);
    expect(find.textContaining('契約'), findsNothing);
    expect(find.textContaining('無料体験を始める'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('A3 runs after actual render once per report presentation',
      (tester) async {
    final source = _Source(const PersonalityReportState.loading('owner-a'));
    final viewed = <String>[];
    addTearDown(source.changes.close);
    await _show(tester, source, onViewed: (report) {
      viewed.add(report.reportId);
    });
    expect(viewed, isEmpty);
    source.emit(_ready('weight_only'));
    expect(viewed, isEmpty);
    await tester.pump();
    expect(viewed, ['personality_v1_body']);
    source.emit(_ready('weight_only'));
    await tester.pump();
    expect(viewed, hasLength(1));
    source.emit(_ready('both'));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('personality-overview')), findsOneWidget);
    expect(viewed, ['personality_v1_body', 'personality_v1_body_activity']);
  });
  testWidgets('covered route does not count a view until the report is visible',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    final source = _Source(const PersonalityReportState.loading('owner-a'));
    final viewed = <String>[];
    addTearDown(source.changes.close);
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      home: PersonalityReportScreen(
          repo: source,
          onReportViewed: (report) => viewed.add(report.reportId)),
    ));
    await tester.pump();
    navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('covering route'))));
    await tester.pumpAndSettle();
    source.emit(_ready('weight_only'));
    await tester.pump();
    await tester.pump();
    expect(viewed, isEmpty);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('100'), findsOneWidget);
    expect(viewed, ['personality_v1_body']);
    navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('covering route'))));
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(viewed, ['personality_v1_body']);
  });
  testWidgets(
      'owner-bound route withholds a different owner before first render',
      (tester) async {
    final report = _ready('weight_only').report!;
    final source = _Source(PersonalityReportState.available('owner-b', report));
    var views = 0;
    addTearDown(source.changes.close);
    await _show(tester, source, expectedOwnerUid: 'owner-a', onViewed: (_) {
      views++;
    });
    expect(find.text('100'), findsNothing);
    expect(find.text('体重'), findsNothing);
    expect(find.text('個性レポートを確認できませんでした'), findsOneWidget);
    expect(views, 0);
    await tester.tap(find.text('再試行'));
    await tester.pump();
    await tester.pump();
    expect(find.text('100'), findsNothing);
    expect(views, 0);
  });
  testWidgets(
      'owner-bound route clears A and never displays B with the same ID',
      (tester) async {
    final ready = _ready('weight_only');
    final source = _Source(ready);
    final viewed = <String>[];
    addTearDown(source.changes.close);
    await _show(tester, source,
        expectedOwnerUid: 'owner-a',
        onViewed: (report) => viewed.add(report.reportId));
    expect(find.text('100'), findsOneWidget);
    expect(viewed, ['personality_v1_body']);
    source.emit(const PersonalityReportState.loading('owner-b'));
    await tester.pump();
    source.emit(PersonalityReportState.available('owner-b', ready.report));
    await tester.pump();
    await tester.pump();
    expect(find.text('100'), findsNothing);
    expect(find.text('体重'), findsNothing);
    expect(find.text('個性レポートを確認できませんでした'), findsOneWidget);
    expect(viewed, ['personality_v1_body']);
  });
  testWidgets('account-switch loading clears previous owner content',
      (tester) async {
    final source = _Source(_ready('weight_only'));
    addTearDown(source.changes.close);
    await _show(tester, source);
    source.emit(const PersonalityReportState.loading('owner-b'));
    await tester.pump();
    expect(find.text('体重'), findsNothing);
    expect(find.text('個性レポートを確認しています'), findsOneWidget);
  });
  testWidgets('measurement details are opt-in and explain zero MAD',
      (tester) async {
    final source = _Source(_ready('weight_only'));
    addTearDown(source.changes.close);
    await _show(tester, source);
    final details = find.text('記録の詳細・研究の出典');
    await tester.scrollUntilVisible(details, 200);
    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(find.textContaining('中央値'), findsWidgets);
    expect(find.textContaining('MADが0でも'), findsOneWidget);
  });
  testWidgets(
      'research context has provenance and small sample caution, no ranking',
      (tester) async {
    final source = _Source(
        _ready('weight_only', population: applicablePopulation(small: true)));
    addTearDown(source.changes.close);
    await _show(tester, source);
    await tester.scrollUntilVisible(find.text('体重'), 200);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('body-comparison-delta')),
            matching: find.text('33g')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('body-comparison-delta')),
            matching: find.text('軽め')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('body-comparison-delta')),
            matching: find.text('参考中央値より')),
        findsOneWidget);
    expect(find.textContaining('少数'), findsNothing);
    expect(find.textContaining('パーセンタイル'), findsNothing);
    await tester.scrollUntilVisible(find.text('記録の詳細・研究の出典'), 200);
    await tester.ensureVisible(find.text('記録の詳細・研究の出典'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('記録の詳細・研究の出典'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.textContaining('10.1111/jsap.13527'), 200);
    expect(find.textContaining('10.1111/jsap.13527'), findsOneWidget);
    expect(find.textContaining('成体体重の標本数: 未公表'), findsOneWidget);
    expect(find.text('少数の種別集団のため、比較は慎重に扱ってください。'), findsOneWidget);
  });
  testWidgets(
      'applicable research shows saved center and IQR in graphic legends',
      (tester) async {
    final source =
        _Source(_ready('weight_only', population: applicablePopulation()));
    addTearDown(source.changes.close);
    await _show(tester, source);
    await tester.scrollUntilVisible(find.text('体重'), 200);
    final comparison =
        tester.widget<MetricComparisonBar>(find.byType(MetricComparisonBar));
    expect(comparison.value, 100);
    expect(comparison.referenceValue, 133);
    expect(comparison.referenceStart, 100);
    expect(comparison.referenceEnd, 160);
    expect(find.textContaining('MAD'), findsNothing);
    await tester.scrollUntilVisible(find.text('記録の詳細・研究の出典'), 200);
    await tester.ensureVisible(find.text('記録の詳細・研究の出典'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('記録の詳細・研究の出典'));
    await tester.pumpAndSettle();
    expect(find.text('同種の研究中央値: 133g'), findsOneWidget);
    expect(find.text('研究の中央50%: 100〜160g'), findsOneWidget);
  });
  for (final reason in ['age_unknown', 'not_adult']) {
    testWidgets('inapplicable $reason never shows cohort center or IQR',
        (tester) async {
      final population = applicablePopulation()
        ..['applicability'] = 'not_applicable'
        ..['reason'] = reason
        ..['expressionJa'] = '年齢条件を確認できないため公開研究との比較を適用しません。';
      final source = _Source(_ready('weight_only', population: population));
      addTearDown(source.changes.close);
      await _show(tester, source);
      await tester.scrollUntilVisible(find.text('体重'), 200);
      expect(find.byType(MetricComparisonBar), findsNothing);
      expect(find.textContaining('比較を適用しません'), findsNothing);
      await tester.scrollUntilVisible(find.text('記録の詳細・研究の出典'), 200);
      await tester.ensureVisible(find.text('記録の詳細・研究の出典'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('記録の詳細・研究の出典'));
      await tester.pumpAndSettle();
      expect(find.textContaining('比較を適用しません'), findsOneWidget);
      expect(find.textContaining('研究集団の中心は'), findsNothing);
      expect(find.textContaining('133g'), findsNothing);
      expect(find.textContaining('100〜160g'), findsNothing);
    });
  }
  testWidgets('unknown raw memo or question fields never render',
      (tester) async {
    final data = personalityFixture()
      ..['memo'] = 'PRIVATE_MEMO'
      ..['question'] = 'PRIVATE_QUESTION';
    final source = _Source(PersonalityReportState.available(
        'owner-a', PersonalityReport.fromMap(data)));
    addTearDown(source.changes.close);
    await _show(tester, source);
    expect(find.textContaining('PRIVATE_'), findsNothing);
  });
  testWidgets('view callback failure cannot replace a readable report',
      (tester) async {
    final source = _Source(_ready('weight_only'));
    addTearDown(source.changes.close);
    await _show(tester, source, onViewed: (_) async {
      throw StateError('analytics unavailable');
    });
    await tester.pump();
    expect(find.text('体重'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

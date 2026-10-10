import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/personality_report.dart';
import 'package:hamster_project/screens/personality_report_screen.dart';
import 'package:hamster_project/services/personality_reports_repo.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/widgets/metric_comparison_bar.dart';
import 'package:hamster_project/widgets/metric_pair_comparison_bars.dart';

import 'personality_report_fixtures.dart';
import 'personality_report_v2_ui_fixtures.dart';

class _Source implements PersonalitySpecificReportSource {
  _Source(this.report);
  final PersonalityReport report;
  int latestReads = 0;
  final requested = <String>[];
  @override
  Stream<PersonalityReportState> watchLatest() {
    latestReads++;
    return Stream.value(
        PersonalityReportState.available('synthetic-owner', report));
  }

  @override
  Stream<PersonalityReportState> watchReport(String id) {
    requested.add(id);
    return Stream.value(id == report.reportId
        ? PersonalityReportState.available('synthetic-owner', report)
        : const PersonalityReportState.unavailable('synthetic-owner'));
  }
}

Future<_Source> _show(WidgetTester tester, Map<String, dynamic> data,
    {String? reportId,
    bool dark = false,
    double scale = 1,
    double width = 400,
    FutureOr<void> Function(PersonalityReport)? onViewed}) async {
  tester.view.physicalSize = Size(width, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final source = _Source(PersonalityReport.fromMap(data));
  await tester.pumpWidget(MaterialApp(
    theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
    builder: (context, child) => MediaQuery(
      data:
          MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: PersonalityReportScreen(
        repo: source, reportId: reportId, onReportViewed: onViewed),
  ));
  await tester.pump();
  return source;
}

Future<void> _details(WidgetTester tester) async {
  final title = find.text('記録の詳細・研究の出典');
  await tester.scrollUntilVisible(title, 300);
  await tester.ensureVisible(title);
  await tester.pumpAndSettle();
  await tester.tap(title);
  await tester.pumpAndSettle();
}

void main() {
  for (final type in ['body', 'activity', 'both']) {
    testWidgets('backend daily Gold $type renders the saved daily contract',
        (tester) async {
      final data = jsonDecode(
          File('test/fixtures/personality_v2_daily_gold_$type.json')
              .readAsStringSync()) as Map<String, dynamic>;
      final viewed = <String>[];
      final source = await _show(tester, data,
          reportId: data['reportId'] as String,
          onViewed: (report) => viewed.add(report.reportId));
      expect(source.latestReads, 0);
      expect(source.requested, ['daily_2026-10-10']);
      expect(viewed, ['daily_2026-10-10']);
      if (type != 'activity') expect(find.text('100'), findsOneWidget);
      if (type != 'body') {
        await tester.scrollUntilVisible(find.text('628'), 200);
        expect(find.text('628'), findsOneWidget);
        expect(
            find.descendant(
                of: find.byKey(const ValueKey('personality-activity-card')),
                matching: find.text('普段と同じ')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('comparison-reference-range')),
            findsNothing);
      }
      expect(find.textContaining('628.3185307179587'), findsNothing);
      await _details(tester);
      final cutoffRows =
          find.ancestor(of: find.text('採用最終日'), matching: find.byType(Row));
      expect(find.descendant(of: cutoffRows, matching: find.text('2026-10-09')),
          findsOneWidget);
      final silverRows =
          find.ancestor(of: find.text('Silver基準日'), matching: find.byType(Row));
      expect(find.descendant(of: silverRows, matching: find.text('2026-10-10')),
          findsOneWidget);
      expect(find.textContaining('生成時のデータ基準日:'), findsNothing);
      // The saved Gold notices are unchanged; the screen presents concise,
      // deduplicated equivalents without losing their restrictions.
      for (final notice in [
        '記録に基づく特徴です。肥満・健康・病気の診断ではありません。',
        '日別記録から夜型や深夜の活動は判断できません。',
        'EWMA（平滑化値）だけで長期的な増減は判断できません。',
        'MADが0でも、全記録が同じ値とは限りません。',
        if (type != 'activity') ...[
          '2016年の英国の一次診療の受診記録です。健康な個体の標準体重や日本の全個体を代表しません。',
          '研究は3か月超の各個体の平均体重を集計。本レポートの中央値とは集計方法が異なります。',
          '種別総数は成体体重の標本数ではありません。体重の解析標本数は公開表では未確認です。',
          '研究集団の参考値です。健康上の正常範囲ではありません。',
          '中央値と四分位点だけでは正確なパーセンタイルは求められません。',
        ],
      ]) {
        expect(find.text(notice), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('body snapshot shows 100g and saved 133g / IQR comparison',
      (tester) async {
    await _show(tester, personalityV2UiFixture(type: 'weight_only'));
    expect(find.text('100'), findsOneWidget);
    expect(find.byKey(const ValueKey('personality-body-card')), findsOneWidget);
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
    expect(find.byType(MetricComparisonBar), findsOneWidget);
    final comparison =
        tester.widget<MetricComparisonBar>(find.byType(MetricComparisonBar));
    expect(comparison.value, 100);
    expect(comparison.referenceValue, 133);
    expect(comparison.referenceStart, 100);
    expect(comparison.referenceEnd, 160);
    expect(find.textContaining('MAD:'), findsNothing);
  });
  testWidgets('activity rounds 628m per day, equality has no MAD-derived band',
      (tester) async {
    await _show(tester, personalityV2UiFixture(type: 'activity_only'));
    expect(find.text('628'), findsOneWidget);
    expect(find.text('記録日の中央値'), findsOneWidget);
    expect(find.text('普段と同じ'), findsOneWidget);
    expect(find.byType(MetricPairComparisonBars), findsOneWidget);
    expect(
        find.byKey(const ValueKey('comparison-reference-range')), findsNothing);
    expect(find.textContaining('628.3185307179587'), findsNothing);
  });
  testWidgets('both retains independent body and activity comparisons',
      (tester) async {
    await _show(tester, personalityV2UiFixture());
    expect(find.text('100'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('628'), 300);
    expect(find.text('628'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final reason in ['age_unknown', 'not_adult', 'reference_unavailable']) {
    testWidgets(
        '$reason does not draw saved-but-inapplicable cohort statistics',
        (tester) async {
      final population = applicablePopulation()
        ..['applicability'] = 'not_applicable'
        ..['reason'] = reason
        ..['expressionJa'] = '条件が確認できないため公開研究との比較を適用しません。';
      await _show(tester,
          personalityV2UiFixture(type: 'weight_only', population: population));
      expect(find.byType(MetricComparisonBar), findsNothing);
      expect(find.textContaining('133g'), findsNothing);
      expect(find.textContaining('100〜160g'), findsNothing);
      expect(find.textContaining('比較を適用しません'), findsNothing);
      await _details(tester);
      expect(find.textContaining('比較を適用しません'), findsOneWidget);
      expect(find.textContaining('133g'), findsNothing);
      expect(find.textContaining('100〜160g'), findsNothing);
    });
  }
  testWidgets(
      'missing activity latest value withholds comparison without fake band',
      (tester) async {
    await _show(tester,
        personalityV2UiFixture(type: 'activity_only', activityLatest: null));
    expect(find.text('628'), findsOneWidget);
    expect(find.byKey(const ValueKey('comparison-axis')), findsNothing);
    expect(
        find.byKey(const ValueKey('comparison-reference-range')), findsNothing);
  });
  testWidgets('source and readable statistics are disclosed only in details',
      (tester) async {
    await _show(tester, personalityV2UiFixture());
    expect(find.textContaining('10.1111/jsap.13527'), findsNothing);
    await _details(tester);
    expect(find.textContaining('採用記録の最終日:'), findsNothing);
    final silverRows =
        find.ancestor(of: find.text('Silver基準日'), matching: find.byType(Row));
    expect(find.descendant(of: silverRows, matching: find.text('2026-10-08')),
        findsOneWidget);
    await tester.scrollUntilVisible(
        find.textContaining('10.1111/jsap.13527'), 200);
    expect(find.widgetWithText(TextButton, 'DOI: 10.1111/jsap.13527'),
        findsOneWidget);
    expect(find.textContaining('成体体重の標本数: 未公表'), findsOneWidget);
    expect(find.textContaining('628.3185307179587'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unsafe source DOI is never turned into a launchable link',
      (tester) async {
    final population = applicablePopulation();
    (population['cohort'] as Map<String, dynamic>)['sourceDOI'] =
        'javascript:alert(1)';
    await _show(tester,
        personalityV2UiFixture(type: 'weight_only', population: population));
    await _details(tester);
    expect(find.widgetWithText(TextButton, 'DOI: javascript:alert(1)'),
        findsNothing);
    expect(find.textContaining('javascript:'), findsNothing);
  });
  for (final dark in [false, true]) {
    testWidgets(
        'screen and expanded detail fit width 240 at text scale 3, dark=$dark',
        (tester) async {
      await _show(tester, personalityV2UiFixture(),
          dark: dark, scale: 3, width: 240);
      expect(tester.takeException(), isNull);
      await _details(tester);
      await tester.scrollUntilVisible(
          find.textContaining('10.1111/jsap.13527'), 300,
          maxScrolls: 100);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'explicit reportId reads the immutable report and preserves postframe view callback',
      (tester) async {
    final viewed = <String>[];
    final source = await _show(
        tester, personalityV2UiFixture(type: 'weight_only'),
        reportId: 'personality_v1_body',
        onViewed: (report) => viewed.add(report.reportId));
    expect(source.latestReads, 0);
    expect(source.requested, ['personality_v1_body']);
    expect(viewed, ['personality_v1_body']);
  });
  testWidgets(
      'saved applicable cohort remains comparable if only publication year is missing',
      (tester) async {
    final population = applicablePopulation();
    (population['cohort'] as Map<String, dynamic>).remove('sourceYear');
    await _show(tester,
        personalityV2UiFixture(type: 'weight_only', population: population));
    expect(find.byType(MetricComparisonBar), findsOneWidget);
  });
  testWidgets(
      'screen reader gets baseline units and latest-vs-baseline marker meanings',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _show(tester, personalityV2UiFixture(type: 'activity_only'));
      expect(
          find.bySemanticsLabel('日別記録から見える普段の走行距離、628メートル/日'), findsOneWidget);
      await tester.scrollUntilVisible(
          find.byType(MetricPairComparisonBars), 200);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('普段の基準、628メートル。直近の記録、628メートル。共通のゼロ起点スケール。'),
          findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}

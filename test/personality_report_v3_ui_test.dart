import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/personality_report.dart';
import 'package:hamster_project/services/personality_report_view_service.dart';
import 'package:hamster_project/widgets/metric_comparison_bar.dart';
import 'package:hamster_project/widgets/metric_pair_comparison_bars.dart';

import 'personality_report_fixtures.dart';
import 'personality_report_v3_test_support.dart';

void main() {
  setUpAll(loadPersonalityV3GoldenFonts);
  for (final type in ['weight_only', 'activity_only', 'both']) {
    testWidgets(
        'v3 $type has compact header, large values and meaningful charts',
        (tester) async {
      await showPersonalityV3(tester, personalityV3Fixture(type: type));
      expect(find.widgetWithText(AppBar, 'うちの子の個性レポート'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('personality-overview')), findsOneWidget);
      expect(find.textContaining('作成 '), findsOneWidget);
      expect(find.byIcon(Icons.monitor_weight_outlined), findsNothing);
      expect(find.byIcon(Icons.directions_run_rounded), findsNothing);
      expect(find.byIcon(Icons.pets_rounded), findsNothing);
      if (type != 'activity_only') {
        expect(find.text('体重'), findsOneWidget);
        expect(find.text('100'), findsOneWidget);
        expect(find.text('g'), findsOneWidget);
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
      }
      if (type != 'weight_only') {
        await tester.scrollUntilVisible(
            find.byType(MetricPairComparisonBars), 200);
        expect(find.text('活動量'), findsOneWidget);
        expect(find.text('628'), findsOneWidget);
        expect(find.text('m / 日'), findsOneWidget);
        expect(find.byType(MetricPairComparisonBars), findsOneWidget);
        expect(find.text('普段と同じ'), findsWidgets);
        expect(
            find.byKey(const ValueKey('pair-reference-fill')), findsOneWidget);
        expect(find.byKey(const ValueKey('pair-value-fill')), findsOneWidget);
      }
      expect(find.textContaining('628.318530'), findsNothing);
      expect(find.textContaining('MAD'), findsNothing);
      expect(find.textContaining('personality_v1'), findsNothing);
      expect(find.textContaining('published_weight_v1'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final type in ['body', 'activity', 'both']) {
    testWidgets('saved backend daily Gold $type remains renderable in v3',
        (tester) async {
      final data = savedPersonalityV3Fixture(type);
      final viewed = <String>[];
      final source = await showPersonalityV3(tester, data,
          reportId: data['reportId'] as String,
          onViewed: (report) => viewed.add(report.reportId));
      expect(source.latestReads, 0);
      expect(source.requestedIds, ['daily_2026-10-10']);
      expect(viewed, ['daily_2026-10-10']);
      if (type != 'activity') expect(find.text('100'), findsOneWidget);
      if (type != 'body') {
        await tester.scrollUntilVisible(find.text('628'), 250);
        expect(find.text('628'), findsOneWidget);
      }
      await expandPersonalityV3Details(tester);
      final cutoffRows =
          find.ancestor(of: find.text('採用最終日'), matching: find.byType(Row));
      expect(find.descendant(of: cutoffRows, matching: find.text('2026-10-09')),
          findsOneWidget);
      final silverRows =
          find.ancestor(of: find.text('Silver基準日'), matching: find.byType(Row));
      expect(find.descendant(of: silverRows, matching: find.text('2026-10-10')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final reason in [
    'reference_unavailable',
    'species_unknown',
    'age_unknown',
    'not_adult',
  ]) {
    testWidgets('$reason withholds cohort discovery and graphic',
        (tester) async {
      final population = applicablePopulation()
        ..['applicability'] = 'not_applicable'
        ..['reason'] = reason
        ..['expressionJa'] = '比較条件が確認できないため公開研究との比較を適用しません。';
      await showPersonalityV3(tester,
          personalityV3Fixture(type: 'weight_only', population: population));
      expect(find.text('100'), findsOneWidget);
      expect(find.byType(MetricComparisonBar), findsNothing);
      expect(find.textContaining('参考中央値より'), findsNothing);
      expect(find.textContaining('133g'), findsNothing);
      expect(find.textContaining('100〜160g'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'IQR boundary, median and extreme values have proportional positions',
      (tester) async {
    for (final value in [100.0, 133.0, 160.0, 30.0, 400.0]) {
      await showPersonalityV3(
          tester, personalityV3Fixture(type: 'weight_only', bodyMedian: value));
      final range = tester
          .getRect(find.byKey(const ValueKey('comparison-reference-range')));
      final individual = tester
          .getCenter(find.byKey(const ValueKey('comparison-value-marker')))
          .dx;
      final median = tester
          .getCenter(find.byKey(const ValueKey('comparison-reference-marker')))
          .dx;
      expect((median - range.left) / range.width, closeTo(33 / 60, 0.015));
      if (value == 100) expect(individual, closeTo(range.left, 0.01));
      if (value == 133) expect(individual, closeTo(median, 0.01));
      if (value == 160) expect(individual, closeTo(range.right, 0.01));
      if (value < 100) expect(individual, lessThan(range.left));
      if (value > 160) expect(individual, greaterThan(range.right));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'equal activity bars have identical length and no fabricated MAD band',
      (tester) async {
    await showPersonalityV3(
        tester, personalityV3Fixture(type: 'activity_only'));
    expect(
        tester.getSize(find.byKey(const ValueKey('pair-reference-fill'))).width,
        tester.getSize(find.byKey(const ValueKey('pair-value-fill'))).width);
    expect(
        find.byKey(const ValueKey('comparison-reference-range')), findsNothing);
    expect(find.text('普段と同じ'), findsWidgets);
    expect(find.textContaining('正常範囲'), findsNothing);
    expect(find.textContaining('全記録'), findsNothing);
    expect(find.textContaining('平均'), findsNothing);
    expect(find.textContaining('夜型'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unequal activity uses common scale and saved measurements',
      (tester) async {
    await showPersonalityV3(
        tester,
        personalityV3Fixture(
            type: 'activity_only', activityMedian: 500, activityLatest: 1000));
    final reference =
        tester.getSize(find.byKey(const ValueKey('pair-reference-fill'))).width;
    final value =
        tester.getSize(find.byKey(const ValueKey('pair-value-fill'))).width;
    expect(value / reference, closeTo(2, 0.001));
    expect(find.textContaining('500m'), findsWidgets);
    expect(find.textContaining('1000m'), findsWidgets);
    expect(
        find.byKey(const ValueKey('comparison-reference-range')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'missing latest measurement keeps baseline without inventing comparison',
      (tester) async {
    await showPersonalityV3(tester,
        personalityV3Fixture(type: 'activity_only', activityLatest: null));
    expect(find.text('628'), findsOneWidget);
    expect(find.byKey(const ValueKey('pair-value-fill')), findsNothing);
    expect(find.text('普段と同じ'), findsNothing);
    expect(
        find.byKey(const ValueKey('activity-comparison-delta')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'statistics and safe DOI are collapsed then expanded and launchable',
      (tester) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await showPersonalityV3(tester, personalityV3Fixture());
    expect(find.textContaining('MAD'), findsNothing);
    expect(find.textContaining('10.1111/jsap.13527'), findsNothing);
    await expandPersonalityV3Details(tester);
    expect(find.textContaining('MAD'), findsWidgets);
    final recordRows =
        find.ancestor(of: find.text('有効記録数'), matching: find.byType(Row));
    expect(find.descendant(of: recordRows, matching: find.text('8日 / 14日間')),
        findsNWidgets(2));
    expect(find.textContaining('14日'), findsWidgets);
    final doi = find.widgetWithText(TextButton, 'DOI: 10.1111/jsap.13527');
    await tester.ensureVisible(doi);
    await tester.pumpAndSettle();
    await tester.tap(doi);
    await tester.pumpAndSettle();
    expect(calls.where((call) => call.method == 'launch'), hasLength(1));
    final args = calls.single.arguments as Map;
    expect(args['url'], 'https://doi.org/10.1111/jsap.13527');
    expect(args['useWebView'], false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid DOI cannot become an executable link', (tester) async {
    final population = applicablePopulation();
    (population['cohort'] as Map<String, dynamic>)['sourceDOI'] =
        'javascript:alert(1)';
    await showPersonalityV3(tester,
        personalityV3Fixture(type: 'weight_only', population: population));
    await expandPersonalityV3Details(tester);
    expect(find.textContaining('javascript:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
        'width240, textscale3, inset34 fits collapsed and expanded dark=$dark',
        (tester) async {
      await showPersonalityV3(tester, personalityV3Fixture(),
          dark: dark, width: 240, height: 1000, textScale: 3, bottomInset: 34);
      expect(tester.takeException(), isNull);
      final number = find.text('100');
      await tester.scrollUntilVisible(number, 300, maxScrolls: 120);
      await tester.ensureVisible(number);
      await tester.pumpAndSettle();
      final paragraph = tester.renderObject<RenderParagraph>(number);
      expect(
        paragraph.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 3),
        ),
        hasLength(1),
        reason:
            'A numeric value must remain one visual token at large text scale.',
      );
      final card =
          tester.getRect(find.byKey(const ValueKey('personality-body-card')));
      final numberBounds = tester.getRect(number);
      expect(numberBounds.left, greaterThanOrEqualTo(card.left));
      expect(numberBounds.right, lessThanOrEqualTo(card.right));
      await expandPersonalityV3Details(tester);
      final doi = find.textContaining('10.1111/jsap.13527');
      await tester.scrollUntilVisible(doi, 300, maxScrolls: 140);
      await tester.ensureVisible(doi);
      await tester.pumpAndSettle();
      expect(tester.getRect(doi).bottom, lessThanOrEqualTo(966));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('screen readers receive values, units and pair meanings',
      (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await showPersonalityV3(
          tester, personalityV3Fixture(type: 'activity_only'));
      expect(find.bySemanticsLabel(RegExp('628.*メートル')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('普段.*628')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('直近.*628')), findsWidgets);
    } finally {
      handle.dispose();
    }
  });

  testWidgets(
      'historical exact-ID viewing marks only that report and never latest',
      (tester) async {
    final marked = <String>[];
    final events = <Map<String, Object>>[];
    final service = PersonalityReportViewService(
      currentUid: () => 'synthetic-owner',
      markReportViewed: (_, reportId) async => marked.add(reportId),
      markFirstView: (_) async => false,
      logView: (event) async => events.add(event),
    );
    final old = personalityV3Fixture(type: 'weight_only');
    final id = old['reportId'] as String;
    final source = await showPersonalityV3(tester, old,
        reportId: id,
        expectedOwnerUid: 'synthetic-owner', onViewed: (report) async {
      await service.recordView(
          ownerUid: 'synthetic-owner',
          reportId: report.reportId,
          petId: report.petId,
          schemaVersion: report.schemaVersion,
          presentationId: 'synthetic-history');
    });
    expect(source.latestReads, 0);
    expect(source.requestedIds, [id]);
    expect(marked, [id]);
    expect(events.single['report_id'], id);
    expect(marked, isNot(contains('daily_2026-10-10')));
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
        'Samsung viewport shows compact cards and one introduction dark=$dark',
        (tester) async {
      await showPersonalityV3(
        tester,
        personalityV3Fixture(),
        dark: dark,
        goldenFont: true,
        width: personalitySamsungViewport.width,
        height: personalitySamsungViewport.height,
        topInset: personalitySamsungTopInset,
        bottomInset: personalitySamsungBottomInset,
        asPushedRoute: true,
      );
      expect(find.byType(BackButton), findsOneWidget);
      final overview = find.byKey(const ValueKey('personality-overview'));
      expect(overview, findsOneWidget);
      expect(
        find.descendant(
            of: overview, matching: find.byType(Text), matchRoot: true),
        findsOneWidget,
      );
      expect(find.text('この子の特徴'), findsNothing);
      expect(find.text('同種の参考中央値より軽め'), findsNothing);
      expect(find.text('走行距離は普段と同じ水準'), findsNothing);
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
      expect(find.text('普段と同じ'), findsOneWidget);
      expect(find.text('この子の普段の体重: 100g'), findsNothing);
      expect(find.text('同種の研究中央値: 133g'), findsNothing);
      expect(find.text('研究の中央50%: 100〜160g'), findsNothing);
      expect(find.textContaining('正常範囲'), findsNothing);
      expect(find.textContaining('MAD'), findsNothing);
      final body =
          tester.getRect(find.byKey(const ValueKey('personality-body-card')));
      final activity = tester
          .getRect(find.byKey(const ValueKey('personality-activity-card')));
      expect(body.height, lessThanOrEqualTo(300));
      expect(activity.height, lessThanOrEqualTo(235));
      final contentBottom =
          personalitySamsungViewport.height - personalitySamsungBottomInset;
      expect(tester.getRect(find.text('100')).bottom, lessThan(contentBottom));
      expect(tester.getRect(find.text('628')).bottom, lessThan(contentBottom));
      expect(
          tester.getRect(find.byKey(const ValueKey('pair-value-fill'))).bottom,
          lessThanOrEqualTo(contentBottom));
      expect(tester.takeException(), isNull);
      await expandPersonalityV3Details(tester);
      expect(find.textContaining('MAD'), findsWidgets);
      expect(find.textContaining('10.1111/jsap.13527'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'expanded notices are concise and deduplicated without dropping unknown study limits',
      (tester) async {
    const diagnosis = '記録に基づく特徴です。肥満・健康・病気の診断ではありません。';
    const mad = 'MADが0でも、全記録が同じ値とは限りません。';
    const qualification = 'この研究には個別の適用条件があります。';
    final population = applicablePopulation()
      ..['limitations'] = [diagnosis, mad, qualification];
    final data = personalityV3Fixture(population: population);
    data['limitations'] = [
      '観察記録に基づく特徴の説明です。肥満・健康・病気の診断ではありません。',
      'MADが0でも、すべての記録が同じ値だったことを意味しません。',
      qualification,
    ];
    await showPersonalityV3(tester, data);
    expect(find.text(diagnosis), findsNothing);
    expect(find.text(mad), findsNothing);
    await expandPersonalityV3Details(tester);
    expect(find.text(diagnosis), findsOneWidget);
    expect(find.text(mad), findsOneWidget);
    expect(find.text(qualification), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('covered detail records no view until successfully displayed',
      (tester) async {
    final source = PersonalityV3Source(
        const PersonalityReportState.learning('synthetic-owner'));
    addTearDown(source.close);
    final navigator = GlobalKey<NavigatorState>();
    final viewed = <String>[];
    final data = personalityV3Fixture(type: 'weight_only');
    await showPersonalityV3(tester, data,
        source: source,
        navigatorKey: navigator,
        onViewed: (report) => viewed.add(report.reportId));
    expect(viewed, isEmpty);
    navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('covering route'))));
    await tester.pumpAndSettle();
    source.emit(personalityV3Ready(data));
    await tester.pump();
    expect(viewed, isEmpty);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('100'), findsOneWidget);
    expect(viewed, ['personality_v1_body']);
    source.emit(personalityV3Ready(data));
    await tester.pumpAndSettle();
    expect(viewed, hasLength(1));
  });
}

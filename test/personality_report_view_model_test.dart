import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/personality_report.dart';
import 'package:hamster_project/viewmodels/personality_report_view_model.dart';

import 'personality_report_fixtures.dart';
import 'personality_report_v2_ui_fixtures.dart';

PersonalityReportViewModel _model({
  String type = 'both',
  String? reportId,
  double body = 100,
  double activity = 628.3185307179587,
  double? activityLatest = 628.3185307179587,
  Map<String, dynamic>? population,
}) =>
    PersonalityReportViewModel(PersonalityReport.fromMap(personalityV2UiFixture(
      type: type,
      reportId: reportId,
      bodyMedian: body,
      activityMedian: activity,
      activityLatest: activityLatest,
      population: population,
    )));

void main() {
  test('overview is one observation-based sentence, not card comparisons', () {
    final vm = _model();
    expect(vm.overviewSummary, '14日間の観察から見える、この子らしさ。');
    expect(vm.overviewSummary, isNot(contains('参考中央値')));
    expect(vm.overviewSummary, isNot(contains('同じ水準')));
    expect(vm.overviewSummary, isNot(contains('33g')));
    expect(vm.overviewSummary, isNot(contains('628')));
  });

  test('partial ready overview uses its saved observation span', () {
    for (final type in ['weight_only', 'activity_only']) {
      final data = personalityV2UiFixture(type: type);
      final metric = type == 'weight_only' ? 'body' : 'activity';
      (data['metrics'] as Map)[metric]['baseline']['spanDays'] = 25;
      final vm = PersonalityReportViewModel(PersonalityReport.fromMap(data));
      expect(vm.overviewSummary, '25日間の観察から見える、この子らしさ。');
    }
  });

  test('different metric periods do not invent a common observation duration',
      () {
    final data = personalityV2UiFixture();
    (data['metrics'] as Map)['activity']['baseline']['spanDays'] = 21;
    (data['metrics'] as Map)['activity']['baseline']['firstDateKey'] =
        '2026-09-15';
    final vm = PersonalityReportViewModel(PersonalityReport.fromMap(data));
    expect(vm.overviewSummary, '記録から見える、この子の体重と活動量。');
    expect(vm.overviewSummary, isNot(contains('14')));
    expect(vm.overviewSummary, isNot(contains('21')));
    expect(vm.overviewSummary, isNot(contains('35')));
  });

  test('same duration with distinct dates does not claim a shared period', () {
    final data = personalityV2UiFixture();
    (data['metrics'] as Map)['activity']['baseline']['firstDateKey'] =
        '2026-09-23';
    (data['metrics'] as Map)['activity']['baseline']['lastDateKey'] =
        '2026-10-06';
    final vm = PersonalityReportViewModel(PersonalityReport.fromMap(data));
    expect(vm.overviewSummary, '記録から見える、この子の体重と活動量。');
  });

  test('overview is based on saved snapshot for legacy and daily reports', () {
    final legacy = _model();
    final daily = _model(reportId: 'daily_2026-10-09');
    expect(daily.overviewSummary, legacy.overviewSummary);
    expect(daily.overviewSummary, isNot(contains('今日')));
  });

  test('body-only presents saved baseline and applicable research difference',
      () {
    final vm = _model(type: 'weight_only');
    expect(vm.body!.title, '体重');
    expect(vm.body!.value, '100');
    expect(vm.body!.unit, 'g');
    expect(vm.body!.caption, 'この子の普段の体重');
    expect(vm.body!.summary, '同種の参考中央値より33g軽め');
    expect(vm.activity, isNull);
    expect(vm.discoveries, ['同種の参考中央値より軽め']);
    expect(vm.body!.populationApplicable, isTrue);
  });

  test('activity-only uses recorded-day median and saved latest value', () {
    final vm = _model(type: 'activity_only');
    expect(vm.body, isNull);
    expect(vm.activity!.title, '活動量');
    expect(vm.activity!.value, '628');
    expect(vm.activity!.unit, 'm / 日');
    expect(vm.activity!.caption, '日別記録から見える普段の走行距離');
    expect(vm.activity!.baselineValueLabel, '628m');
    expect(vm.activity!.latestValueLabel, '628m');
    expect(vm.activity!.summary, '普段と同じ水準');
    expect(vm.discoveries, ['走行距離は普段と同じ水準']);
  });

  test('both discoveries are concise and ordered without report text copies',
      () {
    final vm = _model();
    expect(vm.discoveries, ['同種の参考中央値より軽め', '走行距離は普段と同じ水準']);
    expect(vm.discoveries.join(), isNot(contains('100')));
    expect(vm.discoveries.join(), isNot(contains('628')));
    expect(vm.discoveries.join(), isNot(contains('夜型')));
  });

  test('equal and above-reference weights keep accurate comparison wording',
      () {
    expect(_model(body: 133).body!.summary, '同種の参考中央値と同じ水準');
    expect(_model(body: 133).body!.discovery, '同種の参考中央値と同じ水準');
    expect(_model(body: 170.5).body!.summary, '同種の参考中央値より37.5g重め');
    expect(_model(body: 170.5).body!.discovery, '同種の参考中央値より重め');
  });

  test('comparison pill uses saved body reference delta and compact caption',
      () {
    final below = _model().body!;
    expect(below.comparisonDeltaValue, '33g');
    expect(below.comparisonDeltaCaption, '軽め');
    expect(below.comparisonDeltaContext, '参考中央値より');
    final above = _model(body: 150).body!;
    expect(above.comparisonDeltaValue, '17g');
    expect(above.comparisonDeltaCaption, '重め');
    expect(above.summary, '同種の参考中央値より17g重め');
  });

  test('activity comparison pill keeps signed differences and equal values',
      () {
    final longer = _model(activity: 600, activityLatest: 750).activity!;
    final shorter = _model(activity: 600, activityLatest: 500).activity!;
    final same = _model().activity!;
    expect(longer.comparisonDeltaValue, '+150m');
    expect(longer.comparisonDeltaCaption, '普段より長い');
    expect(longer.comparisonDeltaContext, isNull);
    expect(shorter.comparisonDeltaValue, '−100m');
    expect(shorter.comparisonDeltaCaption, '普段より短い');
    expect(same.comparisonDeltaValue, '±0m');
    expect(same.comparisonDeltaCaption, '普段と同じ');
    final sameBody = _model(body: 133).body!;
    expect(sameBody.comparisonDeltaValue, '0g');
    expect(sameBody.comparisonDeltaCaption, '同じ水準');
    expect(sameBody.comparisonDeltaContext, '参考中央値と');
  });

  test('comparison pill does not round small actual differences into equality',
      () {
    final tiny = _model(body: 132.99, activity: 628, activityLatest: 628.01);
    expect(tiny.body!.comparisonDeltaValue, '0.1g未満');
    expect(tiny.body!.comparisonDeltaCaption, '軽め');
    expect(tiny.activity!.comparisonDeltaValue, '+1m未満');
    expect(tiny.activity!.comparisonDeltaCaption, '普段より長い');
    final shorter = _model(activity: 628, activityLatest: 627.99).activity!;
    expect(shorter.comparisonDeltaValue, '−1m未満');
    expect(shorter.comparisonDeltaCaption, '普段より短い');
  });

  test('comparison pill is withheld for unknown reference or missing latest',
      () {
    final population = applicablePopulation()
      ..['applicability'] = 'not_applicable'
      ..['reason'] = 'species_unknown';
    final vm = _model(population: population, activityLatest: null);
    for (final metric in [vm.body!, vm.activity!]) {
      expect(metric.comparisonDeltaValue, isNull);
      expect(metric.comparisonDeltaCaption, isNull);
      expect(metric.comparisonDeltaContext, isNull);
    }
  });

  test('latest weight difference is distinct from population difference', () {
    final data = personalityV2UiFixture(type: 'weight_only');
    (data['metrics'] as Map)['body']['latestValue'] = 104.5;
    final vm = PersonalityReportViewModel(PersonalityReport.fromMap(data));
    expect(vm.body!.summary, '同種の参考中央値より33g軽め');
    expect(vm.body!.latestComparison, '普段より4.5g重め');
    expect(vm.body!.latestValueLabel, '104.5g');
  });

  for (final reason in [
    'reference_unavailable',
    'species_unknown',
    'age_unknown',
    'not_adult'
  ]) {
    test('inapplicable $reason suppresses all population discoveries', () {
      final population = applicablePopulation()
        ..['applicability'] = 'not_applicable'
        ..['reason'] = reason;
      final vm = _model(type: 'weight_only', population: population);
      expect(vm.body!.populationApplicable, isFalse);
      expect(vm.body!.summary, 'この子の記録から見える普段の体重');
      expect(vm.body!.discovery, isNull);
      expect(vm.discoveries, isEmpty);
      expect(vm.body!.snapshot.population!.reason, reason);
      expect(
          vm.body!.snapshot.population!.sourceTitle, 'Published hamster study');
    });
  }

  test(
      'missing population preserves individual data without fabricated reference',
      () {
    final data = personalityV2UiFixture(type: 'weight_only');
    (data['metrics'] as Map)['body'].remove('populationComparison');
    final vm = PersonalityReportViewModel(PersonalityReport.fromMap(data));
    expect(vm.body!.populationApplicable, isFalse);
    expect(vm.body!.referenceDoiUri, isNull);
    expect(vm.body!.value, '100');
    expect(vm.discoveries, isEmpty);
  });

  test('activity changes use precise saved value differences', () {
    expect(_model(activity: 600, activityLatest: 750).activity!.summary,
        '普段より150m長い');
    expect(_model(activity: 600, activityLatest: 500).activity!.summary,
        '普段より100m短い');
    expect(_model(activity: 600, activityLatest: 750).activity!.discovery,
        '走行距離は普段より長め');
  });

  test('rounding never turns a nonzero difference into an equal comparison',
      () {
    final population = applicablePopulation();
    final vm = _model(
        body: 132.99,
        activity: 628,
        activityLatest: 628.01,
        population: population);
    expect(vm.body!.summary, '同種の参考中央値より0.1g未満軽め');
    expect(vm.activity!.summary, '普段より1m未満長い');
    expect(vm.activity!.discovery, '走行距離は普段より長め');
  });

  test('latest value missing displays unavailable and creates no discovery',
      () {
    final vm = _model(type: 'activity_only', activityLatest: null);
    expect(vm.activity!.latestValueLabel, '未記録');
    expect(vm.activity!.summary, '日別記録から見える普段の走行距離');
    expect(vm.activity!.latestComparison, isNull);
    expect(vm.activity!.discovery, isNull);
    expect(vm.discoveries, isEmpty);
  });

  test(
      'zero baseline and zero latest remain valid and generate no invented range',
      () {
    final vm = _model(type: 'activity_only', activity: 0, activityLatest: 0);
    expect(vm.activity!.value, '0');
    expect(vm.activity!.summary, '普段と同じ水準');
    expect(vm.activity!.madDetail, 'MAD: 0m');
    expect(vm.activity!.summary, isNot(contains('正常')));
    expect(vm.activity!.summary, isNot(contains('すべて')));
  });

  test('JST generated date is deterministic across UTC midnight', () {
    final data = personalityV2UiFixture();
    data['generatedAt'] = Timestamp.fromDate(DateTime.utc(2026, 10, 7, 23, 9));
    final vm = PersonalityReportViewModel(PersonalityReport.fromMap(data));
    expect(vm.generatedAtLabel, '2026/10/8 08:09 JST');
    expect(vm.generatedAtLabel, isNot(contains('2026/10/7')));
  });

  test('legacy and daily reports retain distinct saved provenance', () {
    final legacy = _model();
    final daily = _model(reportId: 'daily_2026-10-09');
    expect(legacy.isDaily, isFalse);
    expect(daily.isDaily, isTrue);
    expect(daily.evaluationDateLabel, '2026-10-09');
    expect(daily.cutoffDateLabel, '2026-10-08');
    expect(daily.silverDateLabel, '2026-10-09');
    expect(legacy.body!.snapshot.firstDateKey, '2026-09-22');
    expect(legacy.body!.recordDetail, '有効記録数: 8日');
    expect(legacy.body!.observationDetail, '観察期間: 2026-09-22〜2026-10-05（14日間）');
  });

  test('aligned statistics details format saved values independently of labels',
      () {
    final vm = _model();
    expect(vm.body!.medianValueDetail, '100g');
    expect(vm.activity!.medianValueDetail, '628.32m');
    expect(vm.body!.madValueDetail, '0g');
    expect(vm.activity!.madValueDetail, '0m');
    expect(vm.body!.observationPeriodLabel, '2026-09-22〜2026-10-05');
    expect(vm.body!.observationCoverageLabel, '8日 / 14日間');
    expect(vm.body!.medianDetail, '中央値: 100g');
    expect(vm.activity!.madDetail, 'MAD: 0m');
    final data = personalityV2UiFixture(type: 'weight_only');
    ((data['metrics'] as Map)['body']['baseline'] as Map).remove('mad');
    final missing = PersonalityReportViewModel(PersonalityReport.fromMap(data));
    expect(missing.body!.madValueDetail, '未算出');
    expect(missing.body!.madDetail, 'MAD: 未算出');
  });

  test('details retain nonzero subprecision values rather than displaying zero',
      () {
    final data = personalityV2UiFixture(type: 'activity_only');
    (data['metrics'] as Map)['activity']['baseline']['mad'] = 0.00034;
    final vm = PersonalityReportViewModel(PersonalityReport.fromMap(data));
    expect(vm.activity!.madDetail, 'MAD: 0.00034m');
    expect(vm.activity!.medianDetail, '中央値: 628.32m');
  });

  test(
      'population detail labels format saved reference values only when applicable',
      () {
    final population = applicablePopulation();
    final cohort = population['cohort'] as Map;
    cohort['median'] = 133.333333;
    cohort['p25'] = 100.123456;
    cohort['p75'] = 160.456789;
    final vm = _model(population: population);
    expect(vm.body!.populationMedianDetail, '同種の研究中央値: 133.33g');
    expect(vm.body!.populationRangeDetail, '研究の中央50%: 100.12〜160.46g');
    expect(vm.activity!.populationMedianDetail, isNull);
    expect(vm.activity!.populationRangeDetail, isNull);
    population['applicability'] = 'not_applicable';
    population['reason'] = 'age_unknown';
    final unavailable = _model(population: population);
    expect(unavailable.body!.populationMedianDetail, isNull);
    expect(unavailable.body!.populationRangeDetail, isNull);
    population['applicability'] = 'applicable';
    population['reason'] = null;
    (population['cohort'] as Map)['p25'] = null;
    final missing = _model(population: population);
    expect(missing.body!.populationMedianDetail, isNull);
    expect(missing.body!.populationRangeDetail, isNull);
  });

  test('DOI links are limited to saved valid DOI on the official resolver', () {
    expect(_model().body!.referenceDoiUri.toString(),
        'https://doi.org/10.1111/jsap.13527');
    for (final doi in [
      'https://other.example/path',
      'javascript:alert(1)',
      '10.1111/jsap.13527?x=1'
    ]) {
      final population = applicablePopulation();
      (population['cohort'] as Map)['sourceDOI'] = doi;
      expect(_model(population: population).body!.referenceDoiUri, isNull);
    }
  });

  test(
      'limitations are deduplicated while source and small-sample caution survive',
      () {
    final data =
        personalityV2UiFixture(population: applicablePopulation(small: true));
    data['limitations'] = ['Saved caution', 'Saved caution'];
    (data['metrics'] as Map)['body']['populationComparison']
        ['limitations'] = ['Saved caution', 'Study limitation'];
    final vm = PersonalityReportViewModel(PersonalityReport.fromMap(data));
    expect(vm.limitations, ['Saved caution', 'Study limitation']);
    expect(vm.body!.snapshot.population!.sampleSizeCaution, isTrue);
    expect(vm.body!.snapshot.population!.population,
        'UK primary veterinary care, 2016');
    expect(() => vm.limitations.add('x'), throwsUnsupportedError);
    expect(() => vm.discoveries.add('x'), throwsUnsupportedError);
  });

  test('display notices keep each statistical limit in concise wording', () {
    final data = personalityV2UiFixture();
    data['limitations'] = [
      '観察記録に基づく特徴の説明です。肥満・健康・病気の診断ではありません。',
      '日別の活動記録から、夜型や深夜に活発かどうかは判断できません。',
      '平滑化した値だけで、長期的な増減は断定できません。',
      'MADが0でも、すべての記録が同じ値だったことを意味しません。',
      '2016年の英国の一次診療施設を受診したハムスターの記録であり、健康な個体だけの標準体重や日本の全個体を代表するものではありません。',
      '論文は各個体の3か月超の体重記録の平均を集計しています。比較する個体のベースライン中央値とは測定のまとめ方が異なります。',
      '表の種別総個体数は成人体重を解析した標本数ではありません。成人体重の種別解析数は公開表からは確認できません。',
      '中央値と四分位点だけでは正確なパーセンタイルは計算できず、中央50%の範囲を健康・異常の判定に使うことはできません。',
    ];
    (data['metrics'] as Map)['body']['populationComparison']
        ['limitations'] = [];
    final report = PersonalityReport.fromMap(data);
    final vm = PersonalityReportViewModel(report);
    expect(vm.detailsLimitations, [
      '記録に基づく特徴です。肥満・健康・病気の診断ではありません。',
      '日別記録から夜型や深夜の活動は判断できません。',
      'EWMA（平滑化値）だけで長期的な増減は判断できません。',
      'MADが0でも、全記録が同じ値とは限りません。',
      '2016年の英国の一次診療の受診記録です。健康な個体の標準体重や日本の全個体を代表しません。',
      '研究は3か月超の各個体の平均体重を集計。本レポートの中央値とは集計方法が異なります。',
      '種別総数は成体体重の標本数ではありません。体重の解析標本数は公開表では未確認です。',
      '研究集団の参考値です。健康上の正常範囲ではありません。',
      '中央値と四分位点だけでは正確なパーセンタイルは求められません。',
    ]);
    expect(report.limitations, data['limitations']);
    expect(vm.limitations, data['limitations']);
    expect(() => vm.detailsLimitations.add('x'), throwsUnsupportedError);
  });

  test('display notices preserve unknown and small Campbell cohort warnings',
      () {
    const caution = 'キャンベルは種別総数52匹と少数です。成人体重の解析標本数は不明なので比較結果を慎重に扱ってください。';
    final data = personalityV2UiFixture();
    data['limitations'] = [caution, 'Future study qualification'];
    (data['metrics'] as Map)['body']['populationComparison']
        ['limitations'] = [caution];
    final vm = PersonalityReportViewModel(PersonalityReport.fromMap(data));
    expect(vm.detailsLimitations, [
      caution,
      'Future study qualification',
      '研究集団の参考値です。健康上の正常範囲ではありません。',
    ]);
    expect(vm.body!.snapshot.population!.sourceDoi, '10.1111/jsap.13527');
  });

  test('already concise and original notices do not duplicate the same meaning',
      () {
    final data = personalityV2UiFixture();
    data['limitations'] = [
      'MADが0でも、すべての記録が同じ値だったことを意味しません。',
      'MADが0でも、全記録が同じ値とは限りません。',
    ];
    (data['metrics'] as Map)['body']['populationComparison']
        ['limitations'] = [];
    final vm = PersonalityReportViewModel(PersonalityReport.fromMap(data));
    expect(vm.detailsLimitations, [
      'MADが0でも、全記録が同じ値とは限りません。',
      '研究集団の参考値です。健康上の正常範囲ではありません。',
    ]);
    expect(vm.limitations, hasLength(2));
  });

  test(
      'reference notices appear once and retain percentile and sample cautions',
      () {
    const normal = '研究集団の参考値です。健康上の正常範囲ではありません。';
    const percentile = '中央値と四分位点だけでは正確なパーセンタイルは求められません。';
    const sample = '少数の種別集団のため、比較は慎重に扱ってください。';
    const campbell = 'キャンベルは種別総数52匹と少数です。成人体重の解析標本数は不明なので比較結果を慎重に扱ってください。';
    final data =
        personalityV2UiFixture(population: applicablePopulation(small: true));
    data['limitations'] = [
      '中央値と四分位点だけでは正確なパーセンタイルは計算できず、中央50%の範囲を健康・異常の判定に使うことはできません。',
      '中央50%の範囲を健康・異常の判定に使うことはできません。',
      normal,
      campbell,
    ];
    (data['metrics'] as Map)['body']['populationComparison']
        ['limitations'] = [normal];
    final report = PersonalityReport.fromMap(data);
    final vm = PersonalityReportViewModel(report);
    expect(vm.detailsLimitations.where((text) => text == normal), hasLength(1));
    expect(vm.detailsLimitations, contains(percentile));
    expect(vm.detailsLimitations, contains(sample));
    expect(vm.detailsLimitations, contains(campbell));
    expect(report.limitations, data['limitations']);
    expect(vm.limitations, contains(campbell));
    final activity = _model(type: 'activity_only');
    expect(activity.detailsLimitations, isNot(contains(normal)));
    expect(activity.detailsLimitations, isNot(contains(sample)));
  });

  test('unknown memo and private question are never copied into presentation',
      () {
    final data = personalityV2UiFixture()
      ..['memo'] = 'PRIVATE_MEMO'
      ..['question'] = 'PRIVATE_QUESTION';
    final vm = PersonalityReportViewModel(PersonalityReport.fromMap(data));
    final text = [
      vm.headerLabel,
      vm.overviewSummary,
      vm.generatedAtLabel,
      ...vm.discoveries,
      ...vm.limitations,
      ...vm.detailsLimitations,
      vm.body!.summary,
      vm.activity!.summary
    ].join();
    expect(text, isNot(contains('PRIVATE_')));
  });
}

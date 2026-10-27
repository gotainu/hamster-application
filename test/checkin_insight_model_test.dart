import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/checkin_insight.dart';
import 'package:hamster_project/models/personality_report.dart';
import 'package:hamster_project/models/daily_health_features.dart';
import 'package:hamster_project/models/weight_insight.dart';
import 'package:hamster_project/viewmodels/checkin_insights_view_model.dart';
import 'checkin_insight_test_support.dart';
import 'personality_report_fixtures.dart';
import 'current_weight_analysis_test_support.dart';
import 'weight_insight_test_support.dart';

void main() {
  test('new optional typed observations preserve mixed and old weight APIs',
      () {
    final features = DailyHealthFeatures.fromMap(
        currentWeightFeaturesFixture(latest: 103),
        fallbackDateKey: '2026-10-11');
    final original = weightInsightSetFixture();
    expect(
        CurrentInsightSet.fromMap(original,
                features: features, evaluationDateKey: '2026-10-11')
            .checkinInsights,
        isNull);
    original['checkinInsights'] = checkinEnvelopeFixture();
    final mixed = CurrentInsightSet.fromMap(original,
        features: features, evaluationDateKey: '2026-10-11');
    expect(mixed.insights, hasLength(2));
    expect(mixed.checkinInsights!.insights, hasLength(1));
  });
  test(
      'new catalog items and renamed saved labels need no client aggregate change',
      () {
    final gold = checkinGoldFixture();
    (gold['checkinInsights'] as Map)['catalogVersion'] =
        'observation_catalog_future';
    final evidence = ((gold['checkinInsights'] as Map)['insights'] as List)
        .single['evidence'] as Map;
    evidence['itemId'] = 'future_item';
    evidence['itemLabel'] = '保存時の項目名';
    final current = CurrentCheckinAnalysis.fromDocuments(
        ownerId: 'synthetic-owner',
        evaluationDateKey: '2026-10-11',
        silver: checkinSilverFixture(),
        gold: gold);
    expect(CheckinInsightsViewModel.fromCurrent(current).items.single.text,
        contains('保存時の項目名が3日'));
    for (final vm in [
      CheckinInsightsViewModel.fromCurrent(current, expectedOwnerId: 'another'),
      CheckinInsightsViewModel.fromCurrent(current,
          evaluationDateKey: '2026-10-10'),
      CheckinInsightsViewModel.fromCurrent(current,
          generatedAt: DateTime.utc(2026, 10, 11, 3)),
    ]) {
      expect(vm.items, isEmpty);
    }
  });
  test('snapshot cannot be passed as current analysis', () {
    expect(
        () => CurrentCheckinAnalysis.fromDocuments(
            ownerId: 'synthetic-owner',
            evaluationDateKey: '2026-10-11',
            silver: checkinSilverFixture(),
            gold: checkinGoldFixture(snapshot: true)),
        throwsFormatException);
  });
  test('actual TypeScript builders decode current and immutable report wire',
      () {
    Map<String, dynamic> fixture(String part) => jsonDecode(
        File('test/fixtures/checkin_insight_backend_${part}_fixture.json')
            .readAsStringSync()) as Map<String, dynamic>;
    final current = CurrentCheckinAnalysis.fromDocuments(
        ownerId: 'synthetic-owner',
        evaluationDateKey: '2026-10-11',
        silver: fixture('silver'),
        gold: fixture('current'));
    expect(CheckinInsightsViewModel.fromCurrent(current).items.single.text,
        contains('食欲が3日'));
    final snapshot = CheckinReportInsightSnapshot.fromMap(fixture('snapshot'),
        evaluationDateKey: '2026-10-11',
        generatedAt: DateTime.utc(2026, 10, 11, 2),
        cutoffDateKey: '2026-10-10');
    expect(snapshot.windowStartDateKey, '2026-09-27');
    expect(CheckinInsightsViewModel.fromSnapshot(snapshot).items.single.text,
        contains('確認できた7日分'));
  });
  for (final kind in [
    'checkin_item_repetition',
    'checkin_concern_frequency',
    'checkin_record_continuity'
  ]) {
    test('typed server evidence $kind is independent of weight/research', () {
      final current = checkinCurrentFixture(kind: kind);
      final vm = CheckinInsightsViewModel.fromCurrent(current);
      expect(current.insights.insights.single.metric, 'condition');
      expect(vm.items, hasLength(1));
      expect(vm.items.single.text, isNot(contains('正常')));
      expect(
          vm.primaryDiscoveryText == null, kind == 'checkin_record_continuity');
    });
  }
  test('defaults never provide per-item answered denominator', () {
    final value = checkinCurrentFixture().insights.insights.single;
    expect(value.evidence.itemAnsweredDayCount, isNull);
    expect(value.evidence.selectionVerifiedDayCount, 7);
    expect(
        CheckinInsightsViewModel.fromCurrent(checkinCurrentFixture())
            .items
            .single
            .text,
        '確認できた7日分の記録で、食欲が3日、気になる箇所として選ばれました');
  });
  test('current rejects generation/day/hash mismatch and unsafe quality', () {
    for (final mutate
        in <void Function(Map<String, dynamic>, Map<String, dynamic>)>[
      (s, g) => s['generatedAt'] = '2026-10-11T03:00:00Z',
      (s, g) => s['dateKey'] = '2026-10-10',
      (s, g) => s['checkinInsightEvidence'] = {'evidenceHash': 'another'},
      (s, g) =>
          (g['checkinInsights'] as Map)['windowEndDateKey'] = '2026-10-10',
      (s, g) => (((g['checkinInsights'] as Map)['insights'] as List)
          .single['dataQuality'] as Map)['normalDefaultsAreNotAnswers'] = false,
    ]) {
      final silver = checkinSilverFixture(), gold = checkinGoldFixture();
      mutate(silver, gold);
      expect(
          () => CurrentCheckinAnalysis.fromDocuments(
              ownerId: 'owner',
              evaluationDateKey: '2026-10-11',
              silver: silver,
              gold: gold),
          throwsFormatException);
    }
  });
  test(
      'legacy reports have no checkin snapshot; daily snapshot owns cutoff and labels',
      () {
    expect(
        PersonalityReport.fromMap(personalityFixture()).checkinInsightSnapshot,
        isNull);
    final data = checkinReportFixture();
    final report = PersonalityReport.fromMap(data);
    expect(report.checkinInsightSnapshot!.windowEndDateKey, '2026-10-10');
    expect(
        CheckinInsightsViewModel.fromSnapshot(report.checkinInsightSnapshot)
            .items
            .single
            .text,
        contains('食欲'));
    (data['insightSnapshot'] as Map)['checkinInsights']['windowEndDateKey'] =
        '2026-10-11';
    expect(PersonalityReport.fromMap(data).checkinInsightSnapshot, isNull);
    expect(report.checkinInsightSnapshot!.windowEndDateKey, '2026-10-10');
  });
  test('malformed optional checkin does not invalidate legacy metric report',
      () {
    final data = checkinReportFixture();
    (data['insightSnapshot'] as Map)['checkinInsights'] = {'schemaVersion': 99};
    expect(PersonalityReport.fromMap(data).body, isNotNull);
    expect(PersonalityReport.fromMap(data).checkinInsightSnapshot, isNull);
  });
}

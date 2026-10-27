import 'package:hamster_project/models/checkin_insight.dart';
import 'weight_insight_test_support.dart';
import 'weight_insights_ui_support.dart';

Map<String, dynamic> checkinEnvelopeFixture(
    {String kind = 'checkin_item_repetition',
    bool snapshot = false,
    String generation = '2026-10-11T02:00:00Z'}) {
  final start = snapshot ? '2026-09-27' : '2026-09-28';
  final end = snapshot ? '2026-10-10' : '2026-10-11';
  final continuity = kind == 'checkin_record_continuity';
  return {
    'schemaVersion': 1,
    'calculationSpecVersion': 'checkin_insights_v1',
    'catalogVersion': 'observation_catalog_v1',
    'evaluationDateKey': '2026-10-11',
    'windowStartDateKey': start,
    'windowEndDateKey': end,
    'sourceGeneratedAt': generation,
    'evidenceHash': 'checkin-fixture-evidence',
    'insights': [
      {
        'id': kind,
        'kind': kind,
        'metric': 'condition',
        'evaluationDateKey': '2026-10-11',
        'observationStartDateKey': start,
        'observationEndDateKey': end,
        'validRecordCount': 7,
        'unit': 'days',
        'evidence': {
          'windowDays': 14,
          'validRecordDayCount': 7,
          'selectionVerifiedDayCount':
              kind == 'checkin_item_repetition' ? 7 : 0,
          'concernDayCount': continuity ? 0 : 3,
          'matchingDayCount': continuity ? 7 : 3,
          'missingDayCount': 7,
          'invalidDayCount': 0,
          if (kind == 'checkin_item_repetition') ...{
            'itemId': 'appetite',
            'itemLabel': '食欲'
          },
          'itemAnsweredDayCount': null
        },
        'dataQuality': {
          'missingDaysNotImputed': true,
          'normalDefaultsAreNotAnswers': true
        },
        'interpretationCode': kind == 'checkin_item_repetition'
            ? 'checkin_item_repeated'
            : continuity
                ? 'checkin_records_continued'
                : 'checkin_concern_recorded',
        'eligible': true,
        'priority': continuity
            ? 60
            : kind == 'checkin_item_repetition'
                ? 40
                : 50,
        'discovery': !continuity,
        'semanticFingerprint': 'same-evidence-discovery',
        'sourceGeneratedAt': generation,
        'limitations': ['記録頻度は実際の発生頻度ではありません。'],
      }
    ],
  };
}

Map<String, dynamic> checkinGoldFixture(
        {String kind = 'checkin_item_repetition',
        bool snapshot = false,
        String generation = '2026-10-11T02:00:00Z'}) =>
    weightInsightSetFixture(
        kind: snapshot ? 'report_snapshot' : 'current',
        generatedAt: generation,
        range: false,
        period: false)
      ..['checkinInsights'] = checkinEnvelopeFixture(
          kind: kind, snapshot: snapshot, generation: generation);
Map<String, dynamic> checkinSilverFixture(
        {String generation = '2026-10-11T02:00:00Z'}) =>
    {
      'schemaVersion': 5,
      'dateKey': '2026-10-11',
      'generatedAt': generation,
      'checkinInsightEvidence': {'evidenceHash': 'checkin-fixture-evidence'},
    };
CurrentCheckinAnalysis checkinCurrentFixture(
        {String kind = 'checkin_item_repetition'}) =>
    CurrentCheckinAnalysis.fromDocuments(
        ownerId: 'synthetic-owner',
        evaluationDateKey: '2026-10-11',
        silver: checkinSilverFixture(),
        gold: checkinGoldFixture(kind: kind));
Map<String, dynamic> checkinReportFixture(
        {String kind = 'checkin_item_repetition'}) =>
    reportInsightsUiFixture(includeInsights: false)
      ..['insightSnapshot'] = checkinGoldFixture(snapshot: true, kind: kind);

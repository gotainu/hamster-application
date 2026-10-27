import 'package:hamster_project/models/current_weight_analysis.dart';
import 'package:hamster_project/models/weight_insight.dart';

import 'current_weight_analysis_test_support.dart';
import 'personality_report_v3_test_support.dart';
import 'weight_insight_test_support.dart';

CurrentWeightAnalysis currentInsightsUiFixture({
  bool range = true,
  bool period = true,
  bool allEqual = false,
  bool learning = false,
  bool research = true,
  bool includeInsights = true,
}) {
  final original = currentWeightAnalysisFixture(
    ready: !learning,
    latest: allEqual ? 100 : 103,
    referenceAvailable: research,
  );
  return CurrentWeightAnalysis(
    ownerId: original.ownerId,
    evaluationDateKey: original.evaluationDateKey,
    features: original.features,
    profile: original.profile,
    reference: original.reference,
    insights: includeInsights
        ? CurrentInsightSet.fromMap(
            weightInsightSetFixture(
                range: range,
                period: period,
                allEqual: allEqual,
                learning: learning),
            features: original.features,
            evaluationDateKey: original.evaluationDateKey,
          )
        : null,
  );
}

Map<String, dynamic> reportInsightsUiFixture(
    {bool includeInsights = true, bool bodyReady = true}) {
  final data = personalityV3Fixture(
      reportId: 'daily_2026-10-11', type: bodyReady ? 'both' : 'activity_only');
  data['generatedAt'] = DateTime.utc(2026, 10, 11, 2);
  data['inputDates'] = {'body': '2026-10-10', 'activity': '2026-10-10'};
  if (bodyReady) {
    final body = (data['metrics'] as Map<String, dynamic>)['body']
        as Map<String, dynamic>;
    final baseline = body['baseline'] as Map<String, dynamic>;
    baseline['firstDateKey'] = '2026-09-21';
    baseline['lastDateKey'] = '2026-10-04';
    body['latestValue'] = 103;
    body['latestDateKey'] = '2026-10-10';
    body['difference'] = {'absolute': 3, 'percent': 3};
  }
  if (includeInsights) {
    data['insightSnapshot'] = weightInsightSetFixture(
        kind: 'report_snapshot', range: bodyReady, learning: !bodyReady);
  }
  return data;
}

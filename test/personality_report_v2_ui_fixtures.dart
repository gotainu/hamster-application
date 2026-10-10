import 'personality_report_fixtures.dart';

/// Synthetic snapshot-only UI fixtures; no production reads or account data.
Map<String, dynamic> personalityV2UiFixture({
  String type = 'both',
  String? reportId,
  double bodyMedian = 100,
  double activityMedian = 628.3185307179587,
  double? activityLatest = 628.3185307179587,
  double activityMad = 0,
  Map<String, dynamic>? population,
}) {
  final data = personalityFixture(
    type: type,
    population: population ?? applicablePopulation(),
  );
  final metrics = data['metrics'] as Map<String, dynamic>;
  for (final metric in metrics.entries) {
    final value = metric.value as Map<String, dynamic>;
    final baseline = value['baseline'] as Map<String, dynamic>;
    final body = metric.key == 'body';
    baseline['median'] = body ? bodyMedian : activityMedian;
    baseline['ewma'] = baseline['median'];
    baseline['mad'] = body ? 0 : activityMad;
    value['latestValue'] = body ? bodyMedian : activityLatest;
    value['interpretations'] = <Map<String, dynamic>>[];
  }
  if (reportId != null) {
    data['reportId'] = reportId;
    if (reportId.startsWith('daily_')) {
      data['reportKind'] = 'daily';
      data['evaluationDateKey'] = reportId.substring(6);
      data['silverDateKey'] = reportId.substring(6);
      data['cutoffDateKey'] =
          DateTime.parse('${reportId.substring(6)}T00:00:00Z')
              .subtract(const Duration(days: 1))
              .toIso8601String()
              .substring(0, 10);
      data['inputDates'] = {'body': '2026-10-08', 'activity': '2026-10-08'};
    }
  }
  return data;
}

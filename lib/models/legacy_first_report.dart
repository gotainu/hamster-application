import 'package:cloud_firestore/cloud_firestore.dart';

/// The frozen first report contains readiness evidence, not metric baselines.
/// Missing numerical values are deliberately not supplied from current analysis.
class LegacyFirstReportSnapshot {
  const LegacyFirstReportSnapshot(
      {required this.analysisRevision,
      required this.generatedAt,
      required this.sourceDateKey,
      required this.metrics});
  final int analysisRevision;
  final DateTime? generatedAt;
  final String? sourceDateKey;
  final List<LegacyFirstMetricSnapshot> metrics;
  factory LegacyFirstReportSnapshot.fromMap(Map<String, dynamic> data) {
    final generation = data['generation'];
    if (generation is! Map || generation['status'] != 'generated') {
      throw const FormatException('First report is not generated');
    }
    DateTime? date(Object? value) => value is Timestamp
        ? value.toDate()
        : value is DateTime
            ? value
            : value is String
                ? DateTime.tryParse(value)
                : null;
    final ready = (data['readyMetrics'] is List
            ? (data['readyMetrics'] as List)
            : const [])
        .whereType<String>()
        .where((m) => m == 'body' || m == 'activity')
        .toSet();
    final states =
        data['metricStates'] is List ? data['metricStates'] as List : const [];
    final metrics = <LegacyFirstMetricSnapshot>[];
    for (final metric in ['body', 'activity']) {
      if (!ready.contains(metric)) continue;
      final matching =
          states.whereType<Map>().where((x) => x['metric'] == metric).toList();
      final state = matching.length == 1 ? matching.single : null;
      int? number(String key) {
        final n = state?[key];
        return n is num && n.isFinite && n >= 0 ? n.toInt() : null;
      }

      String? text(String key) {
        final s = state?[key];
        return s is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)
            ? s
            : null;
      }

      metrics.add(LegacyFirstMetricSnapshot(
          metric: metric,
          validRecordCount: number('validRecordCount'),
          observationSpanDays: number('observationSpanDays'),
          startDateKey: text('observationStartDateKey'),
          endDateKey: text('observationEndDateKey')));
    }
    final rawRevision = data['analysisRevision'];
    return LegacyFirstReportSnapshot(
        analysisRevision:
            rawRevision is num && rawRevision >= 1 ? rawRevision.toInt() : 1,
        generatedAt:
            date(generation['generatedAt']) ?? date(data['firstGeneratedAt']),
        sourceDateKey: generation['sourceDateKey'] is String
            ? generation['sourceDateKey'] as String
            : null,
        metrics: List.unmodifiable(metrics));
  }
}

class LegacyFirstMetricSnapshot {
  const LegacyFirstMetricSnapshot(
      {required this.metric,
      this.validRecordCount,
      this.observationSpanDays,
      this.startDateKey,
      this.endDateKey});
  final String metric;
  final int? validRecordCount, observationSpanDays;
  final String? startDateKey, endDateKey;
  String get label => metric == 'body' ? '体重' : '活動量';
}

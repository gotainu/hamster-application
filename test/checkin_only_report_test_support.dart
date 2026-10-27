import 'checkin_insight_test_support.dart';

/// Synthetic new daily payload; no baseline is borrowed from a prior report.
Map<String, dynamic> checkinOnlyReportFixture({
  String kind = 'checkin_item_repetition',
}) =>
    checkinReportFixture(kind: kind)
      ..['reportType'] = 'observation_only'
      ..['readyMetrics'] = <String>[]
      ..['metrics'] = <String, dynamic>{}
      ..['inputDates'] = <String, dynamic>{}
      ..['readinessSnapshot'] = {
        'body': {'status': 'learning', 'recordCount': 0, 'spanDays': 0},
        'activity': {'status': 'learning', 'recordCount': 0, 'spanDays': 0},
      }
      ..['limitations'] = ['記録頻度は実際の発生頻度ではありません。病気の診断ではありません。'];

/// A second new immutable daily for unread reappearance coverage.
Map<String, dynamic> nextCheckinOnlyReportFixture() {
  dynamic next(dynamic value) {
    if (value is DateTime) return value.add(const Duration(days: 1));
    if (value is String &&
        RegExp(r'^\d{4}-\d{2}-\d{2}(T.*)?$').hasMatch(value)) {
      final shifted =
          DateTime.parse(value).add(const Duration(days: 1)).toIso8601String();
      return value.length == 10 ? shifted.substring(0, 10) : shifted;
    }
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key as String: next(entry.value)
      };
    }
    if (value is List) return value.map(next).toList();
    return value;
  }

  return next(checkinOnlyReportFixture()) as Map<String, dynamic>
    ..['reportId'] = 'daily_2026-10-12';
}

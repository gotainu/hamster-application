/// Display-only projection of server readiness. It does not decide when an
/// analysis becomes ready, select observations, or calculate a baseline.
class AnalysisMetricProgress {
  const AnalysisMetricProgress({
    required this.id,
    required this.label,
    required this.ready,
    required this.validRecords,
    required this.requiredRecords,
    required this.spanDays,
    required this.requiredSpanDays,
  });

  final String id;
  final String label;
  final bool ready;
  final int? validRecords;
  final int? requiredRecords;
  final int? spanDays;
  final int? requiredSpanDays;

  static int? _count(Object? value) => value is num &&
          value.isFinite &&
          value >= 0 &&
          value == value.roundToDouble()
      ? value.toInt()
      : null;

  factory AnalysisMetricProgress.fromServer(
      String id, Map<String, dynamic>? source) {
    final records = _count(source?['requiredRecordCount']);
    final span = _count(source?['requiredObservationSpanDays']);
    return AnalysisMetricProgress(
      id: id,
      label: id == 'body' ? '体重' : '活動量',
      ready: source?['currentStatus'] == 'ready',
      validRecords: _count(source?['validRecordCount']),
      requiredRecords: records != null && records > 0 ? records : null,
      spanDays: _count(source?['observationSpanDays']),
      requiredSpanDays: span != null && span > 0 ? span : null,
    );
  }

  double? _fraction(int? value, int? target) =>
      value == null || target == null ? null : (value / target).clamp(0.0, 1.0);

  double? get recordProgress => _fraction(validRecords, requiredRecords);
  double? get spanProgress => _fraction(spanDays, requiredSpanDays);
  String get recordLabel => recordProgress == null
      ? '記録数を確認中'
      : '記録 $validRecords / $requiredRecords 件';
  String get spanLabel => spanProgress == null
      ? '観察期間を確認中'
      : '観察期間 $spanDays / $requiredSpanDays 日';
  String get semanticLabel => ready
      ? '$labelの分析は準備できています'
      : '$label。$recordLabel。$spanLabel。毎日の連続記録は不要です';
}

class AnalysisProgressViewModel {
  AnalysisProgressViewModel.fromServer(List<Map<String, dynamic>> states)
      : metrics = [
          for (final id in ['body', 'activity'])
            AnalysisMetricProgress.fromServer(
              id,
              states.where((item) => item['metric'] == id).firstOrNull,
            ),
        ];

  final List<AnalysisMetricProgress> metrics;
  bool get allReady => metrics.every((metric) => metric.ready);
  bool get anyReady => metrics.any((metric) => metric.ready);
  String get title => allReady ? 'この子の個性が見えてきたよ' : 'うちの子を知る準備';
  String get message =>
      allReady ? '集まった記録から、この子らしさを見てみよう。' : '今は分析に必要な情報を集めているよ！';
}

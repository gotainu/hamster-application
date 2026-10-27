import '../models/current_weight_analysis.dart';
import '../models/weight_insight.dart';

class WeightInsightDisplay {
  final String id;
  final WeightInsightKind kind;
  final String text;
  final String periodLabel;
  final String evidenceLabel;
  const WeightInsightDisplay(
      {required this.id,
      required this.kind,
      required this.text,
      required this.periodLabel,
      required this.evidenceLabel});
}

/// Formats committed server evidence; priority and statistical choices belong
/// to the server. No records are imputed or statistics calculated in the UI.
class WeightInsightsViewModel {
  final List<WeightInsightDisplay> items;
  const WeightInsightsViewModel._(this.items);
  factory WeightInsightsViewModel.fromCurrent(CurrentWeightAnalysis? analysis) {
    final set = analysis?.insights;
    final features = analysis?.features;
    if (analysis == null ||
        analysis.ownerId.isEmpty ||
        set == null ||
        features == null ||
        features.generatedAt == null ||
        set.evaluationDateKey != analysis.evaluationDateKey ||
        set.silverDateKey != features.dateKey ||
        features.schemaVersion != 5 ||
        set.evaluationDateKey != features.dateKey ||
        !set.silverGeneratedAt.isAtSameMomentAs(features.generatedAt!)) {
      return const WeightInsightsViewModel._([]);
    }
    return WeightInsightsViewModel._(_format(set.insights));
  }
  factory WeightInsightsViewModel.fromSnapshot(
          ReportInsightSnapshot? snapshot) =>
      WeightInsightsViewModel._(_format(snapshot?.insights ?? const []));
  String? get primaryText => items.isEmpty ? null : items.first.text;

  static List<WeightInsightDisplay> _format(List<WeightInsight> insights) =>
      List.unmodifiable(insights.map((insight) {
        final evidence = insight.evidence;
        final text = switch (evidence) {
          WeightRangeEvidence() => evidence.allEqual
              ? '採用した${insight.validRecordCount}件の体重はすべて${_number(evidence.minimumGrams)}gでした'
              : '採用した${insight.validRecordCount}件の体重は${_number(evidence.minimumGrams)}〜${_number(evidence.maximumGrams)}gでした',
          WeightPeriodEvidence() => evidence.differenceGrams == 0
              ? '${_date(evidence.startDateKey)}と${_date(evidence.endDateKey)}の体重は同じでした'
              : '${_date(evidence.startDateKey)}から${_date(evidence.endDateKey)}までに${_difference(evidence)}',
        };
        return WeightInsightDisplay(
            id: insight.id,
            kind: insight.kind,
            text: text,
            periodLabel:
                '${insight.observationStartDateKey}〜${insight.observationEndDateKey}${insight.kind == WeightInsightKind.periodDifference ? '（直近30日以内）' : ''}',
            evidenceLabel: '${insight.validRecordCount}件の実測記録');
      }));
  static String _difference(WeightPeriodEvidence evidence) {
    final direction = evidence.differenceGrams > 0 ? '増えました' : '減りました';
    if (evidence.absoluteDifferenceGrams < .01) {
      return '0.01g未満$direction';
    }
    final rounded =
        double.parse(evidence.absoluteDifferenceGrams.toStringAsFixed(2));
    final qualifier =
        (rounded - evidence.absoluteDifferenceGrams).abs() > 1e-9 ? '約' : '';
    return '$qualifier${_number(rounded)}g$direction';
  }

  // Keep distinct measured endpoints distinct; rounding must not imply equality.
  static String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
  static String _date(String key) {
    final parts = key.split('-');
    return '${int.parse(parts[1])}月${int.parse(parts[2])}日';
  }
}

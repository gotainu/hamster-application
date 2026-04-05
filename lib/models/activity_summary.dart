import 'activity_distribution.dart';
import 'semantic_chart_band.dart';
import 'metric_card_view_data.dart';

class ActivitySummary {
  final double todayDistanceMeters;
  final double avg7DistanceMeters;
  final double deltaPct;
  final DateTime? latestRecordedAt;
  final String headline;
  final String deltaText;
  final String summaryText;
  final String directionText;
  final bool hasAnyRecord;
  final bool todayHasRecord;
  final double referenceDistanceMeters;
  final DateTime? referenceDate;
  final ActivityDistribution? distribution;
  final List<SemanticChartBand>? chartBands;
  final MetricCardViewData card;

  const ActivitySummary({
    required this.todayDistanceMeters,
    required this.avg7DistanceMeters,
    required this.deltaPct,
    required this.latestRecordedAt,
    required this.headline,
    required this.deltaText,
    required this.summaryText,
    required this.directionText,
    required this.hasAnyRecord,
    required this.todayHasRecord,
    required this.referenceDistanceMeters,
    required this.referenceDate,
    required this.distribution,
    required this.chartBands,
    required this.card,
  });

  factory ActivitySummary.empty() {
    return const ActivitySummary(
      todayDistanceMeters: 0,
      avg7DistanceMeters: 0,
      deltaPct: 0,
      latestRecordedAt: null,
      headline: 'まずは記録をためよう',
      deltaText: '比較データがまだ少ないです',
      summaryText: '走行距離の記録が増えると推移を表示できます',
      directionText: '比較中',
      hasAnyRecord: false,
      todayHasRecord: false,
      referenceDistanceMeters: 0,
      referenceDate: null,
      distribution: null,
      chartBands: null,
      card: MetricCardViewData(
        currentValueText: '未入力',
        stateText: '比較中',
        deltaText: '比較データがまだ少ないです',
        summaryText: '走行距離の記録が増えると推移を表示できます',
        chartBands: null,
        hasChart: false,
        emptyChartText: 'まだ走行距離の記録がありません',
        emptyChartSubtext: '記録すると7日推移を表示できます',
      ),
    );
  }
}

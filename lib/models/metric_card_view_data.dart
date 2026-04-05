// /Users/gota/local_dev/flutter_projects/hamster_project/lib/models/metric_card_view_data.dart
import 'semantic_chart_band.dart';

class MetricCardViewData {
  final String currentValueText;
  final String stateText;
  final String deltaText;
  final String summaryText;
  final List<SemanticChartBand>? chartBands;
  final bool hasChart;
  final String? emptyChartText;
  final String? emptyChartSubtext;

  const MetricCardViewData({
    required this.currentValueText,
    required this.stateText,
    required this.deltaText,
    required this.summaryText,
    required this.chartBands,
    required this.hasChart,
    this.emptyChartText,
    this.emptyChartSubtext,
  });
}

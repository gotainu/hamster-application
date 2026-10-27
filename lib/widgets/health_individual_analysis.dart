import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../viewmodels/health_analysis_view_model.dart';
import '../viewmodels/weight_insights_view_model.dart';
import '../viewmodels/weight_research_comparison_view_model.dart';
import 'status_card.dart';
import 'weight_insights_card.dart';
import 'weight_research_comparison_card.dart';

/// A small entrance, not a repeated full comparison or a second health gauge.
class HealthWeightAnalysisEntry extends StatelessWidget {
  const HealthWeightAnalysisEntry({
    super.key,
    required this.viewModel,
    required this.onTap,
  });
  final HealthAnalysisViewModel viewModel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!viewModel.hasBodyAnalysis) return const SizedBox.shrink();
    final comparison = viewModel.weightComparison;
    return StatusCard(
      key: const ValueKey('health-weight-analysis-entry'),
      level: StatusCardLevel.neutral,
      radius: AppTheme.dataCardRadius,
      padding: AppTheme.dataCardPadding,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('体重の個体別分析', style: AppTheme.dataTitleStyle(context)),
        const SizedBox(height: AppTheme.dataSmallGap),
        Text('普段の体重：${viewModel.bodyBaselineValue}g',
            style: AppTheme.dataBodyStyle(context)),
        if (comparison != null)
          Text(
              '同種の研究参考中央値：'
              '${formatWeight(comparison.comparison.referenceMedianGrams)}g',
              style: AppTheme.dataCaptionStyle(context)),
        const SizedBox(height: AppTheme.dataSmallGap),
        Text('体重の詳細を見る', style: AppTheme.dataCaptionStyle(context)),
      ]),
    );
  }
}

/// Personal observation and population reference stay visually distinct from
/// the existing health assessment shown by the parent screen.
class HealthWeightIndividualAnalysis extends StatelessWidget {
  const HealthWeightIndividualAnalysis({
    super.key,
    required this.viewModel,
    this.onOpenCurrentAnalysis,
  });
  final HealthAnalysisViewModel viewModel;
  final VoidCallback? onOpenCurrentAnalysis;

  @override
  Widget build(BuildContext context) {
    final insights = WeightInsightsViewModel.fromCurrent(
        viewModel.aligned ? viewModel.analysis : null);
    if (!viewModel.hasBodyAnalysis) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(viewModel.bodyFallback,
              key: const ValueKey('health-weight-analysis-fallback'),
              style: AppTheme.dataCaptionStyle(context)),
          if (insights.items.isNotEmpty) ...[
            const SizedBox(height: AppTheme.dataSectionGap),
            WeightInsightsCard(
              viewModel: insights,
              evaluationDateKey: viewModel.analysis!.evaluationDateKey,
              maxItems: 1,
            ),
          ],
          if (viewModel.canOpenCurrentWeightAnalysis &&
              onOpenCurrentAnalysis != null) ...[
            const SizedBox(height: AppTheme.dataContentGap),
            if (viewModel.savedHealthEvaluationTime != null)
              Text('健康評価の日時：${viewModel.savedHealthEvaluationTime}',
                  style: AppTheme.dataCaptionStyle(context)),
            const SizedBox(height: AppTheme.dataSmallGap),
            Text('この健康評価とは別に、現在の体重分析を確認できます。',
                style: AppTheme.dataBodyStyle(context)),
            Text('分析日時：${viewModel.currentWeightAnalysisTime}',
                style: AppTheme.dataCaptionStyle(context)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('health-current-weight-analysis-link'),
                style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryText(context)),
                onPressed: onOpenCurrentAnalysis,
                child: const Text('現在の体重分析を見る'),
              ),
            ),
          ],
        ],
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      StatusCard(
        key: const ValueKey('health-weight-individual-analysis'),
        level: StatusCardLevel.neutral,
        radius: AppTheme.dataCardRadius,
        padding: AppTheme.dataCardPadding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('この子の体重記録', style: AppTheme.dataTitleStyle(context)),
          const SizedBox(height: AppTheme.dataContentGap),
          Text('普段の体重：${viewModel.bodyBaselineValue}g',
              style: AppTheme.dataBodyStyle(context)),
          Text('直近の体重：${viewModel.bodyLatestValue}g',
              style: AppTheme.dataBodyStyle(context)),
          const SizedBox(height: AppTheme.dataSmallGap),
          Text(viewModel.bodyRecentChangeLabel!,
              style: AppTheme.dataBodyStyle(context)),
          const SizedBox(height: AppTheme.dataSmallGap),
          Text(
              '評価日 ${viewModel.analysis!.evaluationDateKey} · '
              '記録日 ${viewModel.bodyRecordDateKey}',
              style: AppTheme.dataCaptionStyle(context)),
          Text('普段の基準の観察期間 ${viewModel.bodyObservationPeriod}',
              style: AppTheme.dataCaptionStyle(context)),
          if (insights.items.isNotEmpty) ...[
            const SizedBox(height: AppTheme.dataSectionGap),
            WeightInsightsCard(
              viewModel: insights,
              embedded: true,
              maxItems: 1,
            ),
          ],
        ]),
      ),
      if (viewModel.weightComparison != null) ...[
        const SizedBox(height: AppTheme.dataSectionGap),
        WeightResearchComparisonCard(analysis: viewModel.analysis!),
      ],
    ]);
  }
}

/// Readiness does not imply a record exists or a health evaluation was made.
class HealthActivityAnalysisStatus extends StatelessWidget {
  const HealthActivityAnalysisStatus({super.key, required this.viewModel});
  final HealthAnalysisViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (!viewModel.activityContextAvailable) {
      return Text(
        '評価日に対応する活動量の基準・記録は確認できません。健康評価は引き続き表示します。',
        key: const ValueKey('health-activity-analysis-fallback'),
        style: AppTheme.dataCaptionStyle(context),
      );
    }
    return Column(
      key: const ValueKey('health-activity-analysis-status'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppTheme.dataContentGap),
        Text('個体別の基準：${viewModel.activityBaselineLabel}',
            style: AppTheme.dataCaptionStyle(context)),
        Text(
            '評価対象日の記録'
            '${viewModel.activityTargetDateKey == null ? '' : '（${viewModel.activityTargetDateKey}）'}'
            '：${viewModel.activityRecordLabel}',
            style: AppTheme.dataCaptionStyle(context)),
        Text('健康評価：${viewModel.activityHealthLabel}',
            style: AppTheme.dataCaptionStyle(context)),
      ],
    );
  }
}

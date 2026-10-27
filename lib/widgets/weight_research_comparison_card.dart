import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/current_weight_analysis.dart';
import '../theme/app_theme.dart';
import '../viewmodels/weight_research_comparison_view_model.dart';
import 'metric_comparison_bar.dart';
import 'status_card.dart';

/// Supplemental research context. Safe omission never hides the weight chart.
/// This same component can be placed in a condition detail without screen math.
class WeightResearchComparisonCard extends StatelessWidget {
  const WeightResearchComparisonCard({super.key, required this.analysis});
  final CurrentWeightAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final vm = WeightResearchComparisonViewModel.fromCurrent(analysis);
    if (vm == null) return const SizedBox.shrink();
    final reference = analysis.reference!;
    final baseline = analysis.baseline;
    return StatusCard(
      key: const ValueKey('current-weight-research-comparison'),
      level: StatusCardLevel.neutral,
      padding: AppTheme.dataCardPadding,
      radius: AppTheme.dataCardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('同種の体重参考', style: AppTheme.dataTitleStyle(context)),
          const SizedBox(height: AppTheme.dataSmallGap),
          Text(vm.summary, style: AppTheme.dataBodyStyle(context)),
          const SizedBox(height: AppTheme.dataContentGap),
          MetricComparisonBar(
            value: vm.comparison.individualWeightGrams,
            referenceValue: vm.comparison.referenceMedianGrams,
            referenceStart: vm.comparison.referenceP25Grams,
            referenceEnd: vm.comparison.referenceP75Grams,
            valueLabel:
                WeightResearchComparisonViewModel.compactIndividualLabel,
            referenceLabel:
                WeightResearchComparisonViewModel.compactReferenceLabel,
            rangeLabel: WeightResearchComparisonViewModel.compactRangeLabel,
            unit: 'g',
            semanticUnit: 'グラム',
            showAxisLabels: false,
            compact: true,
          ),
          const SizedBox(height: AppTheme.dataSmallGap),
          Text('評価日 ${analysis.evaluationDateKey} · 個体別の基準と研究の比較',
              style: AppTheme.dataCaptionStyle(context)),
          Text(WeightResearchComparisonViewModel.referenceNote,
              style: AppTheme.dataCaptionStyle(context)),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title:
                Text('記録の基準・研究の出典', style: AppTheme.dataCaptionStyle(context)),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '観察期間 ${baseline.firstDateKey}〜${baseline.lastDateKey}'
                        '（${baseline.spanDays}日間・有効${baseline.recordCount}日）',
                        style: AppTheme.dataCaptionStyle(context)),
                    Text(
                        '直近の記録 ${formatWeight(analysis.latestWeightGrams!)}g'
                        ' · ${weightAnalysisDateKeyJst(analysis.features.body.latestWeightDate!)}',
                        style: AppTheme.dataCaptionStyle(context)),
                    const SizedBox(height: AppTheme.dataSmallGap),
                    Text(reference.sourceTitle,
                        style: AppTheme.dataCaptionStyle(context)),
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.https('doi.org', '/${reference.sourceDoi}'),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text('DOI: ${reference.sourceDoi}'),
                    ),
                    Text('対象種の成体（3か月超）。観察開始時と評価日の年齢を確認済み。',
                        style: AppTheme.dataCaptionStyle(context)),
                    if (reference.sampleSizeCaution)
                      Text('この種は研究対象が少なく、比較には慎重な解釈が必要です。',
                          style: AppTheme.dataCaptionStyle(context)),
                    for (final text in reference.limitations.toSet())
                      Padding(
                        padding: const EdgeInsets.only(
                            bottom: AppTheme.dataSmallGap),
                        child: Text(text,
                            style: AppTheme.dataCaptionStyle(context)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

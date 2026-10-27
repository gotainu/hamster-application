import 'package:flutter/material.dart';

import '../viewmodels/insight_display.dart';
import '../viewmodels/weight_insights_view_model.dart';
import 'insights_card.dart';

/// Presents server-ranked measurement discoveries. This widget neither selects
/// records nor calculates statistics, and never labels an Insight a health score.
class WeightInsightsCard extends StatelessWidget {
  const WeightInsightsCard({
    super.key,
    required this.viewModel,
    this.evaluationDateKey,
    this.embedded = false,
    this.maxItems = 2,
  }) : assert(maxItems > 0);

  final WeightInsightsViewModel viewModel;
  final String? evaluationDateKey;
  final bool embedded;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    return InsightsCard(
      title: '分析に採用した体重記録',
      items: [
        for (final item in viewModel.items)
          InsightDisplay(
              id: item.id,
              text: item.text,
              periodLabel: item.periodLabel,
              evidenceLabel: item.evidenceLabel),
      ],
      evaluationDateKey: evaluationDateKey,
      embedded: embedded,
      maxItems: maxItems,
      contentKey: const ValueKey('weight-insights-card'),
      itemKeyPrefix: 'weight-insight',
    );
  }
}

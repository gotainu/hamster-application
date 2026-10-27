import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../viewmodels/insight_display.dart';
import 'status_card.dart';

/// Shared neutral presentation. Selection and interpretation stay server-side.
class InsightsCard extends StatelessWidget {
  const InsightsCard(
      {super.key,
      required this.title,
      required this.items,
      this.evaluationDateKey,
      this.embedded = false,
      this.maxItems = 2,
      this.contentKey,
      this.itemKeyPrefix = 'insight',
      this.evaluationCaption = '観察記録の特徴'})
      : assert(maxItems > 0);
  final String title, itemKeyPrefix, evaluationCaption;
  final List<InsightDisplay> items;
  final String? evaluationDateKey;
  final bool embedded;
  final int maxItems;
  final Key? contentKey;
  @override
  Widget build(BuildContext context) {
    final shown = items.take(maxItems).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    final content = Column(
        key: contentKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTheme.dataTitleStyle(context)),
          if (evaluationDateKey != null) ...[
            const SizedBox(height: AppTheme.dataSmallGap),
            Text('分析日 $evaluationDateKey · $evaluationCaption',
                style: AppTheme.dataCaptionStyle(context)),
          ],
          for (final item in shown) ...[
            const SizedBox(height: AppTheme.dataContentGap),
            Text(item.text,
                key: ValueKey('$itemKeyPrefix-${item.id}'),
                style: AppTheme.dataBodyStyle(context)),
            const SizedBox(height: AppTheme.dataSmallGap),
            Text('${item.periodLabel} · ${item.evidenceLabel}',
                style: AppTheme.dataCaptionStyle(context)),
          ],
        ]);
    return embedded
        ? content
        : StatusCard(
            level: StatusCardLevel.neutral,
            dataSurface: true,
            padding: AppTheme.dataCardPadding,
            radius: AppTheme.dataCardRadius,
            child: content);
  }
}

import 'package:flutter/material.dart';
import '../services/personalized_analysis_repo.dart';
import '../theme/app_theme.dart';
import '../viewmodels/analysis_progress_view_model.dart';
import 'status_card.dart';

/// A calm progress surface for server-owned body/activity readiness.
/// Report navigation is owned by the caller and always opens the unified report.
class AnalysisProgressCard extends StatelessWidget {
  const AnalysisProgressCard({
    super.key,
    this.state,
    required this.onOpenRecord,
    required this.onOpenSwitchbot,
    this.onViewAnalysis,
    this.readinessStream,
    this.illustrationAsset,
  });

  // Kept for existing callers; onboarding state never determines readiness.
  final Object? state;
  final VoidCallback onOpenRecord;
  // Kept for existing callers. Temperature acquisition is not a body/activity
  // baseline prerequisite, so this card does not imply that a sensor is needed.
  final VoidCallback onOpenSwitchbot;
  final VoidCallback? onViewAnalysis;
  final Stream<List<Map<String, dynamic>>>? readinessStream;
  final String? illustrationAsset;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: readinessStream ?? PersonalizedAnalysisRepo().watchReadiness(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const SizedBox.shrink();
          final view = AnalysisProgressViewModel.fromServer(
              snapshot.data ?? const <Map<String, dynamic>>[]);
          if (view.allReady) {
            return StatusCard(
              level: StatusCardLevel.neutral,
              dataSurface: true,
              radius: AppTheme.dataCardRadius,
              padding: AppTheme.analysisPreparationReadyPadding,
              child: TextButton(
                style: TextButton.styleFrom(
                    foregroundColor:
                        AppTheme.analysisPreparationProgressColor(context)),
                onPressed: onViewAnalysis,
                child: const Text('うちの子レポートを見る'),
              ),
            );
          }
          final asset = illustrationAsset ??
              AppTheme.analysisPreparationIllustrationAsset;
          return StatusCard(
            level: StatusCardLevel.neutral,
            dataSurface: true,
            radius: AppTheme.dataCardRadius,
            padding: AppTheme.dataCardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PreparationHeader(view: view, asset: asset),
                const SizedBox(height: AppTheme.analysisPreparationMetricGap),
                for (final metric in view.metrics) ...[
                  _MetricProgress(metric: metric),
                  if (metric != view.metrics.last)
                    const SizedBox(
                        height: AppTheme.analysisPreparationMetricGap),
                ],
                if (!view.allReady) ...[
                  const SizedBox(height: AppTheme.dataContentGap),
                  Text('毎日連続でなくても大丈夫。',
                      style: AppTheme.dataCaptionStyle(context)),
                  const SizedBox(height: AppTheme.dataSectionGap),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onOpenRecord,
                      child: const Text('今日の記録をつける'),
                    ),
                  ),
                ],
                if (onViewAnalysis != null) ...[
                  const SizedBox(height: AppTheme.dataSmallGap),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      style: TextButton.styleFrom(
                          foregroundColor:
                              AppTheme.analysisPreparationProgressColor(
                                  context)),
                      onPressed: onViewAnalysis,
                      child: const Text('うちの子レポートを見る'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
}

class _PreparationHeader extends StatelessWidget {
  const _PreparationHeader({required this.view, required this.asset});
  final AnalysisProgressViewModel view;
  final String? asset;

  @override
  Widget build(BuildContext context) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(view.title, style: AppTheme.dataCaptionStyle(context)),
        const SizedBox(height: AppTheme.dataSmallGap),
        Text(view.message,
            style: AppTheme.analysisPreparationMessageStyle(context)),
      ],
    );
    if (asset == null) return title;
    return LayoutBuilder(builder: (context, constraints) {
      final stacked =
          constraints.maxWidth < AppTheme.analysisPreparationCompactWidth ||
              MediaQuery.textScalerOf(context).scale(1) > 1.4;
      final picture = ExcludeSemantics(
        child: Image.asset(
          asset!,
          key: const ValueKey('analysis-preparation-illustration'),
          width: stacked
              ? AppTheme.analysisPreparationCompactIllustrationSize
              : AppTheme.analysisPreparationIllustrationSize,
          height: stacked
              ? AppTheme.analysisPreparationCompactIllustrationSize
              : AppTheme.analysisPreparationIllustrationSize,
          fit: BoxFit.contain,
        ),
      );
      if (stacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(alignment: Alignment.center, child: picture),
            const SizedBox(height: AppTheme.dataSmallGap),
            title,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: title),
          const SizedBox(width: AppTheme.dataContentGap),
          picture,
        ],
      );
    });
  }
}

class _MetricProgress extends StatelessWidget {
  const _MetricProgress({required this.metric});
  final AnalysisMetricProgress metric;

  @override
  Widget build(BuildContext context) => Semantics(
        label: metric.semanticLabel,
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppTheme.dataContentGap,
                runSpacing: AppTheme.dataValueGap,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(metric.label,
                      style: AppTheme.dataBodyStyle(context)
                          .copyWith(fontWeight: FontWeight.w600)),
                  if (metric.ready)
                    Text('分析できるよ',
                        style: AppTheme.dataCaptionStyle(context).copyWith(
                            color: AppTheme.analysisPreparationProgressColor(
                                context))),
                ],
              ),
              if (!metric.ready) ...[
                const SizedBox(height: AppTheme.dataSmallGap),
                LayoutBuilder(builder: (context, constraints) {
                  final stacked = constraints.maxWidth <
                          AppTheme.analysisPreparationCompactWidth ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.4;
                  final records = _ProgressMeasure(
                      label: metric.recordLabel,
                      value: metric.recordProgress,
                      id: '${metric.id}-record-progress');
                  final span = _ProgressMeasure(
                      label: metric.spanLabel,
                      value: metric.spanProgress,
                      id: '${metric.id}-span-progress');
                  if (stacked) {
                    return Column(children: [
                      records,
                      const SizedBox(height: AppTheme.dataContentGap),
                      span,
                    ]);
                  }
                  return Row(children: [
                    Expanded(child: records),
                    const SizedBox(width: AppTheme.dataSectionGap),
                    Expanded(child: span),
                  ]);
                }),
              ],
            ],
          ),
        ),
      );
}

class _ProgressMeasure extends StatelessWidget {
  const _ProgressMeasure(
      {required this.label, required this.value, required this.id});
  final String label;
  final double? value;
  final String id;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.dataCaptionStyle(context)),
          if (value != null) ...[
            const SizedBox(height: AppTheme.dataSmallGap),
            LinearProgressIndicator(
              key: ValueKey(id),
              value: value,
              minHeight: AppTheme.analysisPreparationTrackHeight,
              borderRadius:
                  BorderRadius.circular(AppTheme.comparisonTrackRadius),
              backgroundColor: AppTheme.comparisonTrackColor(context),
              color: AppTheme.analysisPreparationProgressColor(context),
            ),
          ],
        ],
      );
}

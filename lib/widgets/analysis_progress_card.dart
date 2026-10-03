import 'package:flutter/material.dart';

import '../models/daily_health_features.dart';
import '../services/daily_health_features_repo.dart';
import '../services/onboarding_state_repo.dart';
import '../theme/app_theme.dart';
import 'status_card.dart';

class AnalysisProgressCard extends StatelessWidget {
  const AnalysisProgressCard({
    super.key,
    required this.state,
    required this.onOpenRecord,
    required this.onOpenSwitchbot,
    required this.onViewAnalysis,
  });

  final OnboardingState state;
  final VoidCallback onOpenRecord;
  final VoidCallback onOpenSwitchbot;
  final VoidCallback onViewAnalysis;

  @override
  Widget build(BuildContext context) {
    final startedAt = state.firstMonitoringDataRecordedAt;
    if (state.personalizedAnalysisAvailableAt != null &&
        state.firstPersonalizedAnalysisViewedAt == null) {
      return StatusCard(
        level: StatusCardLevel.good,
        radius: 24,
        padding: const EdgeInsets.all(18),
        onTap: onViewAnalysis,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最初のコンディションレポートを確認できます',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              '集まった記録をもとに、現在確認できる範囲をまとめました。',
              style: TextStyle(color: AppTheme.secondaryText(context)),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onViewAnalysis,
              icon: const Icon(Icons.insights_rounded),
              label: const Text('レポートを見る'),
            ),
          ],
        ),
      );
    }
    if (startedAt == null || state.personalizedAnalysisAvailableAt != null) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<List<DailyHealthFeatures>>(
      stream: DailyHealthFeaturesRepo().watchSince(startedAt),
      builder: (context, snapshot) {
        final activeDays = (snapshot.data ?? const <DailyHealthFeatures>[])
            .where((feature) => feature.hasAnyDomainData)
            .map((feature) => feature.dateKey)
            .toSet()
            .length;
        final shownDays = activeDays.clamp(0, 7);
        if (activeDays >= 7) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            OnboardingStateRepo().markPersonalizedAnalysisAvailable();
          });
        }
        return StatusCard(
          level: StatusCardLevel.neutral,
          radius: 24,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_graph_rounded, color: AppTheme.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '個体別コンディション分析を準備中',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: shownDays / 7,
                minHeight: 8,
                borderRadius: BorderRadius.circular(999),
              ),
              const SizedBox(height: 8),
              Text(
                '$shownDays / 7 日分の有効な記録を確認できました',
                style: TextStyle(color: AppTheme.secondaryText(context)),
              ),
              const SizedBox(height: 8),
              Text(
                'データが集まるほど、普段の状態と比べた見守りに役立ちます。',
                style: TextStyle(
                  color: AppTheme.secondaryText(context),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: onOpenRecord,
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('記録する'),
                  ),
                  TextButton.icon(
                    onPressed: onOpenSwitchbot,
                    icon: const Icon(Icons.thermostat_rounded),
                    label: const Text('SwitchBotを連携'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

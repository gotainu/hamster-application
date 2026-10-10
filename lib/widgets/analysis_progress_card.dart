import 'package:flutter/material.dart';
import '../services/personalized_analysis_repo.dart';
import '../theme/app_theme.dart';
import 'status_card.dart';

class AnalysisProgressCard extends StatelessWidget {
  const AnalysisProgressCard(
      {super.key,
      this.state,
      required this.onOpenRecord,
      required this.onOpenSwitchbot,
      this.onViewAnalysis,
      this.readinessStream});
  // Preserved only for the current caller. It must not determine readiness.
  final Object? state;
  final VoidCallback onOpenRecord;
  final VoidCallback onOpenSwitchbot;
  final VoidCallback? onViewAnalysis;
  final Stream<List<Map<String, dynamic>>>? readinessStream;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: readinessStream ?? PersonalizedAnalysisRepo().watchReadiness(),
        builder: (context, readinessSnapshot) =>
            StreamBuilder<Map<String, dynamic>?>(
          stream: onViewAnalysis == null
              ? Stream.value(null)
              : PersonalizedAnalysisRepo().watchFirstReport(),
          builder: (context, reportSnapshot) {
            if (readinessSnapshot.hasError) return const SizedBox.shrink();
            final states =
                readinessSnapshot.data ?? const <Map<String, dynamic>>[];
            final metrics = {for (final item in states) item['metric']: item};
            if ([
              'body',
              'activity'
            ].every((metric) => metrics[metric]?['currentStatus'] == 'ready')) {
              return const SizedBox.shrink();
            }
            final report = reportSnapshot.data;
            final generated = report?['generation'] is Map &&
                (report!['generation'] as Map)['status'] == 'generated';
            if (generated && onViewAnalysis != null) {
              return StatusCard(
                  level: StatusCardLevel.good,
                  radius: 24,
                  padding: const EdgeInsets.all(18),
                  onTap: onViewAnalysis,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('個体別コンディションレポート',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Text('準備が整った指標だけで初回レポートを作成しました。閲覧は無料です。',
                            style: TextStyle(
                                color: AppTheme.secondaryText(context))),
                        TextButton.icon(
                            onPressed: onViewAnalysis,
                            icon: const Icon(Icons.insights_rounded),
                            label: const Text('レポートを見る')),
                      ]));
            }
            return StatusCard(
                level: StatusCardLevel.neutral,
                radius: 24,
                padding: const EdgeInsets.all(18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.auto_graph_rounded, color: AppTheme.accent),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text('個体別コンディション分析を準備中',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900)))
                      ]),
                      const SizedBox(height: 10),
                      if (states.isEmpty)
                        Text('体重または活動量の有効な記録が集まると、指標ごとの準備状況を表示します。',
                            style: TextStyle(
                                color: AppTheme.secondaryText(context)))
                      else
                        ...['body', 'activity'].map((name) {
                          final item = metrics[name] ?? {'metric': name};
                          final metric =
                              item['metric'] == 'activity' ? '活動量' : '体重';
                          final ready = item['currentStatus'] == 'ready';
                          return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                  '$metric: ${ready ? '準備完了' : '有効記録 ${item['validRecordCount'] ?? 0}/${item['requiredRecordCount'] ?? 7}・観察期間 ${item['observationSpanDays'] ?? 0}/${item['requiredObservationSpanDays'] ?? 14} 日'}',
                                  style: TextStyle(
                                      color: ready
                                          ? Colors.green
                                          : AppTheme.secondaryText(context))));
                        }),
                      const SizedBox(height: 6),
                      Text('温湿度や今日の様子は一般的な評価に使えますが、体重・活動量の個体別ベースラインは作りません。',
                          style: TextStyle(
                              color: AppTheme.secondaryText(context),
                              height: 1.4)),
                      Wrap(spacing: 4, children: [
                        TextButton.icon(
                            onPressed: onOpenRecord,
                            icon: const Icon(Icons.edit_note_rounded),
                            label: const Text('記録する')),
                        TextButton.icon(
                            onPressed: onOpenSwitchbot,
                            icon: const Icon(Icons.thermostat_rounded),
                            label: const Text('SwitchBotを連携'))
                      ]),
                    ]));
          },
        ),
      );
}

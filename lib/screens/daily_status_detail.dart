import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../models/activity_distribution.dart';
import '../models/activity_summary.dart';
import '../models/environment_assessment.dart';
import '../models/environment_assessment_history.dart';
import '../models/health_record.dart';
import '../models/metric_card_view_data.dart';
import '../models/sensor_evaluation.dart';
import '../models/anomaly_detection.dart';
import '../services/activity_trend_service.dart';
import '../services/anomaly_detection_service.dart';
import '../services/environment_assessment_repo.dart';
import '../services/distance_records_repo.dart';
import '../services/environment_status_service.dart';
import '../services/daily_status_summary_service.dart';
import '../widgets/semantic_sparkline.dart';
import '../theme/app_theme.dart';

class DailyStatusDetailScreen extends StatefulWidget {
  const DailyStatusDetailScreen({super.key});

  @override
  State<DailyStatusDetailScreen> createState() =>
      _DailyStatusDetailScreenState();
}

class _DailyStatusDetailScreenState extends State<DailyStatusDetailScreen> {
  final _assessmentRepo = EnvironmentAssessmentRepo();
  final _anomalyDetectionService = const AnomalyDetectionService();
  final _activityTrendService = const ActivityTrendService();
  final _distanceRepo = DistanceRecordsRepo();
  final _environmentStatusService = const EnvironmentStatusService();
  final _dailyStatusSummaryService = const DailyStatusSummaryService();

  Future<_DetailBundle> _loadBundle() async {
    final latest = await _assessmentRepo.fetchLatest();
    final history = await _assessmentRepo.fetchRecentHistory(limit: 7);
    final anomalyHistory = await _assessmentRepo.fetchRecentHistory(limit: 14);

    final todayDistance =
        await _distanceRepo.fetchDailyTotalDistance(DateTime.now());
    final avg7Distance = await _distanceRepo.fetchRollingDailyAverage(days: 7);
    final dailyDistanceSeries =
        await _distanceRepo.fetchDailyDistanceSeries(days: 7);
    final allDailyDistanceSeries =
        await _distanceRepo.fetchAllDailyDistanceSeries();

    final activitySummary = _activityTrendService.buildSummary(
      todayDistanceMeters: todayDistance,
      avg7DistanceMeters: avg7Distance,
      recentRecords: dailyDistanceSeries,
      allDailyRecords: allDailyDistanceSeries,
    );

    final SensorEvaluation? sensorEvaluation =
        (latest != null && latest.hasData)
            ? _dailyStatusSummaryService.buildSensorEvaluation(
                assessment: latest,
                activitySummary: activitySummary,
              )
            : null;

    final anomalyDetection = _anomalyDetectionService.detect(
      history: anomalyHistory,
    );

    return _DetailBundle(
      assessment: latest,
      history: history,
      activitySummary: activitySummary,
      distanceSeries: dailyDistanceSeries,
      sensorEvaluation: sensorEvaluation,
      anomalyDetection: anomalyDetection,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient =
        isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('サマリーの詳細'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          top: false,
          child: FutureBuilder<_DetailBundle>(
            future: _loadBundle(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final bundle = snap.data!;
              final a = bundle.assessment;

              if (a == null || !a.hasData) {
                return const Center(
                  child: Text('評価データがまだありません'),
                );
              }

              final tempStatus =
                  _environmentStatusService.buildTemperatureStatus(a.avgTemp);
              final humStatus =
                  _environmentStatusService.buildHumidityStatus(a.avgHum);

              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                children: [
                  _OverallSummaryCard(assessment: a),
                  if (bundle.sensorEvaluation != null) ...[
                    const SizedBox(height: 18),
                    _SensorEvaluationCard(
                      evaluation: bundle.sensorEvaluation!,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _SensorEvaluationBreakdownScreen(
                              evaluation: bundle.sensorEvaluation!,
                            ),
                          ),
                        );
                      },
                    ),
                    if (bundle.anomalyDetection.hasAnomaly) ...[
                      const SizedBox(height: 18),
                      _AnomalyDetectionCard(
                        result: bundle.anomalyDetection,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _AnomalyDetectionBreakdownScreen(
                                result: bundle.anomalyDetection,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                  const SizedBox(height: 18),
                  _SectionLabel(title: '環境'),
                  const SizedBox(height: 10),
                  _MetricDetailCard(
                    title: '過去7日間の平均温度',
                    card: tempStatus.card,
                    secondaryStats: [
                      const _StatItem('対象期間', '過去7日'),
                      _StatItem('評価時刻', _formatTime(a.evaluatedAt)),
                    ],
                    sparkValues: bundle.history
                        .map((e) => e.avgTemp)
                        .whereType<double>()
                        .toList(),
                    accent: AppTheme.environmentAccent(a.level),
                  ),
                  const SizedBox(height: 14),
                  _MetricDetailCard(
                    title: '過去7日間の平均湿度',
                    card: humStatus.card,
                    secondaryStats: [
                      const _StatItem('対象期間', '過去7日'),
                      _StatItem('評価時刻', _formatTime(a.evaluatedAt)),
                    ],
                    sparkValues: bundle.history
                        .map((e) => e.avgHum)
                        .whereType<double>()
                        .toList(),
                    accent: AppTheme.environmentAccent(a.level),
                  ),
                  const SizedBox(height: 20),
                  _SectionLabel(title: '活動量'),
                  const SizedBox(height: 10),
                  _MetricDetailCard(
                    title: '直近の走った距離',
                    card: bundle.activitySummary.card,
                    secondaryStats: [
                      _StatItem(
                        '7日平均',
                        '${bundle.activitySummary.avg7DistanceMeters.toStringAsFixed(0)} m',
                      ),
                      _StatItem(
                        '最新記録',
                        bundle.activitySummary.latestRecordedAt != null
                            ? _formatTime(
                                bundle.activitySummary.latestRecordedAt)
                            : '—',
                      ),
                    ],
                    sparkValues:
                        bundle.distanceSeries.map((e) => e.distance).toList(),
                    accent: AppTheme.accent,
                  ),
                  const SizedBox(height: 14),
                  if (bundle.activitySummary.distribution != null)
                    _ActivityDistributionCard(
                      distribution: bundle.activitySummary.distribution!,
                      referenceDate: bundle.activitySummary.referenceDate,
                      todayHasRecord: bundle.activitySummary.todayHasRecord,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static String _formatTime(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('M/d HH:mm').format(dt.toLocal());
  }
}

class _DetailBundle {
  final EnvironmentAssessment? assessment;
  final List<EnvironmentAssessmentHistory> history;
  final ActivitySummary activitySummary;
  final List<HealthRecord> distanceSeries;
  final SensorEvaluation? sensorEvaluation;
  final AnomalyDetectionResult anomalyDetection;

  _DetailBundle({
    required this.assessment,
    required this.history,
    required this.activitySummary,
    required this.distanceSeries,
    required this.sensorEvaluation,
    required this.anomalyDetection,
  });
}

class _OverallSummaryCard extends StatelessWidget {
  final EnvironmentAssessment assessment;

  const _OverallSummaryCard({required this.assessment});

  @override
  Widget build(BuildContext context) {
    final accent =
        AppTheme.environmentAccentForContext(context, assessment.level);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: Offset(0, 8),
            color: AppTheme.softShadow(context),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '総合サマリー',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            '総合評価: ${assessment.level ?? '未評価'}',
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
          if ((assessment.headline ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              assessment.headline!,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
          if ((assessment.todayAction ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '今日やること',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(assessment.todayAction!),
          ],
          if ((assessment.why ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              assessment.why!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.secondaryText(context),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;

  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _SensorEvaluationCard extends StatelessWidget {
  final SensorEvaluation evaluation;
  final VoidCallback? onTap;

  const _SensorEvaluationCard({
    required this.evaluation,
    this.onTap,
  });

  String _metricStateText({
    required String metricKey,
    required MetricState state,
  }) {
    if (metricKey == 'activity' && state == MetricState.unknown) {
      return '記録待ち';
    }
    return _stateText(state);
  }

  String _metricScoreText({
    required String metricKey,
    required int score,
    required MetricState state,
  }) {
    if (metricKey == 'activity' && state == MetricState.unknown) {
      return '—';
    }
    return '$score';
  }

  String _stateText(MetricState state) {
    switch (state) {
      case MetricState.unknown:
        return '未評価';
      case MetricState.good:
        return '良好';
      case MetricState.caution:
        return '注意';
      case MetricState.alert:
        return '警戒';
    }
  }

  Color _stateColor(BuildContext context, MetricState state) {
    switch (state) {
      case MetricState.unknown:
        return AppTheme.secondaryText(context);
      case MetricState.good:
        return AppTheme.envGood;
      case MetricState.caution:
        return AppTheme.envCaution;
      case MetricState.alert:
        return AppTheme.envDanger;
    }
  }

  String _flagText(EvaluationFlag flag) {
    switch (flag) {
      case EvaluationFlag.tempLow:
        return '温度低め';
      case EvaluationFlag.tempHigh:
        return '温度高め';
      case EvaluationFlag.humidityLow:
        return '湿度低め';
      case EvaluationFlag.humidityHigh:
        return '湿度高め';
      case EvaluationFlag.activityMissing:
        return '活動記録なし';
      case EvaluationFlag.activityLow:
        return '活動量少なめ';
      case EvaluationFlag.activityHigh:
        return '活動量多め';
      case EvaluationFlag.activityDrop:
        return '活動量低下';
    }
  }

  Color _flagColor(BuildContext context, EvaluationFlag flag) {
    switch (flag) {
      case EvaluationFlag.tempLow:
      case EvaluationFlag.tempHigh:
      case EvaluationFlag.humidityLow:
      case EvaluationFlag.humidityHigh:
      case EvaluationFlag.activityLow:
      case EvaluationFlag.activityHigh:
      case EvaluationFlag.activityDrop:
        return AppTheme.envDanger;

      case EvaluationFlag.activityMissing:
        return AppTheme.secondaryText(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateColor = _stateColor(context, evaluation.overallState);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.cardSurface(context),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                blurRadius: 16,
                offset: const Offset(0, 8),
                color: AppTheme.softShadow(context),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'センサー総合評価（仮）',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.tertiaryText(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${evaluation.overallScore}',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '/ 100',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.secondaryText(context),
                          ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.chipFill(stateColor, context),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _stateText(evaluation.overallState),
                      style: TextStyle(
                        color: stateColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                evaluation.summary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.secondaryText(context),
                    ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _SensorScoreMiniChip(
                      label: '温度',
                      scoreText: _metricScoreText(
                        metricKey: 'temperature',
                        score: evaluation.temperature.score,
                        state: evaluation.temperature.state,
                      ),
                      stateText: _metricStateText(
                        metricKey: 'temperature',
                        state: evaluation.temperature.state,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SensorScoreMiniChip(
                      label: '湿度',
                      scoreText: _metricScoreText(
                        metricKey: 'humidity',
                        score: evaluation.humidity.score,
                        state: evaluation.humidity.state,
                      ),
                      stateText: _metricStateText(
                        metricKey: 'humidity',
                        state: evaluation.humidity.state,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SensorScoreMiniChip(
                      label: '活動',
                      scoreText: _metricScoreText(
                        metricKey: 'activity',
                        score: evaluation.activity.score,
                        state: evaluation.activity.state,
                      ),
                      stateText: _metricStateText(
                        metricKey: 'activity',
                        state: evaluation.activity.state,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: evaluation.flags.isEmpty
                    ? [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.chipFill(
                              AppTheme.envGood,
                              context,
                              opacity: AppTheme.isDark(context) ? 0.10 : 0.08,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '注意フラグなし',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                        ),
                      ]
                    : evaluation.flags.map(
                        (flag) {
                          final flagColor = _flagColor(context, flag);

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.chipFill(
                                flagColor,
                                context,
                                opacity: AppTheme.isDark(context) ? 0.10 : 0.08,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              _flagText(flag),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: flagColor,
                                  ),
                            ),
                          );
                        },
                      ).toList(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _SensorScoreMiniChip extends StatelessWidget {
  final String label;
  final String scoreText;
  final String stateText;

  const _SensorScoreMiniChip({
    required this.label,
    required this.scoreText,
    required this.stateText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.chipFill(
          AppTheme.accent,
          context,
          opacity: AppTheme.isDark(context) ? 0.08 : 0.06,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.secondaryText(context),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            scoreText,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            stateText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.secondaryText(context),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;

  const _StatItem(this.label, this.value);
}

class _MetricDetailCard extends StatelessWidget {
  final String title;
  final MetricCardViewData card;
  final List<_StatItem> secondaryStats;
  final List<double> sparkValues;
  final Color accent;

  const _MetricDetailCard({
    required this.title,
    required this.card,
    required this.secondaryStats,
    required this.sparkValues,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 8),
            color: AppTheme.softShadow(context),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.chipFill(accent, context),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  card.stateText,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            card.currentValueText,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: secondaryStats
                .map(
                  (s) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.chipFill(
                        AppTheme.accent,
                        context,
                        opacity: AppTheme.isDark(context) ? 0.08 : 0.06,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${s.label}: ${s.value}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Text(
            card.deltaText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            card.summaryText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.secondaryText(context),
                ),
          ),
          const SizedBox(height: 14),
          if (card.hasChart && sparkValues.length >= 2)
            SemanticSparkline(
              values: sparkValues,
              color: accent,
              bands: card.chartBands,
              height: 56,
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.chipFill(accent, context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.emptyChartText ?? 'まだデータがありません',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if ((card.emptyChartSubtext ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      card.emptyChartSubtext!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.secondaryText(context),
                          ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityDistributionCard extends StatelessWidget {
  final ActivityDistribution distribution;
  final DateTime? referenceDate;
  final bool todayHasRecord;

  const _ActivityDistributionCard({
    required this.distribution,
    required this.referenceDate,
    required this.todayHasRecord,
  });

  @override
  Widget build(BuildContext context) {
    final midIndex =
        distribution.bins.isEmpty ? 0 : distribution.bins.length ~/ 2;

    final points = distribution.bins.asMap().entries.map((entry) {
      final i = entry.key;
      final b = entry.value;

      final isLastBin = i == distribution.bins.length - 1;
      final isHighlighted = isLastBin
          ? (distribution.markerValue >= b.start &&
              distribution.markerValue <= b.end)
          : (distribution.markerValue >= b.start &&
              distribution.markerValue < b.end);

      String displayLabel = '';
      if (i == 0) {
        displayLabel = '${b.start.round()}';
      } else if (i == midIndex) {
        displayLabel = '${((b.start + b.end) / 2).round()}';
      } else if (i == distribution.bins.length - 1) {
        displayLabel = '${b.end.round()}';
      }

      return _DistributionPoint(
        xKey: 'bin_$i',
        displayLabel: displayLabel,
        count: b.count,
        isHighlighted: isHighlighted,
        start: b.start,
        end: b.end,
      );
    }).toList();

    final referenceValueText = '${distribution.markerValue.round()} m';

    final markerText = todayHasRecord
        ? '今日は $referenceValueText で、「${distribution.bandLabel}」です'
        : '今日は未入力です。直近の記録は $referenceValueText で、「${distribution.bandLabel}」でした';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: Offset(0, 8),
            color: AppTheme.softShadow(context),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '走行距離の分布',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            markerText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.secondaryText(context),
                ),
          ),
          if (referenceDate != null) ...[
            const SizedBox(height: 4),
            Text(
              '基準日: ${DateFormat('M/d').format(referenceDate!.toLocal())} の記録',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.tertiaryText(context),
                  ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 220,
            child: SfCartesianChart(
              plotAreaBorderWidth: 0,
              primaryXAxis: CategoryAxis(
                title: AxisTitle(
                  text: '走行距離 (m)',
                  textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText(context),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                labelRotation: -45,
                majorGridLines: const MajorGridLines(width: 0),
                axisLine: AxisLine(
                  color: AppTheme.chartAxis(context),
                ),
                axisLabelFormatter: (AxisLabelRenderDetails args) {
                  final point = points.firstWhere(
                    (p) => p.xKey == args.text,
                    orElse: () => _DistributionPoint(
                      xKey: '',
                      displayLabel: '',
                      count: 0,
                      isHighlighted: false,
                      start: 0,
                      end: 0,
                    ),
                  );

                  return ChartAxisLabel(
                    point.displayLabel,
                    args.textStyle,
                  );
                },
              ),
              primaryYAxis: NumericAxis(
                title: AxisTitle(
                  text: '日数',
                  textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText(context),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                majorGridLines: MajorGridLines(
                  width: 0.6,
                  color: AppTheme.chartGrid(context),
                ),
                axisLine: AxisLine(
                  color: AppTheme.chartAxis(context),
                ),
              ),
              series: <CartesianSeries>[
                ColumnSeries<_DistributionPoint, String>(
                  dataSource: points,
                  xValueMapper: (p, _) => p.xKey,
                  yValueMapper: (p, _) => p.count,
                  pointColorMapper: (p, _) => p.isHighlighted
                      ? AppTheme.histogramBarHighlight(context)
                      : AppTheme.histogramBar(context),
                  borderRadius: const BorderRadius.all(Radius.circular(6)),
                  dataLabelSettings: const DataLabelSettings(
                    isVisible: false,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PercentileChip(label: '少なめの境目', value: distribution.p25),
              _PercentileChip(label: 'ふつうの中心', value: distribution.p50),
              _PercentileChip(label: '多めの境目', value: distribution.p75),
            ],
          ),
        ],
      ),
    );
  }
}

class _DistributionPoint {
  final String xKey;
  final String displayLabel;
  final int count;
  final bool isHighlighted;
  final double start;
  final double end;

  _DistributionPoint({
    required this.xKey,
    required this.displayLabel,
    required this.count,
    required this.isHighlighted,
    required this.start,
    required this.end,
  });
}

class _PercentileChip extends StatelessWidget {
  final String label;
  final double value;

  const _PercentileChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.chipFill(
          AppTheme.accent,
          context,
          opacity: AppTheme.isDark(context) ? 0.08 : 0.06,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$label: ${value.round()} m',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _SensorEvaluationBreakdownScreen extends StatelessWidget {
  final SensorEvaluation evaluation;

  const _SensorEvaluationBreakdownScreen({
    required this.evaluation,
  });

  String _metricStateText({
    required String metricKey,
    required MetricState state,
  }) {
    if (metricKey == 'activity' && state == MetricState.unknown) {
      return '記録待ち';
    }
    return _stateText(state);
  }

  String _metricScoreText({
    required String metricKey,
    required int score,
    required MetricState state,
  }) {
    if (metricKey == 'activity' && state == MetricState.unknown) {
      return '—';
    }
    return '$score';
  }

  String _stateText(MetricState state) {
    switch (state) {
      case MetricState.unknown:
        return '未評価';
      case MetricState.good:
        return '良好';
      case MetricState.caution:
        return '注意';
      case MetricState.alert:
        return '警戒';
    }
  }

  String _flagText(EvaluationFlag flag) {
    switch (flag) {
      case EvaluationFlag.tempLow:
        return '温度低め';
      case EvaluationFlag.tempHigh:
        return '温度高め';
      case EvaluationFlag.humidityLow:
        return '湿度低め';
      case EvaluationFlag.humidityHigh:
        return '湿度高め';
      case EvaluationFlag.activityMissing:
        return '活動記録なし';
      case EvaluationFlag.activityLow:
        return '活動量少なめ';
      case EvaluationFlag.activityHigh:
        return '活動量多め';
      case EvaluationFlag.activityDrop:
        return '活動量低下';
    }
  }

  Color _flagColor(BuildContext context, EvaluationFlag flag) {
    switch (flag) {
      case EvaluationFlag.tempLow:
      case EvaluationFlag.tempHigh:
      case EvaluationFlag.humidityLow:
      case EvaluationFlag.humidityHigh:
      case EvaluationFlag.activityLow:
      case EvaluationFlag.activityHigh:
      case EvaluationFlag.activityDrop:
        return AppTheme.envDanger;

      case EvaluationFlag.activityMissing:
        return AppTheme.secondaryText(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient =
        isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('センサー評価の内訳'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          children: [
            _SensorMetricBreakdownCard(
              title: '温度',
              scoreText: _metricScoreText(
                metricKey: 'temperature',
                score: evaluation.temperature.score,
                state: evaluation.temperature.state,
              ),
              stateText: _metricStateText(
                metricKey: 'temperature',
                state: evaluation.temperature.state,
              ),
              reason: evaluation.temperature.reason,
            ),
            const SizedBox(height: 14),
            _SensorMetricBreakdownCard(
              title: '湿度',
              scoreText: _metricScoreText(
                metricKey: 'humidity',
                score: evaluation.humidity.score,
                state: evaluation.humidity.state,
              ),
              stateText: _metricStateText(
                metricKey: 'humidity',
                state: evaluation.humidity.state,
              ),
              reason: evaluation.humidity.reason,
            ),
            const SizedBox(height: 14),
            _SensorMetricBreakdownCard(
              title: '活動量',
              scoreText: _metricScoreText(
                metricKey: 'activity',
                score: evaluation.activity.score,
                state: evaluation.activity.state,
              ),
              stateText: _metricStateText(
                metricKey: 'activity',
                state: evaluation.activity.state,
              ),
              reason: evaluation.activity.reason,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.cardSurface(context),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                    color: AppTheme.softShadow(context),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '検出フラグ',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: evaluation.flags.isEmpty
                        ? [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.chipFill(
                                  AppTheme.envGood,
                                  context,
                                  opacity:
                                      AppTheme.isDark(context) ? 0.10 : 0.08,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                '注意フラグなし',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ]
                        : evaluation.flags.map(
                            (flag) {
                              final flagColor = _flagColor(context, flag);

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.chipFill(
                                    flagColor,
                                    context,
                                    opacity:
                                        AppTheme.isDark(context) ? 0.10 : 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  _flagText(flag),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: flagColor,
                                      ),
                                ),
                              );
                            },
                          ).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SensorMetricBreakdownCard extends StatelessWidget {
  final String title;
  final String scoreText;
  final String stateText;
  final String reason;

  const _SensorMetricBreakdownCard({
    required this.title,
    required this.scoreText,
    required this.stateText,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 8),
            color: AppTheme.softShadow(context),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            scoreText == '—' ? '—' : '$scoreText / 100',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            stateText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            reason,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.secondaryText(context),
                ),
          ),
        ],
      ),
    );
  }
}

class _AnomalyDetectionCard extends StatelessWidget {
  final AnomalyDetectionResult result;
  final VoidCallback? onTap;

  const _AnomalyDetectionCard({
    required this.result,
    this.onTap,
  });

  String _severityText(AnomalySeverity severity) {
    switch (severity) {
      case AnomalySeverity.info:
        return '軽微';
      case AnomalySeverity.low:
        return '低';
      case AnomalySeverity.medium:
        return '中';
      case AnomalySeverity.high:
        return '高';
    }
  }

  Color _severityColor(BuildContext context, AnomalySeverity severity) {
    switch (severity) {
      case AnomalySeverity.info:
        return AppTheme.secondaryText(context);
      case AnomalySeverity.low:
        return AppTheme.envCaution;
      case AnomalySeverity.medium:
        return AppTheme.envDanger;
      case AnomalySeverity.high:
        return AppTheme.envDanger;
    }
  }

  String _flagText(AnomalyFlag flag) {
    switch (flag) {
      case AnomalyFlag.highHumidityStreak:
        return '高湿が継続';
      case AnomalyFlag.lowTemperatureStreak:
        return '低温が継続';
      case AnomalyFlag.highTemperatureStreak:
        return '高温が継続';
      case AnomalyFlag.dangerMinutesDetected:
        return '危険域への滞在';
      case AnomalyFlag.tempSpikeDetected:
        return '温度急変';
      case AnomalyFlag.humiditySpikeDetected:
        return '湿度急変';
      case AnomalyFlag.tempRatioWorsened:
        return '温度指標が悪化';
      case AnomalyFlag.humidityRatioWorsened:
        return '湿度指標が悪化';
      case AnomalyFlag.cautionLevelStreak:
        return '注意評価が継続';
      case AnomalyFlag.dangerLevelDetected:
        return '危険評価を検出';
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = result.topAnomaly!;
    final severityColor = _severityColor(context, top.severity);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.cardSurface(context),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                blurRadius: 16,
                offset: const Offset(0, 8),
                color: AppTheme.softShadow(context),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '異常検知結果',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.tertiaryText(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      top.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.chipFill(severityColor, context),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '重要度: ${_severityText(top.severity)}',
                      style: TextStyle(
                        color: severityColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                top.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.secondaryText(context),
                    ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: result.anomalies
                    .take(3)
                    .map(
                      (a) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.chipFill(
                            _severityColor(context, a.severity),
                            context,
                            opacity: AppTheme.isDark(context) ? 0.10 : 0.08,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          _flagText(a.flag),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: _severityColor(context, a.severity),
                                  ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnomalyDetectionBreakdownScreen extends StatelessWidget {
  final AnomalyDetectionResult result;

  const _AnomalyDetectionBreakdownScreen({
    required this.result,
  });

  String _severityText(AnomalySeverity severity) {
    switch (severity) {
      case AnomalySeverity.info:
        return '軽微';
      case AnomalySeverity.low:
        return '低';
      case AnomalySeverity.medium:
        return '中';
      case AnomalySeverity.high:
        return '高';
    }
  }

  Color _severityColor(BuildContext context, AnomalySeverity severity) {
    switch (severity) {
      case AnomalySeverity.info:
        return AppTheme.secondaryText(context);
      case AnomalySeverity.low:
        return AppTheme.envCaution;
      case AnomalySeverity.medium:
        return AppTheme.envDanger;
      case AnomalySeverity.high:
        return AppTheme.envDanger;
    }
  }

  String _flagText(AnomalyFlag flag) {
    switch (flag) {
      case AnomalyFlag.highHumidityStreak:
        return '高湿が継続';
      case AnomalyFlag.lowTemperatureStreak:
        return '低温が継続';
      case AnomalyFlag.highTemperatureStreak:
        return '高温が継続';
      case AnomalyFlag.dangerMinutesDetected:
        return '危険域への滞在';
      case AnomalyFlag.tempSpikeDetected:
        return '温度急変';
      case AnomalyFlag.humiditySpikeDetected:
        return '湿度急変';
      case AnomalyFlag.tempRatioWorsened:
        return '温度指標が悪化';
      case AnomalyFlag.humidityRatioWorsened:
        return '湿度指標が悪化';
      case AnomalyFlag.cautionLevelStreak:
        return '注意評価が継続';
      case AnomalyFlag.dangerLevelDetected:
        return '危険評価を検出';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient =
        isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('異常検知の内訳'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          itemCount: result.anomalies.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final anomaly = result.anomalies[index];
            final color = _severityColor(context, anomaly.severity);

            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.cardSurface(context),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                    color: AppTheme.softShadow(context),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          anomaly.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.chipFill(color, context),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '重要度: ${_severityText(anomaly.severity)}',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _flagText(anomaly.flag),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    anomaly.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.secondaryText(context),
                        ),
                  ),
                  if (anomaly.startDateKey != null ||
                      anomaly.endDateKey != null ||
                      anomaly.count != null ||
                      anomaly.value != null) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (anomaly.startDateKey != null &&
                            anomaly.endDateKey != null)
                          _DetailChip(
                            text:
                                '期間: ${anomaly.startDateKey} 〜 ${anomaly.endDateKey}',
                          ),
                        if (anomaly.count != null)
                          _DetailChip(text: '件数: ${anomaly.count}'),
                        if (anomaly.value != null)
                          _DetailChip(
                            text: '値: ${anomaly.value!.toStringAsFixed(1)}',
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String text;

  const _DetailChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.chipFill(
          AppTheme.accent,
          context,
          opacity: AppTheme.isDark(context) ? 0.08 : 0.06,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

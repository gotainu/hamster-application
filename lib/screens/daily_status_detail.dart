import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../models/activity_distribution.dart';
import '../models/activity_summary.dart';
import '../models/environment_assessment.dart';
import '../models/environment_assessment_history.dart';
import '../models/health_record.dart';
import '../models/health_assessment.dart';
import '../models/metric_card_view_data.dart';
import '../models/sensor_evaluation.dart';
import '../models/weight_record.dart';
import '../models/weight_trend_evaluation.dart';
import '../models/anomaly_detection.dart';
import '../services/activity_trend_service.dart';
import '../services/anomaly_detection_service.dart';
import '../services/environment_assessment_repo.dart';
import '../services/distance_records_repo.dart';
import '../services/environment_status_service.dart';
import '../services/daily_status_summary_service.dart';
import '../services/weight_records_repo.dart';
import '../services/weight_trend_evaluation_service.dart';
import '../services/health_assessment_repo.dart';
import '../widgets/semantic_trend_chart.dart';
import '../widgets/status_card.dart';
import '../widgets/health_score_gauge.dart';
import '../widgets/health_score_trend_chart.dart';
import '../theme/app_theme.dart';

class DailyStatusDetailScreen extends StatefulWidget {
  const DailyStatusDetailScreen({super.key});

  @override
  State<DailyStatusDetailScreen> createState() =>
      _DailyStatusDetailScreenState();
}

class _DailyStatusDetailScreenState extends State<DailyStatusDetailScreen> {
  final _assessmentRepo = EnvironmentAssessmentRepo();
  final _healthAssessmentRepo = HealthAssessmentRepo();
  final _anomalyDetectionService = const AnomalyDetectionService();
  final _activityTrendService = const ActivityTrendService();
  final _distanceRepo = DistanceRecordsRepo();
  final _environmentStatusService = const EnvironmentStatusService();
  final _dailyStatusSummaryService = const DailyStatusSummaryService();
  final _weightRepo = WeightRecordsRepo();
  final _weightTrendService = const WeightTrendEvaluationService();

  Future<_DetailBundle> _loadBundle() async {
    final healthAssessment = await _healthAssessmentRepo.fetchLatest();
    final healthHistory =
        await _healthAssessmentRepo.fetchRecentHistory(limit: 7);
    final latest = await _assessmentRepo.fetchLatest();
    final history = await _assessmentRepo.fetchRecentHistory(limit: 7);
    final anomalyHistory = await _assessmentRepo.fetchRecentHistory(limit: 14);

    final now = DateTime.now();
    final yesterdayRaw = now.subtract(const Duration(days: 1));
    final referenceDay = DateTime(
      yesterdayRaw.year,
      yesterdayRaw.month,
      yesterdayRaw.day,
    );

    final referenceDistance =
        await _distanceRepo.fetchDailyTotalDistance(referenceDay);
    final avg7Distance = await _distanceRepo.fetchRollingDailyAverage(
      days: 7,
      todayLocal: referenceDay,
    );
    final dailyDistanceSeries = await _distanceRepo.fetchDailyDistanceSeries(
      days: 7,
      todayLocal: referenceDay,
    );
    final allDailyDistanceSeries =
        await _distanceRepo.fetchAllDailyDistanceSeries();

    final activitySummary = _activityTrendService.buildSummary(
      todayDistanceMeters: referenceDistance,
      avg7DistanceMeters: avg7Distance,
      recentRecords: dailyDistanceSeries,
      allDailyRecords: allDailyDistanceSeries,
      referenceDate: referenceDay,
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

    final weightRecords = await _weightRepo.fetchAll();
    final weightEvaluation = _weightTrendService.evaluate(weightRecords);

    return _DetailBundle(
      healthAssessment: healthAssessment,
      healthHistory: healthHistory,
      assessment: latest,
      history: history,
      activitySummary: activitySummary,
      distanceSeries: dailyDistanceSeries,
      sensorEvaluation: sensorEvaluation,
      anomalyDetection: anomalyDetection,
      activityReferenceDate: referenceDay,
      weightRecords: weightRecords,
      weightEvaluation: weightEvaluation,
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
        backgroundColor: isDark
            ? const Color(0xFF20253C)
            : const Color.fromARGB(255, 242, 244, 248),
        foregroundColor: isDark ? Colors.white : AppTheme.primaryText(context),
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
              final healthAssessment = bundle.healthAssessment;
              final hasEnvironment = a?.hasData == true;
              final hasHealth =
                  healthAssessment?.hasMeaningfulAssessment == true;

              if (!hasEnvironment && !hasHealth) {
                return const Center(
                  child: Text('評価データがまだありません'),
                );
              }

              final tempStatus = hasEnvironment
                  ? _environmentStatusService.buildTemperatureStatus(a!.avgTemp)
                  : null;
              final humStatus = hasEnvironment
                  ? _environmentStatusService.buildHumidityStatus(a!.avgHum)
                  : null;

              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                children: [
                  if (hasHealth)
                    _HealthOverallSummaryCard(
                      assessment: healthAssessment!,
                      history: bundle.healthHistory,
                    )
                  else
                    _OverallSummaryCard(assessment: a!),
                  if (hasHealth) ...[
                    const SizedBox(height: 18),
                    _HealthAssessmentBreakdownCard(
                      assessment: healthAssessment!,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _HealthAssessmentBreakdownScreen(
                              assessment: healthAssessment,
                            ),
                          ),
                        );
                      },
                    ),
                  ] else if (bundle.sensorEvaluation != null) ...[
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
                  ],
                  if (!hasHealth && bundle.anomalyDetection.hasAnomaly) ...[
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
                  const SizedBox(height: 18),
                  _SectionLabel(title: '身体・活動の変化'),
                  const SizedBox(height: 10),
                  _WeightTrendCard(
                    evaluation: bundle.weightEvaluation,
                    records: bundle.weightRecords,
                  ),
                  const SizedBox(height: 14),
                  if (bundle.activitySummary.todayHasRecord)
                    _MetricDetailCard(
                      title: '昨日の走った距離',
                      card: bundle.activitySummary.card,
                      secondaryStats: [
                        _StatItem(
                          '昨日',
                          '${bundle.activitySummary.todayDistanceMeters.toStringAsFixed(0)} m',
                        ),
                        _StatItem(
                          '7日平均',
                          '${bundle.activitySummary.avg7DistanceMeters.toStringAsFixed(0)} m',
                        ),
                        _StatItem(
                          '基準日',
                          DateFormat('M/d').format(
                            bundle.activityReferenceDate.toLocal(),
                          ),
                        ),
                      ],
                      trendPoints: bundle.distanceSeries
                          .map(
                            (e) => SemanticTrendPoint(
                              x: e.date.toLocal(),
                              y: e.distance,
                            ),
                          )
                          .toList(),
                      accent: AppTheme.accent,
                      unit: 'm',
                      chartMinimum: 0,
                      chartMaximum: _activityChartMaximum(
                        bundle.distanceSeries,
                        bundle.activitySummary.avg7DistanceMeters,
                      ),
                      chartBands: _activityChartBands(
                        bundle.activitySummary.avg7DistanceMeters,
                        _activityChartMaximum(
                          bundle.distanceSeries,
                          bundle.activitySummary.avg7DistanceMeters,
                        ),
                      ),
                    )
                  else
                    _ActivityMissingCard(
                      referenceDate: bundle.activityReferenceDate,
                    ),
                  if (bundle.activitySummary.distribution != null) ...[
                    const SizedBox(height: 14),
                    _ActivityDistributionCard(
                      distribution: bundle.activitySummary.distribution!,
                      referenceDate: bundle.activitySummary.referenceDate,
                      referenceDayHasRecord:
                          bundle.activitySummary.todayHasRecord,
                    ),
                  ],
                  if (a != null &&
                      a.hasData &&
                      tempStatus != null &&
                      humStatus != null) ...[
                    const SizedBox(height: 18),
                    _SectionLabel(title: '環境'),
                    const SizedBox(height: 10),
                    _MetricDetailCard(
                      title: '過去7日間の平均温度',
                      card: tempStatus.card,
                      secondaryStats: [
                        const _StatItem('対象期間', '過去7日'),
                        _StatItem(
                          '評価時刻',
                          _formatTime(a.evaluatedAt),
                        ),
                      ],
                      trendPoints: _historyTrendPoints(
                        history: bundle.history,
                        valueOf: (e) => e.avgTemp,
                      ),
                      accent: AppTheme.environmentAccent(a.level),
                      unit: '℃',
                      chartMinimum: 18,
                      chartMaximum: 28,
                      chartBands: [
                        SemanticTrendBand(
                          start: 18,
                          end: EnvironmentStatusService.tempMin,
                          label: '低め',
                          color: Colors.blue.withValues(alpha: 0.07),
                          labelColor: Colors.blue.shade200,
                        ),
                        SemanticTrendBand(
                          start: EnvironmentStatusService.tempMin,
                          end: EnvironmentStatusService.tempMax,
                          label: '適正',
                          color: Colors.green.withValues(alpha: 0.07),
                          labelColor: Colors.green.shade200,
                        ),
                        SemanticTrendBand(
                          start: EnvironmentStatusService.tempMax,
                          end: 28,
                          label: '高め',
                          color: Colors.orange.withValues(alpha: 0.08),
                          labelColor: Colors.orange.shade200,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _MetricDetailCard(
                      title: '過去7日間の平均湿度',
                      card: humStatus.card,
                      secondaryStats: [
                        const _StatItem('対象期間', '過去7日'),
                        _StatItem(
                          '評価時刻',
                          _formatTime(a.evaluatedAt),
                        ),
                      ],
                      trendPoints: _historyTrendPoints(
                        history: bundle.history,
                        valueOf: (e) => e.avgHum,
                      ),
                      accent: AppTheme.environmentAccent(a.level),
                      unit: '%',
                      chartMinimum: 30,
                      chartMaximum: 75,
                      chartBands: [
                        SemanticTrendBand(
                          start: 30,
                          end: EnvironmentStatusService.humMin,
                          label: '低め',
                          color: Colors.blue.withValues(alpha: 0.07),
                          labelColor: Colors.blue.shade200,
                        ),
                        SemanticTrendBand(
                          start: EnvironmentStatusService.humMin,
                          end: EnvironmentStatusService.humMax,
                          label: '適正',
                          color: Colors.green.withValues(alpha: 0.07),
                          labelColor: Colors.green.shade200,
                        ),
                        SemanticTrendBand(
                          start: EnvironmentStatusService.humMax,
                          end: 75,
                          label: '高め',
                          color: Colors.orange.withValues(alpha: 0.08),
                          labelColor: Colors.orange.shade200,
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static DateTime? _parseHistoryDate(String? rawDate) {
    final value = rawDate?.trim();
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  static List<SemanticTrendPoint> _historyTrendPoints({
    required List<EnvironmentAssessmentHistory> history,
    required double? Function(EnvironmentAssessmentHistory item) valueOf,
  }) {
    final points = <SemanticTrendPoint>[];

    for (final item in history) {
      final date = _parseHistoryDate(item.date);
      final value = valueOf(item);

      if (date == null || value == null) continue;

      points.add(
        SemanticTrendPoint(
          x: date,
          y: value,
        ),
      );
    }

    points.sort((a, b) => a.x.compareTo(b.x));
    return points;
  }

  static double _activityChartMaximum(
    List<HealthRecord> records,
    double baseline,
  ) {
    final dataMaximum = records.isEmpty
        ? 0.0
        : records
            .map((record) => record.distance)
            .reduce((a, b) => a > b ? a : b);

    final baselineMaximum = baseline > 0 ? baseline * 1.6 : 0.0;
    final maximum =
        dataMaximum > baselineMaximum ? dataMaximum : baselineMaximum;

    return maximum <= 0 ? 1000 : maximum * 1.12;
  }

  static List<SemanticTrendBand> _activityChartBands(
    double baseline,
    double maximum,
  ) {
    if (baseline <= 0) return const [];

    final lowEnd = baseline * 0.7;
    final normalEnd = baseline * 1.3;

    return [
      SemanticTrendBand(
        start: 0,
        end: lowEnd,
        label: '少なめ',
        color: Colors.orange.withValues(alpha: 0.07),
        labelColor: Colors.orange.shade200,
      ),
      SemanticTrendBand(
        start: lowEnd,
        end: normalEnd,
        label: '普段の範囲',
        color: Colors.green.withValues(alpha: 0.07),
        labelColor: Colors.green.shade200,
      ),
      SemanticTrendBand(
        start: normalEnd,
        end: maximum,
        label: '多め',
        color: Colors.blue.withValues(alpha: 0.06),
        labelColor: Colors.blue.shade200,
      ),
    ];
  }

  static String _formatTime(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('M/d HH:mm').format(dt.toLocal());
  }
}

class _DetailBundle {
  final HealthAssessment? healthAssessment;
  final List<HealthAssessment> healthHistory;
  final EnvironmentAssessment? assessment;
  final List<EnvironmentAssessmentHistory> history;
  final ActivitySummary activitySummary;
  final List<HealthRecord> distanceSeries;
  final SensorEvaluation? sensorEvaluation;
  final AnomalyDetectionResult anomalyDetection;
  final DateTime activityReferenceDate;
  final List<WeightRecord> weightRecords;
  final WeightTrendEvaluation weightEvaluation;

  _DetailBundle({
    required this.healthAssessment,
    required this.healthHistory,
    required this.assessment,
    required this.history,
    required this.activitySummary,
    required this.distanceSeries,
    required this.sensorEvaluation,
    required this.anomalyDetection,
    required this.activityReferenceDate,
    required this.weightRecords,
    required this.weightEvaluation,
  });
}

class _WeightTrendCard extends StatelessWidget {
  final WeightTrendEvaluation evaluation;
  final List<WeightRecord> records;

  const _WeightTrendCard({
    required this.evaluation,
    required this.records,
  });

  StatusCardLevel _level() {
    switch (evaluation.state) {
      case WeightTrendState.stable:
        return StatusCardLevel.good;
      case WeightTrendState.changed:
        return StatusCardLevel.caution;
      case WeightTrendState.caution:
        return StatusCardLevel.danger;
      case WeightTrendState.insufficientData:
        return StatusCardLevel.unavailable;
    }
  }

  String _formatWeight(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final latest = evaluation.latest;
    final difference = evaluation.previousDifferenceGrams;
    final trendPoints = records
        .map(
          (record) => SemanticTrendPoint(
            x: record.date.toLocal(),
            y: record.weightGrams,
          ),
        )
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));

    final values = trendPoints.map((point) => point.y).toList();
    final minimumValue =
        values.isEmpty ? 0.0 : values.reduce((a, b) => a < b ? a : b);
    final maximumValue =
        values.isEmpty ? 100.0 : values.reduce((a, b) => a > b ? a : b);
    final padding = (maximumValue - minimumValue).abs() < 1
        ? 5.0
        : (maximumValue - minimumValue) * 0.25;

    return StatusCard(
      level: _level(),
      emphasize: evaluation.shouldEmphasize,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '体重',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 14),
          Text(
            latest == null ? '—' : '${_formatWeight(latest.weightGrams)}g',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                ),
          ),
          if (latest != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DetailChip(
                  text:
                      '記録日 ${DateFormat('M/d').format(latest.date.toLocal())}',
                ),
                if (difference != null)
                  _DetailChip(
                    text:
                        '前回比 ${difference >= 0 ? '+' : ''}${difference.toStringAsFixed(1)}g',
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Text(
            evaluation.headline,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            evaluation.message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.secondaryText(context),
                  height: 1.45,
                ),
          ),
          if (trendPoints.length >= 2) ...[
            const SizedBox(height: 16),
            SemanticTrendChart(
              points: trendPoints,
              bands: const [],
              unit: 'g',
              minimum:
                  (minimumValue - padding).clamp(0, double.infinity).toDouble(),
              maximum: maximumValue + padding,
              height: 210,
              mode: SemanticTrendChartMode.full,
              dateFormat: DateFormat('M/d'),
              showBandLabels: false,
              lineColor: AppTheme.isDark(context)
                  ? Colors.white
                  : const Color(0xFF374151),
            ),
          ],
        ],
      ),
    );
  }
}

class _HealthOverallSummaryCard extends StatelessWidget {
  final HealthAssessment assessment;
  final List<HealthAssessment> history;

  const _HealthOverallSummaryCard({
    required this.assessment,
    this.history = const [],
  });

  StatusCardLevel _level() {
    switch (assessment.overall.observedState) {
      case HealthAssessmentState.alert:
        return StatusCardLevel.danger;
      case HealthAssessmentState.caution:
      case HealthAssessmentState.changed:
        return StatusCardLevel.caution;
      case HealthAssessmentState.good:
      case HealthAssessmentState.stable:
        return StatusCardLevel.good;
      case HealthAssessmentState.unknown:
      case HealthAssessmentState.insufficientData:
        return StatusCardLevel.unavailable;
    }
  }

  String _confidenceLabel() {
    switch (assessment.overall.confidence) {
      case HealthAssessmentConfidence.high:
        return '高';
      case HealthAssessmentConfidence.medium:
        return '中';
      case HealthAssessmentConfidence.low:
        return '低';
      case HealthAssessmentConfidence.insufficient:
        return '不足';
    }
  }

  String _deltaText(int delta) {
    if (delta > 0) return '+$delta';
    return '$delta';
  }

  @override
  Widget build(BuildContext context) {
    final completeness =
        (assessment.dataQuality.completeness * 100).clamp(0, 100).round();
    final trend = buildHealthScoreTrendSummary(
      history: history,
      latest: assessment,
      days: 7,
    );
    final primaryFactor = assessment.overall.primaryFactor?.trim();

    return StatusCard(
      level: _level(),
      emphasize:
          assessment.overall.observedState == HealthAssessmentState.alert,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '統合コンディション評価',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 2),
          Center(
            child: HealthScoreGauge(
              score:
                  assessment.overall.score ?? assessment.overall.observedScore,
              state: assessment.overall.state,
              isProvisional: assessment.overall.isProvisional,
              width: 280,
              height: 166,
              strokeWidth: 18,
              scoreFontSize: 54,
              stateFontSize: 16,
              showProvisionalCaption: true,
            ),
          ),
          Text(
            assessment.overall.summary,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.45,
                ),
          ),
          if (primaryFactor != null && primaryFactor.isNotEmpty) ...[
            const SizedBox(height: 13),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppTheme.cardSurface(context).withValues(
                  alpha: AppTheme.isDark(context) ? 0.25 : 0.55,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.insights_rounded,
                    size: 19,
                    color: healthAssessmentAccent(
                      context,
                      assessment.overall.observedState,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '主な要因：$primaryFactor',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            '直近7日間の総合推移',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.secondaryText(context),
                  fontWeight: FontWeight.w900,
                ),
          ),
          if (trend.averageScore != null || trend.previousDayDelta != null) ...[
            const SizedBox(height: 7),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                if (trend.averageScore != null)
                  _DetailChip(text: '7日平均 ${trend.averageScore}'),
                if (trend.previousDayDelta != null)
                  _DetailChip(
                    text: '前日比 ${_deltaText(trend.previousDayDelta!)}',
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          HealthScoreTrendChart(
            summary: trend,
            height: 170,
            showThresholdLabels: true,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DetailChip(
                text: '評価信頼度 ${_confidenceLabel()}',
              ),
              _DetailChip(text: 'データ充足率 $completeness%'),
              if (assessment.overall.isProvisional)
                const _DetailChip(text: '暫定評価'),
              _DetailChip(text: '評価日 ${assessment.dateKey}'),
            ],
          ),
          if (assessment.overall.flags.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              '注意フラグ',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.secondaryText(context),
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 7),
            Text(
              assessment.overall.flags.map(_healthFlagText).join('・'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                  ),
            ),
          ],
          if (assessment.overall.recommendedActions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '確認したいこと',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.secondaryText(context),
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 7),
            ...assessment.overall.recommendedActions.take(3).map(
                  (action) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            action,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _OverallSummaryCard extends StatelessWidget {
  final EnvironmentAssessment assessment;

  const _OverallSummaryCard({required this.assessment});

  String _cleanHeadline(String raw) {
    return raw
        .trim()
        .replaceFirst(
          RegExp(r'^[⚠️❗❕‼️!！△▲\s]+'),
          '',
        )
        .replaceFirst(
          RegExp(r'^(良好|注意|警戒|危険)\s*[：:・\-]?\s*'),
          '',
        )
        .trim();
  }

  StatusCardLevel _level(String? level) {
    switch (level) {
      case '良好':
        return StatusCardLevel.good;
      case '注意':
        return StatusCardLevel.caution;
      case '危険':
        return StatusCardLevel.danger;
      default:
        return StatusCardLevel.unavailable;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent =
        AppTheme.environmentAccentForContext(context, assessment.level);

    return StatusCard(
      level: _level(assessment.level),
      emphasize: assessment.level == '危険',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '総合サマリー',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          if (_cleanHeadline(assessment.headline ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _cleanHeadline(assessment.headline ?? ''),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
            ),
          ],
          if ((assessment.todayAction ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.task_alt_rounded,
                  color: accent,
                  size: 22,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '今日やること',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        assessment.todayAction!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if ((assessment.why ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              assessment.why!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.secondaryText(context),
                    height: 1.45,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityMissingCard extends StatelessWidget {
  final DateTime referenceDate;

  const _ActivityMissingCard({
    required this.referenceDate,
  });

  @override
  Widget build(BuildContext context) {
    return StatusCard(
      level: StatusCardLevel.unavailable,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '昨日の走った距離',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 14),
          Text(
            '未入力',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.directions_run_rounded,
                size: 19,
                color: AppTheme.secondaryText(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '走行距離を記録すると、7日平均との比較と推移を表示します。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.secondaryText(context),
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '基準日 ${DateFormat('M/d').format(referenceDate.toLocal())}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.tertiaryText(context),
                  fontWeight: FontWeight.w700,
                ),
          ),
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

String _healthStateText(HealthAssessmentState state) {
  switch (state) {
    case HealthAssessmentState.alert:
      return '警戒';
    case HealthAssessmentState.caution:
      return '注意';
    case HealthAssessmentState.changed:
      return '変化あり';
    case HealthAssessmentState.good:
      return '良好';
    case HealthAssessmentState.stable:
      return '安定';
    case HealthAssessmentState.insufficientData:
      return '記録待ち';
    case HealthAssessmentState.unknown:
      return '未評価';
  }
}

Color _healthStateAccent(
  BuildContext context,
  HealthAssessmentState state,
) {
  switch (state) {
    case HealthAssessmentState.alert:
      return AppTheme.envDanger;
    case HealthAssessmentState.caution:
    case HealthAssessmentState.changed:
      return AppTheme.envCaution;
    case HealthAssessmentState.good:
    case HealthAssessmentState.stable:
      return AppTheme.envGood;
    case HealthAssessmentState.insufficientData:
    case HealthAssessmentState.unknown:
      return AppTheme.secondaryText(context);
  }
}

String _healthFlagText(String flag) {
  const labels = <String, String>{
    'environmentMissing': '環境データなし',
    'activityMissing': '活動記録なし',
    'activityComparisonMissing': '活動比較データ不足',
    'activityLow': '活動量少なめ',
    'activityDrop': '活動量低下',
    'activityHigh': '活動量多め',
    'conditionMissing': '今日の様子未入力',
    'conditionSlightlyConcerned': '少し気になる',
    'conditionVeryConcerned': 'かなり心配',
    'weightMissing': '体重記録なし',
    'weightComparisonMissing': '体重比較データ不足',
    'weightStale': '体重記録が古い',
    'weightDecreaseModerate': '体重減少',
    'weightDecreaseLarge': '体重大幅減少',
    'weightIncreaseModerate': '体重増加',
    'weightIncreaseLarge': '体重大幅増加',
    'temperatureLow': '温度低め',
    'temperatureHigh': '温度高め',
    'humidityLow': '湿度低め',
    'humidityHigh': '湿度高め',
  };

  return labels[flag] ?? flag;
}

class _HealthAssessmentBreakdownCard extends StatelessWidget {
  final HealthAssessment assessment;
  final VoidCallback? onTap;

  const _HealthAssessmentBreakdownCard({
    required this.assessment,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final domains = assessment.domains;
    final accent = _healthStateAccent(
      context,
      assessment.overall.observedState,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: AppTheme.statusCardDecoration(
            context,
            accent: accent,
            strength: 0.58,
            radius: 26,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '統合評価の内訳',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.tertiaryText(context),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                '環境・体重・活動量・今日の様子を個別に確認できます。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.secondaryText(context),
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _HealthDomainGaugeTile(
                      label: '環境',
                      domain: domains.environment,
                      isProvisional: assessment.overall.isProvisional,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _HealthDomainGaugeTile(
                      label: '体重',
                      domain: domains.body,
                      isProvisional: assessment.overall.isProvisional,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _HealthDomainGaugeTile(
                      label: '活動',
                      domain: domains.activity,
                      isProvisional: assessment.overall.isProvisional,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _HealthDomainGaugeTile(
                      label: '今日の様子',
                      domain: domains.condition,
                      isProvisional: assessment.overall.isProvisional,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthDomainGaugeTile extends StatelessWidget {
  final String label;
  final HealthDomainAssessment domain;
  final bool isProvisional;

  const _HealthDomainGaugeTile({
    required this.label,
    required this.domain,
    required this.isProvisional,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _healthStateAccent(context, domain.state);

    return Container(
      padding: const EdgeInsets.fromLTRB(7, 11, 7, 8),
      decoration: BoxDecoration(
        color: AppTheme.chipFill(
          accent,
          context,
          opacity: AppTheme.isDark(context) ? 0.12 : 0.075,
        ),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: accent.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.secondaryText(context),
                  fontWeight: FontWeight.w800,
                ),
          ),
          HealthScoreGauge(
            score: domain.score,
            state: domain.state,
            isProvisional: isProvisional,
            width: 128,
            height: 92,
            strokeWidth: 10,
            scoreFontSize: 30,
            stateFontSize: 12,
          ),
        ],
      ),
    );
  }
}

class _HealthAssessmentBreakdownScreen extends StatelessWidget {
  final HealthAssessment assessment;

  const _HealthAssessmentBreakdownScreen({
    required this.assessment,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient =
        isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF20253C) : const Color(0xFFF2F4F8),
      appBar: AppBar(
        title: const Text('統合評価の内訳'),
        backgroundColor: isDark
            ? const Color(0xFF20253C)
            : const Color.fromARGB(255, 242, 244, 248),
        foregroundColor: isDark ? Colors.white : AppTheme.primaryText(context),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            children: [
              _HealthDomainBreakdownCard(
                title: '環境',
                domain: assessment.domains.environment,
              ),
              const SizedBox(height: 14),
              _HealthDomainBreakdownCard(
                title: '体重',
                domain: assessment.domains.body,
              ),
              const SizedBox(height: 14),
              _HealthDomainBreakdownCard(
                title: '活動量',
                domain: assessment.domains.activity,
              ),
              const SizedBox(height: 14),
              _HealthDomainBreakdownCard(
                title: '今日の様子',
                domain: assessment.domains.condition,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthDomainBreakdownCard extends StatelessWidget {
  final String title;
  final HealthDomainAssessment domain;

  const _HealthDomainBreakdownCard({
    required this.title,
    required this.domain,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _healthStateAccent(context, domain.state);
    final stateText = _healthStateText(domain.state);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: AppTheme.statusCardDecoration(
        context,
        accent: accent,
        strength: domain.state == HealthAssessmentState.insufficientData
            ? 0.46
            : 0.78,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  stateText,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Center(
            child: _MetricStatusGauge(
              score: domain.score,
              stateText: stateText,
              accent: accent,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                domain.state == HealthAssessmentState.good ||
                        domain.state == HealthAssessmentState.stable
                    ? Icons.check_circle_outline_rounded
                    : domain.state == HealthAssessmentState.insufficientData
                        ? Icons.schedule_rounded
                        : Icons.info_outline_rounded,
                size: 21,
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  domain.summary,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.secondaryText(context),
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          if (domain.flags.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: domain.flags
                  .map(
                    (flag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.chipFill(
                          accent,
                          context,
                          opacity: AppTheme.isDark(context) ? 0.14 : 0.10,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _healthFlagText(flag),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (domain.recommendedActions.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...domain.recommendedActions.take(2).map(
                  (action) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.task_alt_rounded,
                          size: 18,
                          color: accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            action,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
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
      case EvaluationFlag.activityMissing:
        return AppTheme.secondaryText(context);
      case EvaluationFlag.tempLow:
      case EvaluationFlag.tempHigh:
      case EvaluationFlag.humidityLow:
      case EvaluationFlag.humidityHigh:
      case EvaluationFlag.activityLow:
      case EvaluationFlag.activityHigh:
      case EvaluationFlag.activityDrop:
        return AppTheme.envDanger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.sensorStateAccent(evaluation.overallState);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: AppTheme.statusCardDecoration(
            context,
            accent: accent,
            strength: evaluation.overallState == MetricState.good ? 0.58 : 0.9,
            radius: 26,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'センサー総合評価',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.tertiaryText(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: _StatusGauge(
                  score: evaluation.overallScore,
                  stateText: _stateText(evaluation.overallState),
                  accent: accent,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                evaluation.summary,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.primaryText(context),
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 16),
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
              if (evaluation.flags.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: evaluation.flags.map((flag) {
                    final flagColor = _flagColor(context, flag);

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.chipFill(
                          flagColor,
                          context,
                          opacity: AppTheme.isDark(context) ? 0.14 : 0.10,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _flagText(flag),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: flagColor,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusGauge extends StatelessWidget {
  final int score;
  final String stateText;
  final Color accent;

  const _StatusGauge({
    required this.score,
    required this.stateText,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(250, 150),
            painter: _StatusGaugePainter(
              progress: (score.clamp(0, 100)) / 100,
              accent: accent,
              trackColor: AppTheme.isDark(context)
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            top: 43,
            child: Column(
              children: [
                Text(
                  '$score',
                  style: TextStyle(
                    fontSize: 48,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                    color: AppTheme.primaryText(context),
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    stateText,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusGaugePainter extends CustomPainter {
  final double progress;
  final Color accent;
  final Color trackColor;

  const _StatusGaugePainter({
    required this.progress,
    required this.accent,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      20,
      20,
      size.width - 40,
      size.height * 1.34,
    );

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 17
      ..strokeCap = StrokeCap.round
      ..color = trackColor;

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 17
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: math.pi,
        endAngle: math.pi * 2,
        colors: [
          accent.withValues(alpha: 0.45),
          accent,
        ],
      ).createShader(rect);

    canvas.drawArc(rect, math.pi, math.pi, false, trackPaint);
    canvas.drawArc(
      rect,
      math.pi,
      math.pi * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _StatusGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accent != accent ||
        oldDelegate.trackColor != trackColor;
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
  final List<SemanticTrendPoint> trendPoints;
  final String unit;
  final double chartMinimum;
  final double chartMaximum;
  final List<SemanticTrendBand> chartBands;
  final Color accent;

  const _MetricDetailCard({
    required this.title,
    required this.card,
    required this.secondaryStats,
    required this.trendPoints,
    required this.accent,
    required this.unit,
    required this.chartMinimum,
    required this.chartMaximum,
    required this.chartBands,
  });

  Color _semanticAccent(BuildContext context) {
    final state = card.stateText;

    if (state.contains('危険') || state.contains('警戒') || state.contains('かなり')) {
      return AppTheme.envDanger;
    }

    if (state.contains('高め') || state.contains('低め') || state.contains('注意')) {
      return AppTheme.envCaution;
    }

    if (state.contains('適正') ||
        state.contains('理想') ||
        state.contains('良好') ||
        state.contains('普段')) {
      return AppTheme.envGood;
    }

    return accent;
  }

  StatusCardLevel _statusLevel() {
    final state = card.stateText;

    if (state.contains('危険') || state.contains('警戒') || state.contains('かなり')) {
      return StatusCardLevel.danger;
    }
    if (state.contains('高め') || state.contains('低め') || state.contains('注意')) {
      return StatusCardLevel.caution;
    }
    if (state.contains('適正') ||
        state.contains('理想') ||
        state.contains('良好') ||
        state.contains('普段')) {
      return StatusCardLevel.good;
    }
    return StatusCardLevel.neutral;
  }

  @override
  Widget build(BuildContext context) {
    final semanticAccent = _semanticAccent(context);

    return StatusCard(
      level: _statusLevel(),
      emphasize: _statusLevel() == StatusCardLevel.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 14),
          Text(
            card.currentValueText,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.4,
                  height: 1,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: secondaryStats
                .map(
                  (s) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTheme.chipFill(
                        semanticAccent,
                        context,
                        opacity: AppTheme.isDark(context) ? 0.10 : 0.07,
                      ),
                      borderRadius: BorderRadius.circular(999),
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
          const SizedBox(height: 14),
          Text(
            card.summaryText.trim().isNotEmpty
                ? card.summaryText
                : card.deltaText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.secondaryText(context),
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 16),
          if (card.hasChart && trendPoints.length >= 2)
            SemanticTrendChart(
              points: trendPoints,
              bands: chartBands,
              unit: unit,
              minimum: chartMinimum,
              maximum: chartMaximum,
              height: 220,
              mode: SemanticTrendChartMode.full,
              dateFormat: DateFormat('M/d'),
              showBandLabels: true,
              lineColor: AppTheme.isDark(context)
                  ? Colors.white
                  : const Color(0xFF374151),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.chipFill(
                  semanticAccent,
                  context,
                  opacity: AppTheme.isDark(context) ? 0.10 : 0.07,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.emptyChartText ?? 'まだデータがありません',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if ((card.emptyChartSubtext ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
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
  final bool referenceDayHasRecord;

  const _ActivityDistributionCard({
    required this.distribution,
    required this.referenceDate,
    required this.referenceDayHasRecord,
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

    final markerText = referenceDayHasRecord
        ? '昨日は $referenceValueText で、「${distribution.bandLabel}」です'
        : '昨日は未入力です。直近の記録は $referenceValueText で、「${distribution.bandLabel}」でした';
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

  List<EvaluationFlag> _flagsForMetric(String metricKey) {
    return evaluation.flags.where((flag) {
      switch (metricKey) {
        case 'temperature':
          return flag == EvaluationFlag.tempLow ||
              flag == EvaluationFlag.tempHigh;
        case 'humidity':
          return flag == EvaluationFlag.humidityLow ||
              flag == EvaluationFlag.humidityHigh;
        case 'activity':
          return flag == EvaluationFlag.activityMissing ||
              flag == EvaluationFlag.activityLow ||
              flag == EvaluationFlag.activityHigh ||
              flag == EvaluationFlag.activityDrop;
        default:
          return false;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient =
        isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF20253C) : const Color(0xFFF2F4F8),
      appBar: AppBar(
        title: const Text('センサー評価の内訳'),
        backgroundColor: isDark
            ? const Color(0xFF20253C)
            : const Color.fromARGB(255, 242, 244, 248),
        foregroundColor: isDark ? Colors.white : AppTheme.primaryText(context),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            children: [
              _SensorMetricBreakdownCard(
                title: '温度',
                score: evaluation.temperature.score,
                state: evaluation.temperature.state,
                stateText: _metricStateText(
                  metricKey: 'temperature',
                  state: evaluation.temperature.state,
                ),
                reason: evaluation.temperature.reason,
                flags: _flagsForMetric('temperature'),
                flagText: _flagText,
                flagColor: _flagColor,
              ),
              const SizedBox(height: 14),
              _SensorMetricBreakdownCard(
                title: '湿度',
                score: evaluation.humidity.score,
                state: evaluation.humidity.state,
                stateText: _metricStateText(
                  metricKey: 'humidity',
                  state: evaluation.humidity.state,
                ),
                reason: evaluation.humidity.reason,
                flags: _flagsForMetric('humidity'),
                flagText: _flagText,
                flagColor: _flagColor,
              ),
              const SizedBox(height: 14),
              _SensorMetricBreakdownCard(
                title: '活動量',
                score: evaluation.activity.state == MetricState.unknown
                    ? null
                    : evaluation.activity.score,
                state: evaluation.activity.state,
                stateText: _metricStateText(
                  metricKey: 'activity',
                  state: evaluation.activity.state,
                ),
                reason: evaluation.activity.reason,
                flags: _flagsForMetric('activity'),
                flagText: _flagText,
                flagColor: _flagColor,
              ),
              const SizedBox(height: 18),
              _DetectedFlagsCard(
                flags: evaluation.flags,
                flagText: _flagText,
                flagColor: _flagColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SensorMetricBreakdownCard extends StatelessWidget {
  final String title;
  final int? score;
  final MetricState state;
  final String stateText;
  final String reason;
  final List<EvaluationFlag> flags;
  final String Function(EvaluationFlag) flagText;
  final Color Function(BuildContext, EvaluationFlag) flagColor;

  const _SensorMetricBreakdownCard({
    required this.title,
    required this.score,
    required this.state,
    required this.stateText,
    required this.reason,
    required this.flags,
    required this.flagText,
    required this.flagColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.sensorStateAccent(state);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: AppTheme.statusCardDecoration(
        context,
        accent: accent,
        strength: state == MetricState.unknown ? 0.46 : 0.78,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  stateText,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Center(
            child: _MetricStatusGauge(
              score: score,
              stateText: stateText,
              accent: accent,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                state == MetricState.good
                    ? Icons.check_circle_outline_rounded
                    : state == MetricState.unknown
                        ? Icons.schedule_rounded
                        : Icons.info_outline_rounded,
                size: 21,
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reason,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.secondaryText(context),
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          if (flags.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: flags.map((flag) {
                final color = flagColor(context, flag);
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.chipFill(
                      color,
                      context,
                      opacity: AppTheme.isDark(context) ? 0.14 : 0.10,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    flagText(flag),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricStatusGauge extends StatelessWidget {
  final int? score;
  final String stateText;
  final Color accent;

  const _MetricStatusGauge({
    required this.score,
    required this.stateText,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(220, 132),
            painter: _StatusGaugePainter(
              progress: score == null ? 0 : score!.clamp(0, 100) / 100,
              accent: accent,
              trackColor: AppTheme.isDark(context)
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            top: 39,
            child: Column(
              children: [
                Text(
                  score == null ? '—' : '${score!}',
                  style: TextStyle(
                    fontSize: 42,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: score == null ? 0 : -1.8,
                    color: AppTheme.primaryText(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  score == null ? stateText : '/ 100',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: score == null
                            ? accent
                            : AppTheme.secondaryText(context),
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectedFlagsCard extends StatelessWidget {
  final List<EvaluationFlag> flags;
  final String Function(EvaluationFlag) flagText;
  final Color Function(BuildContext, EvaluationFlag) flagColor;

  const _DetectedFlagsCard({
    required this.flags,
    required this.flagText,
    required this.flagColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = flags.isEmpty ? AppTheme.envGood : AppTheme.envDanger;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.statusCardDecoration(
        context,
        accent: accent,
        strength: flags.isEmpty ? 0.42 : 0.58,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                flags.isEmpty ? Icons.verified_outlined : Icons.flag_outlined,
                color: accent,
              ),
              const SizedBox(width: 9),
              Text(
                '検出フラグ',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: flags.isEmpty
                ? [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.chipFill(
                          AppTheme.envGood,
                          context,
                          opacity: AppTheme.isDark(context) ? 0.12 : 0.09,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '注意フラグなし',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.envGood,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                  ]
                : flags.map((flag) {
                    final color = flagColor(context, flag);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.chipFill(
                          color,
                          context,
                          opacity: AppTheme.isDark(context) ? 0.14 : 0.10,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        flagText(flag),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    );
                  }).toList(),
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

  @override
  Widget build(BuildContext context) {
    final top = result.topAnomaly!;
    final level = top.severity == AnomalySeverity.high
        ? StatusCardLevel.danger
        : StatusCardLevel.caution;

    return StatusCard(
      level: level,
      onTap: onTap,
      emphasize: top.severity == AnomalySeverity.high,
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '異常検知結果',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.tertiaryText(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            top.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
          ),
          const SizedBox(height: 9),
          Text(
            top.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.secondaryText(context),
                  height: 1.5,
                ),
          ),
        ],
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

  IconData _anomalyIcon(AnomalyFlag flag) {
    switch (flag) {
      case AnomalyFlag.highHumidityStreak:
      case AnomalyFlag.humiditySpikeDetected:
      case AnomalyFlag.humidityRatioWorsened:
        return Icons.water_drop_rounded;
      case AnomalyFlag.lowTemperatureStreak:
        return Icons.ac_unit_rounded;
      case AnomalyFlag.highTemperatureStreak:
      case AnomalyFlag.tempSpikeDetected:
      case AnomalyFlag.tempRatioWorsened:
        return Icons.thermostat_rounded;
      case AnomalyFlag.dangerMinutesDetected:
      case AnomalyFlag.dangerLevelDetected:
        return Icons.warning_amber_rounded;
      case AnomalyFlag.cautionLevelStreak:
        return Icons.notification_important_rounded;
    }
  }

  String _dateLabel(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('M/d').format(parsed);
  }

  String? _periodText({
    required String? startDateKey,
    required String? endDateKey,
  }) {
    final start = startDateKey;
    final end = endDateKey;
    if (start == null || end == null) return null;
    return '${_dateLabel(start)}〜${_dateLabel(end)}';
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
        backgroundColor: isDark
            ? const Color(0xFF20253C)
            : const Color.fromARGB(255, 242, 244, 248),
        foregroundColor: isDark ? Colors.white : AppTheme.primaryText(context),
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
            final accent = AppTheme.anomalySeverityAccent(anomaly.severity);
            final period = _periodText(
              startDateKey: anomaly.startDateKey,
              endDateKey: anomaly.endDateKey,
            );

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.statusCardDecoration(
                context,
                accent: accent,
                strength:
                    anomaly.severity == AnomalySeverity.high ? 0.92 : 0.68,
                radius: 26,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: accent.withValues(
                            alpha: AppTheme.isDark(context) ? 0.18 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          _anomalyIcon(anomaly.flag),
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            anomaly.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  height: 1.25,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(
                            alpha: AppTheme.isDark(context) ? 0.18 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '重要度 ${_severityText(anomaly.severity)}',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    anomaly.description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.secondaryText(context),
                          height: 1.55,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (period != null ||
                      anomaly.count != null ||
                      anomaly.value != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(
                          alpha: AppTheme.isDark(context) ? 0.10 : 0.07,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 10,
                        children: [
                          if (period != null)
                            _AnomalyFact(
                              icon: Icons.calendar_today_rounded,
                              label: '期間',
                              value: period,
                            ),
                          if (anomaly.count != null)
                            _AnomalyFact(
                              icon: Icons.repeat_rounded,
                              label: '継続',
                              value: '${anomaly.count}日',
                            ),
                          if (anomaly.value != null)
                            _AnomalyFact(
                              icon: Icons.analytics_rounded,
                              label: '最新値',
                              value: anomaly.value!.toStringAsFixed(1),
                            ),
                        ],
                      ),
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

class _AnomalyFact extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AnomalyFact({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: AppTheme.secondaryText(context),
        ),
        const SizedBox(width: 6),
        Text(
          '$label $value',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
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

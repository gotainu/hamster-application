// lib/screens/home.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hamster_project/models/environment_assessment.dart';
import 'package:hamster_project/models/environment_assessment_history.dart';
import 'package:hamster_project/models/health_record.dart';
import 'package:hamster_project/models/sensor_evaluation.dart';
import 'package:hamster_project/models/anomaly_detection.dart';
import 'package:hamster_project/services/activity_trend_service.dart';
import 'package:hamster_project/services/anomaly_detection_service.dart';
import 'package:hamster_project/services/daily_status_summary_service.dart';
import 'package:hamster_project/services/distance_records_repo.dart';
import 'package:hamster_project/services/environment_status_service.dart';
import 'package:hamster_project/services/environment_assessment_repo.dart';
import 'package:hamster_project/services/environment_trend_service.dart';
import 'package:hamster_project/screens/switchbot_setup.dart';
import 'package:hamster_project/screens/func_b.dart';
import 'package:hamster_project/screens/daily_status_detail.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/widgets/semantic_sparkline.dart';

class HomeScreen extends StatefulWidget {
  final void Function(int) onTabSelected;
  const HomeScreen({super.key, required this.onTabSelected});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _activityTrendService = const ActivityTrendService();
  final _assessmentRepo = EnvironmentAssessmentRepo();
  final _anomalyDetectionService = const AnomalyDetectionService();
  final _distanceRepo = DistanceRecordsRepo();
  final _dailyStatusSummaryService = const DailyStatusSummaryService();

  List<HealthRecord> _buildRecentDistanceSeries(
    List<HealthRecord> allRecords, {
    int days = 7,
    DateTime? today,
  }) {
    final baseDay = today ?? DateTime.now();
    final normalizedToday = DateTime(baseDay.year, baseDay.month, baseDay.day);
    final startDay = normalizedToday.subtract(Duration(days: days - 1));

    final map = <String, double>{};
    for (final r in allRecords) {
      final d = r.date.toLocal();
      final day = DateTime(d.year, d.month, d.day);
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      map[key] = r.distance;
    }

    final result = <HealthRecord>[];
    for (int i = 0; i < days; i++) {
      final d = startDay.add(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      result.add(
        HealthRecord(
          date: d,
          distance: map[key] ?? 0,
        ),
      );
    }

    return result;
  }

  SensorEvaluation? _buildHomeSensorEvaluation({
    required EnvironmentAssessment? assessment,
    required List<HealthRecord> allDistanceRecords,
  }) {
    if (assessment == null || !assessment.hasData) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    double todayDistance = 0;
    for (final r in allDistanceRecords) {
      final d = r.date.toLocal();
      final day = DateTime(d.year, d.month, d.day);
      if (day == today) {
        todayDistance = r.distance;
        break;
      }
    }

    final recentRecords = _buildRecentDistanceSeries(
      allDistanceRecords,
      days: 7,
      today: today,
    );

    final avg7Distance = recentRecords.fold<double>(
          0,
          (sum, e) => sum + e.distance,
        ) /
        7;

    final activitySummary = _activityTrendService.buildSummary(
      todayDistanceMeters: todayDistance,
      avg7DistanceMeters: avg7Distance,
      recentRecords: recentRecords,
      allDailyRecords: allDistanceRecords,
    );

    return _dailyStatusSummaryService.buildSensorEvaluation(
      assessment: assessment,
      activitySummary: activitySummary,
    );
  }

  AnomalyDetectionResult _buildHomeAnomalyDetection({
    required List<EnvironmentAssessmentHistory> history,
  }) {
    return _anomalyDetectionService.detect(history: history);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient =
        isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: null,
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: StreamBuilder<EnvironmentAssessment?>(
            stream: _assessmentRepo.watchLatest(),
            builder: (context, latestSnap) {
              final assessment = latestSnap.data;
              final isLoadingLatest =
                  latestSnap.connectionState == ConnectionState.waiting;

              return StreamBuilder<List<EnvironmentAssessmentHistory>>(
                stream: _assessmentRepo.watchRecentHistory(limit: 14),
                builder: (context, historySnap) {
                  final history = historySnap.data ??
                      const <EnvironmentAssessmentHistory>[];
                  final isLoadingHistory =
                      historySnap.connectionState == ConnectionState.waiting;

                  final isLoading = isLoadingLatest || isLoadingHistory;

                  return StreamBuilder<List<HealthRecord>>(
                    stream: _distanceRepo.watchDistanceSeries(),
                    builder: (context, distanceSnap) {
                      final allDistanceRecords =
                          distanceSnap.data ?? const <HealthRecord>[];

                      final sensorEvaluation = _buildHomeSensorEvaluation(
                        assessment: assessment,
                        allDistanceRecords: allDistanceRecords,
                      );

                      final anomalyDetection = _buildHomeAnomalyDetection(
                        history: history,
                      );

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HomeHeader(
                              title: assessment?.hasData == true
                                  ? 'OverView'
                                  : 'Hamster Project',
                              subtitle: assessment?.hasData == true
                                  ? 'いまの状態をすぐ確認できます'
                                  : '毎日の飼育をひと目でわかりやすく',
                            ),
                            const SizedBox(height: 18),
                            if (isLoading)
                              _EnvironmentAssessmentHero.loading()
                            else if (assessment == null || !assessment.hasData)
                              _EnvironmentAssessmentHero.empty(
                                onOpenSetup: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const SwitchbotSetupScreen(),
                                    ),
                                  );
                                },
                              )
                            else
                              _EnvironmentAssessmentHero(
                                assessment: assessment,
                                history: history,
                                sensorEvaluation: sensorEvaluation,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const DailyStatusDetailScreen(),
                                    ),
                                  );
                                },
                              ),
                            if (!isLoading && anomalyDetection.hasAnomaly) ...[
                              const SizedBox(height: 14),
                              _HomeAnomalyCard(
                                result: anomalyDetection,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const DailyStatusDetailScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],
                            const SizedBox(height: 14),
                            if (!isLoading &&
                                assessment != null &&
                                assessment.hasData &&
                                (assessment.todayAction ?? '')
                                    .trim()
                                    .isNotEmpty) ...[
                              _TodayActionCard(
                                assessment: assessment,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const DailyStatusDetailScreen(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 14),
                            ],
                            _QuickActionsCard(
                              onOpenAi: () => widget.onTabSelected(1),
                              onOpenGraph: () => widget.onTabSelected(2),
                              onOpenGraphDirect: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const FuncBScreen(),
                                  ),
                                );
                              },
                              onOpenSwitchbot: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const SwitchbotSetupScreen(),
                                  ),
                                );
                              },
                              onOpenMyPage: () => widget.onTabSelected(3),
                            ),
                            const SizedBox(height: 18),
                            Center(
                              child: Text(
                                '© 2025 Go / hamster well-being',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _HomeHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.secondaryText(context),
                ),
          ),
        ],
      ),
    );
  }
}

class _EnvironmentAssessmentHero extends StatelessWidget {
  final EnvironmentAssessment? assessment;
  final VoidCallback? onTap;
  final VoidCallback? onOpenSetup;
  final bool isLoading;
  final bool isEmptyState;
  final List<EnvironmentAssessmentHistory> history;
  final SensorEvaluation? sensorEvaluation;

  const _EnvironmentAssessmentHero({
    this.assessment,
    this.onTap,
    this.onOpenSetup,
    this.isLoading = false,
    this.isEmptyState = false,
    this.history = const [],
    this.sensorEvaluation,
  });

  static const EnvironmentTrendService _trendService =
      EnvironmentTrendService();

  static const EnvironmentStatusService _environmentStatusService =
      EnvironmentStatusService();

  factory _EnvironmentAssessmentHero.loading() {
    return const _EnvironmentAssessmentHero(isLoading: true);
  }

  factory _EnvironmentAssessmentHero.empty({
    VoidCallback? onOpenSetup,
  }) {
    return _EnvironmentAssessmentHero(
      isEmptyState: true,
      onOpenSetup: onOpenSetup,
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '未評価';
    return DateFormat('M/d HH:mm').format(dt.toLocal());
  }

  String _levelShortText(String? level) {
    switch (level) {
      case '良好':
        return '総合評価: 良好';
      case '注意':
        return '総合評価: 注意';
      case '危険':
        return '総合評価: 危険';
      default:
        return '総合評価: 未評価';
    }
  }

  List<double> _buildSparkValues(EnvironmentAssessment a) {
    final validHistory = history.where((e) => e.hasCoreData).toList();
    if (validHistory.isEmpty) return const [];

    final heroData = _environmentStatusService.buildHeroViewData(a);

    if (heroData.metricKind == EnvironmentMetricKind.humidity) {
      return validHistory.map((e) => e.avgHum).whereType<double>().toList();
    }

    return validHistory.map((e) => e.avgTemp).whereType<double>().toList();
  }

  String _sensorStateText(MetricState state) {
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

  String _sensorFlagSummary(SensorEvaluation evaluation) {
    if (evaluation.flags.isEmpty) return '気になるフラグはありません';

    return evaluation.flags.take(2).map(_flagText).join('・');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppTheme.environmentHeroGradient('注意', isDark: isDark),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '今日の注目ポイント',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppTheme.primaryText(context),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '読み込み中…',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryText(context),
              ),
            ),
          ],
        ),
      );
    }

    if (isEmptyState) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppTheme.environmentHeroGradient('注意', isDark: isDark),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '今日の飼育環境',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppTheme.primaryText(context),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'データがありません',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onOpenSetup,
              icon: const Icon(Icons.link),
              label: const Text('SwitchBot設定へ'),
            ),
          ],
        ),
      );
    }

    final a = assessment!;
    final heroData = _environmentStatusService.buildHeroViewData(a);
    final label = heroData.metricLabel;
    final value = heroData.metricValueText;
    final sub = heroData.metricSubText;

    final trend = _trendService.buildWeeklyTrendSummary(
      assessment: a,
      history: history,
      mainMetricLabel: label,
    );

    final sparkValues = _buildSparkValues(a);
    final sparkBands = heroData.chartBands;
    final accent = AppTheme.environmentAccentForContext(context, a.level);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          decoration: BoxDecoration(
            gradient: AppTheme.environmentHeroGradient(a.level, isDark: isDark),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                blurRadius: 36,
                offset: const Offset(0, 18),
                color: accent.withValues(alpha: 0.25),
              ),
            ],
          ),
          child: Stack(
            children: [
              _HeroBackgroundDecoration(accent: accent),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // タイトル（最小）
                  Text(
                    '今日の飼育環境',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.secondaryText(context),
                        ),
                  ),

                  const SizedBox(height: 24),

                  // ===== 主役ラベル =====
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.secondaryText(context),
                        ),
                  ),

                  const SizedBox(height: 4),

                  // ===== 主役数値（超重要） =====
                  Text(
                    value,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 0.9,
                          letterSpacing: -1.5,
                        ),
                  ),

                  const SizedBox(height: 6),

                  // ===== サブ説明 =====
                  Text(
                    sub,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.secondaryText(context),
                        ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Text(
                        _levelShortText(a.level),
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Text(
                          trend.directionText,
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Text(
                    trend.deltaText,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    trend.summaryText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.secondaryText(context),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (sensorEvaluation != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.isDark(context)
                            ? accent.withValues(alpha: 0.10)
                            : accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.isDark(context)
                              ? accent.withValues(alpha: 0.14)
                              : accent.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.monitor_heart_outlined,
                            size: 18,
                            color: accent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'センサーの総合評価: ${_sensorStateText(sensorEvaluation!.overallState)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: accent,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _sensorFlagSummary(sensorEvaluation!),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppTheme.secondaryText(context),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (sparkValues.length >= 2) ...[
                    const SizedBox(height: 12),
                    SemanticSparkline(
                      values: sparkValues,
                      color: accent,
                      bands: sparkBands,
                      height: 36,
                    ),
                  ],

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '最終評価: ${_formatTime(a.evaluatedAt)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.secondaryText(context),
                                  ),
                        ),
                      ),
                      Text(
                        '詳細',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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

class _HeroBackgroundDecoration extends StatelessWidget {
  final Color? accent;

  const _HeroBackgroundDecoration({this.accent});

  @override
  Widget build(BuildContext context) {
    final c = accent ?? AppTheme.accent;

    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -20,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.heroDecorationFill(
                    context,
                    c,
                    darkOpacity: 0.10,
                    lightOpacity: 0.08,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -30,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.heroDecorationFill(
                    context,
                    c,
                    darkOpacity: 0.06,
                    lightOpacity: 0.05,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 24,
              top: 28,
              child: Transform.rotate(
                angle: -0.18,
                child: Icon(
                  Icons.pets_rounded,
                  size: 92,
                  color: AppTheme.heroPetIcon(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayActionCard extends StatelessWidget {
  final EnvironmentAssessment assessment;
  final VoidCallback? onTap;

  const _TodayActionCard({
    required this.assessment,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = AppTheme.cardSurface(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                blurRadius: 16,
                offset: Offset(0, 8),
                color: Color(0x1A000000),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.chipFill(
                    AppTheme.accent,
                    context,
                    opacity: AppTheme.isDark(context) ? 0.14 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今日やること',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      assessment.todayAction ?? '',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  final VoidCallback onOpenAi;
  final VoidCallback onOpenGraph;
  final VoidCallback onOpenGraphDirect;
  final VoidCallback onOpenSwitchbot;
  final VoidCallback onOpenMyPage;

  const _QuickActionsCard({
    required this.onOpenAi,
    required this.onOpenGraph,
    required this.onOpenGraphDirect,
    required this.onOpenSwitchbot,
    required this.onOpenMyPage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardInnerDark : AppTheme.cardInnerLight,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.heroDecorationFill(
              context,
              AppTheme.accent,
              darkOpacity: 0.16,
              lightOpacity: 0.12,
            ),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'クイックアクション',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'よく使う機能にすぐアクセスできます',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.secondaryText(context),
                ),
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.55,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _QuickActionTile(
                icon: Icons.search,
                title: 'AIに相談',
                subtitle: '飼育の悩みを聞く',
                onTap: onOpenAi,
              ),
              _QuickActionTile(
                icon: Icons.show_chart_outlined,
                title: '走った記録',
                subtitle: '温湿度と運動を見る',
                onTap: onOpenGraph,
              ),
              _QuickActionTile(
                icon: Icons.open_in_new,
                title: '別画面で開く',
                subtitle: 'グラフ画面へ直接移動',
                onTap: onOpenGraphDirect,
              ),
              _QuickActionTile(
                icon: Icons.link,
                title: 'SwitchBot設定',
                subtitle: '連携や機器設定',
                onTap: onOpenSwitchbot,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _WideActionTile(
            icon: Icons.person_2_outlined,
            title: 'マイページ',
            subtitle: 'プロフィールや各種設定を見る',
            onTap: onOpenMyPage,
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tileColor = AppTheme.quickActionFill(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppTheme.quickActionBorder(context),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppTheme.accent, size: 24),
                const Spacer(),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText(context),
                        height: 1.25,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WideActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _WideActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tileColor = AppTheme.quickActionFill(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppTheme.quickActionBorder(context),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.accent, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.secondaryText(context),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.tertiaryText(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeAnomalyCard extends StatelessWidget {
  final AnomalyDetectionResult result;
  final VoidCallback? onTap;

  const _HomeAnomalyCard({
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

  @override
  Widget build(BuildContext context) {
    final top = result.topAnomaly!;
    final color = _severityColor(context, top.severity);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.cardSurface(context),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                blurRadius: 16,
                offset: const Offset(0, 8),
                color: AppTheme.softShadow(context),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.chipFill(
                    color,
                    context,
                    opacity: AppTheme.isDark(context) ? 0.14 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '最近の気になる変化',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      top.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      top.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.secondaryText(context),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '重要度: ${_severityText(top.severity)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.tertiaryText(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../models/activity_distribution.dart';
import '../models/activity_summary.dart';
import '../models/environment_assessment.dart';
import '../models/environment_assessment_history.dart';
import '../models/health_record.dart';
import '../services/activity_trend_service.dart';
import '../services/environment_assessment_repo.dart';
import '../services/health_records_repo.dart';
import '../services/environment_status_service.dart';
import '../theme/app_theme.dart';
import '../models/semantic_chart_band.dart';
import '../widgets/semantic_sparkline.dart';

class DailyStatusDetailScreen extends StatefulWidget {
  const DailyStatusDetailScreen({super.key});

  @override
  State<DailyStatusDetailScreen> createState() =>
      _DailyStatusDetailScreenState();
}

class _DailyStatusDetailScreenState extends State<DailyStatusDetailScreen> {
  final _assessmentRepo = EnvironmentAssessmentRepo();
  final _healthRepo = HealthRecordsRepo();
  final _activityTrendService = const ActivityTrendService();
  final _environmentStatusService = const EnvironmentStatusService();

  Future<_DetailBundle> _loadBundle() async {
    final latest = await _assessmentRepo.fetchLatest();
    final history = await _assessmentRepo.fetchRecentHistory(limit: 7);

    final todayDistance =
        await _healthRepo.fetchDailyTotalDistance(DateTime.now());
    final avg7Distance = await _healthRepo.fetchRollingDailyAverage(days: 7);
    final dailyDistanceSeries =
        await _healthRepo.fetchDailyDistanceSeries(days: 7);
    final allDailyDistanceSeries =
        await _healthRepo.fetchAllDailyDistanceSeries();

    final activitySummary = _activityTrendService.buildSummary(
      todayDistanceMeters: todayDistance,
      avg7DistanceMeters: avg7Distance,
      recentRecords: dailyDistanceSeries,
      allDailyRecords: allDailyDistanceSeries,
    );

    return _DetailBundle(
      assessment: latest,
      history: history,
      activitySummary: activitySummary,
      distanceSeries: dailyDistanceSeries,
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
                  const SizedBox(height: 18),
                  _SectionLabel(title: '環境'),
                  const SizedBox(height: 10),
                  _MetricDetailCard(
                    title: '過去7日間の平均温度',
                    currentValue: a.avgTemp != null
                        ? '${a.avgTemp!.toStringAsFixed(1)}℃'
                        : '—',
                    stateText: tempStatus.stateText,
                    secondaryStats: [
                      const _StatItem('対象期間', '過去7日'),
                      _StatItem('評価時刻', _formatTime(a.evaluatedAt)),
                    ],
                    summaryText: tempStatus.summaryText,
                    deltaText: tempStatus.deltaText,
                    sparkValues: bundle.history
                        .map((e) => e.avgTemp)
                        .whereType<double>()
                        .toList(),
                    accent: AppTheme.environmentAccent(a.level),
                    chartBands: tempStatus.chartBands,
                  ),
                  const SizedBox(height: 14),
                  _MetricDetailCard(
                    title: '過去7日間の平均湿度',
                    currentValue:
                        a.avgHum != null ? '${a.avgHum!.round()}%' : '—',
                    stateText: humStatus.stateText,
                    secondaryStats: [
                      const _StatItem('対象期間', '過去7日'),
                      _StatItem('評価時刻', _formatTime(a.evaluatedAt)),
                    ],
                    summaryText: humStatus.summaryText,
                    deltaText: humStatus.deltaText,
                    sparkValues: bundle.history
                        .map((e) => e.avgHum)
                        .whereType<double>()
                        .toList(),
                    accent: AppTheme.environmentAccent(a.level),
                    chartBands: humStatus.chartBands,
                  ),
                  const SizedBox(height: 20),
                  _SectionLabel(title: '活動量'),
                  const SizedBox(height: 10),
                  _MetricDetailCard(
                    title: '直近の走った距離',
                    currentValue: bundle.activitySummary.todayHasRecord
                        ? '${bundle.activitySummary.todayDistanceMeters.toStringAsFixed(0)} m'
                        : '未入力',
                    stateText: bundle.activitySummary.directionText,
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
                    summaryText: bundle.activitySummary.summaryText,
                    deltaText: bundle.activitySummary.deltaText,
                    sparkValues:
                        bundle.distanceSeries.map((e) => e.distance).toList(),
                    accent: AppTheme.accent,
                    hasChart: bundle.activitySummary.hasAnyRecord,
                    emptyChartText: 'まだ走行距離の記録がありません',
                    emptyChartSubtext: '記録すると7日推移を表示できます',
                    chartBands: bundle.activitySummary.chartBands,
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

  _DetailBundle({
    required this.assessment,
    required this.history,
    required this.activitySummary,
    required this.distanceSeries,
  });
}

class _OverallSummaryCard extends StatelessWidget {
  final EnvironmentAssessment assessment;

  const _OverallSummaryCard({required this.assessment});

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.environmentAccent(assessment.level);

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

class _StatItem {
  final String label;
  final String value;

  const _StatItem(this.label, this.value);
}

class _MetricDetailCard extends StatelessWidget {
  final String title;
  final String currentValue;
  final String stateText;
  final List<_StatItem> secondaryStats;
  final String summaryText;
  final String deltaText;
  final List<double> sparkValues;
  final Color accent;
  final bool hasChart;
  final String? emptyChartText;
  final String? emptyChartSubtext;
  final List<SemanticChartBand>? chartBands;

  const _MetricDetailCard({
    required this.title,
    required this.currentValue,
    required this.stateText,
    required this.secondaryStats,
    required this.summaryText,
    required this.deltaText,
    required this.sparkValues,
    required this.accent,
    this.hasChart = true,
    this.emptyChartText,
    this.emptyChartSubtext,
    this.chartBands,
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
                  stateText,
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
            currentValue,
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
            deltaText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            summaryText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.secondaryText(context),
                ),
          ),
          const SizedBox(height: 14),
          if (hasChart && sparkValues.length >= 2)
            SemanticSparkline(
              values: sparkValues,
              color: accent,
              bands: chartBands,
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
                    emptyChartText ?? 'まだデータがありません',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if ((emptyChartSubtext ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      emptyChartSubtext!,
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

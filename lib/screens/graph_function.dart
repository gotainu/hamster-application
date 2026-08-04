import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../models/health_record.dart';
import '../models/weight_record.dart';
import '../models/switchbot_reading.dart';
import '../services/distance_records_repo.dart';
import '../services/environment_status_service.dart';
import '../services/switchbot_repo.dart';
import '../services/weight_records_repo.dart';
import '../services/weight_trend_evaluation_service.dart';
import '../theme/app_theme.dart';
import '../widgets/floating_bottom_navigation.dart';
import 'switchbot_setup.dart';

enum _TrendMetric {
  activity,
  temperature,
  humidity,
  weight,
}

enum _TrendPeriod {
  hours24,
  days7,
  days30,
  all,
}

class GraphFunctionScreen extends StatefulWidget {
  final bool embeddedInTab;

  const GraphFunctionScreen({
    super.key,
    this.embeddedInTab = false,
  });

  @override
  State<GraphFunctionScreen> createState() => _GraphFunctionScreenState();
}

class _GraphFunctionScreenState extends State<GraphFunctionScreen> {
  final DistanceRecordsRepo _distanceRepo = DistanceRecordsRepo();
  final SwitchbotRepo _sbRepo = SwitchbotRepo();
  final WeightRecordsRepo _weightRepo = WeightRecordsRepo();

  static const EnvironmentStatusService _environmentStatusService =
      EnvironmentStatusService();
  static const WeightTrendEvaluationService _weightTrendService =
      WeightTrendEvaluationService();

  _TrendMetric _selectedMetric = _TrendMetric.activity;
  _TrendPeriod _selectedPeriod = _TrendPeriod.days7;

  @override
  Widget build(BuildContext context) {
    final topContentInset =
        MediaQuery.paddingOf(context).top + kToolbarHeight + 12;

    return StreamBuilder<SwitchbotConfig?>(
      stream: _sbRepo.watchSwitchbotConfig(),
      builder: (context, configSnap) {
        final config = configSnap.data;
        final linked = config?.isLinked ?? false;
        final hasDevice = config?.hasDevice ?? false;

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: widget.embeddedInTab
              ? null
              : AppBar(
                  title: const Text('最近の変化'),
                ),
          body: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              widget.embeddedInTab ? topContentInset : 16,
              16,
              widget.embeddedInTab
                  ? 28 + FloatingBottomNavigation.contentClearance
                  : 28,
            ),
            children: [
              if (widget.embeddedInTab) ...[
                const _TrendsHeader(),
                const SizedBox(height: 18),
              ],
              _buildMetricSelector(),
              const SizedBox(height: 12),
              _buildPeriodSelector(),
              const SizedBox(height: 18),
              _buildSelectedMetricPanel(
                linked: linked,
                hasDevice: hasDevice,
              ),
              if (_selectedMetric == _TrendMetric.temperature ||
                  _selectedMetric == _TrendMetric.humidity) ...[
                const SizedBox(height: 16),
                if (!linked)
                  _switchbotBlock(hasSwitchBot: false)
                else if (!hasDevice)
                  _switchbotNeedDeviceBlock()
                else
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('SwitchBot設定を編集'),
                      onPressed: _openSwitchbotSetup,
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricSelector() {
    const items = [
      _MetricSelectorItem(
        metric: _TrendMetric.activity,
        icon: Icons.directions_run_rounded,
        label: '活動量',
      ),
      _MetricSelectorItem(
        metric: _TrendMetric.temperature,
        icon: Icons.thermostat_rounded,
        label: '温度',
      ),
      _MetricSelectorItem(
        metric: _TrendMetric.humidity,
        icon: Icons.water_drop_outlined,
        label: '湿度',
      ),
      _MetricSelectorItem(
        metric: _TrendMetric.weight,
        icon: Icons.monitor_weight_outlined,
        label: '体重',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final item in items)
            _MetricCircleSelector(
              icon: item.icon,
              label: item.label,
              selected: _selectedMetric == item.metric,
              onTap: () {
                setState(() {
                  _selectedMetric = item.metric;
                  if (_selectedMetric == _TrendMetric.weight &&
                      _selectedPeriod == _TrendPeriod.hours24) {
                    _selectedPeriod = _TrendPeriod.days30;
                  }
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final items = <_PeriodSelectorItem>[
      if (_selectedMetric != _TrendMetric.weight)
        const _PeriodSelectorItem(
          period: _TrendPeriod.hours24,
          label: '24時間',
        ),
      const _PeriodSelectorItem(
        period: _TrendPeriod.days7,
        label: '7日',
      ),
      const _PeriodSelectorItem(
        period: _TrendPeriod.days30,
        label: '30日',
      ),
      const _PeriodSelectorItem(
        period: _TrendPeriod.all,
        label: '全期間',
      ),
    ];

    return _OuraPeriodSelector(
      items: items,
      selectedPeriod: _selectedPeriod,
      onSelected: (period) {
        setState(() {
          _selectedPeriod = period;
        });
      },
    );
  }

  String get _selectedPeriodLabel {
    switch (_selectedPeriod) {
      case _TrendPeriod.hours24:
        return '24時間';
      case _TrendPeriod.days7:
        return '7日';
      case _TrendPeriod.days30:
        return '30日';
      case _TrendPeriod.all:
        return '全期間';
    }
  }

  String get _previousPeriodLabel {
    switch (_selectedPeriod) {
      case _TrendPeriod.hours24:
        return '前の24時間';
      case _TrendPeriod.days7:
        return '前の7日';
      case _TrendPeriod.days30:
        return '前の30日';
      case _TrendPeriod.all:
        return '全期間';
    }
  }

  Widget _buildSelectedMetricPanel({
    required bool linked,
    required bool hasDevice,
  }) {
    switch (_selectedMetric) {
      case _TrendMetric.activity:
        return _buildActivityPanel();

      case _TrendMetric.temperature:
        if (!linked || !hasDevice) {
          return _buildUnavailableEnvironmentCard(
            title: '温度の変化',
            message: 'SwitchBot温湿度計を設定すると、温度の推移と現在の評価を表示できます。',
            icon: Icons.thermostat_rounded,
          );
        }

        return _buildEnvironmentPanel(
          metric: _TrendMetric.temperature,
        );

      case _TrendMetric.humidity:
        if (!linked || !hasDevice) {
          return _buildUnavailableEnvironmentCard(
            title: '湿度の変化',
            message: 'SwitchBot温湿度計を設定すると、湿度の推移と現在の評価を表示できます。',
            icon: Icons.water_drop_outlined,
          );
        }

        return _buildEnvironmentPanel(
          metric: _TrendMetric.humidity,
        );

      case _TrendMetric.weight:
        return _buildWeightPanel();
    }
  }

  Widget _buildActivityPanel() {
    return StreamBuilder<List<HealthRecord>>(
      stream: _distanceRepo.watchDistanceSeries(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildLoadingPanel();
        }

        final allPoints = (snapshot.data ?? const <HealthRecord>[])
            .map(
              (record) => _Point(
                record.date.toLocal(),
                record.distance,
              ),
            )
            .toList()
          ..sort((a, b) => a.x.compareTo(b.x));

        final points = _filterPointsBySelectedPeriod(allPoints);

        if (points.isEmpty) {
          return _buildEmptyPanel(
            title: '活動量の記録がありません',
            message: '回し車の走行距離が記録されると、活動量の変化を表示できます。',
            icon: Icons.directions_run_rounded,
          );
        }

        final latest = points.last;
        final periodAverage = _average(points);

        final previousPoints = _previousPeriodPoints(allPoints);
        final previousAverage = _average(previousPoints);

        final _ActivityStatus status;

        if (_selectedPeriod == _TrendPeriod.all) {
          status = const _ActivityStatus(
            stateText: '全期間平均',
            detailText: '記録されている全期間の平均です',
            summaryText: '長期的な活動量の基準として確認できます。',
          );
        } else {
          status = _buildActivityStatus(
            current: periodAverage,
            baseline: previousAverage,
            comparisonLabel: _previousPeriodLabel,
          );
        }

        final smoothedPoints = _buildEmaSeries(
          points,
          alpha: points.length >= 20 ? 0.22 : 0.35,
        );

        final chartBaseline =
            previousAverage > 0 ? previousAverage : periodAverage;

        final yMaximum = _activityMaximum(
          points: points,
          baseline: chartBaseline,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(
              icon: Icons.directions_run_rounded,
              title: '活動量',
              valueCaption: '$_selectedPeriodLabel平均',
              currentValue: '${periodAverage.toStringAsFixed(0)} m',
              detailText: status.detailText,
              summaryText: status.summaryText,
            ),
            const SizedBox(height: 16),
            _buildChartCard(
              title: '走行距離の推移',
              subtitle: '薄い線：実測値 太い線：傾向',
              points: points,
              smoothedPoints: smoothedPoints,
              latestPoint: latest,
              unit: 'm',
              yMinimum: 0,
              yMaximum: yMaximum,
              plotBands: _buildActivityPlotBands(
                baseline: chartBaseline,
                maximum: yMaximum,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEnvironmentPanel({
    required _TrendMetric metric,
  }) {
    return StreamBuilder<List<SwitchbotReading>>(
      stream: _sbRepo.watchLatestReadings(limit: 2000),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildLoadingPanel();
        }

        final allPoints = <_Point>[];

        for (final reading in snapshot.data ?? const <SwitchbotReading>[]) {
          final value = metric == _TrendMetric.temperature
              ? reading.temperature
              : reading.humidity;

          if (value != null) {
            allPoints.add(
              _Point(
                reading.ts.toLocal(),
                value,
              ),
            );
          }
        }

        allPoints.sort((a, b) => a.x.compareTo(b.x));

        final points = _filterPointsBySelectedPeriod(allPoints);

        if (points.isEmpty) {
          final isTemperature = metric == _TrendMetric.temperature;

          return _buildEmptyPanel(
            title: isTemperature ? '温度データがありません' : '湿度データがありません',
            message: 'SwitchBotからデータを取得すると、現在の状態と推移を表示できます。',
            icon: isTemperature
                ? Icons.thermostat_rounded
                : Icons.water_drop_outlined,
          );
        }

        final latest = points.last;
        final smoothedPoints = _buildEmaSeries(
          points,
          alpha: points.length >= 100 ? 0.12 : 0.24,
        );
        final periodAverage = _average(points);

        if (metric == _TrendMetric.temperature) {
          final status =
              _environmentStatusService.buildTemperatureStatus(periodAverage);

          final bounds = _temperatureBounds(points);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusCard(
                icon: Icons.thermostat_rounded,
                title: '温度',
                valueCaption: '$_selectedPeriodLabel平均',
                currentValue: '${periodAverage.toStringAsFixed(1)}℃',
                detailText: status.deltaText,
                summaryText: status.summaryText,
              ),
              const SizedBox(height: 16),
              _buildChartCard(
                title: '温度の推移',
                subtitle: '薄い線：実測値 太い線：傾向',
                points: points,
                smoothedPoints: smoothedPoints,
                latestPoint: latest,
                unit: '℃',
                yMinimum: bounds.minimum,
                yMaximum: bounds.maximum,
                plotBands: _buildTemperaturePlotBands(
                  minimum: bounds.minimum,
                  maximum: bounds.maximum,
                ),
              ),
            ],
          );
        }

        final status =
            _environmentStatusService.buildHumidityStatus(periodAverage);
        final bounds = _humidityBounds(points);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(
              icon: Icons.water_drop_outlined,
              title: '湿度',
              valueCaption: '$_selectedPeriodLabel平均',
              currentValue: '${periodAverage.round()}%',
              detailText: status.deltaText,
              summaryText: status.summaryText,
            ),
            const SizedBox(height: 16),
            _buildChartCard(
              title: '湿度の推移',
              subtitle: '薄い線：実測値 太い線：傾向',
              points: points,
              smoothedPoints: smoothedPoints,
              latestPoint: latest,
              unit: '%',
              yMinimum: bounds.minimum,
              yMaximum: bounds.maximum,
              plotBands: _buildHumidityPlotBands(
                minimum: bounds.minimum,
                maximum: bounds.maximum,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWeightPanel() {
    return StreamBuilder<List<WeightRecord>>(
      stream: _weightRepo.watchAll(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildLoadingPanel();
        }

        final allRecords = [...(snapshot.data ?? const <WeightRecord>[])]
          ..sort((a, b) => a.date.compareTo(b.date));

        final allPoints = allRecords
            .map((record) => _Point(record.date.toLocal(), record.weightGrams))
            .toList();

        final points = _filterPointsBySelectedPeriod(allPoints);

        if (points.isEmpty) {
          return _buildEmptyPanel(
            title: '体重の記録がありません',
            message: '記録画面で体重を入力すると、個体自身の変化を表示できます。',
            icon: Icons.monitor_weight_outlined,
          );
        }

        final filteredRecords = allRecords.where((record) {
          return points.any(
            (point) =>
                point.x.year == record.date.year &&
                point.x.month == record.date.month &&
                point.x.day == record.date.day,
          );
        }).toList();

        final evaluation = _weightTrendService.evaluate(filteredRecords);
        final latest = points.last;
        final smoothed =
            points.length >= 3 ? _buildEmaSeries(points, alpha: 0.45) : points;

        final values = points.map((point) => point.y).toList();
        final minimumValue = values.reduce((a, b) => a < b ? a : b);
        final maximumValue = values.reduce((a, b) => a > b ? a : b);
        final padding = (maximumValue - minimumValue).abs() < 1
            ? 5.0
            : (maximumValue - minimumValue) * 0.25;

        final difference = evaluation.previousDifferenceGrams;
        final differenceText = difference == null
            ? '比較データを蓄積中'
            : '前回比 ${difference >= 0 ? '+' : ''}${difference.toStringAsFixed(1)}g';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(
              icon: Icons.monitor_weight_outlined,
              title: '体重',
              valueCaption: '最新',
              currentValue: '${latest.y.toStringAsFixed(1)} g',
              detailText: differenceText,
              summaryText: evaluation.message,
            ),
            const SizedBox(height: 16),
            _buildChartCard(
              title: '体重の推移',
              subtitle: '実測値を中心に、個体自身の変化を確認します',
              points: points,
              smoothedPoints: smoothed,
              latestPoint: latest,
              unit: 'g',
              yMinimum:
                  (minimumValue - padding).clamp(0, double.infinity).toDouble(),
              yMaximum: maximumValue + padding,
              plotBands: const [],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required String currentValue,
    required String detailText,
    required String summaryText,
    required String valueCaption,
  }) {
    final isDark = AppTheme.isDark(context);
    final foreground = isDark ? Colors.white : const Color(0xFF18212C);
    final secondary = foreground.withValues(alpha: isDark ? 0.72 : 0.66);

    return _TrendGlassCard(
      padding: const EdgeInsets.fromLTRB(20, 19, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: foreground.withValues(alpha: isDark ? 0.10 : 0.08),
                  border: Border.all(
                    color: foreground.withValues(alpha: isDark ? 0.42 : 0.22),
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  icon,
                  color: foreground,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    valueCaption,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: secondary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      currentValue,
                      style: TextStyle(
                        fontSize: 36,
                        height: 1.02,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            detailText,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 7),
          Text(
            summaryText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: secondary,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required String subtitle,
    required List<_Point> points,
    required List<_Point> smoothedPoints,
    required _Point latestPoint,
    required String unit,
    required double yMinimum,
    required double yMaximum,
    required List<PlotBand> plotBands,
  }) {
    final isDark = AppTheme.isDark(context);

    final chartColor = isDark ? Colors.white : const Color(0xFF374151);

    final rawChartColor = chartColor.withValues(
      alpha: isDark ? 0.24 : 0.20,
    );
    final secondaryText = AppTheme.secondaryText(context);
    final gridColor = Theme.of(context).dividerColor.withValues(alpha: 0.32);

    final dateBounds = _dateAxisBounds(
      points: points,
    );

    return _TrendGlassCard(
      padding: const EdgeInsets.fromLTRB(16, 19, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: chartColor,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
            ),
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 330,
            child: SfCartesianChart(
              plotAreaBorderWidth: 0,
              plotAreaBackgroundColor: Colors.transparent,
              margin: EdgeInsets.zero,
              tooltipBehavior: TooltipBehavior(
                enable: true,
                format: 'point.x\npoint.y $unit',
              ),
              primaryXAxis: DateTimeAxis(
                minimum: dateBounds.minimum,
                maximum: dateBounds.maximum,
                dateFormat: switch (_selectedPeriod) {
                  _TrendPeriod.hours24 => DateFormat('HH:mm'),
                  _TrendPeriod.days7 => DateFormat('M/d'),
                  _TrendPeriod.days30 => DateFormat('M/d'),
                  _TrendPeriod.all => DateFormat('yy/M'),
                },
                intervalType: switch (_selectedPeriod) {
                  _TrendPeriod.hours24 => DateTimeIntervalType.hours,
                  _TrendPeriod.days7 => DateTimeIntervalType.days,
                  _TrendPeriod.days30 => DateTimeIntervalType.days,
                  _TrendPeriod.all => DateTimeIntervalType.auto,
                },
                majorGridLines: MajorGridLines(
                  width: 0.7,
                  color: gridColor,
                ),
                axisLine: AxisLine(
                  width: 0.8,
                  color: gridColor,
                ),
                labelStyle: TextStyle(
                  color: secondaryText,
                  fontSize: 11,
                ),
                plotBands: [
                  PlotBand(
                    start: latestPoint.x,
                    end: latestPoint.x,
                    borderWidth: 1,
                    borderColor: chartColor.withValues(alpha: 0.55),
                  ),
                ],
              ),
              primaryYAxis: NumericAxis(
                minimum: yMinimum,
                maximum: yMaximum,
                plotBands: plotBands,
                majorGridLines: MajorGridLines(
                  width: 0.7,
                  color: gridColor,
                ),
                axisLine: const AxisLine(width: 0),
                majorTickLines: const MajorTickLines(size: 0),
                labelStyle: TextStyle(
                  color: secondaryText,
                  fontSize: 11,
                ),
                axisLabelFormatter: (details) {
                  final value = details.value;

                  final label = unit == '%'
                      ? '${value.round()}%'
                      : unit == '℃'
                          ? value.toStringAsFixed(1)
                          : value.round().toString();

                  return ChartAxisLabel(
                    label,
                    details.textStyle,
                  );
                },
              ),
              series: <CartesianSeries<_Point, DateTime>>[
                LineSeries<_Point, DateTime>(
                  dataSource: points,
                  xValueMapper: (point, _) => point.x,
                  yValueMapper: (point, _) => point.y,
                  color: rawChartColor,
                  width: 1.2,
                  animationDuration: 0,
                  markerSettings: const MarkerSettings(
                    isVisible: false,
                  ),
                ),
                SplineSeries<_Point, DateTime>(
                  dataSource: smoothedPoints,
                  xValueMapper: (point, _) => point.x,
                  yValueMapper: (point, _) => point.y,
                  splineType: SplineType.monotonic,
                  color: chartColor,
                  width: 3,
                  animationDuration: 500,
                  markerSettings: const MarkerSettings(
                    isVisible: false,
                  ),
                ),
                ScatterSeries<_Point, DateTime>(
                  dataSource: [latestPoint],
                  xValueMapper: (point, _) => point.x,
                  yValueMapper: (point, _) => point.y,
                  color: chartColor,
                  animationDuration: 0,
                  markerSettings: MarkerSettings(
                    isVisible: true,
                    width: 16,
                    height: 16,
                    shape: DataMarkerType.circle,
                    color: chartColor,
                    borderWidth: 4,
                    borderColor:
                        isDark ? const Color(0xFF232635) : Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 9,
                  color: chartColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '最新値  ${_formatLatestValue(latestPoint.y, unit)}'
                    '  ・  ${DateFormat('M/d HH:mm').format(latestPoint.x)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: secondaryText,
                          fontWeight: FontWeight.w700,
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

  List<_Point> _filterPointsBySelectedPeriod(List<_Point> points) {
    if (points.isEmpty) return const [];

    final duration = _selectedPeriodDuration;

    if (duration == null) {
      return List<_Point>.from(points);
    }

    final latest = points.last.x;
    final cutoff = latest.subtract(duration);

    return points.where((point) => !point.x.isBefore(cutoff)).toList();
  }

  Duration? get _selectedPeriodDuration {
    switch (_selectedPeriod) {
      case _TrendPeriod.hours24:
        return const Duration(hours: 24);
      case _TrendPeriod.days7:
        return const Duration(days: 7);
      case _TrendPeriod.days30:
        return const Duration(days: 30);
      case _TrendPeriod.all:
        return null;
    }
  }

  List<_Point> _previousPeriodPoints(List<_Point> allPoints) {
    if (allPoints.isEmpty) return const [];

    final duration = _selectedPeriodDuration;
    if (duration == null) return const [];

    final latest = allPoints.last.x;
    final currentPeriodStart = latest.subtract(duration);
    final previousPeriodStart = currentPeriodStart.subtract(duration);

    return allPoints.where((point) {
      final isAtOrAfterPreviousStart = !point.x.isBefore(previousPeriodStart);
      final isBeforeCurrentStart = point.x.isBefore(currentPeriodStart);

      return isAtOrAfterPreviousStart && isBeforeCurrentStart;
    }).toList();
  }

  List<_Point> _buildEmaSeries(
    List<_Point> points, {
    required double alpha,
  }) {
    if (points.isEmpty) return const [];
    if (points.length == 1) return [points.first];

    final smoothed = <_Point>[];
    var current = points.first.y;

    smoothed.add(
      _Point(
        points.first.x,
        current,
      ),
    );

    for (var i = 1; i < points.length; i++) {
      current = alpha * points[i].y + (1 - alpha) * current;

      smoothed.add(
        _Point(
          points[i].x,
          current,
        ),
      );
    }

    return smoothed;
  }

  _ActivityStatus _buildActivityStatus({
    required double current,
    required double baseline,
    required String comparisonLabel,
  }) {
    if (baseline <= 0) {
      return _ActivityStatus(
        stateText: '比較データを蓄積中',
        detailText: '$comparisonLabelの記録が不足しています',
        summaryText: '記録が増えると、期間ごとの活動量変化を評価できます。',
      );
    }

    final deltaPct = (current - baseline) / baseline * 100;

    if (deltaPct <= -40) {
      return _ActivityStatus(
        stateText: 'かなり少なめ',
        detailText: '$comparisonLabelより ${deltaPct.abs().round()}% 少ない',
        summaryText: '大きな活動量低下です。体調や回し車の状態を確認したい変化です。',
      );
    }

    if (deltaPct <= -15) {
      return _ActivityStatus(
        stateText: '少なめ',
        detailText: '$comparisonLabelより ${deltaPct.abs().round()}% 少ない',
        summaryText: '以前の同じ長さの期間より活動量が少なめです。',
      );
    }

    if (deltaPct >= 60) {
      return _ActivityStatus(
        stateText: 'かなり多め',
        detailText: '$comparisonLabelより ${deltaPct.round()}% 多い',
        summaryText: '以前の同じ長さの期間より大きく増えています。',
      );
    }

    if (deltaPct >= 20) {
      return _ActivityStatus(
        stateText: '多め',
        detailText: '$comparisonLabelより ${deltaPct.round()}% 多い',
        summaryText: '以前の同じ長さの期間より活動量が多めです。',
      );
    }

    return _ActivityStatus(
      stateText: 'いつも通り',
      detailText:
          '$comparisonLabelとの差は ${deltaPct >= 0 ? '+' : ''}${deltaPct.round()}%',
      summaryText: '以前の同じ長さの期間と比べて、概ね安定しています。',
    );
  }

  List<PlotBand> _buildTemperaturePlotBands({
    required double minimum,
    required double maximum,
  }) {
    return [
      PlotBand(
        start: minimum,
        end: EnvironmentStatusService.tempMin,
        text: '低め',
        horizontalTextAlignment: TextAnchor.end,
        verticalTextAlignment: TextAnchor.middle,
        color: Colors.blue.withValues(alpha: 0.07),
        textStyle: TextStyle(
          color: Colors.blue.shade200,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      PlotBand(
        start: EnvironmentStatusService.tempMin,
        end: EnvironmentStatusService.tempMax,
        text: '適正',
        horizontalTextAlignment: TextAnchor.end,
        verticalTextAlignment: TextAnchor.middle,
        color: Colors.green.withValues(alpha: 0.07),
        textStyle: TextStyle(
          color: Colors.green.shade200,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      PlotBand(
        start: EnvironmentStatusService.tempMax,
        end: maximum,
        text: '高め',
        horizontalTextAlignment: TextAnchor.end,
        verticalTextAlignment: TextAnchor.middle,
        color: Colors.orange.withValues(alpha: 0.08),
        textStyle: TextStyle(
          color: Colors.orange.shade200,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ];
  }

  List<PlotBand> _buildHumidityPlotBands({
    required double minimum,
    required double maximum,
  }) {
    return [
      PlotBand(
        start: minimum,
        end: EnvironmentStatusService.humMin,
        text: '低め',
        horizontalTextAlignment: TextAnchor.end,
        verticalTextAlignment: TextAnchor.middle,
        color: Colors.blue.withValues(alpha: 0.07),
        textStyle: TextStyle(
          color: Colors.blue.shade200,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      PlotBand(
        start: EnvironmentStatusService.humMin,
        end: EnvironmentStatusService.humMax,
        text: '適正',
        horizontalTextAlignment: TextAnchor.end,
        verticalTextAlignment: TextAnchor.middle,
        color: Colors.green.withValues(alpha: 0.07),
        textStyle: TextStyle(
          color: Colors.green.shade200,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      PlotBand(
        start: EnvironmentStatusService.humMax,
        end: maximum,
        text: '高め',
        horizontalTextAlignment: TextAnchor.end,
        verticalTextAlignment: TextAnchor.middle,
        color: Colors.orange.withValues(alpha: 0.08),
        textStyle: TextStyle(
          color: Colors.orange.shade200,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ];
  }

  List<PlotBand> _buildActivityPlotBands({
    required double baseline,
    required double maximum,
  }) {
    if (baseline <= 0) return const [];

    final lowEnd = baseline * 0.7;
    final normalEnd = baseline * 1.3;

    return [
      PlotBand(
        start: 0,
        end: lowEnd,
        text: '少なめ',
        horizontalTextAlignment: TextAnchor.end,
        verticalTextAlignment: TextAnchor.middle,
        color: Colors.orange.withValues(alpha: 0.07),
        textStyle: TextStyle(
          color: Colors.orange.shade200,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      PlotBand(
        start: lowEnd,
        end: normalEnd,
        text: '普段の範囲',
        horizontalTextAlignment: TextAnchor.end,
        verticalTextAlignment: TextAnchor.middle,
        color: Colors.green.withValues(alpha: 0.07),
        textStyle: TextStyle(
          color: Colors.green.shade200,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      PlotBand(
        start: normalEnd,
        end: maximum,
        text: '多め',
        horizontalTextAlignment: TextAnchor.end,
        verticalTextAlignment: TextAnchor.middle,
        color: Colors.blue.withValues(alpha: 0.06),
        textStyle: TextStyle(
          color: Colors.blue.shade200,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ];
  }

  _ChartBounds _temperatureBounds(List<_Point> points) {
    final values = points.map((point) => point.y).toList();

    final dataMinimum = values.reduce((a, b) => a < b ? a : b);
    final dataMaximum = values.reduce((a, b) => a > b ? a : b);

    final minimum =
        (dataMinimum - 1.0).clamp(15.0, EnvironmentStatusService.tempMin);
    final maximum =
        (dataMaximum + 1.0).clamp(EnvironmentStatusService.tempMax, 35.0);

    return _ChartBounds(
      minimum: minimum.toDouble(),
      maximum: maximum.toDouble(),
    );
  }

  _ChartBounds _humidityBounds(List<_Point> points) {
    final values = points.map((point) => point.y).toList();

    final dataMinimum = values.reduce((a, b) => a < b ? a : b);
    final dataMaximum = values.reduce((a, b) => a > b ? a : b);

    final minimum =
        (dataMinimum - 5).clamp(20.0, EnvironmentStatusService.humMin);
    final maximum =
        (dataMaximum + 5).clamp(EnvironmentStatusService.humMax, 90.0);

    return _ChartBounds(
      minimum: minimum.toDouble(),
      maximum: maximum.toDouble(),
    );
  }

  double _activityMaximum({
    required List<_Point> points,
    required double baseline,
  }) {
    final dataMaximum =
        points.map((point) => point.y).reduce((a, b) => a > b ? a : b);

    final baselineMaximum = baseline > 0 ? baseline * 1.6 : 0.0;
    final maximum =
        dataMaximum > baselineMaximum ? dataMaximum : baselineMaximum;

    return maximum <= 0 ? 1000 : maximum * 1.12;
  }

  _DateBounds _dateAxisBounds({
    required List<_Point> points,
  }) {
    final latest = points.last.x;

    switch (_selectedPeriod) {
      case _TrendPeriod.hours24:
        return _DateBounds(
          minimum: latest.subtract(const Duration(hours: 18)),
          maximum: latest.add(const Duration(hours: 6)),
        );

      case _TrendPeriod.days7:
        return _DateBounds(
          minimum: latest.subtract(const Duration(days: 6)),
          maximum: latest.add(const Duration(days: 2)),
        );

      case _TrendPeriod.days30:
        return _DateBounds(
          minimum: latest.subtract(const Duration(days: 29)),
          maximum: latest.add(const Duration(days: 4)),
        );

      case _TrendPeriod.all:
        final first = points.first.x;
        final totalSpan = latest.difference(first);

        final paddingMilliseconds = (totalSpan.inMilliseconds * 0.06).round();

        final padding = Duration(
          milliseconds: paddingMilliseconds > 0
              ? paddingMilliseconds
              : const Duration(days: 1).inMilliseconds,
        );

        return _DateBounds(
          minimum: first.subtract(padding),
          maximum: latest.add(padding),
        );
    }
  }

  double _average(List<_Point> points) {
    if (points.isEmpty) return 0;

    final total = points.fold<double>(
      0,
      (previousValue, point) => previousValue + point.y,
    );

    return total / points.length;
  }

  String _formatLatestValue(double value, String unit) {
    if (unit == '℃') {
      return '${value.toStringAsFixed(1)}℃';
    }

    if (unit == '%') {
      return '${value.round()}%';
    }

    return '${value.toStringAsFixed(0)} m';
  }

  Widget _buildUnavailableEnvironmentCard({
    required String title,
    required String message,
    required IconData icon,
  }) {
    return _TrendGlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(
            icon,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.secondaryText(context),
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingPanel() {
    return const _TrendGlassCard(
      height: 220,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildEmptyPanel({
    required String title,
    required String message,
    required IconData icon,
  }) {
    return _TrendGlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(
            icon,
            size: 42,
            color: AppTheme.secondaryText(context),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.secondaryText(context),
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  Widget _switchbotBlock({
    required bool hasSwitchBot,
  }) {
    return _TrendGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SwitchBot連携',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'SwitchBotと連携すると、温度・湿度の自動記録と評価帯付きグラフを利用できます。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.secondaryText(context),
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            icon: const Icon(Icons.link_rounded),
            label: Text(
              hasSwitchBot ? 'SwitchBot連携を編集' : 'SwitchBotと連携する',
            ),
            onPressed: _openSwitchbotSetup,
          ),
        ],
      ),
    );
  }

  Widget _switchbotNeedDeviceBlock() {
    return _TrendGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '温湿度計を選択してください',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'SwitchBotの認証は完了しています。次に使用する温湿度計を選択してください。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.secondaryText(context),
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            icon: const Icon(Icons.settings_rounded),
            label: const Text('SwitchBot設定を開く'),
            onPressed: _openSwitchbotSetup,
          ),
        ],
      ),
    );
  }

  Future<void> _openSwitchbotSetup() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SwitchbotSetupScreen(),
      ),
    );
  }
}

class _Point {
  final DateTime x;
  final double y;

  const _Point(
    this.x,
    this.y,
  );
}

class _ActivityStatus {
  final String stateText;
  final String detailText;
  final String summaryText;

  const _ActivityStatus({
    required this.stateText,
    required this.detailText,
    required this.summaryText,
  });
}

class _ChartBounds {
  final double minimum;
  final double maximum;

  const _ChartBounds({
    required this.minimum,
    required this.maximum,
  });
}

class _DateBounds {
  final DateTime minimum;
  final DateTime maximum;

  const _DateBounds({
    required this.minimum,
    required this.maximum,
  });
}

class _TrendGlassCard extends StatelessWidget {
  const _TrendGlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.height,
    this.radius = 28,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final surface = dark
        ? const Color(0xFF171D28).withValues(alpha: 0.74)
        : Colors.white.withValues(alpha: 0.82);
    final border = dark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.72);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 10,
          sigmaY: 10,
        ),
        child: Container(
          width: double.infinity,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.24 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PeriodSelectorItem {
  final _TrendPeriod period;
  final String label;

  const _PeriodSelectorItem({
    required this.period,
    required this.label,
  });
}

class _OuraPeriodSelector extends StatelessWidget {
  const _OuraPeriodSelector({
    required this.items,
    required this.selectedPeriod,
    required this.onSelected,
  });

  final List<_PeriodSelectorItem> items;
  final _TrendPeriod selectedPeriod;
  final ValueChanged<_TrendPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    final outerFill = Colors.black.withValues(
      alpha: isDark ? 0.20 : 0.12,
    );
    final outerBorder = Colors.white.withValues(
      alpha: isDark ? 0.42 : 0.55,
    );
    final unselectedText = Colors.white.withValues(alpha: 0.92);
    final selectedText =
        isDark ? const Color(0xFF171A20) : const Color(0xFF20242B);

    return Container(
      width: double.infinity,
      height: 48,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: outerFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: outerBorder,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: Semantics(
                button: true,
                selected: item.period == selectedPeriod,
                label: '${item.label}の期間を表示',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => onSelected(item.period),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: item.period == selectedPeriod
                            ? Colors.white.withValues(alpha: 0.98)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: item.period == selectedPeriod
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: item.period == selectedPeriod
                                  ? selectedText
                                  : unselectedText,
                              fontWeight: item.period == selectedPeriod
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                              letterSpacing: 0.1,
                              shadows: item.period == selectedPeriod
                                  ? null
                                  : const [
                                      Shadow(
                                        color: Color(0x66000000),
                                        blurRadius: 6,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricSelectorItem {
  final _TrendMetric metric;
  final IconData icon;
  final String label;

  const _MetricSelectorItem({
    required this.metric,
    required this.icon,
    required this.label,
  });
}

class _MetricCircleSelector extends StatelessWidget {
  const _MetricCircleSelector({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final ringColor = selected
        ? Colors.white.withValues(alpha: 0.96)
        : Colors.white.withValues(alpha: isDark ? 0.34 : 0.48);
    final fillColor = selected
        ? Colors.white.withValues(alpha: isDark ? 0.18 : 0.28)
        : Colors.black.withValues(alpha: isDark ? 0.16 : 0.08);
    final iconColor = Colors.white.withValues(alpha: selected ? 1.0 : 0.88);
    final labelColor = Colors.white.withValues(alpha: selected ? 1.0 : 0.82);

    return SizedBox(
      width: 78,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fillColor,
                border: Border.all(
                  color: ringColor,
                  width: selected ? 1.8 : 1.2,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                size: 30,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: labelColor,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                height: 1.2,
                shadows: const [
                  Shadow(
                    color: Color(0x66000000),
                    blurRadius: 8,
                    offset: Offset(0, 1),
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

class _TrendsHeader extends StatelessWidget {
  const _TrendsHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '現在の状態と最近の傾向を見て、いつもと違う変化に気づきやすくします。',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.82),
          fontWeight: FontWeight.w500,
          height: 1.5,
          shadows: const [
            Shadow(
              color: Color(0x80000000),
              blurRadius: 8,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

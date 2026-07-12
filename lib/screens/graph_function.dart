import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../models/health_record.dart';
import '../models/switchbot_reading.dart';
import '../services/distance_records_repo.dart';
import '../services/environment_status_service.dart';
import '../services/switchbot_repo.dart';
import '../theme/app_theme.dart';
import 'switchbot_setup.dart';

enum _TrendMetric {
  activity,
  temperature,
  humidity,
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

  static const EnvironmentStatusService _environmentStatusService =
      EnvironmentStatusService();

  _TrendMetric _selectedMetric = _TrendMetric.activity;
  _TrendPeriod _selectedPeriod = _TrendPeriod.days7;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SwitchbotConfig?>(
      stream: _sbRepo.watchSwitchbotConfig(),
      builder: (context, configSnap) {
        final config = configSnap.data;
        final linked = config?.isLinked ?? false;
        final hasDevice = config?.hasDevice ?? false;

        return Scaffold(
          appBar: widget.embeddedInTab
              ? null
              : AppBar(
                  title: const Text('最近の変化'),
                ),
          body: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              widget.embeddedInTab ? 84 : 16,
              16,
              28,
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
              if (_selectedMetric != _TrendMetric.activity) ...[
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
    return SegmentedButton<_TrendMetric>(
      segments: const [
        ButtonSegment<_TrendMetric>(
          value: _TrendMetric.activity,
          icon: Icon(Icons.directions_run_rounded),
          label: Text('活動量'),
        ),
        ButtonSegment<_TrendMetric>(
          value: _TrendMetric.temperature,
          icon: Icon(Icons.thermostat_rounded),
          label: Text('温度'),
        ),
        ButtonSegment<_TrendMetric>(
          value: _TrendMetric.humidity,
          icon: Icon(Icons.water_drop_outlined),
          label: Text('湿度'),
        ),
      ],
      selected: {_selectedMetric},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        setState(() {
          _selectedMetric = selection.first;
        });
      },
    );
  }

  Widget _buildPeriodSelector() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<_TrendPeriod>(
        segments: const [
          ButtonSegment<_TrendPeriod>(
            value: _TrendPeriod.hours24,
            label: Text('24時間'),
          ),
          ButtonSegment<_TrendPeriod>(
            value: _TrendPeriod.days7,
            label: Text('7日'),
          ),
          ButtonSegment<_TrendPeriod>(
            value: _TrendPeriod.days30,
            label: Text('30日'),
          ),
          ButtonSegment<_TrendPeriod>(
            value: _TrendPeriod.all,
            label: Text('全期間'),
          ),
        ],
        selected: {_selectedPeriod},
        showSelectedIcon: false,
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
        ),
        onSelectionChanged: (selection) {
          setState(() {
            _selectedPeriod = selection.first;
          });
        },
      ),
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

  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required String currentValue,
    required String detailText,
    required String summaryText,
    required String valueCaption,
  }) {
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 9),
            color: AppTheme.softShadow(context),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: accent,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          valueCaption,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.secondaryText(context),
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
                              fontSize: 34,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.0,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  detailText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.primaryText(context),
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 7),
                Text(
                  summaryText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText(context),
                        height: 1.45,
                      ),
                ),
              ],
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

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 9),
            color: AppTheme.softShadow(context),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: secondaryText,
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 9),
            color: AppTheme.softShadow(context),
          ),
        ],
      ),
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
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildEmptyPanel({
    required String title,
    required String message,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(24),
      ),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(22),
      ),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(22),
      ),
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

class _TrendsHeader extends StatelessWidget {
  const _TrendsHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '最近の変化',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '現在の状態と最近の傾向を見て、いつもと違う変化に気づきやすくします。',
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

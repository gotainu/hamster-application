// lib/screens/graph_function.dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:intl/intl.dart';

/// 期間指定
enum _Range { h24, d7, d30 }

class GraphFunctionScreen extends StatefulWidget {
  const GraphFunctionScreen({super.key});

  @override
  State<GraphFunctionScreen> createState() => _GraphFunctionScreenState();
}

class HealthRecord {
  final DateTime date;
  final double distance;
  final String note;
  HealthRecord(this.date, this.distance, this.note);
}

class _GraphFunctionScreenState extends State<GraphFunctionScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _wheelRotationController =
      TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  final userId = FirebaseAuth.instance.currentUser!.uid;
  double? _wheelDiameter;
  double? _calculatedDistance;

  late ZoomPanBehavior _zoomPanBehavior;
  late TooltipBehavior _tooltipBehavior;

  _Range _range = _Range.d7;

  @override
  void initState() {
    super.initState();
    _loadWheelDiameter();
    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      zoomMode: ZoomMode.xy,
      enablePanning: true,
    );
    _tooltipBehavior = TooltipBehavior(
      enable: true,
      header: '',
      format: 'point.note',
    );
  }

  Future<void> _loadWheelDiameter() async {
    final docSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('breeding_environments')
        .doc('main_env')
        .get();

    setState(() {
      _wheelDiameter =
          double.tryParse(docSnapshot.data()?['wheelDiameter'] ?? '0');
    });
  }

  void _onWheelRotationChanged(String value) {
    final rotation = int.tryParse(value);
    if (_wheelDiameter != null && rotation != null) {
      final dist = rotation * 3.1416 * _wheelDiameter! * 0.01;
      setState(() => _calculatedDistance = dist);
    } else {
      setState(() => _calculatedDistance = null);
    }
  }

  void _addRecord() async {
    if (_formKey.currentState!.validate()) {
      final wheelRotation = int.parse(_wheelRotationController.text);
      final distance = _calculatedDistance ?? 0.0;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({'has_subcollections': true}, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('health_records')
          .add({
        'date': Timestamp.fromDate(DateTime.parse(_dateController.text)),
        'wheel_rotation': wheelRotation,
        'distance': distance,
        'note': _noteController.text,
      });

      _dateController.clear();
      _wheelRotationController.clear();
      _noteController.clear();
      setState(() => _calculatedDistance = null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('記録を追加しました！')),
        );
      }
    }
  }

  // ---- SwitchBot 温湿度（期間で絞り込む） ----
  Stream<QuerySnapshot<Map<String, dynamic>>> _switchbotStream() {
    final now = DateTime.now();
    DateTime since;
    switch (_range) {
      case _Range.h24:
        since = now.subtract(const Duration(hours: 24));
        break;
      case _Range.d7:
        since = now.subtract(const Duration(days: 7));
        break;
      case _Range.d30:
        since = now.subtract(const Duration(days: 30));
        break;
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('switchbot_readings')
        .where('ts', isGreaterThanOrEqualTo: since.toIso8601String())
        .orderBy('ts')
        .limit(500)
        .snapshots();
  }

  DateTime? _pickTs(Map<String, dynamic> m) {
    final v = m['ts'] ?? m['time'] ?? m['timestamp'];
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  Widget _rangeSelector() {
    return SegmentedButton<_Range>(
      segments: const [
        ButtonSegment(value: _Range.h24, label: Text('24h')),
        ButtonSegment(value: _Range.d7, label: Text('7d')),
        ButtonSegment(value: _Range.d30, label: Text('30d')),
      ],
      selected: <_Range>{_range},
      onSelectionChanged: (s) => setState(() => _range = s.first),
    );
  }

  String _rangeLabel(_Range r) {
    switch (r) {
      case _Range.h24:
        return '直近24時間';
      case _Range.d7:
        return '直近7日間';
      case _Range.d30:
        return '直近30日間';
    }
  }

// X軸：期間ごとの最適化（ラベルが消えないように調整）
  DateTimeAxis _xAxisForRange(_Range r) {
    switch (r) {
      case _Range.h24:
        return DateTimeAxis(
          intervalType: DateTimeIntervalType.hours,
          interval: 2, // 2時間ごと
          desiredIntervals: 6, // ラベル個数の目安を明示
          dateFormat: DateFormat('HH:mm'),
          labelIntersectAction: AxisLabelIntersectAction.rotate45,
          edgeLabelPlacement: EdgeLabelPlacement.shift,
          majorGridLines: const MajorGridLines(width: 0.5),
          axisLine: const AxisLine(width: 1),
          majorTickLines: const MajorTickLines(size: 4),
          labelStyle: const TextStyle(fontSize: 11),
        );

      case _Range.d7:
        return DateTimeAxis(
          intervalType: DateTimeIntervalType.days,
          interval: 1, // 1日ごと
          desiredIntervals: 7,
          dateFormat: DateFormat('MM/dd'),
          labelIntersectAction: AxisLabelIntersectAction.rotate45,
          edgeLabelPlacement: EdgeLabelPlacement.shift,
          majorGridLines: const MajorGridLines(width: 0.5),
          axisLine: const AxisLine(width: 1),
          majorTickLines: const MajorTickLines(size: 4),
          labelStyle: const TextStyle(fontSize: 11),
        );

      case _Range.d30:
        return DateTimeAxis(
          intervalType: DateTimeIntervalType.days,
          interval: 5, // 5日ごと
          desiredIntervals: 6,
          dateFormat: DateFormat('MM/dd'),
          labelIntersectAction: AxisLabelIntersectAction.rotate45,
          edgeLabelPlacement: EdgeLabelPlacement.shift,
          majorGridLines: const MajorGridLines(width: 0.5),
          axisLine: const AxisLine(width: 1),
          majorTickLines: const MajorTickLines(size: 4),
          labelStyle: const TextStyle(fontSize: 11),
        );
    }
  }

  // データの最小/最大からスパンを見て、X軸を動的に決める
  DateTimeAxis _axisForPoints(List<_Point> pts) {
    if (pts.isEmpty) {
      return DateTimeAxis(
        dateFormat: DateFormat('MM/dd'),
        majorGridLines: const MajorGridLines(width: 0.5),
        axisLine: const AxisLine(width: 1),
        majorTickLines: const MajorTickLines(size: 4),
        labelStyle: const TextStyle(fontSize: 11),
      );
    }
    final sorted = [...pts]..sort((a, b) => a.x.compareTo(b.x));
    var minX = sorted.first.x;
    var maxX = sorted.last.x;
    var span = maxX.difference(minX);

    // 同一時刻 or ほぼゼロ幅なら、見えるように±1時間広げる
    if (span.inMinutes == 0) {
      minX = minX.subtract(const Duration(hours: 1));
      maxX = maxX.add(const Duration(hours: 1));
      span = maxX.difference(minX);
    }

    // スパンに応じて刻みとフォーマットを自動化
    if (span <= const Duration(hours: 12)) {
      return DateTimeAxis(
        minimum: minX,
        maximum: maxX,
        intervalType: DateTimeIntervalType.hours,
        interval: 1,
        desiredIntervals: 8,
        dateFormat: DateFormat('HH:mm'),
        labelIntersectAction: AxisLabelIntersectAction.rotate45,
        edgeLabelPlacement: EdgeLabelPlacement.shift,
        majorGridLines: const MajorGridLines(width: 0.5),
        axisLine: const AxisLine(width: 1),
        majorTickLines: const MajorTickLines(size: 4),
        labelStyle: const TextStyle(fontSize: 11),
      );
    } else if (span <= const Duration(days: 2)) {
      return DateTimeAxis(
        minimum: minX,
        maximum: maxX,
        intervalType: DateTimeIntervalType.hours,
        interval: 3,
        desiredIntervals: 8,
        dateFormat: DateFormat('MM/dd HH:mm'),
        labelIntersectAction: AxisLabelIntersectAction.rotate45,
        edgeLabelPlacement: EdgeLabelPlacement.shift,
        majorGridLines: const MajorGridLines(width: 0.5),
        axisLine: const AxisLine(width: 1),
        majorTickLines: const MajorTickLines(size: 4),
        labelStyle: const TextStyle(fontSize: 11),
      );
    } else if (span <= const Duration(days: 14)) {
      return DateTimeAxis(
        minimum: minX,
        maximum: maxX,
        intervalType: DateTimeIntervalType.days,
        interval: 1,
        desiredIntervals: 7,
        dateFormat: DateFormat('MM/dd'),
        labelIntersectAction: AxisLabelIntersectAction.rotate45,
        edgeLabelPlacement: EdgeLabelPlacement.shift,
        majorGridLines: const MajorGridLines(width: 0.5),
        axisLine: const AxisLine(width: 1),
        majorTickLines: const MajorTickLines(size: 4),
        labelStyle: const TextStyle(fontSize: 11),
      );
    } else {
      return DateTimeAxis(
        minimum: minX,
        maximum: maxX,
        intervalType: DateTimeIntervalType.days,
        interval: 5,
        desiredIntervals: 6,
        dateFormat: DateFormat('MM/dd'),
        labelIntersectAction: AxisLabelIntersectAction.rotate45,
        edgeLabelPlacement: EdgeLabelPlacement.shift,
        majorGridLines: const MajorGridLines(width: 0.5),
        axisLine: const AxisLine(width: 1),
        majorTickLines: const MajorTickLines(size: 4),
        labelStyle: const TextStyle(fontSize: 11),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient:
                isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // ===== 手入力フォーム =====
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _dateController,
                        readOnly: true,
                        decoration:
                            const InputDecoration(labelText: '日付 (YYYY-MM-DD)'),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(DateTime.now().year - 2),
                            lastDate: DateTime(DateTime.now().year + 2),
                          );
                          if (picked != null) {
                            _dateController.text =
                                picked.toIso8601String().substring(0, 10);
                          }
                        },
                      ),
                      TextFormField(
                        controller: _wheelRotationController,
                        decoration:
                            const InputDecoration(labelText: 'Wheel回転数'),
                        keyboardType: TextInputType.number,
                        onChanged: _onWheelRotationChanged,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            const Text('走った距離（m）：'),
                            Text(
                              _calculatedDistance != null
                                  ? _calculatedDistance!.toStringAsFixed(2)
                                  : '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accent,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextFormField(
                        controller: _noteController,
                        decoration: const InputDecoration(labelText: '備考'),
                      ),
                      ElevatedButton(
                        onPressed: _addRecord,
                        child: const Text('記録を追加'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ===== 走行距離グラフ =====
                SizedBox(
                  height: 350,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .collection('health_records')
                        .orderBy('date', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final records = snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return HealthRecord(
                          (data['date'] as Timestamp).toDate(),
                          (data['distance'] as num).toDouble(),
                          data['note'] ?? '備考なし',
                        );
                      }).toList();
                      return SfCartesianChart(
                        zoomPanBehavior: _zoomPanBehavior,
                        tooltipBehavior: _tooltipBehavior,
                        primaryXAxis: const DateTimeAxis(),
                        series: [
                          LineSeries<HealthRecord, DateTime>(
                            dataSource: records,
                            xValueMapper: (d, _) => d.date,
                            yValueMapper: (d, _) => d.distance,
                            dataLabelMapper: (d, _) => d.note,
                            enableTooltip: true,
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // ===== 温度/湿度（SwitchBot） =====
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '温度 / 湿度（SwitchBot）',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                _alignLeft(_rangeSelector()),
                const SizedBox(height: 8),

                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _switchbotStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const SizedBox(
                        height: 260,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _emptyBlock(
                        context,
                        'この範囲：${_rangeLabel(_range)} は 0件です\n'
                        'FuncB →「今すぐ取得して保存」を実行してください',
                      );
                    }

                    final docs = snapshot.data!.docs.toList()
                      ..sort((a, b) {
                        final ta = _pickTs(a.data()) ?? DateTime(1970);
                        final tb = _pickTs(b.data()) ?? DateTime(1970);
                        return ta.compareTo(tb);
                      });

                    final tempPoints = <_Point>[];
                    final humPoints = <_Point>[];

                    // …tempPoints / humPoints を作った直後に追加:
                    final baseForAxis = (tempPoints.length >= humPoints.length)
                        ? tempPoints
                        : humPoints;
                    final xAxisDynamic = _axisForPoints(baseForAxis);

                    for (final d in docs) {
                      final m = d.data();
                      final t = _pickTs(m);
                      if (t == null) continue;
                      final temp = (m['temperature'] ?? m['temp']);
                      final hum = (m['humidity'] ?? m['hum']);
                      if (temp is num)
                        tempPoints.add(_Point(t, temp.toDouble()));
                      if (hum is num) humPoints.add(_Point(t, hum.toDouble()));
                    }

                    final lastTs = _pickTs(docs.last.data());

                    // ← 横並びではなく縦並び（各チャートをフル幅に）に変更
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _miniChart(
                          context: context,
                          title: '温度 (℃)',
                          points: tempPoints,
                          xAxis: xAxisDynamic,
                          height: 300,
                          yMin: null,
                          yMax: null,
                        ),
                        const SizedBox(height: 12),
                        _miniChart(
                          context: context,
                          title: '湿度 (%)',
                          points: humPoints,
                          xAxis: xAxisDynamic,
                          height: 300,
                          yMin: 0,
                          yMax: 100,
                        ),
                        const SizedBox(height: 6),
                        if (lastTs != null)
                          Text(
                            '最終更新: ${DateFormat('yyyy/MM/dd HH:mm').format(lastTs)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===== 内部ユーティリティ =====

class _Point {
  final DateTime x;
  final double y;
  _Point(this.x, this.y);
}

Widget _emptyBlock(BuildContext context, String message) {
  return Container(
    height: 120,
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withOpacity(0.2),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(message),
  );
}

Widget _miniChart({
  required BuildContext context,
  required String title,
  required List<_Point> points,
  required DateTimeAxis xAxis,
  double height = 260,
  double? yMin,
  double? yMax,
}) {
  final theme = Theme.of(context);
  return SizedBox(
    height: height,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SfCartesianChart(
        title: ChartTitle(text: title),
        primaryXAxis: xAxis, // ← ここに _xAxisForRange(_range) が渡ってくる
        primaryYAxis: NumericAxis(
          minimum: yMin,
          maximum: yMax,
          majorGridLines: const MajorGridLines(width: 0.5),
          axisLine: const AxisLine(width: 1),
          majorTickLines: const MajorTickLines(size: 4),
          labelStyle: const TextStyle(fontSize: 11),
        ),
        series: [
          LineSeries<_Point, DateTime>(
            dataSource: points,
            xValueMapper: (d, _) => d.x,
            yValueMapper: (d, _) => d.y,
            enableTooltip: true,
            markerSettings:
                const MarkerSettings(isVisible: true, width: 4, height: 4),
          ),
        ],
        zoomPanBehavior: ZoomPanBehavior(
          enablePanning: true,
          enablePinching: true,
          zoomMode: ZoomMode.xy,
        ),
        tooltipBehavior: TooltipBehavior(enable: true),
      ),
    ),
  );
}

Widget _alignLeft(Widget child) =>
    Align(alignment: Alignment.centerLeft, child: child);

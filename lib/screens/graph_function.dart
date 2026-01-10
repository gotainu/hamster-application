import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

import 'switchbot_setup.dart';

class GraphFunctionScreen extends StatefulWidget {
  const GraphFunctionScreen({super.key});

  @override
  State<GraphFunctionScreen> createState() => _GraphFunctionScreenState();
}

class _GraphFunctionScreenState extends State<GraphFunctionScreen> {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  // ===== 回し車 =====
  final _wheelCtrl = TextEditingController();
  double? _wheelDiameter;
  double? _distance;

  // ===== SwitchBot =====
  bool _hasSwitchBot = false;

  @override
  void initState() {
    super.initState();
    _loadWheelDiameter();
    _watchSwitchBotConfig();
  }

  // ---------- 回し車 ----------
  Future<void> _loadWheelDiameter() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('breeding_environments')
        .doc('main_env')
        .get();

    setState(() {
      _wheelDiameter =
          double.tryParse(doc.data()?['wheelDiameter']?.toString() ?? '0');
    });
  }

  void _onWheelChanged(String v) {
    final r = int.tryParse(v);
    if (r != null && _wheelDiameter != null) {
      setState(() {
        _distance = r * 3.1416 * _wheelDiameter! * 0.01;
      });
    } else {
      setState(() => _distance = null);
    }
  }

  // ---------- SwitchBot ----------
  void _watchSwitchBotConfig() {
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('integrations')
        .doc('switchbot')
        .collection('switchbot_secrets')
        .doc('v1_plain')
        .snapshots()
        .listen((doc) {
      setState(() => _hasSwitchBot = doc.exists);
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _switchbotStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('switchbot_readings')
        .orderBy('ts')
        .limit(500)
        .snapshots();
  }

  DateTime? _ts(Map<String, dynamic> m) {
    final v = m['ts'];
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('走った記録')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _wheelBlock(),
          const SizedBox(height: 24),
          _distanceChart(),
          const SizedBox(height: 32),
          _switchbotBlock(),
          if (_hasSwitchBot) ...[
            const SizedBox(height: 24),
            _switchbotCharts(),
          ],
        ],
      ),
    );
  }

  // ---------- Widgets ----------
  Widget _wheelBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _wheelCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '回し車の回転数'),
          onChanged: _onWheelChanged,
        ),
        const SizedBox(height: 8),
        Text(
          '走った距離（m）：${_distance?.toStringAsFixed(2) ?? '-'}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _distanceChart() {
    return SizedBox(
      height: 280,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('health_records')
            .orderBy('date')
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!.docs.map((d) {
            final m = d.data() as Map<String, dynamic>;
            return _Point(
              (m['date'] as Timestamp).toDate(),
              (m['distance'] as num).toDouble(),
            );
          }).toList();

          return SfCartesianChart(
            primaryXAxis: DateTimeAxis(),
            series: [
              LineSeries<_Point, DateTime>(
                dataSource: data,
                xValueMapper: (p, _) => p.x,
                yValueMapper: (p, _) => p.y,
              )
            ],
          );
        },
      ),
    );
  }

  Widget _switchbotBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SwitchBot'),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.link),
          label: Text(_hasSwitchBot ? 'SwitchBot連携を編集する' : 'SwitchBot連携をする'),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SwitchbotSetupScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        const Text(
          'SwitchBotと連携すると、温度・湿度の自動記録が有効になります。',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _switchbotCharts() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _switchbotStream(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final temp = <_Point>[];
        final hum = <_Point>[];

        for (final d in snap.data!.docs) {
          final m = d.data();
          final t = _ts(m);
          if (t == null) continue;
          if (m['temperature'] is num) {
            temp.add(_Point(t, (m['temperature'] as num).toDouble()));
          }
          if (m['humidity'] is num) {
            hum.add(_Point(t, (m['humidity'] as num).toDouble()));
          }
        }

        return Column(
          children: [
            _miniChart('Temperature (°C)', temp),
            const SizedBox(height: 16),
            _miniChart('Humidity (%)', hum),
          ],
        );
      },
    );
  }

  Widget _miniChart(String title, List<_Point> pts) {
    return SizedBox(
      height: 260,
      child: SfCartesianChart(
        title: ChartTitle(text: title),
        primaryXAxis: DateTimeAxis(dateFormat: DateFormat('MM/dd HH:mm')),
        series: [
          LineSeries<_Point, DateTime>(
            dataSource: pts,
            xValueMapper: (p, _) => p.x,
            yValueMapper: (p, _) => p.y,
          )
        ],
      ),
    );
  }
}

// ===== util =====
class _Point {
  final DateTime x;
  final double y;
  _Point(this.x, this.y);
}

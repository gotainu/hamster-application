import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:hamster_project/services/fetch_and_store.dart';

class FuncBScreen extends StatefulWidget {
  const FuncBScreen({super.key});

  @override
  State<FuncBScreen> createState() => _FuncBScreenState();
}

class _FuncBScreenState extends State<FuncBScreen> {
  final _fetcher = FetchAndStore();
  String? _lastInfo;

  Stream<List<_Point>> _watchPoints() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream<List<_Point>>.empty();

    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('switchbot_readings');

    return col.orderBy('ts').limit(2000).snapshots().map((qs) {
      return qs.docs
          .map((d) {
            final m = d.data();
            final tsRaw = (m['ts'] ?? d.id) as String;
            final dt = DateTime.tryParse(tsRaw)?.toLocal();

            final temperature = m['temperature'];
            final humidity = m['humidity'];
            final t = (temperature is num) ? temperature.toDouble() : null;
            final h = (humidity is num) ? humidity.toDouble() : null;

            return _Point(dt, t, h);
          })
          .where((p) => p.x != null)
          .toList();
    });
  }

  void _showSheet(String title, Object data) {
    final text = FetchAndStore.pretty(data);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(12),
          child: ListView(
            controller: controller,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SelectableText(
                text,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('走った記録（温湿度）'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Debug',
            icon: const Icon(Icons.bug_report),
            onSelected: (k) async {
              Map<String, dynamic> res;
              if (k == 'echo') {
                res = await _fetcher.debugEcho();
                _showSheet('Echo', res);
              } else if (k == 'list') {
                res = await _fetcher.debugListFromStore();
                _showSheet('Devices', res);
              } else {
                res = await _fetcher.debugStatusFromStore();
                _showSheet('Status', res);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'echo',
                child: Text('Echo (token/secret 長さ)'),
              ),
              PopupMenuItem(
                value: 'list',
                child: Text('/devices 取得'),
              ),
              PopupMenuItem(
                value: 'status',
                child: Text('/status 取得'),
              ),
            ],
          ),
          IconButton(
            tooltip: '今すぐ取得',
            icon: const Icon(Icons.sync),
            onPressed: () async {
              final res = await _fetcher.pollMineNow();
              if (!mounted) return;
              setState(() => _lastInfo = FetchAndStore.pretty(res));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('poll: ${FetchAndStore.pretty(res)}')),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<_Point>>(
        stream: _watchPoints(),
        builder: (context, snap) {
          final data = snap.data ?? const <_Point>[];

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _Card(
                title: 'Temperature (°C)',
                child: SizedBox(
                  height: 260,
                  child: SfCartesianChart(
                    plotAreaBorderWidth: 0,
                    primaryXAxis: DateTimeAxis(
                      majorGridLines: const MajorGridLines(width: 0),
                    ),
                    primaryYAxis: const NumericAxis(
                      majorGridLines: MajorGridLines(width: 0.5),
                      opposedPosition: true,
                    ),
                    series: <CartesianSeries<dynamic, dynamic>>[
                      LineSeries<_Point, DateTime>(
                        dataSource: data,
                        xValueMapper: (p, _) => p.x!,
                        yValueMapper: (p, _) => p.temp,
                        width: 2,
                        markerSettings: const MarkerSettings(isVisible: false),
                        name: 'Temp',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _Card(
                title: 'Humidity (%)',
                child: SizedBox(
                  height: 260,
                  child: SfCartesianChart(
                    plotAreaBorderWidth: 0,
                    primaryXAxis: DateTimeAxis(
                      majorGridLines: const MajorGridLines(width: 0),
                    ),
                    primaryYAxis: const NumericAxis(
                      majorGridLines: MajorGridLines(width: 0.5),
                      opposedPosition: true,
                    ),
                    series: <CartesianSeries<dynamic, dynamic>>[
                      LineSeries<_Point, DateTime>(
                        dataSource: data,
                        xValueMapper: (p, _) => p.x!,
                        yValueMapper: (p, _) => p.hum,
                        width: 2,
                        markerSettings: const MarkerSettings(isVisible: false),
                        name: 'Humidity',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_lastInfo != null)
                Text(
                  'last: $_lastInfo',
                  style: const TextStyle(fontSize: 12),
                ),
              if (snap.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (snap.hasError)
                Text(
                  '読み込みエラー: ${snap.error}',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              if (data.isEmpty &&
                  !snap.hasError &&
                  snap.connectionState == ConnectionState.active)
                const Text('データがまだありません。ポーラーの実行をお待ちください。'),
            ],
          );
        },
      ),
    );
  }
}

class _Point {
  final DateTime? x;
  final double? temp;
  final double? hum;

  _Point(this.x, this.temp, this.hum);
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;

  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 16,
            offset: Offset(0, 8),
            color: Color(0x1A000000),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

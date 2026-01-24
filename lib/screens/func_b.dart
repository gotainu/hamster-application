// lib/screens/func_b.dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../services/fetch_and_store.dart';
import '../services/switchbot_repo.dart';
import '../models/switchbot_reading.dart';

class FuncBScreen extends StatefulWidget {
  const FuncBScreen({super.key});

  @override
  State<FuncBScreen> createState() => _FuncBScreenState();
}

class _FuncBScreenState extends State<FuncBScreen> {
  final _fetcher = FetchAndStore();
  final _sbRepo = SwitchbotRepo();

  String? _lastInfo;

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
                if (!mounted) return;
                _showSheet('Echo', res);
              } else if (k == 'raw_devices') {
                res = await _fetcher.debugCallDevices();
                if (!mounted) return;
                _showSheet('Raw /devices', res);
              } else if (k == 'list') {
                res = await _fetcher.debugListFromStore();
                if (!mounted) return;
                _showSheet('Devices', res);
              } else {
                res = await _fetcher.debugStatusFromStore();
                if (!mounted) return;
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
              PopupMenuItem(
                value: 'raw_devices',
                child: Text('Debug: /devices 生レスポンス'),
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
      body: StreamBuilder<List<SwitchbotReading>>(
        stream: _sbRepo.watchReadings(limit: 2000), // ★Repo経由
        builder: (context, snap) {
          final readings = snap.data ?? const <SwitchbotReading>[];

          // グラフ用に変換（nullは落とす）
          final tempPts = <_Point>[];
          final humPts = <_Point>[];

          for (final r in readings) {
            final t = r.ts;
            if (r.temperature != null) tempPts.add(_Point(t, r.temperature!));
            if (r.humidity != null) humPts.add(_Point(t, r.humidity!));
          }

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
                    series: <CartesianSeries<_Point, DateTime>>[
                      LineSeries<_Point, DateTime>(
                        dataSource: tempPts,
                        xValueMapper: (p, _) => p.x,
                        yValueMapper: (p, _) => p.y,
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
                    series: <CartesianSeries<_Point, DateTime>>[
                      LineSeries<_Point, DateTime>(
                        dataSource: humPts,
                        xValueMapper: (p, _) => p.x,
                        yValueMapper: (p, _) => p.y,
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
                Text('last: $_lastInfo', style: const TextStyle(fontSize: 12)),
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
              if (readings.isEmpty &&
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
  final DateTime x;
  final double y;
  _Point(this.x, this.y);
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

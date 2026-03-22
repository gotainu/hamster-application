// lib/screens/func_b.dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
  bool _polling = false;
  bool _backfilling = false;

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

  Future<void> _runPollNow() async {
    if (_polling || _backfilling) return;

    setState(() => _polling = true);

    try {
      final res = await _fetcher.pollMineNow();
      if (!mounted) return;

      final pretty = FetchAndStore.pretty(res);
      setState(() => _lastInfo = 'poll:\n$pretty');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最新取得を実行しました')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _lastInfo = 'poll error:\n$e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('最新取得に失敗: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _polling = false);
      }
    }
  }

  Future<void> _runBackfill() async {
    if (_polling || _backfilling) return;

    setState(() => _backfilling = true);

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-northeast1',
      ).httpsCallable('backfillMyEnvironmentAssessmentsHistory');

      final res = await callable.call();

      if (!mounted) return;

      final data = res.data;
      final pretty = FetchAndStore.pretty(data);
      setState(() => _lastInfo = 'backfill:\n$pretty');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('履歴バックフィルを実行しました')),
      );

      _showSheet('Backfill Result', data);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      final msg = e.message ?? e.code;
      setState(() => _lastInfo = 'backfill error:\n$msg');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('バックフィル失敗: $msg')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _lastInfo = 'backfill error:\n$e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('バックフィル失敗: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _backfilling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _polling || _backfilling;

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
            icon: _polling
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            onPressed: busy ? null : _runPollNow,
          ),
        ],
      ),
      body: StreamBuilder<List<SwitchbotReading>>(
        stream: _sbRepo.watchReadings(limit: 2000),
        builder: (context, snap) {
          final readings = snap.data ?? const <SwitchbotReading>[];

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
                title: 'Debug Actions',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: busy ? null : _runPollNow,
                          icon: _polling
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.sync),
                          label: Text(_polling ? '取得中...' : '最新取得'),
                        ),
                        OutlinedButton.icon(
                          onPressed: busy ? null : _runBackfill,
                          icon: _backfilling
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.history),
                          label: Text(_backfilling ? 'バックフィル中...' : '履歴バックフィル'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '履歴バックフィルは、既存の switchbot_readings から '
                      'environment_assessments_history/{yyyyMMdd} を過去日付分まとめて作成します。',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
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
                SelectableText(
                  _lastInfo!,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
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

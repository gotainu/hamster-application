import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

import '../services/switchbot_repo.dart';
import '../services/health_records_repo.dart';
import '../models/health_record.dart';
import '../models/switchbot_reading.dart';
import 'switchbot_setup.dart';
import 'breeding_environment_edit_screen.dart';

class GraphFunctionScreen extends StatefulWidget {
  const GraphFunctionScreen({super.key});

  @override
  State<GraphFunctionScreen> createState() => _GraphFunctionScreenState();
}

class _GraphFunctionScreenState extends State<GraphFunctionScreen> {
  //final uid = FirebaseAuth.instance.currentUser!.uid;

  // ===== 回し車 =====
  final _wheelCtrl = TextEditingController();
  final _healthRepo = HealthRecordsRepo();
  double? _distance;
  bool _saving = false;

  String? _saveMsg;
  int _calcSeq = 0;

  // ===== SwitchBot =====
  final SwitchbotRepo _sbRepo = SwitchbotRepo();

  @override
  void initState() {
    super.initState();
    // 直径を先にキャッシュ（キー入力が軽くなる）
    _healthRepo.refreshWheelDiameter().then((_) {
      if (!mounted) return;
      _recalcDistance(_wheelCtrl.text);
      setState(() {}); // wheelReady表示更新用
    });

    _wheelCtrl.addListener(() => _recalcDistance(_wheelCtrl.text));
  }

  void _recalcDistance(String v) async {
    final seq = ++_calcSeq;

    final r = int.tryParse(v);
    if (r == null) {
      if (!mounted) return;
      setState(() => _distance = null);
      return;
    }

    final dist = await _healthRepo.previewDistanceFromRotations(r);

    if (!mounted) return;
    if (seq != _calcSeq) return; // 古い結果を捨てる

    setState(() => _distance = dist);
  }

  Future<void> _saveDistance() async {
    final rotations = int.tryParse(_wheelCtrl.text);
    if (rotations == null) return;

    setState(() {
      _saving = true;
      _saveMsg = null;
    });

    try {
      await _healthRepo.addWheelRotationRecord(rotations: rotations);
      if (!mounted) return;
      setState(() => _saveMsg = '保存しました！');
    } on MissingWheelDiameterException {
      if (!mounted) return;
      setState(() => _saveMsg = 'まずは飼育環境を設定してください（車輪の直径が未設定です）。');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saveMsg = '保存に失敗: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _sbRepo.watchHasSecrets(),
      builder: (context, secretsSnap) {
        final hasSecrets = secretsSnap.data ?? false;

        return StreamBuilder<SwitchbotConfig?>(
          stream: _sbRepo.watchSwitchbotConfig(),
          builder: (context, cfgSnap) {
            final cfg = cfgSnap.data;
            final hasDevice = (cfg?.hasDevice ?? false);

            // ★連携中判定は secrets 基準
            final linked = hasSecrets;

            return Scaffold(
              appBar: AppBar(title: const Text('走った記録')),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _todayKPI(),
                  const SizedBox(height: 16),

                  _wheelBlock(),
                  const SizedBox(height: 24),
                  _distanceChart(),
                  const SizedBox(height: 32),

                  _switchbotBlock(hasSwitchBot: linked),

                  // ★グラフは secrets + device 選択済みのとき表示
                  if (linked && hasDevice) ...[
                    const SizedBox(height: 24),
                    _switchbotCharts(),
                  ],

                  // （任意）連携済みだがデバイス未選択ならメッセージ
                  if (linked && !hasDevice)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('温湿度計が未選択です。「編集する」からデバイスを選択してください。'),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===== 今日のKPI =====
  Widget _todayKPI() {
    return FutureBuilder<_TodayKpi>(
      future: _buildTodayKpi(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            height: 72,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final k = snap.data!;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).colorScheme.surface,
            boxShadow: const [
              BoxShadow(
                blurRadius: 16,
                offset: Offset(0, 8),
                color: Color(0x1A000000),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(k.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      k.headline,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '今日: ${k.todayMeters.toStringAsFixed(0)} m  /  7日平均: ${k.avg7Meters.toStringAsFixed(0)} m  (${k.deltaPct >= 0 ? '+' : ''}${k.deltaPct.toStringAsFixed(0)}%)',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_TodayKpi> _buildTodayKpi() async {
    final today = await _healthRepo.fetchDailyTotalDistance(DateTime.now());
    final avg7 = await _healthRepo.fetchRollingDailyAverage(days: 7);

    final base = (avg7 <= 0) ? 1.0 : avg7; // 0割防止
    final deltaPct = (today - avg7) / base * 100.0;

    if (avg7 <= 0 && today <= 0) {
      return _TodayKpi(
        emoji: '🌱',
        headline: 'まずは記録をためよう',
        todayMeters: today,
        avg7Meters: avg7,
        deltaPct: 0,
      );
    }

    if (deltaPct >= 20) {
      return _TodayKpi(
        emoji: '🔥',
        headline: '今日はよく走った！',
        todayMeters: today,
        avg7Meters: avg7,
        deltaPct: deltaPct,
      );
    } else if (deltaPct >= 0) {
      return _TodayKpi(
        emoji: '✨',
        headline: 'いい感じ！いつもより上',
        todayMeters: today,
        avg7Meters: avg7,
        deltaPct: deltaPct,
      );
    } else if (deltaPct <= -20) {
      return _TodayKpi(
        emoji: '🫧',
        headline: '今日は控えめ。様子見しよう',
        todayMeters: today,
        avg7Meters: avg7,
        deltaPct: deltaPct,
      );
    } else {
      return _TodayKpi(
        emoji: '🙂',
        headline: 'いつも通り！',
        todayMeters: today,
        avg7Meters: avg7,
        deltaPct: deltaPct,
      );
    }
  }

  // ---------- Widgets ----------
  Widget _wheelBlock() {
    final wheelReady = (_healthRepo.cachedWheelDiameterCm != null);
    final canSave = wheelReady && (_distance != null) && !_saving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _wheelCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '回し車の回転数'),
          enabled: wheelReady,
        ),
        const SizedBox(height: 8),
        Text(
          '走った距離（m）：${_distance?.toStringAsFixed(2) ?? '-'}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        if (!wheelReady) ...[
          const SizedBox(height: 6),
          const Text(
            'まずは飼育環境を設定してください（車輪の直径が未設定です）。',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.settings),
            label: const Text('飼育環境を設定する'),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const BreedingEnvironmentEditScreen()),
              );
              await _healthRepo.refreshWheelDiameter();
              if (!mounted) return;
              _recalcDistance(_wheelCtrl.text);
              setState(() {});
            },
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: canSave ? _saveDistance : null,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? '保存中...' : '距離を保存'),
            ),
            const SizedBox(width: 12),
            if (_saveMsg != null)
              Expanded(child: Text(_saveMsg!, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ],
    );
  }

  Widget _distanceChart() {
    return SizedBox(
      height: 280,
      child: StreamBuilder<List<HealthRecord>>(
        stream: _healthRepo.watchDistanceSeries(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!
              .map((r) => _Point(r.date.toLocal(), r.distance))
              .toList();

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

  Widget _switchbotBlock({required bool hasSwitchBot}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SwitchBot'),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.link),
          label: Text(hasSwitchBot ? 'SwitchBot連携を編集する' : 'SwitchBot連携をする'),
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
    return StreamBuilder<List<SwitchbotReading>>(
      stream: _sbRepo.watchLatestReadings(limit: 500),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final readings = snap.data!;
        final temp = <_Point>[];
        final hum = <_Point>[];

        for (final r in readings) {
          final t = r.ts.toLocal();
          final tempV = r.temperature;
          final humV = r.humidity;

          if (tempV != null) temp.add(_Point(t, tempV));
          if (humV != null) hum.add(_Point(t, humV));
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

class _TodayKpi {
  final String emoji;
  final String headline;
  final double todayMeters;
  final double avg7Meters;
  final double deltaPct;

  _TodayKpi({
    required this.emoji,
    required this.headline,
    required this.todayMeters,
    required this.avg7Meters,
    required this.deltaPct,
  });
}

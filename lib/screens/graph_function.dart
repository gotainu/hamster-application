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

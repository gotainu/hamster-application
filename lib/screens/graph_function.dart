import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

import '../services/switchbot_repo.dart';
import '../services/distance_records_repo.dart';
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
  final _distanceRepo = DistanceRecordsRepo();
  final SwitchbotRepo _sbRepo = SwitchbotRepo();
  late Future<_TodayKpi> _todayKpiFuture;
  double? _distance;
  bool _saving = false;
  String? _saveMsg;
  DateTime _selectedRecordDate = DateTime.now();
  int _calcSeq = 0;

  @override
  void initState() {
    super.initState();

    _todayKpiFuture = _buildTodayKpi(); // ★これを追加

    _distanceRepo.refreshWheelDiameter().then((_) {
      if (!mounted) return;
      _recalcDistance(_wheelCtrl.text);
      setState(() {});
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

    final dist = await _distanceRepo.previewDistanceFromRotations(r);

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
      await _distanceRepo.addWheelRotationRecord(
        rotations: rotations,
        date: _selectedRecordDate,
      );
      if (!mounted) return;
      setState(() {
        _saveMsg =
            '${DateFormat('yyyy/MM/dd').format(_selectedRecordDate)} の記録を保存しました！';
      });
      _invalidateTodayKpiCache();
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

  void _invalidateTodayKpiCache() {
    setState(() {
      _todayKpiFuture = _buildTodayKpi();
    });
  }

  Future<void> _pickRecordDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedRecordDate,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      helpText: '記録する日付を選択',
      locale: const Locale('ja'),
    );

    if (picked == null) return;

    setState(() {
      _selectedRecordDate = picked;
    });
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

                  // ===== SwitchBot UI（課題③対応）=====
                  if (!linked) ...[
                    // 未連携：ボタンを出す
                    _switchbotBlock(hasSwitchBot: false),
                  ] else if (linked && !hasDevice) ...[
                    // 連携済みだがデバイス未選択：編集導線を出す
                    _switchbotNeedDeviceBlock(),
                  ] else ...[
                    // 連携済み＋デバイス選択済み：ボタンは消してグラフを出す
                    const SizedBox(height: 24),
                    _switchbotCharts(),

                    // 任意：設定を触れる導線だけ残したいなら
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.settings),
                        label: const Text('SwitchBot設定を編集'),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SwitchbotSetupScreen()),
                          );
                        },
                      ),
                    ),
                  ],
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
      future: _todayKpiFuture, // ★ここがポイント（キャッシュしたFuture）
      builder: (context, snap) {
        if (!snap.hasData) {
          return _kpiLoadingCard(); // ★ロード用UIに差し替え
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
    final results = await Future.wait<double>([
      _distanceRepo.fetchDailyTotalDistance(DateTime.now()),
      _distanceRepo.fetchRollingDailyAverage(days: 7),
    ]);
    final today = results[0];
    final avg7 = results[1];

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

  Widget _kpiLoadingCard() {
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
          const Text('⏳', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'データから結果を生成中…',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                const LinearProgressIndicator(),
                const SizedBox(height: 6),
                Text(
                  '少し時間がかかることがあります（通信状況・データ量によります）',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Widgets ----------
  Widget _wheelBlock() {
    final wheelReady = (_distanceRepo.cachedWheelDiameterCm != null);
    final canSave = wheelReady && (_distance != null) && !_saving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '記録する日付',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickRecordDate,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white12,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 18),
                const SizedBox(width: 10),
                Text(
                  DateFormat('yyyy/MM/dd').format(_selectedRecordDate),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Spacer(),
                const Icon(Icons.expand_more),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
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
              await _distanceRepo.refreshWheelDiameter();
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
              label: Text(_saving ? '保存中...' : 'この日付で保存'),
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
        stream: _distanceRepo.watchDistanceSeries(),
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

  Widget _switchbotNeedDeviceBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SwitchBot'),
        const SizedBox(height: 8),
        const Text(
          '✅ 認証は完了しています。\n'
          '次は温湿度計（Meter）を選択してください。',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.settings),
          label: const Text('SwitchBot設定を開く'),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SwitchbotSetupScreen()),
            );
          },
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

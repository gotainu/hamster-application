import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

import '../services/switchbot_repo.dart';
import '../services/distance_records_repo.dart';
import '../models/health_record.dart';
import '../models/switchbot_reading.dart';
import '../widgets/wheel_rotation_input_card.dart';
import 'switchbot_setup.dart';

class GraphFunctionScreen extends StatefulWidget {
  const GraphFunctionScreen({super.key});

  @override
  State<GraphFunctionScreen> createState() => _GraphFunctionScreenState();
}

class _GraphFunctionScreenState extends State<GraphFunctionScreen> {
  //final uid = FirebaseAuth.instance.currentUser!.uid;

  // ===== 回し車 =====
  final _distanceRepo = DistanceRecordsRepo();
  final SwitchbotRepo _sbRepo = SwitchbotRepo();
  late Future<_TodayKpi> _todayKpiFuture;

  @override
  void initState() {
    super.initState();

    _todayKpiFuture = _buildTodayKpi();
  }

  void _invalidateTodayKpiCache() {
    setState(() {
      _todayKpiFuture = _buildTodayKpi();
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
                      '昨日: ${k.todayMeters.toStringAsFixed(0)} m  /  7日平均: ${k.avg7Meters.toStringAsFixed(0)} m  (${k.deltaPct >= 0 ? '+' : ''}${k.deltaPct.toStringAsFixed(0)}%)',
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
    final now = DateTime.now();
    final yesterdayRaw = now.subtract(const Duration(days: 1));
    final referenceDay = DateTime(
      yesterdayRaw.year,
      yesterdayRaw.month,
      yesterdayRaw.day,
    );

    final results = await Future.wait<double>([
      _distanceRepo.fetchDailyTotalDistance(referenceDay),
      _distanceRepo.fetchRollingDailyAverage(
        days: 7,
        todayLocal: referenceDay,
      ),
    ]);

    final referenceMeters = results[0];
    final avg7 = results[1];

    final base = (avg7 <= 0) ? 1.0 : avg7;
    final deltaPct = (referenceMeters - avg7) / base * 100.0;

    if (avg7 <= 0 && referenceMeters <= 0) {
      return _TodayKpi(
        emoji: '🌱',
        headline: 'まずは記録をためよう',
        todayMeters: referenceMeters,
        avg7Meters: avg7,
        deltaPct: 0,
      );
    }

    if (deltaPct >= 20) {
      return _TodayKpi(
        emoji: '🔥',
        headline: '昨日はよく走った！',
        todayMeters: referenceMeters,
        avg7Meters: avg7,
        deltaPct: deltaPct,
      );
    } else if (deltaPct >= 0) {
      return _TodayKpi(
        emoji: '✨',
        headline: '昨日はいい感じ！いつもより上',
        todayMeters: referenceMeters,
        avg7Meters: avg7,
        deltaPct: deltaPct,
      );
    } else if (deltaPct <= -20) {
      return _TodayKpi(
        emoji: '🫧',
        headline: '昨日は控えめ。様子見しよう',
        todayMeters: referenceMeters,
        avg7Meters: avg7,
        deltaPct: deltaPct,
      );
    } else {
      return _TodayKpi(
        emoji: '🙂',
        headline: '昨日はいつも通り！',
        todayMeters: referenceMeters,
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
    return WheelRotationInputCard(
      distanceRepo: _distanceRepo,
      title: '昨日の走った記録',
      subtitle: '昨晩〜今朝の回転数を入れると、走行距離に換算して保存できます。',
      onSaved: ({
        required DateTime date,
        required int rotations,
        double? distanceMeters,
      }) {
        _invalidateTodayKpiCache();
      },
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

// lib/screens/home.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hamster_project/models/environment_assessment.dart';
import 'package:hamster_project/models/environment_assessment_history.dart';
import 'package:hamster_project/services/environment_assessment_repo.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/screens/switchbot_setup.dart';
import 'package:hamster_project/screens/func_b.dart';
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  final void Function(int) onTabSelected;
  const HomeScreen({super.key, required this.onTabSelected});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _assessmentRepo = EnvironmentAssessmentRepo();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient =
        isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: null,
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: StreamBuilder<EnvironmentAssessment?>(
            stream: _assessmentRepo.watchLatest(),
            builder: (context, latestSnap) {
              final assessment = latestSnap.data;
              final isLoadingLatest =
                  latestSnap.connectionState == ConnectionState.waiting;

              return StreamBuilder<List<EnvironmentAssessmentHistory>>(
                stream: _assessmentRepo.watchRecentHistory(limit: 7),
                builder: (context, historySnap) {
                  final history = historySnap.data ??
                      const <EnvironmentAssessmentHistory>[];
                  final isLoadingHistory =
                      historySnap.connectionState == ConnectionState.waiting;

                  final isLoading = isLoadingLatest || isLoadingHistory;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HomeHeader(
                          title: assessment?.hasData == true
                              ? '今日の飼育環境'
                              : 'Hamster Project',
                          subtitle: assessment?.hasData == true
                              ? 'いまの状態をすぐ確認できます'
                              : '毎日の飼育をひと目でわかりやすく',
                        ),
                        const SizedBox(height: 18),
                        if (isLoading)
                          _EnvironmentAssessmentHero.loading()
                        else if (assessment == null || !assessment.hasData)
                          _EnvironmentAssessmentHero.empty(
                            onOpenSetup: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SwitchbotSetupScreen(),
                                ),
                              );
                            },
                          )
                        else
                          _EnvironmentAssessmentHero(
                            assessment: assessment,
                            history: history,
                            onTap: () => widget.onTabSelected(2),
                          ),
                        const SizedBox(height: 14),
                        if (!isLoading &&
                            assessment != null &&
                            assessment.hasData &&
                            (assessment.todayAction ?? '')
                                .trim()
                                .isNotEmpty) ...[
                          _TodayActionCard(
                            assessment: assessment,
                            onTap: () => widget.onTabSelected(2),
                          ),
                          const SizedBox(height: 14),
                        ],
                        _QuickActionsCard(
                          onOpenAi: () => widget.onTabSelected(1),
                          onOpenGraph: () => widget.onTabSelected(2),
                          onOpenGraphDirect: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const FuncBScreen(),
                              ),
                            );
                          },
                          onOpenSwitchbot: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SwitchbotSetupScreen(),
                              ),
                            );
                          },
                          onOpenMyPage: () => widget.onTabSelected(3),
                        ),
                        const SizedBox(height: 18),
                        Center(
                          child: Text(
                            '© 2025 Hamster Project',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _HomeHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
        ],
      ),
    );
  }
}

class _EnvironmentAssessmentHero extends StatelessWidget {
  final EnvironmentAssessment? assessment;
  final VoidCallback? onTap;
  final VoidCallback? onOpenSetup;
  final bool isLoading;
  final bool isEmptyState;
  final List<EnvironmentAssessmentHistory> history;

  const _EnvironmentAssessmentHero({
    this.assessment,
    this.onTap,
    this.onOpenSetup,
    this.isLoading = false,
    this.isEmptyState = false,
    this.history = const [],
  });

  factory _EnvironmentAssessmentHero.loading() {
    return const _EnvironmentAssessmentHero(isLoading: true);
  }

  factory _EnvironmentAssessmentHero.empty({
    VoidCallback? onOpenSetup,
  }) {
    return _EnvironmentAssessmentHero(
      isEmptyState: true,
      onOpenSetup: onOpenSetup,
    );
  }

  String _emojiForLevel(String? level) {
    switch (level) {
      case '良好':
        return '✅';
      case '注意':
        return '⚠️';
      case '危険':
        return '🚨';
      default:
        return '🏠';
    }
  }

  IconData _iconForMetricLabel(String text) {
    if (text.contains('温度')) return Icons.thermostat_rounded;
    if (text.contains('湿度')) return Icons.water_drop_outlined;
    return Icons.analytics_outlined;
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '未評価';
    return DateFormat('M/d HH:mm').format(dt.toLocal());
  }

  String _levelShortText(String? level) {
    switch (level) {
      case '良好':
        return '総合評価: 良好';
      case '注意':
        return '総合評価: 注意';
      case '危険':
        return '総合評価: 危険';
      default:
        return '総合評価: 未評価';
    }
  }

  String _buildHeroLead(EnvironmentAssessment a) {
    final hum = a.avgHum;
    final temp = a.avgTemp;

    if (a.level == '危険') {
      return '今すぐ環境を確認したい状態です';
    }

    if (hum != null && hum > 60) {
      return 'いま一番気にしたいのは湿度です';
    }
    if (hum != null && hum < 40) {
      return '乾燥気味なので湿度を見たいです';
    }
    if (temp != null && temp > 26) {
      return '暑さに注意したい状態です';
    }
    if (temp != null && temp < 20) {
      return '寒さに注意したい状態です';
    }
    if (a.level == '良好') {
      return 'かなり安定した飼育環境です';
    }
    return 'いまの状態をすぐ確認できます';
  }

  String _mainMetricLabel(EnvironmentAssessment a) {
    final hum = a.avgHum;
    final temp = a.avgTemp;

    if (hum != null && hum > 60) return '平均湿度';
    if (hum != null && hum < 40) return '平均湿度';
    if (temp != null && temp > 26) return '平均温度';
    if (temp != null && temp < 20) return '平均温度';
    if ((a.humRatio ?? 1) < (a.tempRatio ?? 1)) return '平均湿度';
    return '平均温度';
  }

  String _mainMetricValue(EnvironmentAssessment a) {
    final label = _mainMetricLabel(a);
    if (label == '平均湿度' && a.avgHum != null) {
      return '${a.avgHum!.round()}%';
    }
    if (label == '平均温度' && a.avgTemp != null) {
      return '${a.avgTemp!.toStringAsFixed(1)}℃';
    }
    return '—';
  }

  String _mainMetricSub(EnvironmentAssessment a) {
    final label = _mainMetricLabel(a);

    if (label == '平均湿度') {
      final hum = a.avgHum;
      if (hum == null) return '理想 40–60%';
      if (hum > 60) return '理想 40–60% より高め';
      if (hum < 40) return '理想 40–60% より低め';
      return '理想 40–60% の範囲';
    }

    final temp = a.avgTemp;
    if (temp == null) return '理想 20–26℃';
    if (temp > 26) return '理想 20–26℃ より高め';
    if (temp < 20) return '理想 20–26℃ より低め';
    return '理想 20–26℃ の範囲';
  }

  List<_MetricPillData> _buildMetricPills(EnvironmentAssessment a) {
    final pills = <_MetricPillData>[];

    if (a.avgTemp != null) {
      pills.add(
        _MetricPillData(
          icon: Icons.thermostat_rounded,
          label: '平均温度',
          value: '${a.avgTemp!.toStringAsFixed(1)}℃',
        ),
      );
    }

    if (a.avgHum != null) {
      pills.add(
        _MetricPillData(
          icon: Icons.water_drop_outlined,
          label: '平均湿度',
          value: '${a.avgHum!.round()}%',
        ),
      );
    }

    if (a.tempRatio != null) {
      pills.add(
        _MetricPillData(
          icon: Icons.monitor_heart_outlined,
          label: '温度適正率',
          value: '${(a.tempRatio! * 100).round()}%',
        ),
      );
    }

    if (a.humRatio != null) {
      pills.add(
        _MetricPillData(
          icon: Icons.air_rounded,
          label: '湿度適正率',
          value: '${(a.humRatio! * 100).round()}%',
        ),
      );
    }

    return pills;
  }

  double? _avgOfHistory(
    List<EnvironmentAssessmentHistory> items,
    double? Function(EnvironmentAssessmentHistory e) pick,
  ) {
    if (items.isEmpty) return null;

    final values = items.map(pick).whereType<double>().toList();

    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  int? _avgIntOfHistory(
    List<EnvironmentAssessmentHistory> items,
    int? Function(EnvironmentAssessmentHistory e) pick,
  ) {
    if (items.isEmpty) return null;

    final values = items.map(pick).whereType<int>().toList();

    if (values.isEmpty) return null;
    return (values.reduce((a, b) => a + b) / values.length).round();
  }

  String _buildTrendText(EnvironmentAssessment a) {
    final validHistory = history.where((e) => e.hasCoreData).toList();
    if (validHistory.length < 2) return 'まだ週間比較データが少ないです';

    final label = _mainMetricLabel(a);

    if (label == '平均湿度' && a.avgHum != null) {
      final baseline = _avgOfHistory(validHistory, (e) => e.avgHum);
      if (baseline == null) return 'まだ週間比較データが少ないです';

      final diff = a.avgHum! - baseline;
      final sign = diff > 0 ? '+' : '';
      final absDiff = diff.abs().round();

      if (absDiff == 0) {
        return '直近7日平均とほぼ同じ湿度です';
      }
      return '直近7日平均より湿度 ${sign}${diff.round()}%';
    }

    if (label == '平均温度' && a.avgTemp != null) {
      final baseline = _avgOfHistory(validHistory, (e) => e.avgTemp);
      if (baseline == null) return 'まだ週間比較データが少ないです';

      final diff = a.avgTemp! - baseline;
      final sign = diff > 0 ? '+' : '';
      final absDiff = diff.abs();

      if (absDiff < 0.1) {
        return '直近7日平均とほぼ同じ温度です';
      }
      return '直近7日平均より温度 ${sign}${diff.toStringAsFixed(1)}℃';
    }

    return '直近7日の推移を確認できます';
  }

  List<double> _buildSparkValues(EnvironmentAssessment a) {
    final validHistory = history.where((e) => e.hasCoreData).toList();
    if (validHistory.isEmpty) return const [];

    final label = _mainMetricLabel(a);

    if (label == '平均湿度') {
      return validHistory.map((e) => e.avgHum).whereType<double>().toList();
    }

    return validHistory.map((e) => e.avgTemp).whereType<double>().toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppTheme.environmentHeroGradient('注意', isDark: isDark),
          borderRadius: BorderRadius.circular(32),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '今日の飼育環境',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              '読み込み中…',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    if (isEmptyState) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppTheme.environmentHeroGradient('注意', isDark: isDark),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '今日の飼育環境',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 20),
            Text(
              'データがありません',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onOpenSetup,
              icon: const Icon(Icons.link),
              label: const Text('SwitchBot設定へ'),
            ),
          ],
        ),
      );
    }

    final a = assessment!;
    final trendText = _buildTrendText(a);
    final sparkValues = _buildSparkValues(a);
    final accent = AppTheme.environmentAccent(a.level);

    // ===== 主役決定 =====
    final label = _mainMetricLabel(a);
    final value = _mainMetricValue(a);
    final sub = _mainMetricSub(a);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          decoration: BoxDecoration(
            gradient: AppTheme.environmentHeroGradient(a.level, isDark: isDark),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                blurRadius: 36,
                offset: const Offset(0, 18),
                color: accent.withOpacity(0.25),
              ),
            ],
          ),
          child: Stack(
            children: [
              _HeroBackgroundDecoration(accent: accent),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // タイトル（最小）
                  Text(
                    '今日の飼育環境',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                  ),

                  const SizedBox(height: 24),

                  // ===== 主役ラベル =====
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                        ),
                  ),

                  const SizedBox(height: 4),

                  // ===== 主役数値（超重要） =====
                  Text(
                    value,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 0.9,
                          letterSpacing: -1.5,
                        ),
                  ),

                  const SizedBox(height: 6),

                  // ===== サブ説明 =====
                  Text(
                    sub,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    _levelShortText(a.level),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    trendText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                  ),

                  if (sparkValues.length >= 2) ...[
                    const SizedBox(height: 12),
                    _MiniSparkline(
                      values: sparkValues,
                      color: accent,
                    ),
                  ],

                  const SizedBox(height: 18),

                  // ===== 小さい補助指標 =====
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _buildMetricPills(a)
                        .map((m) => _HeroMetricPill(
                              data: m,
                              accent: accent,
                            ))
                        .toList(),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '最終評価: ${_formatTime(a.evaluatedAt)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white70,
                                  ),
                        ),
                      ),
                      Text(
                        '詳細',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const String _levelBadgeTextPrefix = '●';
}

class _MetricPillData {
  final IconData icon;
  final String label;
  final String value;

  const _MetricPillData({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _HeroMetricPill extends StatelessWidget {
  final _MetricPillData data;
  final Color accent;

  const _HeroMetricPill({
    required this.data,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent.withOpacity(0.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            data.icon,
            size: 16,
            color: accent,
          ),
          const SizedBox(width: 6),
          Text(
            '${data.label} ${data.value}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBackgroundDecoration extends StatelessWidget {
  final Color? accent;

  const _HeroBackgroundDecoration({this.accent});

  @override
  Widget build(BuildContext context) {
    final c = accent ?? AppTheme.accent;

    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -20,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.withOpacity(0.10),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -30,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              right: 24,
              top: 28,
              child: Transform.rotate(
                angle: -0.18,
                child: Icon(
                  Icons.pets_rounded,
                  size: 92,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _WavePainter(
                  color: c.withOpacity(0.12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final Color color;

  _WavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.78);

    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.78 +
          math.sin((x / size.width) * math.pi * 2.2) * 12 +
          math.sin((x / size.width) * math.pi * 5.0) * 5;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _TodayActionCard extends StatelessWidget {
  final EnvironmentAssessment assessment;
  final VoidCallback? onTap;

  const _TodayActionCard({
    required this.assessment,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                blurRadius: 16,
                offset: Offset(0, 8),
                color: Color(0x1A000000),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今日やること',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      assessment.todayAction ?? '',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if ((assessment.why ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        assessment.why!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  final VoidCallback onOpenAi;
  final VoidCallback onOpenGraph;
  final VoidCallback onOpenGraphDirect;
  final VoidCallback onOpenSwitchbot;
  final VoidCallback onOpenMyPage;

  const _QuickActionsCard({
    required this.onOpenAi,
    required this.onOpenGraph,
    required this.onOpenGraphDirect,
    required this.onOpenSwitchbot,
    required this.onOpenMyPage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardInnerDark : AppTheme.cardInnerLight,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withOpacity(0.16),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'クイックアクション',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'よく使う機能にすぐアクセスできます',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.55,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _QuickActionTile(
                icon: Icons.search,
                title: 'AIに相談',
                subtitle: '飼育の悩みを聞く',
                onTap: onOpenAi,
              ),
              _QuickActionTile(
                icon: Icons.show_chart_outlined,
                title: '走った記録',
                subtitle: '温湿度と運動を見る',
                onTap: onOpenGraph,
              ),
              _QuickActionTile(
                icon: Icons.open_in_new,
                title: '別画面で開く',
                subtitle: 'グラフ画面へ直接移動',
                onTap: onOpenGraphDirect,
              ),
              _QuickActionTile(
                icon: Icons.link,
                title: 'SwitchBot設定',
                subtitle: '連携や機器設定',
                onTap: onOpenSwitchbot,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _WideActionTile(
            icon: Icons.person_2_outlined,
            title: 'マイページ',
            subtitle: 'プロフィールや各種設定を見る',
            onTap: onOpenMyPage,
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tileColor = AppTheme.accent.withOpacity(0.09);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppTheme.accent.withOpacity(0.18),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppTheme.accent, size: 24),
                const Spacer(),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        height: 1.25,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WideActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _WideActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tileColor = AppTheme.accent.withOpacity(0.09);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppTheme.accent.withOpacity(0.18),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.accent, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white54,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetricChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.accent),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniSparkline extends StatelessWidget {
  final List<double> values;
  final Color color;

  const _MiniSparkline({
    required this.values,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      height: 36,
      child: CustomPaint(
        painter: _MiniSparklinePainter(
          values: values,
          color: color,
        ),
      ),
    );
  }
}

class _MiniSparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _MiniSparklinePainter({
    required this.values,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final range = (maxV - minV).abs() < 0.0001 ? 1.0 : (maxV - minV);

    final path = Path();

    for (int i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - ((values[i] - minV) / range) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final glow = Paint()
      ..color = color.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, glow);
    canvas.drawPath(path, paint);

    final lastX = size.width;
    final lastY = size.height - ((values.last - minV) / range) * size.height;

    canvas.drawCircle(
      Offset(lastX, lastY),
      3.5,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniSparklinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

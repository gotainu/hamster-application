// lib/screens/home.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hamster_project/models/environment_assessment.dart';
import 'package:hamster_project/models/environment_assessment_history.dart';
import 'package:hamster_project/models/anomaly_detection.dart';
import 'package:hamster_project/services/anomaly_detection_service.dart';
import 'package:hamster_project/services/environment_status_service.dart';
import 'package:hamster_project/services/environment_assessment_repo.dart';
import 'package:hamster_project/services/environment_trend_service.dart';
import 'package:hamster_project/services/paid_feature_guard_service.dart';
import 'package:hamster_project/screens/switchbot_setup.dart';
import 'package:hamster_project/screens/daily_status_detail.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/widgets/semantic_sparkline.dart';

class HomeScreen extends StatefulWidget {
  final void Function(int) onTabSelected;
  final Future<void> Function(String draftText)? onOpenAiWithDraft;

  const HomeScreen({
    super.key,
    required this.onTabSelected,
    this.onOpenAiWithDraft,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _anomalyCardKey = GlobalKey();

  final _assessmentRepo = EnvironmentAssessmentRepo();
  final _anomalyDetectionService = const AnomalyDetectionService();
  final _paidFeatureGuard = PaidFeatureGuardService();

  Stream<String?> _watchMainPetName() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Stream<String?>.value(null);
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('pet_profiles')
        .doc('main_pet')
        .snapshots()
        .map((snap) {
      final data = snap.data();
      if (data == null) return null;

      final rawName = data['name'] ?? data['petName'] ?? data['nickname'];
      final name = rawName?.toString().trim();

      if (name == null || name.isEmpty) return null;
      return name;
    });
  }

  String _homeSubtitle({
    required String? petName,
    required bool hasAssessmentData,
  }) {
    if (!hasAssessmentData) {
      return 'まずは温湿度や飼育情報を登録しましょう';
    }

    final displayName =
        petName?.trim().isNotEmpty == true ? petName!.trim() : 'ハムスター';

    return '$displayNameちゃんの環境と変化を確認しましょう';
  }

  AnomalyDetectionResult _buildHomeAnomalyDetection({
    required List<EnvironmentAssessmentHistory> history,
  }) {
    return _anomalyDetectionService.detect(history: history);
  }

  Future<void> focusAnomalyCard() async {
    final messenger = ScaffoldMessenger.of(context);

    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    await WidgetsBinding.instance.endOfFrame;

    if (!mounted) return;

    final anomalyContext = _anomalyCardKey.currentContext;

    if (anomalyContext == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('現在、最近の気になる変化は表示されていません。'),
        ),
      );
      return;
    }

    await Scrollable.ensureVisible(
      anomalyContext,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      alignment: 0.18,
    );

    if (!mounted) return;

    messenger.showSnackBar(
      const SnackBar(
        content: Text('最近の気になる変化を表示しました。'),
      ),
    );
  }

  Future<void> _openAiWithDraft(String draftText) async {
    final allowed = await _ensurePaidFeature(featureName: 'AI相談');
    if (!allowed) return;

    final handler = widget.onOpenAiWithDraft;

    if (handler != null) {
      await handler(draftText);
      return;
    }

    widget.onTabSelected(1);
  }

  Future<bool> _ensurePaidFeature({
    required String featureName,
  }) {
    return _paidFeatureGuard.ensureCanUsePaidFeature(
      context,
      featureName: featureName,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
          child: StreamBuilder<String?>(
            stream: _watchMainPetName(),
            builder: (context, petSnap) {
              final petName = petSnap.data;

              return StreamBuilder<EnvironmentAssessment?>(
                stream: _assessmentRepo.watchLatest(),
                builder: (context, latestSnap) {
                  final assessment = latestSnap.data;
                  final isLoadingLatest =
                      latestSnap.connectionState == ConnectionState.waiting;

                  return StreamBuilder<List<EnvironmentAssessmentHistory>>(
                    stream: _assessmentRepo.watchRecentHistory(limit: 14),
                    builder: (context, historySnap) {
                      final history = historySnap.data ??
                          const <EnvironmentAssessmentHistory>[];
                      final isLoadingHistory = historySnap.connectionState ==
                          ConnectionState.waiting;

                      final isLoading = isLoadingLatest || isLoadingHistory;

                      final anomalyDetection = _buildHomeAnomalyDetection(
                        history: history,
                      );

                      return SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HomeHeader(
                              title: '今日の状態',
                              subtitle: _homeSubtitle(
                                petName: petName,
                                hasAssessmentData: assessment?.hasData == true,
                              ),
                            ),
                            const SizedBox(height: 18),
                            if (isLoading)
                              _EnvironmentAssessmentHero.loading()
                            else if (assessment == null || !assessment.hasData)
                              _EnvironmentAssessmentHero.empty(
                                onOpenSetup: () async {
                                  final allowed = await _ensurePaidFeature(
                                    featureName: 'SwitchBot連携',
                                  );
                                  if (!allowed) return;

                                  if (!context.mounted) return;

                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const SwitchbotSetupScreen(),
                                    ),
                                  );
                                },
                              )
                            else
                              _EnvironmentAssessmentHero(
                                assessment: assessment,
                                history: history,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const DailyStatusDetailScreen(),
                                    ),
                                  );
                                },
                                onAskAi: () {
                                  _openAiWithDraft(
                                    '今日の飼育環境の評価を踏まえて、今確認すべきことと優先順位を教えてください。',
                                  );
                                },
                              ),
                            if (!isLoading && anomalyDetection.hasAnomaly) ...[
                              const SizedBox(height: 14),
                              Container(
                                key: _anomalyCardKey,
                                child: _HomeAnomalyCard(
                                  result: anomalyDetection,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const DailyStatusDetailScreen(),
                                      ),
                                    );
                                  },
                                  onAskAi: () {
                                    final top = anomalyDetection.topAnomaly;

                                    _openAiWithDraft(
                                      top == null
                                          ? '最近の気になる変化について、原因候補と今日確認すべきことを教えてください。'
                                          : '最近の気になる変化「${top.title}」について、原因候補と今日確認すべきことを教えてください。',
                                    );
                                  },
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            _HomeNextActionsCard(
                              onOpenAi: () async {
                                final allowed = await _ensurePaidFeature(
                                  featureName: 'AI相談',
                                );
                                if (!allowed) return;

                                widget.onTabSelected(1);
                              },
                              onOpenRecord: () async {
                                final allowed = await _ensurePaidFeature(
                                  featureName: '記録',
                                );
                                if (!allowed) return;

                                widget.onTabSelected(2);
                              },
                            ),
                            const SizedBox(height: 18),
                            Center(
                              child: Text(
                                '© 2025 Go / hamster well-being',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
                  color: AppTheme.secondaryText(context),
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
  final VoidCallback? onAskAi;
  final bool isLoading;
  final bool isEmptyState;
  final List<EnvironmentAssessmentHistory> history;

  const _EnvironmentAssessmentHero({
    this.assessment,
    this.onTap,
    this.onOpenSetup,
    this.onAskAi,
    this.isLoading = false,
    this.isEmptyState = false,
    this.history = const [],
  });

  static const EnvironmentTrendService _trendService =
      EnvironmentTrendService();

  static const EnvironmentStatusService _environmentStatusService =
      EnvironmentStatusService();

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

  String _formatTime(DateTime? dt) {
    if (dt == null) return '未評価';
    return DateFormat('M/d HH:mm').format(dt.toLocal());
  }

  String _levelJudgement(String? level) {
    switch (level) {
      case '良好':
        return '今日は安定しています';
      case '危険':
        return '今日はすぐ確認したい状態です';
      case '注意':
        return '今日は少し注意です';
      default:
        return 'まだ判断できません';
    }
  }

  String _levelShortText(String? level) {
    switch (level) {
      case '良好':
        return '良好';
      case '注意':
        return '注意';
      case '危険':
        return '危険';
      default:
        return '未評価';
    }
  }

  IconData _levelIcon(String? level) {
    switch (level) {
      case '良好':
        return Icons.check_circle_rounded;
      case '危険':
        return Icons.warning_amber_rounded;
      case '注意':
        return Icons.info_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _mainMessage(
    EnvironmentAssessment assessment,
    EnvironmentHeroViewData heroData,
  ) {
    final headline = assessment.headline?.trim();
    if (headline != null && headline.isNotEmpty) {
      return headline;
    }

    return '${heroData.metricLabel}は${heroData.metricSubText}です。';
  }

  String _primaryAction(EnvironmentAssessment assessment) {
    final action = assessment.todayAction?.trim();
    if (action != null && action.isNotEmpty) {
      return action;
    }

    switch (assessment.level) {
      case '良好':
        return '今の環境を維持しつつ、いつも通り様子を見ましょう。';
      case '危険':
        return '温度・湿度・床材・通気をすぐ確認してください。';
      case '注意':
        return '温湿度やケージ周辺を確認し、必要なら調整しましょう。';
      default:
        return '温湿度データが入ると、今日確認したいことを表示できます。';
    }
  }

  List<double> _buildSparkValues(EnvironmentAssessment a) {
    final validHistory = history.where((e) => e.hasCoreData).toList();
    if (validHistory.isEmpty) return const [];

    final heroData = _environmentStatusService.buildHeroViewData(a);

    if (heroData.metricKind == EnvironmentMetricKind.humidity) {
      return validHistory.map((e) => e.avgHum).whereType<double>().toList();
    }

    return validHistory.map((e) => e.avgTemp).whereType<double>().toList();
  }

  Widget _metricPill(
    BuildContext context, {
    required String label,
    required String value,
    required String sub,
    required Color accent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.isDark(context)
            ? Colors.black.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accent.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText(context),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText(context),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: accent,
                  letterSpacing: -0.5,
                ),
          ),
        ],
      ),
    );
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '今日の状態',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppTheme.primaryText(context),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '読み込み中…',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryText(context),
              ),
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
            Text(
              '今日の状態',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppTheme.primaryText(context),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'まだ判断できません',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'SwitchBot連携や飼育情報を登録すると、温度・湿度・活動量から今日の状態を表示できます。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.secondaryText(context),
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 16),
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
    final heroData = _environmentStatusService.buildHeroViewData(a);

    final label = heroData.metricLabel;
    final value = heroData.metricValueText;
    final sub = heroData.metricSubText;

    final trend = _trendService.buildWeeklyTrendSummary(
      assessment: a,
      history: history,
      mainMetricLabel: label,
    );

    final sparkValues = _buildSparkValues(a);
    final sparkBands = heroData.chartBands;
    final accent = AppTheme.environmentAccentForContext(context, a.level);

    final judgement = _levelJudgement(a.level);
    final message = _mainMessage(a, heroData);
    final action = _primaryAction(a);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
          decoration: BoxDecoration(
            gradient: AppTheme.environmentHeroGradient(a.level, isDark: isDark),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                blurRadius: 36,
                offset: const Offset(0, 18),
                color: accent.withValues(alpha: 0.25),
              ),
            ],
          ),
          child: Stack(
            children: [
              _HeroBackgroundDecoration(accent: accent),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: accent.withValues(
                            alpha: AppTheme.isDark(context) ? 0.16 : 0.18,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _levelIcon(a.level),
                          color: accent,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '今日の飼育環境',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.secondaryText(context),
                                  ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.24),
                          ),
                        ),
                        child: Text(
                          _levelShortText(a.level),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: accent,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    judgement,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.secondaryText(context),
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _metricPill(
                    context,
                    label: label,
                    value: value,
                    sub: sub,
                    accent: accent,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardSurface(context).withValues(
                        alpha: AppTheme.isDark(context) ? 0.28 : 0.55,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.task_alt_rounded,
                          size: 20,
                          color: accent,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'まず確認したいこと',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: accent,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                action,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppTheme.primaryText(context),
                                      fontWeight: FontWeight.w700,
                                      height: 1.45,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (sparkValues.length >= 2) ...[
                    const SizedBox(height: 14),
                    Text(
                      trend.deltaText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trend.summaryText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.secondaryText(context),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 10),
                    SemanticSparkline(
                      values: sparkValues,
                      color: accent,
                      bands: sparkBands,
                      height: 36,
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '最終評価: ${_formatTime(a.evaluatedAt)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.secondaryText(context),
                                  ),
                        ),
                      ),
                      Text(
                        '詳細',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  if (onAskAi != null) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onAskAi,
                        icon: const Icon(Icons.smart_toy_outlined),
                        label: const Text('今日の状態についてAIに相談'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
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
                  color: AppTheme.heroDecorationFill(
                    context,
                    c,
                    darkOpacity: 0.10,
                    lightOpacity: 0.08,
                  ),
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
                  color: AppTheme.heroDecorationFill(
                    context,
                    c,
                    darkOpacity: 0.06,
                    lightOpacity: 0.05,
                  ),
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
                  color: AppTheme.heroPetIcon(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeAnomalyCard extends StatelessWidget {
  final AnomalyDetectionResult result;
  final VoidCallback? onTap;
  final VoidCallback? onAskAi;

  const _HomeAnomalyCard({
    required this.result,
    this.onTap,
    this.onAskAi,
  });

  String _severityText(AnomalySeverity severity) {
    switch (severity) {
      case AnomalySeverity.info:
        return '軽微';
      case AnomalySeverity.low:
        return '低';
      case AnomalySeverity.medium:
        return '中';
      case AnomalySeverity.high:
        return '高';
    }
  }

  Color _severityColor(BuildContext context, AnomalySeverity severity) {
    switch (severity) {
      case AnomalySeverity.info:
        return AppTheme.secondaryText(context);
      case AnomalySeverity.low:
        return AppTheme.envCaution;
      case AnomalySeverity.medium:
        return AppTheme.envDanger;
      case AnomalySeverity.high:
        return AppTheme.envDanger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = result.topAnomaly!;
    final color = _severityColor(context, top.severity);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.cardSurface(context),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                blurRadius: 16,
                offset: const Offset(0, 8),
                color: AppTheme.softShadow(context),
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
                  color: AppTheme.chipFill(
                    color,
                    context,
                    opacity: AppTheme.isDark(context) ? 0.14 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '最近の気になる変化',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      top.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      top.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.secondaryText(context),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '重要度: ${_severityText(top.severity)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (onAskAi != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: onAskAi,
                          icon: const Icon(Icons.smart_toy_outlined, size: 18),
                          label: const Text('この変化をAIに相談'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.tertiaryText(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeNextActionsCard extends StatelessWidget {
  final VoidCallback onOpenAi;
  final VoidCallback onOpenRecord;

  const _HomeNextActionsCard({
    required this.onOpenAi,
    required this.onOpenRecord,
  });

  @override
  Widget build(BuildContext context) {
    final surface = AppTheme.cardSurface(context);
    final secondary = AppTheme.secondaryText(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 8),
            color: AppTheme.softShadow(context),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '次にできること',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '気になることがあれば相談し、日々の様子は記録に残せます。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: secondary,
                ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenAi,
                  icon: const Icon(Icons.smart_toy_outlined),
                  label: const Text('相談する'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpenRecord,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('記録する'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

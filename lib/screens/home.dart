// lib/screens/home.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hamster_project/models/environment_assessment.dart';
import 'package:hamster_project/models/environment_assessment_history.dart';
import 'package:hamster_project/models/anomaly_detection.dart';
import 'package:hamster_project/models/daily_record_completion.dart';
import 'package:hamster_project/services/anomaly_detection_service.dart';
import 'package:hamster_project/services/environment_status_service.dart';
import 'package:hamster_project/services/environment_assessment_repo.dart';
import 'package:hamster_project/services/environment_trend_service.dart';
import 'package:hamster_project/services/paid_feature_guard_service.dart';
import 'package:hamster_project/services/daily_record_completion_service.dart';
import 'package:hamster_project/screens/switchbot_setup.dart';
import 'package:hamster_project/screens/daily_status_detail.dart';
import 'package:hamster_project/screens/record_screen.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/widgets/semantic_trend_chart.dart';
import 'package:hamster_project/widgets/status_card.dart';

class HomeScreen extends StatefulWidget {
  final void Function(int) onTabSelected;
  final Future<void> Function(String draftText)? onOpenAiWithDraft;
  final Future<void> Function()? onOpenRecord;

  const HomeScreen({
    super.key,
    required this.onTabSelected,
    this.onOpenAiWithDraft,
    this.onOpenRecord,
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
  final _recordCompletionService = DailyRecordCompletionService();

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

  Future<void> _openRecord() async {
    final allowed = await _ensurePaidFeature(featureName: '記録');
    if (!allowed || !mounted) return;

    final handler = widget.onOpenRecord;
    if (handler != null) {
      await handler();
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const RecordScreen(),
      ),
    );
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
                            StreamBuilder<DailyRecordCompletion>(
                              stream: _recordCompletionService.watch(),
                              builder: (context, completionSnapshot) {
                                final completion = completionSnapshot.data;

                                if (completion == null ||
                                    !completion.shouldShowPrompt) {
                                  return const SizedBox.shrink();
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 18),
                                  child: _HomeRecordPromptCard(
                                    completion: completion,
                                    onOpenRecord: _openRecord,
                                  ),
                                );
                              },
                            ),
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
        return '飼育環境は安定しています';
      case '危険':
        return '飼育環境をすぐ確認してください';
      case '注意':
        return '飼育環境は少し注意です';
      default:
        return '飼育環境はまだ判断できません';
    }
  }

  String _environmentSummary(EnvironmentAssessment assessment) {
    final parts = <String>[];

    final temp = assessment.avgTemp;
    if (temp != null) {
      parts.add('平均${temp.toStringAsFixed(1)}℃');
    }

    final hum = assessment.avgHum;
    if (hum != null) {
      parts.add('平均${hum.round()}%');
    }

    if (parts.isEmpty) {
      return '温湿度データを確認中です';
    }

    return parts.join(' / ');
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

  List<SemanticTrendBand> _heroChartBands(
    EnvironmentMetricKind metricKind,
  ) {
    if (metricKind == EnvironmentMetricKind.temperature) {
      return [
        SemanticTrendBand(
          start: 18,
          end: EnvironmentStatusService.tempMin,
          label: '低め',
          color: Colors.blue.withValues(alpha: 0.07),
          labelColor: Colors.blue.shade200,
        ),
        SemanticTrendBand(
          start: EnvironmentStatusService.tempMin,
          end: EnvironmentStatusService.tempMax,
          label: '適正',
          color: Colors.green.withValues(alpha: 0.07),
          labelColor: Colors.green.shade200,
        ),
        SemanticTrendBand(
          start: EnvironmentStatusService.tempMax,
          end: 28,
          label: '高め',
          color: Colors.orange.withValues(alpha: 0.08),
          labelColor: Colors.orange.shade200,
        ),
      ];
    }

    return [
      SemanticTrendBand(
        start: 30,
        end: EnvironmentStatusService.humMin,
        label: '低め',
        color: Colors.blue.withValues(alpha: 0.07),
        labelColor: Colors.blue.shade200,
      ),
      SemanticTrendBand(
        start: EnvironmentStatusService.humMin,
        end: EnvironmentStatusService.humMax,
        label: '適正',
        color: Colors.green.withValues(alpha: 0.07),
        labelColor: Colors.green.shade200,
      ),
      SemanticTrendBand(
        start: EnvironmentStatusService.humMax,
        end: 75,
        label: '高め',
        color: Colors.orange.withValues(alpha: 0.08),
        labelColor: Colors.orange.shade200,
      ),
    ];
  }

  DateTime? _parseHistoryDate(String? rawDate) {
    final value = rawDate?.trim();
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  Color _heroTrendColor(
    EnvironmentMetricKind metricKind,
    double latestValue,
  ) {
    if (metricKind == EnvironmentMetricKind.temperature) {
      if (latestValue < EnvironmentStatusService.tempMin) {
        return Colors.blue.shade400;
      }
      if (latestValue > EnvironmentStatusService.tempMax) {
        return Colors.orange.shade400;
      }
      return AppTheme.envGood;
    }

    if (latestValue < EnvironmentStatusService.humMin) {
      return Colors.blue.shade400;
    }
    if (latestValue > EnvironmentStatusService.humMax) {
      return Colors.orange.shade400;
    }
    return AppTheme.envGood;
  }

  List<SemanticTrendPoint> _buildTrendPoints(
    EnvironmentAssessment assessment,
  ) {
    final heroData = _environmentStatusService.buildHeroViewData(assessment);
    final points = <SemanticTrendPoint>[];

    for (final item in history.where((e) => e.hasCoreData)) {
      final date = _parseHistoryDate(item.date);
      if (date == null) continue;

      final value = heroData.metricKind == EnvironmentMetricKind.humidity
          ? item.avgHum
          : item.avgTemp;

      if (value == null) continue;

      points.add(
        SemanticTrendPoint(
          x: date,
          y: value,
        ),
      );
    }

    points.sort((a, b) => a.x.compareTo(b.x));
    return points;
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

    final trendPoints = _buildTrendPoints(a);
    final trendColor = trendPoints.isEmpty
        ? AppTheme.environmentAccentForContext(context, a.level)
        : _heroTrendColor(
            heroData.metricKind,
            trendPoints.last.y,
          );
    final accent = AppTheme.environmentAccentForContext(context, a.level);

    final judgement = _levelJudgement(a.level);
    final summary = _environmentSummary(a);
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
                    summary,
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
                  if (trendPoints.length >= 2) ...[
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
                    SemanticTrendChart(
                      points: trendPoints,
                      bands: _heroChartBands(
                        heroData.metricKind,
                      ),
                      unit: heroData.metricKind ==
                              EnvironmentMetricKind.temperature
                          ? '℃'
                          : '%',
                      minimum: heroData.metricKind ==
                              EnvironmentMetricKind.temperature
                          ? 18
                          : 30,
                      maximum: heroData.metricKind ==
                              EnvironmentMetricKind.temperature
                          ? 28
                          : 75,
                      height: 64,
                      mode: SemanticTrendChartMode.compact,
                      showBandLabels: false,
                      showLatestVerticalLine: false,
                      lineColor: trendColor,
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

  @override
  Widget build(BuildContext context) {
    final top = result.topAnomaly!;
    final level = top.severity == AnomalySeverity.high
        ? StatusCardLevel.danger
        : StatusCardLevel.caution;

    return StatusCard(
      level: level,
      onTap: onTap,
      emphasize: top.severity == AnomalySeverity.high,
      radius: 22,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '最近の気になる変化',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.tertiaryText(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            top.title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            top.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.secondaryText(context),
                  height: 1.45,
                ),
          ),
          if (onAskAi != null) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onAskAi,
              icon: const Icon(Icons.smart_toy_outlined, size: 18),
              label: const Text('この変化をAIに相談'),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeRecordPromptCard extends StatelessWidget {
  final DailyRecordCompletion completion;
  final VoidCallback onOpenRecord;

  const _HomeRecordPromptCard({
    required this.completion,
    required this.onOpenRecord,
  });

  @override
  Widget build(BuildContext context) {
    final dailyItems = completion.incompleteDailyLabels;
    final showWeight = completion.weightDue;

    final title = dailyItems.isNotEmpty
        ? completion.remainingDailyCount == 1
            ? '今日の記録があと1件あります'
            : '今日の記録が残っています'
        : 'そろそろ体重を記録しませんか？';

    return StatusCard(
      level: StatusCardLevel.neutral,
      radius: 24,
      padding: const EdgeInsets.all(18),
      onTap: onOpenRecord,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.tertiaryText(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (dailyItems.isNotEmpty)
            ...dailyItems.map(
              (label) => _PromptRow(
                icon: label.contains('走った')
                    ? Icons.directions_run_rounded
                    : Icons.favorite_border_rounded,
                label: label,
                trailing: '未入力',
              ),
            ),
          if (showWeight)
            _PromptRow(
              icon: Icons.monitor_weight_outlined,
              label: completion.weightPromptLabel,
              trailing: '任意',
            ),
          const SizedBox(height: 10),
          Text(
            dailyItems.isNotEmpty
                ? '入力が完了すると、このカードは自動で消えます。'
                : '体重は毎日の必須記録ではありません。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.secondaryText(context),
                ),
          ),
        ],
      ),
    );
  }
}

class _PromptRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String trailing;

  const _PromptRow({
    required this.icon,
    required this.label,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: AppTheme.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          Text(
            trailing,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.secondaryText(context),
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

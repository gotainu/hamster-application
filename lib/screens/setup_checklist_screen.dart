import 'dart:async';

import 'package:flutter/material.dart';

import '../models/breeding_environment.dart';
import '../models/pet_profile.dart';
import '../screens/breeding_environment_edit_screen.dart';
import '../screens/pet_profile_edit_screen.dart';
import '../screens/switchbot_setup.dart';
import '../services/breeding_environment_repo.dart';
import '../services/onboarding_state_repo.dart';
import '../services/pet_profile_repo.dart';
import '../services/switchbot_repo.dart';
import '../theme/app_theme.dart';

class SetupChecklistScreen extends StatefulWidget {
  final VoidCallback? onFinished;

  const SetupChecklistScreen({
    super.key,
    this.onFinished,
  });

  @override
  State<SetupChecklistScreen> createState() => _SetupChecklistScreenState();
}

class _SetupChecklistScreenState extends State<SetupChecklistScreen> {
  final _petRepo = PetProfileRepo();
  final _envRepo = BreedingEnvironmentRepo();
  final _switchbotRepo = SwitchbotRepo();
  final _onboardingRepo = OnboardingStateRepo();

  late Future<_SetupChecklistStatus> _statusFuture;

  @override
  void initState() {
    super.initState();
    _statusFuture = _loadStatus();
  }

  Future<void> _refresh() async {
    setState(() {
      _statusFuture = _loadStatus();
    });
  }

  Future<_SetupChecklistStatus> _loadStatus() async {
    final pet = await _petRepo.fetchMainPet();
    final env = await _envRepo.fetchMainEnv();

    final hasSwitchbotSecrets = await _safeReadSwitchbotSecrets();
    final switchbotConfig = await _safeReadSwitchbotConfig();

    return _SetupChecklistStatus(
      hasPetProfile: _hasPetProfile(pet),
      hasBreedingEnvironment: _hasBreedingEnvironment(env),
      hasSwitchbotSecrets: hasSwitchbotSecrets,
      hasSwitchbotDevice: switchbotConfig?.hasDevice ?? false,
    );
  }

  Future<bool> _safeReadSwitchbotSecrets() async {
    try {
      return await _switchbotRepo.watchHasSecrets().first.timeout(
            const Duration(seconds: 3),
            onTimeout: () => false,
          );
    } catch (_) {
      return false;
    }
  }

  Future<SwitchbotConfig?> _safeReadSwitchbotConfig() async {
    try {
      return await _switchbotRepo.watchSwitchbotConfig().first.timeout(
            const Duration(seconds: 3),
            onTimeout: () => null,
          );
    } catch (_) {
      return null;
    }
  }

  bool _hasPetProfile(PetProfile? pet) {
    if (pet == null) return false;
    return pet.name.trim().isNotEmpty &&
        pet.species.trim().isNotEmpty &&
        pet.color?.trim().isNotEmpty == true &&
        pet.birthday != null;
  }

  bool _hasBreedingEnvironment(BreedingEnvironment? env) {
    if (env == null) return false;

    return (env.cageWidth ?? '').trim().isNotEmpty &&
        (env.cageDepth ?? '').trim().isNotEmpty &&
        (env.beddingThickness ?? '').trim().isNotEmpty &&
        (env.wheelDiameter ?? '').trim().isNotEmpty &&
        env.temperatureControl.trim().isNotEmpty;
  }

  Future<void> _openPetProfileEdit() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PetProfileEditScreen(),
      ),
    );

    if (!mounted) return;
    await _refresh();
  }

  Future<void> _openBreedingEnvironmentEdit() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const BreedingEnvironmentEditScreen(),
      ),
    );

    if (!mounted) return;
    await _refresh();
  }

  Future<void> _openSwitchbotSetup() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SwitchbotSetupScreen(),
      ),
    );

    if (!mounted) return;
    await _refresh();
  }

  Future<void> _finishSetup() async {
    await _onboardingRepo.markSetupChecklistViewed();

    if (!mounted) return;

    widget.onFinished?.call();

    if (widget.onFinished == null) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: FutureBuilder<_SetupChecklistStatus>(
            future: _statusFuture,
            builder: (context, snap) {
              final loading = snap.connectionState == ConnectionState.waiting;
              final status = snap.data ?? _SetupChecklistStatus.empty();

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: [
                  Row(
                    children: [
                      Text(
                        '初期設定',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primaryText(context),
                                ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _finishSetup,
                        child: Text(
                          'あとで',
                          style: TextStyle(
                            color: AppTheme.secondaryText(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'まずは、このアプリの価値が出る設定を整えましょう。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.secondaryText(context),
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 20),
                  _SetupProgressCard(
                    completedCount: status.completedRequiredCount,
                    totalCount: status.totalRequiredCount,
                    loading: loading,
                  ),
                  const SizedBox(height: 22),
                  _SectionTitle(
                    title: '必須設定',
                    subtitle: 'AI相談と評価の精度に直接関わります',
                  ),
                  const SizedBox(height: 12),
                  _ChecklistTile(
                    icon: Icons.pets_rounded,
                    title: 'ペットプロフィールを登録',
                    subtitle: '名前・種類・毛色・誕生日を登録します',
                    requiredLabel: '必須',
                    completed: status.hasPetProfile,
                    onTap: _openPetProfileEdit,
                    actionLabel: status.hasPetProfile ? '編集' : '登録する',
                  ),
                  const SizedBox(height: 12),
                  _ChecklistTile(
                    icon: Icons.home_work_rounded,
                    title: '飼育環境を登録',
                    subtitle: 'ケージ・床材・回し車・温度管理を登録します',
                    requiredLabel: '必須',
                    completed: status.hasBreedingEnvironment,
                    onTap: _openBreedingEnvironmentEdit,
                    actionLabel: status.hasBreedingEnvironment ? '編集' : '登録する',
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle(
                    title: 'おすすめ設定',
                    subtitle: '毎日の見守りがさらに便利になります',
                  ),
                  const SizedBox(height: 12),
                  _ChecklistTile(
                    icon: Icons.thermostat_rounded,
                    title: 'SwitchBotを連携',
                    subtitle: status.hasSwitchbotSecrets
                        ? status.hasSwitchbotDevice
                            ? '温湿度計の選択まで完了しています'
                            : '認証済みです。温湿度計を選択してください'
                        : '温湿度を自動で記録できます',
                    requiredLabel: '推奨',
                    completed:
                        status.hasSwitchbotSecrets && status.hasSwitchbotDevice,
                    onTap: _openSwitchbotSetup,
                    actionLabel: status.hasSwitchbotSecrets ? '設定を開く' : '連携する',
                  ),
                  const SizedBox(height: 12),
                  _ChecklistTile(
                    icon: Icons.directions_run_rounded,
                    title: '昨日の走行記録を入れる',
                    subtitle: '昨晩〜今朝の回転数を入力すると活動量評価に使えます',
                    requiredLabel: '任意',
                    completed: false,
                    onTap: _finishSetup,
                    actionLabel: 'Homeで入力',
                  ),
                  const SizedBox(height: 12),
                  _ChecklistTile(
                    icon: Icons.favorite_border_rounded,
                    title: '今日の様子を残す',
                    subtitle: '気になる様子がある時だけ記録できます',
                    requiredLabel: '任意',
                    completed: false,
                    onTap: _finishSetup,
                    actionLabel: 'Homeで入力',
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _finishSetup,
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text(
                        'Homeへ進む',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SetupChecklistStatus {
  final bool hasPetProfile;
  final bool hasBreedingEnvironment;
  final bool hasSwitchbotSecrets;
  final bool hasSwitchbotDevice;

  const _SetupChecklistStatus({
    required this.hasPetProfile,
    required this.hasBreedingEnvironment,
    required this.hasSwitchbotSecrets,
    required this.hasSwitchbotDevice,
  });

  factory _SetupChecklistStatus.empty() {
    return const _SetupChecklistStatus(
      hasPetProfile: false,
      hasBreedingEnvironment: false,
      hasSwitchbotSecrets: false,
      hasSwitchbotDevice: false,
    );
  }

  int get completedRequiredCount {
    return [
      hasPetProfile,
      hasBreedingEnvironment,
    ].where((e) => e).length;
  }

  int get totalRequiredCount => 2;
}

class _SetupProgressCard extends StatelessWidget {
  final int completedCount;
  final int totalCount;
  final bool loading;

  const _SetupProgressCard({
    required this.completedCount,
    required this.totalCount,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = totalCount == 0 ? 0.0 : completedCount / totalCount;
    final allDone = completedCount >= totalCount;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: AppTheme.softShadow(context),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppTheme.chipFill(
                allDone ? AppTheme.envGood : AppTheme.accent,
                context,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              allDone ? Icons.check_circle_rounded : Icons.checklist_rounded,
              color: allDone ? AppTheme.envGood : AppTheme.accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loading
                      ? '設定状況を確認中…'
                      : allDone
                          ? '必須設定は完了しています'
                          : 'あと ${totalCount - completedCount} 件で準備完了',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: loading ? null : ratio,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(999),
                ),
                const SizedBox(height: 6),
                Text(
                  '$completedCount / $totalCount 完了',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText(context),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.secondaryText(context),
                ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String requiredLabel;
  final bool completed;
  final VoidCallback onTap;
  final String actionLabel;

  const _ChecklistTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.requiredLabel,
    required this.completed,
    required this.onTap,
    required this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final color = completed ? AppTheme.envGood : AppTheme.accent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardSurface(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: completed
                  ? AppTheme.envGood.withValues(alpha: 0.22)
                  : AppTheme.quickActionBorder(context),
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 14,
                offset: const Offset(0, 8),
                color: AppTheme.softShadow(context),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.chipFill(color, context),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  completed ? Icons.check_circle_rounded : icon,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.chipFill(color, context),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            requiredLabel,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: color,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.secondaryText(context),
                            height: 1.45,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onTap,
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

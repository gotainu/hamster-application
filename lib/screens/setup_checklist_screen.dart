import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../models/breeding_environment.dart';
import '../models/pet_profile.dart';
import '../screens/breeding_environment_edit_screen.dart';
import '../screens/pet_profile_edit_screen.dart';
import '../screens/owner_profile_edit_screen.dart';
import '../services/breeding_environment_repo.dart';
import '../services/onboarding_state_repo.dart';
import '../services/pet_profile_repo.dart';
import '../services/owner_profile_repo.dart';
import '../theme/app_theme.dart';

/// 新規ユーザーが、説明を読むだけでなくアプリの価値に到達するための導線です。
///
/// SwitchBot 等の追加設定はここでは扱わず、AI相談の精度に直結する三つの
/// 操作（ペット、環境、最初の相談）だけに絞っています。
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
  final _onboardingRepo = OnboardingStateRepo();
  final _ownerRepo = OwnerProfileRepo();

  late Future<_SetupChecklistStatus> _statusFuture;
  final GlobalKey _petProfileStepKey = GlobalKey();
  final GlobalKey _environmentStepKey = GlobalKey();
  final GlobalKey _ownerStepKey = GlobalKey();
  int? _scheduledCoachStep;

  @override
  void initState() {
    super.initState();
    _statusFuture = _loadStatus();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _statusFuture = _loadStatus());
  }

  Future<_SetupChecklistStatus> _loadStatus() async {
    final results = await Future.wait<Object?>([
      _petRepo.fetchMainPet(),
      _envRepo.fetchMainEnv(),
      _ownerRepo.fetch(),
      _onboardingRepo.fetchState(),
    ]);

    final pet = results[0] as PetProfile?;
    final env = results[1] as BreedingEnvironment?;
    final owner = results[2];
    final onboarding = results[3] as OnboardingState;

    return _SetupChecklistStatus(
      petName: pet?.name.trim() ?? '',
      hasPetProfile:
          pet != null || onboarding.completedSetupSteps.contains('pet'),
      hasBreedingEnvironment:
          env != null || onboarding.completedSetupSteps.contains('environment'),
      hasOwnerProfile:
          owner != null || onboarding.completedSetupSteps.contains('owner'),
      setupCoachMarkStep: onboarding.setupCoachMarkStep,
    );
  }

  Future<void> _openPetProfileEdit({required bool isAlreadyRegistered}) async {
    if (!isAlreadyRegistered) {
      final shouldContinue = await _showValuePreview(
        imagePath: 'assets/images/onboarding/personalized_care_portrait.png',
        eyebrow: 'うちの子だけの見守りへ',
        title: '名前を呼べる\n見守りを始めよう',
        body: '種類・毛色・誕生日を登録すると、記録と相談がその子に合わせてまとまります。',
        actionLabel: 'プロフィールを登録する',
      );
      if (!shouldContinue || !mounted) return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PetProfileEditScreen()),
    );
    if (saved == true) await _onboardingRepo.markSetupStepCompleted('pet');
    await _refresh();
  }

  Future<void> _openBreedingEnvironmentEdit({
    required bool isAlreadyRegistered,
  }) async {
    if (!isAlreadyRegistered) {
      final shouldContinue = await _showValuePreview(
        imagePath: 'assets/images/onboarding/detect_small_changes_portrait.png',
        eyebrow: '環境を基準にする',
        title: '気になる変化を\n見つけやすくしよう',
        body: 'ケージ・床材・回し車・温度管理を登録すると、環境評価とAI相談が具体的になります。',
        actionLabel: '飼育環境を登録する',
      );
      if (!shouldContinue || !mounted) return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const BreedingEnvironmentEditScreen()),
    );
    if (saved == true) {
      await _onboardingRepo.markSetupStepCompleted('environment');
    }
    await _refresh();
  }

  Future<void> _openOwnerProfileEdit(
      {required bool isAlreadyRegistered}) async {
    if (!isAlreadyRegistered) {
      final shouldContinue = await _showValuePreview(
        imagePath: 'assets/images/onboarding/owner_context_portrait.png',
        eyebrow: '見守りをあなた向けに',
        title: '地域や経験を\nあとから活かせます',
        body: '地域の天気や、あなたの飼育経験に合わせた振り返りに使えます。すべて後から変更できます。',
        actionLabel: '飼い主プロフィールを登録する',
      );
      if (!shouldContinue || !mounted) return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const OwnerProfileEditScreen()),
    );
    if (saved == true) await _onboardingRepo.markSetupStepCompleted('owner');
    await _refresh();
  }

  Future<void> _finishSetup() async {
    final status = await _statusFuture;
    await _onboardingRepo.markJourneyCompleted(
      startHomeAiOnboarding: status.isComplete,
    );
    if (!mounted) return;

    widget.onFinished?.call();
    if (widget.onFinished == null) {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _showValuePreview({
    required String imagePath,
    required String eyebrow,
    required String title,
    required String body,
    required String actionLabel,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ValuePreviewSheet(
        imagePath: imagePath,
        eyebrow: eyebrow,
        title: title,
        body: body,
        actionLabel: actionLabel,
      ),
    );
    return result == true;
  }

  void _scheduleStartGuide(_SetupChecklistStatus status) {
    final step = status.nextCoachStep;
    if (step == null || _scheduledCoachStep == step) return;
    _scheduledCoachStep = step;
    final config = switch (step) {
      1 => (
          key: _petProfileStepKey,
          title: 'まずは、うちの子を登録',
          body: '登録すると、その子に合わせた見守りを始められます。'
        ),
      2 => (
          key: _environmentStepKey,
          title: '次は、飼育環境を登録',
          body: '環境の変化に気づく基準を作りましょう。'
        ),
      _ => (
          key: _ownerStepKey,
          title: '最後に、飼い主プロフィール',
          body: '地域や経験を、これからの見守りに活かせます。'
        ),
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      TutorialCoachMark(
        targets: [
          TargetFocus(
            identify: 'setup-step-$step',
            keyTarget: config.key,
            shape: ShapeLightFocus.RRect,
            radius: 24,
            contents: [
              TargetContent(
                align: ContentAlign.bottom,
                child: _CoachMarkContent(
                  title: config.title,
                  body: config.body,
                ),
              ),
            ],
          ),
        ],
        colorShadow: const Color(0xFF080D19),
        opacityShadow: 0.76,
        textSkip: 'あとで',
        onSkip: () {
          _onboardingRepo.markSetupCoachMarkStepSeen(step);
          return true;
        },
        onFinish: () {
          _onboardingRepo.markSetupCoachMarkStepSeen(step);
        },
      ).show(context: context);
    });
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

              if (!loading && status.nextCoachStep != null) {
                _scheduleStartGuide(status);
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: [
                  Row(
                    children: [
                      Text(
                        'はじめる準備',
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
                    '3つの登録で、見守りを始められます。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.secondaryText(context),
                        ),
                  ),
                  const SizedBox(height: 22),
                  _JourneyProgress(
                    completedCount: status.completedCount,
                    totalCount: status.totalCount,
                    loading: loading,
                  ),
                  const SizedBox(height: 22),
                  _JourneyStepTile(
                    number: 1,
                    icon: Icons.pets_rounded,
                    title: 'うちの子を登録',
                    subtitle: '名前・種類・毛色・誕生日',
                    completed: status.hasPetProfile,
                    enabled: !loading,
                    actionLabel: status.hasPetProfile ? '編集' : '登録する',
                    targetKey: _petProfileStepKey,
                    onTap: () => _openPetProfileEdit(
                      isAlreadyRegistered: status.hasPetProfile,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _JourneyStepTile(
                    number: 2,
                    icon: Icons.home_work_rounded,
                    title: '飼育環境を登録',
                    subtitle: 'ケージ・床材・回し車・温度管理',
                    completed: status.hasBreedingEnvironment,
                    enabled: !loading,
                    actionLabel: status.hasBreedingEnvironment ? '編集' : '登録する',
                    targetKey: _environmentStepKey,
                    onTap: () => _openBreedingEnvironmentEdit(
                      isAlreadyRegistered: status.hasBreedingEnvironment,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _JourneyStepTile(
                    number: 3,
                    icon: Icons.person_pin_circle_rounded,
                    title: '飼い主プロフィールを登録',
                    subtitle: '地域・年齢層・飼育経験',
                    completed: status.hasOwnerProfile,
                    enabled: !loading,
                    actionLabel: status.hasOwnerProfile ? '編集' : '登録する',
                    targetKey: _ownerStepKey,
                    onTap: () => _openOwnerProfileEdit(
                      isAlreadyRegistered: status.hasOwnerProfile,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _finishSetup,
                      icon: Icon(
                        status.isComplete
                            ? Icons.check_circle_rounded
                            : Icons.home_rounded,
                      ),
                      label: Text(
                        status.isComplete ? '見守りを始める' : 'Homeへ進む',
                        style: const TextStyle(fontWeight: FontWeight.w800),
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
  final String petName;
  final bool hasPetProfile;
  final bool hasBreedingEnvironment;
  final bool hasOwnerProfile;
  final int setupCoachMarkStep;

  const _SetupChecklistStatus({
    required this.petName,
    required this.hasPetProfile,
    required this.hasBreedingEnvironment,
    required this.hasOwnerProfile,
    required this.setupCoachMarkStep,
  });

  factory _SetupChecklistStatus.empty() {
    return const _SetupChecklistStatus(
      petName: '',
      hasPetProfile: false,
      hasBreedingEnvironment: false,
      hasOwnerProfile: false,
      setupCoachMarkStep: 0,
    );
  }

  int get completedCount => [
        hasPetProfile,
        hasBreedingEnvironment,
        hasOwnerProfile,
      ].where((value) => value).length;
  int get totalCount => 3;
  bool get isComplete => completedCount == totalCount;
  int? get nextCoachStep {
    if (!hasPetProfile) return setupCoachMarkStep < 1 ? 1 : null;
    if (!hasBreedingEnvironment) return setupCoachMarkStep < 2 ? 2 : null;
    if (!hasOwnerProfile) return setupCoachMarkStep < 3 ? 3 : null;
    return null;
  }
}

class _JourneyProgress extends StatelessWidget {
  final int completedCount;
  final int totalCount;
  final bool loading;

  const _JourneyProgress({
    required this.completedCount,
    required this.totalCount,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = totalCount == 0 ? 0.0 : completedCount / totalCount;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.quickActionBorder(context)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            height: 54,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: loading ? null : ratio,
                  strokeWidth: 6,
                  backgroundColor: AppTheme.quickActionFill(context),
                ),
                Center(
                  child: Text(
                    '$completedCount/$totalCount',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              completedCount == totalCount
                  ? '準備ができました'
                  : 'あと${totalCount - completedCount}つ',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryText(context),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyStepTile extends StatelessWidget {
  final int number;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool completed;
  final bool enabled;
  final String actionLabel;
  final VoidCallback onTap;
  final Key? targetKey;

  const _JourneyStepTile({
    required this.number,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.completed,
    required this.enabled,
    required this.actionLabel,
    required this.onTap,
    this.targetKey,
  });

  @override
  Widget build(BuildContext context) {
    final muted = !enabled && !completed;
    final textColor =
        muted ? AppTheme.weakText(context) : AppTheme.primaryText(context);

    return Semantics(
      button: enabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            key: targetKey,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardSurface(context),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: completed
                    ? AppTheme.accent.withValues(alpha: 0.7)
                    : AppTheme.quickActionBorder(context),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: completed
                        ? AppTheme.accent.withValues(alpha: 0.16)
                        : AppTheme.quickActionFill(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    completed ? Icons.check_rounded : icon,
                    color: completed
                        ? AppTheme.accent
                        : (muted
                            ? AppTheme.weakText(context)
                            : AppTheme.accent),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$number. $title',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: muted
                                  ? AppTheme.weakText(context)
                                  : AppTheme.secondaryText(context),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  actionLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: completed
                            ? AppTheme.accent
                            : (muted
                                ? AppTheme.weakText(context)
                                : AppTheme.accent),
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(width: 4),
                Icon(
                  completed
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: completed
                      ? AppTheme.accent
                      : (muted
                          ? AppTheme.weakText(context)
                          : AppTheme.secondaryText(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ValuePreviewSheet extends StatelessWidget {
  final String imagePath;
  final String eyebrow;
  final String title;
  final String body;
  final String actionLabel;

  const _ValuePreviewSheet({
    required this.imagePath,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: AppTheme.quickActionBorder(context)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(imagePath, fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.26, 0.52, 1],
                    colors: [
                      Colors.black.withValues(alpha: 0.08),
                      Colors.black.withValues(alpha: 0.20),
                      AppTheme.cardSurface(context).withValues(alpha: 0.84),
                      AppTheme.cardSurface(context),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            AppTheme.weakText(context).withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 156),
                  Text(
                    eyebrow,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1.18,
                          color: AppTheme.primaryText(context),
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.secondaryText(context),
                          height: 1.55,
                        ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(
                      actionLabel,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('あとで'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachMarkContent extends StatelessWidget {
  final String title;
  final String body;

  const _CoachMarkContent({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }
}

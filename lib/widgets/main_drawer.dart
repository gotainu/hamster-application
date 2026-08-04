import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/hamster_avatar.dart';
import '../models/health_assessment.dart';
import '../models/daily_record_completion.dart';
import '../models/pet_profile.dart';
import '../services/hamster_avatar_appearance_resolver.dart';
import '../services/hamster_avatar_asset_resolver.dart';
import '../services/hamster_avatar_condition_resolver.dart';
import '../services/health_assessment_repo.dart';
import '../services/pet_profile_repo.dart';
import '../theme/app_theme.dart';
import 'hamster_avatar_view.dart';
import 'shine_border.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({
    super.key,
    required this.onSelectScreen,
    required this.recordCompletionListenable,
  });

  final void Function(String identifier) onSelectScreen;
  final ValueListenable<DailyRecordCompletion?> recordCompletionListenable;

  @override
  Widget build(BuildContext context) {
    final drawerWidth =
        (MediaQuery.sizeOf(context).width * 0.84).clamp(304.0, 390.0);

    return Drawer(
      width: drawerWidth,
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppTheme.drawerBlurSigma,
            sigmaY: AppTheme.drawerBlurSigma,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.drawerSurface(context),
              border: Border(
                right: BorderSide(
                  color: AppTheme.drawerOuterBorder(context),
                ),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: double.infinity,
                      height: MediaQuery.paddingOf(context).top + 14,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppTheme.drawerStatusBarOverlay(context),
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      const _DrawerHeader(),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                          children: [
                            const _SectionLabel(label: '記録・管理'),
                            const SizedBox(height: 10),
                            ValueListenableBuilder<DailyRecordCompletion?>(
                              valueListenable: recordCompletionListenable,
                              builder: (context, completion, _) {
                                final needsRecord =
                                    completion?.shouldShowPrompt == true;

                                return Semantics(
                                  label: needsRecord
                                      ? '今日の未入力記録があります。記録する'
                                      : '今日の記録は完了しています。記録する',
                                  child: AnimatedShiningBorder(
                                    active: needsRecord,
                                    borderRadius: 24,
                                    borderWidth: 2.2,
                                    duration:
                                        const Duration(milliseconds: 2600),
                                    colors: [
                                      AppTheme.accent.withValues(alpha: 0.40),
                                      AppTheme.accent,
                                      Colors.cyanAccent.withValues(alpha: 0.92),
                                      Colors.white.withValues(alpha: 0.94),
                                      AppTheme.accent,
                                    ],
                                    child: _DrawerGroup(
                                      children: [
                                        _DrawerItem(
                                          icon: Icons.edit_note_rounded,
                                          title: '記録する',
                                          subtitle: '体重・食事・活動などを入力',
                                          onTap: () => onSelectScreen('record'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 26),
                            const _SectionLabel(label: 'プロフィール・設定'),
                            const SizedBox(height: 10),
                            _DrawerGroup(
                              children: [
                                _DrawerItem(
                                  icon: Icons.account_circle_outlined,
                                  title: 'ペットのプロフィール',
                                  subtitle: '名前や基本情報を編集',
                                  onTap: () => onSelectScreen('pets_profile'),
                                ),
                                _DrawerItem(
                                  icon: Icons.settings_outlined,
                                  title: 'アプリの設定',
                                  subtitle: '表示・通知・アカウント',
                                  onTap: () => onSelectScreen('settings'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const _DrawerFooter(),
                    ],
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

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  static final PetProfileRepo _petProfileRepo = PetProfileRepo();
  static final HealthAssessmentRepo _healthAssessmentRepo =
      HealthAssessmentRepo();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PetProfile?>(
      stream: _petProfileRepo.watchMainPet(),
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data;
        final petName = profile?.name.trim();
        final subtitle = petName != null && petName.isNotEmpty
            ? '$petNameの記録と管理'
            : 'ハムスターの記録と管理';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 16, 18, 18),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppTheme.drawerDivider(context),
              ),
            ),
          ),
          child: Row(
            children: [
              StreamBuilder<HealthAssessment?>(
                stream: _healthAssessmentRepo.watchLatest(),
                builder: (context, assessmentSnapshot) {
                  return _DrawerAvatar(
                    profile: profile,
                    assessment: assessmentSnapshot.data,
                    assessmentIsLoading: assessmentSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !assessmentSnapshot.hasData,
                    assessmentHasError: assessmentSnapshot.hasError,
                  );
                },
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hamster Project',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.drawerPrimaryText(context),
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.1,
                          ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        subtitle,
                        key: ValueKey<String>(subtitle),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.drawerSecondaryText(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
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
}

class _DrawerAvatar extends StatelessWidget {
  const _DrawerAvatar({
    required this.profile,
    required this.assessment,
    required this.assessmentIsLoading,
    required this.assessmentHasError,
  });

  final PetProfile? profile;
  final HealthAssessment? assessment;
  final bool assessmentIsLoading;
  final bool assessmentHasError;

  static const HamsterAvatarAppearanceResolver _appearanceResolver =
      HamsterAvatarAppearanceResolver();
  static const HamsterAvatarConditionResolver _conditionResolver =
      HamsterAvatarConditionResolver();
  static const HamsterAvatarAssetResolver _assetResolver =
      HamsterAvatarAssetResolver();

  static const double _frameSize = 66;
  static const double _avatarSize = 88;

  @override
  Widget build(BuildContext context) {
    final imageUrl = profile?.imageUrl?.trim();

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return _photoAvatar(
        context,
        imageUrl: imageUrl,
      );
    }

    return _avatarOrFallback(context);
  }

  Widget _photoAvatar(
    BuildContext context, {
    required String imageUrl,
  }) {
    return Semantics(
      label: '${_petSubject(profile)}の写真',
      image: true,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _avatarFrame(
          context,
          key: ValueKey<String>('photo:$imageUrl'),
          child: Image.network(
            imageUrl,
            width: _frameSize,
            height: _frameSize,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;

              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: child,
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;

              final expected = loadingProgress.expectedTotalBytes;
              final progress = expected == null
                  ? null
                  : loadingProgress.cumulativeBytesLoaded / expected;

              return Center(
                child: SizedBox.square(
                  dimension: 19,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 2,
                    color: AppTheme.drawerIconForeground(context),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Drawer pet photo load failed: $imageUrl, $error');
              return _avatarContentOrFallback(context);
            },
          ),
        ),
      ),
    );
  }

  Widget _avatarOrFallback(BuildContext context) {
    final presentation = _resolvePresentation();

    if (presentation == null) {
      return _fallbackIcon(context);
    }

    final assetKey = presentation.assetCandidates.isEmpty
        ? 'drawer-avatar'
        : presentation.assetCandidates.first;

    return Semantics(
      label: '${_petSubject(profile)}の現在の状態を表すアバター',
      image: true,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _avatarFrame(
          context,
          key: ValueKey<String>('avatar:$assetKey'),
          child: _avatarContent(presentation),
        ),
      ),
    );
  }

  Widget _avatarContentOrFallback(BuildContext context) {
    final presentation = _resolvePresentation();

    if (presentation == null) {
      return Icon(
        Icons.pets_rounded,
        color: AppTheme.drawerIconForeground(context),
        size: 29,
      );
    }

    return _avatarContent(presentation);
  }

  HamsterAvatarPresentation? _resolvePresentation() {
    if (profile?.hasAvatarIdentity != true) return null;

    final appearance = _appearanceResolver.resolve(profile);

    final conditionResult = assessmentIsLoading || assessmentHasError
        ? HamsterAvatarConditionResult(
            condition: HamsterAvatarCondition.stable,
            cause: HamsterAvatarCause.none,
            message: '${_petSubject(profile)}のアバターです。',
            animateBreathing: true,
          )
        : _conditionResolver.resolve(
            assessment: assessment,
            petName: profile?.name,
          );

    return _assetResolver.resolve(
      appearance: appearance,
      conditionResult: conditionResult,
    );
  }

  Widget _avatarContent(HamsterAvatarPresentation presentation) {
    return OverflowBox(
      minWidth: 0,
      minHeight: 0,
      maxWidth: _avatarSize,
      maxHeight: _avatarSize,
      child: Transform.translate(
        offset: const Offset(0, 5),
        child: HamsterAvatarView(
          presentation: presentation,
          size: _avatarSize,
          showMessage: false,
          showDebugLabel: false,
          showBackdrop: false,
          showCauseBadge: false,
        ),
      ),
    );
  }

  Widget _avatarFrame(
    BuildContext context, {
    required Key key,
    required Widget child,
  }) {
    return Container(
      key: key,
      width: _frameSize,
      height: _frameSize,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.drawerHeaderIconSurface(context),
        border: Border.all(
          color: AppTheme.drawerHeaderIconBorder(context),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppTheme.isDark(context) ? 0.20 : 0.10,
            ),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _fallbackIcon(BuildContext context) {
    return Semantics(
      label: 'ペットプロフィール未登録',
      image: true,
      child: _avatarFrame(
        context,
        key: const ValueKey<String>('drawer-fallback-icon'),
        child: Icon(
          Icons.pets_rounded,
          color: AppTheme.drawerIconForeground(context),
          size: 29,
        ),
      ),
    );
  }

  String _petSubject(PetProfile? profile) {
    final name = profile?.name.trim();
    return name != null && name.isNotEmpty ? name : 'ハムスター';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.drawerSectionLabel(context),
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.35,
            ),
      ),
    );
  }
}

class _DrawerGroup extends StatelessWidget {
  const _DrawerGroup({
    required this.children,
  });

  final List<_DrawerItem> children;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.drawerGroupSurface(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.drawerGroupBorder(context),
          ),
          boxShadow: AppTheme.drawerGroupShadows(context),
        ),
        child: Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index < children.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 76, right: 16),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: AppTheme.drawerDivider(context),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title。$subtitle',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: AppTheme.drawerInteractionFill(context),
          highlightColor: AppTheme.drawerInteractionFill(context),
          hoverColor: AppTheme.drawerInteractionFill(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 78),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 13, 14, 13),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.drawerItemIconSurface(context),
                      border: Border.all(
                        color: AppTheme.drawerItemIconBorder(context),
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: AppTheme.drawerIconForeground(context),
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppTheme.drawerPrimaryText(context),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                  ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: AppTheme.drawerSecondaryText(context),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.25,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.drawerChevron(context),
                    size: 25,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerFooter extends StatelessWidget {
  const _DrawerFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
      child: Row(
        children: [
          Icon(
            Icons.pets_outlined,
            size: 15,
            color: AppTheme.drawerFooterText(context),
          ),
          const SizedBox(width: 7),
          Text(
            'Go / hamster well-being',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.drawerFooterText(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.15,
                ),
          ),
        ],
      ),
    );
  }
}

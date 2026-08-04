import 'package:flutter/material.dart';

import '../models/health_assessment.dart';
import '../models/pet_profile.dart';
import '../services/hamster_avatar_appearance_resolver.dart';
import '../services/hamster_avatar_asset_resolver.dart';
import '../services/hamster_avatar_condition_resolver.dart';
import '../theme/app_theme.dart';
import 'hamster_avatar_view.dart';

class HamsterAvatarHero extends StatelessWidget {
  final PetProfile? profile;
  final HealthAssessment? assessment;
  final Widget? trailing;
  final double avatarSize;
  final bool showMessage;
  final bool showDebugLabel;
  final bool showBackdrop;

  const HamsterAvatarHero({
    super.key,
    required this.profile,
    required this.assessment,
    this.trailing,
    this.avatarSize = 150,
    this.showMessage = true,
    this.showDebugLabel = false,
    this.showBackdrop = true,
  });

  static const _appearanceResolver = HamsterAvatarAppearanceResolver();
  static const _conditionResolver = HamsterAvatarConditionResolver();
  static const _assetResolver = HamsterAvatarAssetResolver();

  @override
  Widget build(BuildContext context) {
    final appearance = _appearanceResolver.resolve(profile);
    final condition = _conditionResolver.resolve(
      assessment: assessment,
      petName: profile?.name,
    );
    final presentation = _assetResolver.resolve(
      appearance: appearance,
      conditionResult: condition,
    );

    final avatar = HamsterAvatarView(
      presentation: presentation,
      size: avatarSize,
      showDebugLabel: showDebugLabel,
      showBackdrop: showBackdrop,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (trailing == null || constraints.maxWidth < 280) {
              return avatar;
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: avatar,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: trailing!,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        if (showMessage) ...[
          const SizedBox(height: 10),
          Text(
            presentation.message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.secondaryText(context),
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
          ),
        ],
      ],
    );
  }
}

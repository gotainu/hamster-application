import '../models/hamster_avatar.dart';

class HamsterAvatarAssetResolver {
  const HamsterAvatarAssetResolver();

  HamsterAvatarPresentation resolve({
    required HamsterAvatarAppearance appearance,
    required HamsterAvatarConditionResult conditionResult,
  }) {
    final body = appearance.bodyType.assetKey;
    final color = appearance.colorVariant.assetKey;
    final condition = conditionResult.condition.assetKey;

    final candidates = <String>[
      'assets/avatars/$body/$color/$condition.png',

      // 指定状態が未制作の場合のみ、
      // 同じ種類・同じ毛色のstableへフォールバックする。
      if (condition != HamsterAvatarCondition.stable.assetKey)
        'assets/avatars/$body/$color/stable.png',
    ];

    return HamsterAvatarPresentation(
      appearance: appearance,
      condition: conditionResult.condition,
      cause: conditionResult.cause,
      assetCandidates: candidates,
      message: conditionResult.message,
      animateBreathing: conditionResult.animateBreathing,
    );
  }
}

enum HamsterAvatarBodyType {
  syrian,
  djungarian,
  roborovski,
}

enum HamsterAvatarColorVariant {
  golden,
  cream,
  white,
  dark,
  dalmatian,
  normal,
  sapphire,
  pearl,
  whiteFace,
}

enum HamsterAvatarCondition {
  happy,
  stable,
  worried,
  alert,
  insufficientData,
  environmentDiscomfort,
  activityHigh,
  conditionConcerned,
}

enum HamsterAvatarCause {
  none,
  heat,
  cold,
  humidityHigh,
  humidityLow,
  activityHigh,
  activityLow,
  weightChanged,
  conditionConcern,
  insufficientData,
  overallAlert,
}

extension HamsterAvatarBodyTypeAssetKey on HamsterAvatarBodyType {
  String get assetKey {
    switch (this) {
      case HamsterAvatarBodyType.syrian:
        return 'syrian';
      case HamsterAvatarBodyType.djungarian:
        return 'djungarian';
      case HamsterAvatarBodyType.roborovski:
        return 'roborovski';
    }
  }
}

extension HamsterAvatarColorVariantAssetKey on HamsterAvatarColorVariant {
  String get assetKey {
    switch (this) {
      case HamsterAvatarColorVariant.golden:
        return 'golden';
      case HamsterAvatarColorVariant.cream:
        return 'cream';
      case HamsterAvatarColorVariant.white:
        return 'white';
      case HamsterAvatarColorVariant.dark:
        return 'dark';
      case HamsterAvatarColorVariant.dalmatian:
        return 'dalmatian';
      case HamsterAvatarColorVariant.normal:
        return 'normal';
      case HamsterAvatarColorVariant.sapphire:
        return 'sapphire';
      case HamsterAvatarColorVariant.pearl:
        return 'pearl';
      case HamsterAvatarColorVariant.whiteFace:
        return 'white_face';
    }
  }
}

extension HamsterAvatarConditionAssetKey on HamsterAvatarCondition {
  String get assetKey {
    switch (this) {
      case HamsterAvatarCondition.happy:
        return 'happy';
      case HamsterAvatarCondition.stable:
        return 'stable';
      case HamsterAvatarCondition.worried:
        return 'worried';
      case HamsterAvatarCondition.alert:
        return 'alert';
      case HamsterAvatarCondition.insufficientData:
        return 'insufficient_data';
      case HamsterAvatarCondition.environmentDiscomfort:
        return 'environment_discomfort';
      case HamsterAvatarCondition.activityHigh:
        return 'activity_high';
      case HamsterAvatarCondition.conditionConcerned:
        return 'condition_concerned';
    }
  }
}

class HamsterAvatarAppearance {
  final HamsterAvatarBodyType bodyType;
  final HamsterAvatarColorVariant colorVariant;
  final String sourceSpecies;
  final String? sourceColor;

  const HamsterAvatarAppearance({
    required this.bodyType,
    required this.colorVariant,
    required this.sourceSpecies,
    required this.sourceColor,
  });

  String get assetDirectory => '${bodyType.assetKey}/${colorVariant.assetKey}';
}

class HamsterAvatarConditionResult {
  final HamsterAvatarCondition condition;
  final HamsterAvatarCause cause;
  final String message;
  final bool animateBreathing;

  const HamsterAvatarConditionResult({
    required this.condition,
    required this.cause,
    required this.message,
    required this.animateBreathing,
  });
}

class HamsterAvatarPresentation {
  final HamsterAvatarAppearance appearance;
  final HamsterAvatarCondition condition;
  final HamsterAvatarCause cause;
  final List<String> assetCandidates;
  final String message;
  final bool animateBreathing;

  const HamsterAvatarPresentation({
    required this.appearance,
    required this.condition,
    required this.cause,
    required this.assetCandidates,
    required this.message,
    required this.animateBreathing,
  });
}

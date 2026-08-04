import '../models/hamster_avatar.dart';
import '../models/health_assessment.dart';

class HamsterAvatarConditionResolver {
  const HamsterAvatarConditionResolver();

  HamsterAvatarConditionResult resolve({
    required HealthAssessment? assessment,
    String? petName,
  }) {
    final subject = _subject(petName);

    if (assessment == null ||
        !assessment.hasMeaningfulAssessment ||
        assessment.overall.observedState == HealthAssessmentState.unknown ||
        assessment.overall.observedState ==
            HealthAssessmentState.insufficientData) {
      return HamsterAvatarConditionResult(
        condition: HamsterAvatarCondition.insufficientData,
        cause: HamsterAvatarCause.insufficientData,
        message: '$subjectの記録が増えると、表情で状態をお知らせします。',
        animateBreathing: false,
      );
    }

    final searchable = _searchableAssessmentText(assessment);

    if (_containsAny(searchable, [
          'conditionveryconcerned',
          'conditionslightlyconcerned',
          'veryconcerned',
          'slightlyconcerned',
          '食欲',
          '元気がない',
          'ぐったり',
          '様子が気になる',
        ]) ||
        _isCautionOrWorse(assessment.domains.condition.state)) {
      return HamsterAvatarConditionResult(
        condition: HamsterAvatarCondition.conditionConcerned,
        cause: HamsterAvatarCause.conditionConcern,
        message: '$subjectの様子を、いつもより丁寧に確認しましょう。',
        animateBreathing: false,
      );
    }

    if (_containsAny(searchable, [
      'temperaturehigh',
      'temphigh',
      'hightemperature',
      '高温',
      '温度が高',
      '暑',
    ])) {
      return HamsterAvatarConditionResult(
        condition: HamsterAvatarCondition.environmentDiscomfort,
        cause: HamsterAvatarCause.heat,
        message: '$subjectは少し暑さを感じているかもしれません。',
        animateBreathing: false,
      );
    }

    if (_containsAny(searchable, [
      'temperaturelow',
      'templow',
      'lowtemperature',
      '低温',
      '温度が低',
      '寒',
    ])) {
      return HamsterAvatarConditionResult(
        condition: HamsterAvatarCondition.environmentDiscomfort,
        cause: HamsterAvatarCause.cold,
        message: '$subjectが寒くないか、ケージ周辺を確認しましょう。',
        animateBreathing: false,
      );
    }

    if (_containsAny(searchable, [
      'humidityhigh',
      'highhumidity',
      '高湿',
      '湿度が高',
      '蒸し暑',
    ])) {
      return HamsterAvatarConditionResult(
        condition: HamsterAvatarCondition.environmentDiscomfort,
        cause: HamsterAvatarCause.humidityHigh,
        message: '$subjectは湿気を不快に感じているかもしれません。',
        animateBreathing: false,
      );
    }

    if (_containsAny(searchable, [
      'humiditylow',
      'lowhumidity',
      '低湿',
      '乾燥',
      '湿度が低',
    ])) {
      return HamsterAvatarConditionResult(
        condition: HamsterAvatarCondition.environmentDiscomfort,
        cause: HamsterAvatarCause.humidityLow,
        message: '$subjectの周りが乾燥しすぎていないか確認しましょう。',
        animateBreathing: false,
      );
    }

    if (_containsAny(searchable, [
      'activityhigh',
      'activityspike',
      '活動量が高',
      '走りすぎ',
    ])) {
      return HamsterAvatarConditionResult(
        condition: HamsterAvatarCondition.activityHigh,
        cause: HamsterAvatarCause.activityHigh,
        message: '$subjectはたくさん動いたようです。休めているか見守りましょう。',
        animateBreathing: true,
      );
    }

    if (_containsAny(searchable, [
      'activitylow',
      'activitydrop',
      '活動量が低',
      '活動量の低下',
    ])) {
      return HamsterAvatarConditionResult(
        condition: HamsterAvatarCondition.worried,
        cause: HamsterAvatarCause.activityLow,
        message: '$subjectの活動量が少なめです。普段との違いを確認しましょう。',
        animateBreathing: false,
      );
    }

    if (_containsAny(searchable, [
      'weightdecrease',
      'weightincrease',
      'weightchange',
      '体重減',
      '体重増',
      '体重変化',
    ])) {
      return HamsterAvatarConditionResult(
        condition: HamsterAvatarCondition.worried,
        cause: HamsterAvatarCause.weightChanged,
        message: '$subjectの体重に変化があります。食事や様子も確認しましょう。',
        animateBreathing: false,
      );
    }

    if (assessment.overall.observedState == HealthAssessmentState.alert) {
      return HamsterAvatarConditionResult(
        condition: HamsterAvatarCondition.alert,
        cause: HamsterAvatarCause.overallAlert,
        message: '$subjectの状態を早めに確認してください。',
        animateBreathing: false,
      );
    }

    if (assessment.overall.observedState == HealthAssessmentState.caution ||
        assessment.overall.observedState == HealthAssessmentState.changed) {
      return HamsterAvatarConditionResult(
        condition: HamsterAvatarCondition.worried,
        cause: HamsterAvatarCause.none,
        message: '$subjectに少し気になる変化があります。',
        animateBreathing: true,
      );
    }

    final score = assessment.overall.score ?? assessment.overall.observedScore;
    if (score != null && score >= 90) {
      return HamsterAvatarConditionResult(
        condition: HamsterAvatarCondition.happy,
        cause: HamsterAvatarCause.none,
        message: '$subjectは今日もごきげんに過ごせています。',
        animateBreathing: true,
      );
    }

    return HamsterAvatarConditionResult(
      condition: HamsterAvatarCondition.stable,
      cause: HamsterAvatarCause.none,
      message: '$subjectは落ち着いて過ごせています。',
      animateBreathing: true,
    );
  }

  String _searchableAssessmentText(HealthAssessment assessment) {
    final values = <String>[
      ...assessment.overall.flags,
      assessment.overall.summary,
      assessment.overall.primaryFactor ?? '',
    ];

    for (final domain in [
      assessment.domains.environment,
      assessment.domains.activity,
      assessment.domains.body,
      assessment.domains.condition,
      assessment.domains.nutrition,
    ]) {
      values
        ..addAll(domain.flags)
        ..add(domain.summary);

      for (final component in domain.components.values) {
        values
          ..addAll(component.flags)
          ..add(component.summary);
      }
    }

    return values.join(' ').toLowerCase();
  }

  bool _containsAny(String value, List<String> candidates) {
    return candidates.any((candidate) => value.contains(candidate));
  }

  bool _isCautionOrWorse(HealthAssessmentState state) {
    return state == HealthAssessmentState.caution ||
        state == HealthAssessmentState.alert;
  }

  String _subject(String? petName) {
    final value = petName?.trim();
    if (value == null || value.isEmpty) return 'この子';
    return value.endsWith('ちゃん') ? value : '$valueちゃん';
  }
}

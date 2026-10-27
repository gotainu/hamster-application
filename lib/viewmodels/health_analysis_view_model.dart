import '../models/current_weight_analysis.dart';
import '../models/daily_health_features.dart';
import '../models/health_assessment.dart';
import 'weight_research_comparison_view_model.dart';

/// Adds current, date-aligned observation context to an existing health result.
/// Health scores and Silver statistics are supplied, never recomputed here.
class HealthAnalysisViewModel {
  const HealthAnalysisViewModel({
    required this.assessment,
    required this.assessmentServerConfirmed,
    required this.ownerId,
    required this.analysis,
  });

  final HealthAssessment assessment;
  final bool assessmentServerConfirmed;
  final String? ownerId;
  final CurrentWeightAnalysis? analysis;

  bool get aligned {
    final current = analysis;
    final evaluated = assessment.evaluatedAt;
    final generated = current?.features.generatedAt;
    return assessmentServerConfirmed &&
        ownerId != null &&
        ownerId!.isNotEmpty &&
        current != null &&
        current.ownerId == ownerId &&
        parseWeightAnalysisDateKey(current.evaluationDateKey) != null &&
        assessment.dateKey == current.evaluationDateKey &&
        assessment.featureDateKey == current.evaluationDateKey &&
        current.features.dateKey == current.evaluationDateKey &&
        current.features.schemaVersion == 5 &&
        evaluated != null &&
        generated != null &&
        evaluated.isAtSameMomentAs(generated) &&
        weightAnalysisDateKeyJst(generated) == current.evaluationDateKey;
  }

  int? get bodyHealthScore => assessment.domains.body.score;
  bool get bodyHealthEvaluated => _evaluated(assessment.domains.body);

  // These are later research applicability checks; they do not invalidate an
  // otherwise valid personal baseline or turn research into a health decision.
  static const _researchOnlyOmissions = {
    'unknown_species',
    'age_unknown',
    'invalid_birth_date',
    'not_adult',
    'juvenile_observations',
    'reference_unavailable',
    'reference_mismatch',
  };
  bool get hasBodyAnalysis {
    if (!aligned || !bodyHealthEvaluated) return false;
    final reason = analysis!.omissionReason;
    return reason == null || _researchOnlyOmissions.contains(reason);
  }

  /// A separate current-analysis destination; it never supplies data to the
  /// saved health result or weakens its alignment checks.
  bool get canOpenCurrentWeightAnalysis {
    final current = analysis;
    final evaluated = assessment.evaluatedAt;
    final generated = current?.features.generatedAt;
    if (aligned ||
        !assessmentServerConfirmed ||
        !bodyHealthEvaluated ||
        ownerId == null ||
        ownerId!.isEmpty ||
        current == null ||
        current.ownerId != ownerId ||
        parseWeightAnalysisDateKey(assessment.dateKey) == null ||
        parseWeightAnalysisDateKey(assessment.featureDateKey) == null ||
        evaluated == null ||
        generated == null ||
        generated.isBefore(evaluated) ||
        current.evaluationDateKey.compareTo(assessment.dateKey) < 0) {
      return false;
    }
    final reason = current.omissionReason;
    final personalAnalysisReady =
        reason == null || _researchOnlyOmissions.contains(reason);
    return personalAnalysisReady &&
        (current.evaluationDateKey != assessment.dateKey ||
            !generated.isAtSameMomentAs(evaluated));
  }

  String? get savedHealthEvaluationTime => assessment.evaluatedAt == null
      ? null
      : _dateTimeJst(assessment.evaluatedAt!);

  String? get currentWeightAnalysisTime => canOpenCurrentWeightAnalysis
      ? _dateTimeJst(analysis!.features.generatedAt!)
      : null;

  static String _dateTimeJst(DateTime instant) {
    final jst = instant.toUtc().add(const Duration(hours: 9));
    final hour = jst.hour.toString().padLeft(2, '0');
    final minute = jst.minute.toString().padLeft(2, '0');
    return '${weightAnalysisDateKeyJst(instant)} $hour:$minute JST';
  }

  String? get bodyBaselineValue =>
      hasBodyAnalysis ? formatWeight(analysis!.individualWeightGrams!) : null;
  String? get bodyLatestValue =>
      hasBodyAnalysis ? formatWeight(analysis!.latestWeightGrams!) : null;
  String? get bodyRecordDateKey => hasBodyAnalysis
      ? weightAnalysisDateKeyJst(analysis!.features.body.latestWeightDate!)
      : null;
  String? get bodyObservationPeriod => hasBodyAnalysis
      ? '${analysis!.baseline.firstDateKey}〜${analysis!.baseline.lastDateKey}'
      : null;
  String? get bodyRecentChangeLabel {
    if (!hasBodyAnalysis) return null;
    final difference =
        analysis!.latestWeightGrams! - analysis!.individualWeightGrams!;
    if (difference == 0) return '普段と同じ水準';
    return '普段より${weightDifferenceLabel(difference)}'
        '${difference < 0 ? '軽め' : '重め'}';
  }

  WeightResearchComparisonViewModel? get weightComparison => hasBodyAnalysis
      ? WeightResearchComparisonViewModel.fromCurrent(analysis!)
      : null;
  String get bodyFallback {
    if (!bodyHealthEvaluated) return '体重の健康評価は記録待ちです。';
    if (!aligned) return '評価日と整合する個体別分析を確認できません。健康評価は引き続き表示します。';
    if (analysis!.omissionReason == 'baseline_learning') {
      return '普段の体重を学習中です。健康評価はこれまでの体重記録に基づきます。';
    }
    return '個体別分析に必要な記録を確認できません。健康評価は引き続き表示します。';
  }

  ActivityHealthFeatures? get _activity =>
      aligned ? analysis!.features.activity : null;
  String? get activityTargetDateKey {
    if (!aligned) return null;
    final date = parseWeightAnalysisDateKey(analysis!.evaluationDateKey)!;
    final target = date.subtract(const Duration(days: 1));
    return '${target.year.toString().padLeft(4, '0')}-'
        '${target.month.toString().padLeft(2, '0')}-'
        '${target.day.toString().padLeft(2, '0')}';
  }

  bool get _activityDatesAligned {
    final activity = _activity;
    return activity != null &&
        activity.assessmentDateKey == analysis!.evaluationDateKey &&
        activity.sourceDateKey == activityTargetDateKey &&
        activity.lagDays == 1;
  }

  bool get activityContextAvailable => _activityDatesAligned;

  bool get activityBaselineReady {
    if (!_activityDatesAligned) return false;
    final baseline = _activity!.personalBaseline;
    final first = parseWeightAnalysisDateKey(baseline.firstDateKey);
    final last = parseWeightAnalysisDateKey(baseline.lastDateKey);
    final target = parseWeightAnalysisDateKey(activityTargetDateKey)!;
    return baseline.status == 'ready' &&
        baseline.method == 'median_mad_ewma_v1' &&
        baseline.requiredRecordCount >= 7 &&
        baseline.requiredSpanDays >= 14 &&
        baseline.recordCount >= baseline.requiredRecordCount &&
        baseline.recordCount <= 14 &&
        baseline.spanDays >= baseline.requiredSpanDays &&
        _nonNegative(baseline.median) &&
        _nonNegative(baseline.mad) &&
        _nonNegative(baseline.ewma) &&
        first != null &&
        last != null &&
        !first.isAfter(last) &&
        last.isBefore(target) &&
        first.isAfter(target.subtract(const Duration(days: 90))) &&
        baseline.spanDays == last.difference(first).inDays + 1 &&
        baseline.recordCount <= baseline.spanDays;
  }

  bool get activityHasTargetRecord {
    final activity = _activity;
    return _activityDatesAligned &&
        activity!.hasRecord &&
        _nonNegative(activity.distanceMeters) &&
        activity.recordDate != null &&
        weightAnalysisDateKeyJst(activity.recordDate!) == activityTargetDateKey;
  }

  bool get activityHealthEvaluated =>
      activityHasTargetRecord &&
      activityBaselineReady &&
      _evaluated(assessment.domains.activity);
  String get activityBaselineLabel {
    if (!_activityDatesAligned) return '確認できません';
    if (activityBaselineReady) return '準備完了';
    final baseline = _activity!.personalBaseline;
    if (baseline.status == 'learning' &&
        baseline.recordCount >= 0 &&
        baseline.spanDays >= 0) {
      return '学習中（${baseline.recordCount}/${baseline.requiredRecordCount}件・'
          '${baseline.spanDays}/${baseline.requiredSpanDays}日）';
    }
    return '確認できません';
  }

  String get activityRecordLabel {
    if (!_activityDatesAligned) return '確認できません';
    if (!_activity!.hasRecord) return '記録待ち';
    if (!activityHasTargetRecord) return '確認できません';
    return '記録あり（${formatWeight(_activity!.distanceMeters!)}m）';
  }

  String get activityHealthLabel {
    if (!_activityDatesAligned) return '確認できません';
    if (!_activity!.hasRecord) return '記録待ち';
    if (!activityHasTargetRecord) return '確認できません';
    if (!activityBaselineReady) return '準備中';
    if (!activityHealthEvaluated) return '未評価';
    return '評価済み（${assessment.domains.activity.score} / 100）';
  }

  static bool _evaluated(HealthDomainAssessment domain) =>
      domain.score != null &&
      domain.score! >= 0 &&
      domain.score! <= 100 &&
      domain.state != HealthAssessmentState.unknown &&
      domain.state != HealthAssessmentState.insufficientData;
  static bool _nonNegative(double? value) =>
      value != null && value.isFinite && value >= 0;
}

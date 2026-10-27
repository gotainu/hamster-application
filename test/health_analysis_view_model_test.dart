import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/viewmodels/health_analysis_view_model.dart';

import 'health_analysis_test_support.dart';

void main() {
  test(
      'body analysis adds aligned Silver context without changing health score',
      () {
    final analysis = healthAnalysisFixture(latestWeight: 102);
    final assessment =
        healthAssessmentFixture(analysis: analysis, bodyScore: 70);
    final original = assessment.toMap();
    final vm = healthAnalysisViewModelFixture(
        analysis: analysis, assessment: assessment);
    expect(vm.aligned, isTrue);
    expect(vm.bodyHealthScore, 70);
    expect(vm.bodyBaselineValue, '100');
    expect(vm.bodyLatestValue, '102');
    expect(vm.bodyRecentChangeLabel, '普段より2g重め');
    expect(vm.weightComparison?.summary, '同種の参考中央値より33g軽め');
    expect(assessment.toMap(), original);
  });

  test('same body values retain concise equality wording', () {
    final vm =
        healthAnalysisViewModelFixture(analysis: healthAnalysisFixture());
    expect(vm.bodyRecentChangeLabel, '普段と同じ水準');
  });

  test('a real small difference is never rounded into equality', () {
    final vm = healthAnalysisViewModelFixture(
        analysis: healthAnalysisFixture(latestWeight: 100.01));
    expect(vm.bodyRecentChangeLabel, '普段より0.1g未満重め');
  });

  for (final reason in [
    'no research',
    'unknown species',
    'unknown age',
    'juvenile',
    'future birth'
  ]) {
    test('$reason omits only research, keeping personal baseline', () {
      final analysis = healthAnalysisFixture(
        referenceAvailable: reason != 'no research',
        species: reason == 'unknown species' ? '未知の種類' : 'ゴールデン',
        birthdayDateKey: reason == 'unknown age'
            ? null
            : reason == 'juvenile'
                ? '2026-09-01'
                : reason == 'future birth'
                    ? '2027-01-01'
                    : '2026-01-01',
      );
      final vm = healthAnalysisViewModelFixture(analysis: analysis);
      expect(vm.hasBodyAnalysis, isTrue);
      expect(vm.bodyBaselineValue, '100');
      expect(vm.weightComparison, isNull);
    });
  }

  test('learning body keeps health result but hides numeric baseline', () {
    final vm = healthAnalysisViewModelFixture(
        analysis: healthAnalysisFixture(bodyReady: false));
    expect(vm.bodyHealthScore, 100);
    expect(vm.hasBodyAnalysis, isFalse);
    expect(vm.bodyBaselineValue, isNull);
    expect(vm.bodyFallback, contains('学習中'));
  });

  test('body health waiting never becomes evaluated from ready baseline', () {
    final analysis = healthAnalysisFixture();
    final vm = healthAnalysisViewModelFixture(
        analysis: analysis,
        assessment:
            healthAssessmentFixture(analysis: analysis, bodyScore: null));
    expect(vm.hasBodyAnalysis, isFalse);
    expect(vm.bodyFallback, contains('記録待ち'));
  });

  for (final mismatch in [
    'date',
    'feature date',
    'generation time',
    'owner',
    'missing owner',
    'cached assessment',
    'missing Silver'
  ]) {
    test('$mismatch safely omits aligned analysis without changing health', () {
      final current = healthAnalysisFixture();
      final assessment = healthAssessmentFixture(
          analysis: current,
          dateKey: mismatch == 'date' ? '2026-10-10' : null,
          featureDateKey: mismatch == 'feature date' ? '2026-10-10' : null,
          evaluatedAt: mismatch == 'generation time'
              ? current.features.generatedAt!
                  .add(const Duration(microseconds: 1))
              : null);
      final vm = HealthAnalysisViewModel(
          assessment: assessment,
          assessmentServerConfirmed: mismatch != 'cached assessment',
          ownerId: mismatch == 'owner'
              ? 'another-owner'
              : mismatch == 'missing owner'
                  ? null
                  : current.ownerId,
          analysis: mismatch == 'missing Silver' ? null : current);
      expect(vm.aligned, isFalse);
      expect(vm.hasBodyAnalysis, isFalse);
      expect(vm.bodyHealthScore, 100);
      expect(vm.activityBaselineLabel, '確認できません');
      expect(vm.activityHealthLabel, '確認できません');
    });
  }

  test('separate current analysis keeps the saved health date and score', () {
    final old = healthAnalysisFixture(evaluationDateKey: '2026-10-10');
    final current = healthAnalysisFixture();
    final assessment = healthAssessmentFixture(analysis: old, bodyScore: 87);
    final before = assessment.toMap();
    final vm = healthAnalysisViewModelFixture(
        analysis: current, assessment: assessment);
    expect(vm.aligned, isFalse);
    expect(vm.hasBodyAnalysis, isFalse);
    expect(vm.bodyBaselineValue, isNull);
    expect(vm.weightComparison, isNull);
    expect(vm.canOpenCurrentWeightAnalysis, isTrue);
    expect(vm.savedHealthEvaluationTime, '2026-10-10 11:00 JST');
    expect(vm.currentWeightAnalysisTime, '2026-10-11 11:00 JST');
    expect(vm.bodyHealthScore, 87);
    expect(assessment.toMap(), before);
  });

  test('later same-day Silver offers a separate route, never aligned values',
      () {
    final current = healthAnalysisFixture();
    final assessment = healthAssessmentFixture(
        analysis: current,
        evaluatedAt:
            current.features.generatedAt!.subtract(const Duration(minutes: 1)));
    final vm = healthAnalysisViewModelFixture(
        analysis: current, assessment: assessment);
    expect(vm.aligned, isFalse);
    expect(vm.hasBodyAnalysis, isFalse);
    expect(vm.canOpenCurrentWeightAnalysis, isTrue);
    expect(vm.savedHealthEvaluationTime, '2026-10-11 10:59 JST');
    expect(vm.currentWeightAnalysisTime, '2026-10-11 11:00 JST');
  });

  test('aligned health uses its existing analysis without a separate CTA', () {
    final vm =
        healthAnalysisViewModelFixture(analysis: healthAnalysisFixture());
    expect(vm.aligned, isTrue);
    expect(vm.canOpenCurrentWeightAnalysis, isFalse);
    expect(vm.currentWeightAnalysisTime, isNull);
  });

  for (final invalid in [
    'cached health',
    'missing Silver',
    'different owner',
    'missing owner',
    'older Silver',
    'learning baseline',
    'invalid Silver date',
    'invalid health date',
    'unaligned feature only',
  ]) {
    test('separate latest route is unavailable for $invalid', () {
      var current =
          healthAnalysisFixture(bodyReady: invalid != 'learning baseline');
      final old = healthAnalysisFixture(evaluationDateKey: '2026-10-10');
      var assessment = healthAssessmentFixture(analysis: old);
      if (invalid == 'older Silver') {
        assessment = healthAssessmentFixture(
            analysis: current,
            evaluatedAt:
                current.features.generatedAt!.add(const Duration(minutes: 1)));
      } else if (invalid == 'invalid Silver date') {
        final map = current.features.toMap();
        map['dateKey'] = '2026-10-09';
        current = healthAnalysisWithFeatures(current, map);
      } else if (invalid == 'invalid health date') {
        assessment =
            healthAssessmentFixture(analysis: old, dateKey: 'not-a-date');
      } else if (invalid == 'unaligned feature only') {
        assessment = healthAssessmentFixture(
            analysis: current, featureDateKey: '2026-10-10');
      }
      final vm = HealthAnalysisViewModel(
          assessment: assessment,
          assessmentServerConfirmed: invalid != 'cached health',
          ownerId: invalid == 'different owner'
              ? 'another-owner'
              : invalid == 'missing owner'
                  ? null
                  : 'synthetic-owner',
          analysis: invalid == 'missing Silver' ? null : current);
      expect(vm.hasBodyAnalysis, isFalse);
      expect(vm.canOpenCurrentWeightAnalysis, isFalse);
      expect(vm.currentWeightAnalysisTime, isNull);
      expect(vm.bodyHealthScore, 100);
    });
  }

  test('ready activity without target-day record remains waiting', () {
    final current = healthAnalysisFixture(hasActivityRecord: false);
    final vm = healthAnalysisViewModelFixture(
        analysis: current,
        assessment:
            healthAssessmentFixture(analysis: current, activityScore: null));
    expect(vm.activityTargetDateKey, '2026-10-10');
    expect(vm.activityBaselineLabel, '準備完了');
    expect(vm.activityRecordLabel, '記録待ち');
    expect(vm.activityHealthLabel, '記録待ち');
    expect(vm.activityHealthEvaluated, isFalse);
  });

  test(
      'activity learning and a target record are distinct from health readiness',
      () {
    final current = healthAnalysisFixture(activityReady: false);
    final vm = healthAnalysisViewModelFixture(
        analysis: current,
        assessment:
            healthAssessmentFixture(analysis: current, activityScore: null));
    expect(vm.activityBaselineLabel, '学習中（5/7件・14/14日）');
    expect(vm.activityRecordLabel, '記録あり（628.3m）');
    expect(vm.activityHealthLabel, '準備中');
  });

  test('recorded zero is valid and is not a missing record', () {
    final vm = healthAnalysisViewModelFixture(
        analysis: healthAnalysisFixture(activityDistance: 0));
    expect(vm.activityRecordLabel, '記録あり（0m）');
    expect(vm.activityHealthLabel, '評価済み（100 / 100）');
  });

  test('existing null health score stays unevaluated despite ready data', () {
    final current = healthAnalysisFixture();
    final vm = healthAnalysisViewModelFixture(
        analysis: current,
        assessment:
            healthAssessmentFixture(analysis: current, activityScore: null));
    expect(vm.activityHealthLabel, '未評価');
    expect(vm.activityHealthEvaluated, isFalse);
  });

  for (final mismatch in [
    'assessment date',
    'source date',
    'lag',
    'record date',
    'negative',
    'non-finite'
  ]) {
    test('invalid activity $mismatch is not shown as usable target data', () {
      final current = healthAnalysisFixture();
      final features = current.features.toMap();
      final activity = features['activity'] as Map<String, dynamic>;
      switch (mismatch) {
        case 'assessment date':
          activity['assessmentDateKey'] = '2026-10-10';
        case 'source date':
          activity['sourceDateKey'] = '2026-10-09';
        case 'lag':
          activity['lagDays'] = 0;
        case 'record date':
          activity['recordDate'] = DateTime.utc(2026, 10, 9);
        case 'negative':
          activity['distanceMeters'] = -1;
        case 'non-finite':
          activity['distanceMeters'] = double.nan;
      }
      final changed = healthAnalysisWithFeatures(current, features);
      final vm = healthAnalysisViewModelFixture(analysis: changed);
      expect(vm.activityHasTargetRecord, isFalse);
      expect(vm.activityRecordLabel, '確認できません');
      expect(vm.activityHealthLabel, '確認できません');
    });
  }

  for (final invalid in [
    'quality',
    'stale',
    'baseline dates',
    'non-finite weight'
  ]) {
    test('invalid body $invalid hides personal context but preserves the score',
        () {
      final current = healthAnalysisFixture();
      final features = current.features.toMap();
      final body = features['body'] as Map<String, dynamic>;
      final baseline = body['personalBaseline'] as Map<String, dynamic>;
      switch (invalid) {
        case 'quality':
          (features['dataQuality'] as Map<String, dynamic>)['missingDomains'] =
              ['body'];
        case 'stale':
          body['latestWeightDate'] = DateTime.utc(2026, 9, 27);
          body['daysSinceMeasurement'] = 14;
        case 'baseline dates':
          baseline['lastDateKey'] = '2026-10-12';
        case 'non-finite weight':
          body['latestWeightGrams'] = double.infinity;
      }
      final changed = healthAnalysisWithFeatures(current, features);
      final vm = healthAnalysisViewModelFixture(analysis: changed);
      expect(vm.bodyHealthScore, 100);
      expect(vm.hasBodyAnalysis, isFalse);
      expect(vm.weightComparison, isNull);
    });
  }

  test('invalid activity baseline dates cannot be reported as ready', () {
    final current = healthAnalysisFixture();
    final features = current.features.toMap();
    final activity = features['activity'] as Map<String, dynamic>;
    final baseline = activity['personalBaseline'] as Map<String, dynamic>;
    baseline['lastDateKey'] = '2026-10-10';
    final vm = healthAnalysisViewModelFixture(
        analysis: healthAnalysisWithFeatures(current, features));
    expect(vm.activityBaselineLabel, '確認できません');
    expect(vm.activityRecordLabel, '記録あり（628.3m）');
    expect(vm.activityHealthEvaluated, isFalse);
  });
}

import 'package:hamster_project/models/current_weight_analysis.dart';
import 'package:hamster_project/models/daily_health_features.dart';
import 'package:hamster_project/models/health_assessment.dart';
import 'package:hamster_project/viewmodels/health_analysis_view_model.dart';

import 'current_weight_analysis_test_support.dart';

CurrentWeightAnalysis healthAnalysisFixture({
  bool bodyReady = true,
  bool referenceAvailable = true,
  String? species = 'ゴールデン',
  String? birthdayDateKey = '2026-01-01',
  bool activityReady = true,
  bool hasActivityRecord = true,
  double activityDistance = 628.32,
  double weight = 100,
  double latestWeight = 100,
  String ownerId = 'synthetic-owner',
  String evaluationDateKey = '2026-10-11',
}) {
  final features = currentWeightFeaturesFixture(
      ready: bodyReady,
      median: weight,
      latest: latestWeight,
      evaluationDateKey: evaluationDateKey);
  final body = features['body'] as Map<String, dynamic>;
  final base = Map<String, dynamic>.from(
      body['personalBaseline'] as Map<String, dynamic>);
  final evaluation = DateTime.parse('${evaluationDateKey}T00:00:00Z');
  features['activity'] = {
    'assessmentDateKey': evaluationDateKey,
    'sourceDateKey':
        fixtureDateKey(evaluation.subtract(const Duration(days: 1))),
    'lagDays': 1,
    'hasRecord': hasActivityRecord,
    'distanceMeters': hasActivityRecord ? activityDistance : null,
    'recordDate':
        hasActivityRecord ? evaluation.subtract(const Duration(days: 1)) : null,
    'personalBaseline': {
      ...base,
      'status': activityReady ? 'ready' : 'learning',
      'recordCount': activityReady ? 8 : 5,
      'median': 628.32,
      'ewma': 628.32,
    },
  };
  return currentWeightAnalysisFixture(
      ready: bodyReady,
      referenceAvailable: referenceAvailable,
      species: species,
      birthdayDateKey: birthdayDateKey,
      ownerId: ownerId,
      evaluationDateKey: evaluationDateKey,
      features: features);
}

HealthAssessment healthAssessmentFixture({
  CurrentWeightAnalysis? analysis,
  int? bodyScore = 100,
  int? activityScore = 100,
  String? dateKey,
  String? featureDateKey,
  DateTime? evaluatedAt,
}) {
  final current = analysis ?? healthAnalysisFixture();
  return HealthAssessment.fromMap({
    'dateKey': dateKey ?? current.evaluationDateKey,
    'featureDateKey': featureDateKey ?? current.evaluationDateKey,
    'evaluatedAt': evaluatedAt ?? current.features.generatedAt,
    'domains': {
      'body': {
        'state': bodyScore == null ? 'insufficientData' : 'good',
        'score': bodyScore,
        'summary': bodyScore == null ? '体重記録を確認してください。' : '体重は安定しています。',
        'flags': bodyScore == null ? ['weightMissing'] : [],
      },
      'activity': {
        'state': activityScore == null ? 'insufficientData' : 'good',
        'score': activityScore,
        'summary':
            activityScore == null ? '前日分の走行距離が記録されていません。' : '活動量は安定しています。',
        'flags': activityScore == null ? ['activityMissing'] : [],
      },
      'environment': {'state': 'good', 'score': 100, 'summary': '環境は安定しています。'},
      'condition': {'state': 'good', 'score': 100, 'summary': '変化はありません。'},
    },
    'overall': {
      'state': 'good',
      'observedState': 'good',
      'score': 100,
      'summary': '全体として安定しています。',
      'confidence': 'high',
      'scoreCoverage': 1,
    },
    'dataQuality': {'scoreCoverage': 1},
  }, fallbackDateKey: current.evaluationDateKey);
}

CurrentWeightAnalysis healthAnalysisWithFeatures(
        CurrentWeightAnalysis analysis, Map<String, dynamic> features) =>
    CurrentWeightAnalysis(
      ownerId: analysis.ownerId,
      evaluationDateKey: analysis.evaluationDateKey,
      features: DailyHealthFeatures.fromMap(features,
          fallbackDateKey: analysis.evaluationDateKey),
      profile: analysis.profile,
      reference: analysis.reference,
    );

HealthAnalysisViewModel healthAnalysisViewModelFixture({
  CurrentWeightAnalysis? analysis,
  bool confirmed = true,
  String? ownerId = 'synthetic-owner',
  HealthAssessment? assessment,
}) =>
    HealthAnalysisViewModel(
      assessment: assessment ?? healthAssessmentFixture(analysis: analysis),
      assessmentServerConfirmed: confirmed,
      ownerId: ownerId,
      analysis: analysis,
    );

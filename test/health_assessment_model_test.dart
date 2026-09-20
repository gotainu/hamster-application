import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/health_assessment.dart';

void main() {
  test('v6 health assessment reads score coverage, range, and factors', () {
    final assessment = HealthAssessment.fromMap(
      {
        'dateKey': '2026-09-14',
        'overall': {
          'state': 'caution',
          'score': null,
          'observedState': 'caution',
          'observedScore': null,
          'scoreRange': {'minimum': 52, 'maximum': 77},
          'scoreCoverage': 0.75,
          'confidence': 'medium',
          'isProvisional': true,
          'primaryFactor': '環境: 湿度が高めです。',
          'primaryFactors': [
            '環境: 湿度が高めです。',
            '活動量: 普段より少なめです。',
          ],
        },
        'dataQuality': {
          'completeness': 1,
          'scoreCoverage': 0.75,
          'scoredDomains': ['environment', 'activity', 'condition'],
          'unscoredDomains': ['body'],
        },
        'evaluatorVersion': 5,
      },
      fallbackDateKey: 'fallback',
    );

    expect(assessment.overall.score, isNull);
    expect(assessment.overall.scoreRange?.minimum, 52);
    expect(assessment.overall.scoreRange?.maximum, 77);
    expect(assessment.overall.scoreCoverage, 0.75);
    expect(assessment.overall.primaryFactors, hasLength(2));
    expect(assessment.dataQuality.unscoredDomains, ['body']);
    expect(assessment.evaluatorVersion, 5);
  });

  test('legacy assessment keeps primary factor and completeness fallback', () {
    final assessment = HealthAssessment.fromMap(
      {
        'overall': {
          'state': 'stable',
          'score': 92,
          'confidence': 'high',
          'primaryFactor': '環境: 安定しています。',
        },
        'dataQuality': {
          'completeness': 0.5,
        },
      },
      fallbackDateKey: '2026-09-13',
    );

    expect(assessment.overall.primaryFactors, [
      '環境: 安定しています。',
    ]);
    expect(assessment.dataQuality.scoreCoverage, 0.5);
  });
}

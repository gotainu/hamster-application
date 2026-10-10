import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/personality_report.dart';

import 'personality_report_fixtures.dart';

void main() {
  test('decodes weight-only immutable snapshot and stable metadata', () {
    final report = PersonalityReport.fromMap(personalityFixture());
    expect(report.reportId, 'personality_v1_body');
    expect(report.petId, 'main_pet');
    expect(report.schemaVersion, 1);
    expect(report.type, PersonalityReportType.weightOnly);
    expect(report.generatedAt, DateTime.utc(2026, 10, 8, 3));
    expect(report.body!.median, 100);
    expect(report.body!.mad, 0);
    expect(report.activity, isNull);
  });
  test('decodes activity-only and both reports', () {
    final activity =
        PersonalityReport.fromMap(personalityFixture(type: 'activity_only'));
    expect(activity.body, isNull);
    expect(activity.activity!.unit, 'm');
    final both = PersonalityReport.fromMap(personalityFixture(type: 'both'));
    expect(both.type, PersonalityReportType.both);
    expect(both.body, isNotNull);
    expect(both.activity, isNotNull);
  });
  test('allows Firestore and stable string timestamps', () {
    final data = personalityFixture();
    data['generatedAt'] = '2026-10-08T03:00:00.000Z';
    expect(PersonalityReport.fromMap(data).generatedAt,
        DateTime.utc(2026, 10, 8, 3));
    data['generatedAt'] = Timestamp.fromMillisecondsSinceEpoch(0);
    expect(
        PersonalityReport.fromMap(data).generatedAt.millisecondsSinceEpoch, 0);
  });
  test('rejects unsupported schema, type and conflicting report identity', () {
    for (final entry in {
      'schemaVersion': 2,
      'reportType': 'unknown',
      'petId': 'other_pet'
    }.entries) {
      final data = personalityFixture()..[entry.key] = entry.value;
      expect(() => PersonalityReport.fromMap(data), throwsFormatException);
    }
    expect(
        () => PersonalityReport.fromMap(personalityFixture(),
            expectedReportId: 'different'),
        throwsFormatException);
  });
  test('rejects inconsistent ready metrics and incomplete ready snapshot', () {
    final data = personalityFixture();
    data['readyMetrics'] = ['body', 'activity'];
    expect(() => PersonalityReport.fromMap(data), throwsFormatException);
    final absent = personalityFixture();
    (absent['metrics'] as Map).remove('body');
    expect(() => PersonalityReport.fromMap(absent), throwsFormatException);
  });
  test('ignores undeclared metric and never invents missing activity', () {
    final data = personalityFixture();
    (data['metrics'] as Map)['activity'] = {
      'unit': 'm',
      'baseline': {'status': 'learning'}
    };
    expect(PersonalityReport.fromMap(data).activity, isNull);
  });
  test('rejects wrong unit and nonfinite measurement', () {
    final data = personalityFixture();
    (data['metrics']['body'] as Map)['unit'] = 'kg';
    expect(() => PersonalityReport.fromMap(data), throwsFormatException);
    final invalid = personalityFixture();
    (invalid['metrics']['body']['baseline'] as Map)['median'] = double.nan;
    expect(() => PersonalityReport.fromMap(invalid), throwsFormatException);
  });
  test('keeps research provenance and unknown weight sample size distinct', () {
    final report = PersonalityReport.fromMap(
        personalityFixture(population: applicablePopulation(small: true)));
    final context = report.body!.population!;
    expect(context.isApplicable, isTrue);
    expect(context.sampleSizeCaution, isTrue);
    expect(context.sourceDoi, '10.1111/jsap.13527');
    expect(context.weightSampleSize, isNull);
    expect(context.speciesPopulationSize, 52);
  });
  test('daily IDs preserve schema 1 and existing milestone compatibility', () {
    final data = personalityFixture(reportId: 'daily_2026-10-09')
      ..['evaluationDateKey'] = '2026-10-09'
      ..['silverDateKey'] = '2026-10-09'
      ..['reportKind'] = 'daily'
      ..['cutoffDateKey'] = '2026-10-08';
    final report =
        PersonalityReport.fromMap(data, expectedReportId: 'daily_2026-10-09');
    expect(report.reportId, 'daily_2026-10-09');
    expect(report.isDaily, isTrue);
    expect(report.schemaVersion, 1);
    expect(report.analysisSpecVersion, 'personality_v1');
    expect(PersonalityReport.fromMap(personalityFixture()).isDaily, isFalse);
  });
  test('daily identity rejects unsafe, impossible and conflicting dates', () {
    for (final id in [
      '../daily_2026-10-09',
      'daily_2026-02-30',
      'daily_2026-13-01',
      'daily_2026-1-1',
      'daily_0000-01-01'
    ]) {
      expect(isPersonalityReportId(id), isFalse);
      expect(() => PersonalityReport.fromMap(personalityFixture(reportId: id)),
          throwsFormatException);
    }
    expect(isPersonalityReportId('daily_2028-02-29'), isTrue);
    expect(
        () => PersonalityReport.fromMap(
            personalityFixture(reportId: 'daily_2026-10-09')),
        throwsFormatException);
  });
}

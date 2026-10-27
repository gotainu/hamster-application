import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/current_weight_analysis.dart';
import 'package:hamster_project/models/reference_weight_cohort.dart';

import 'current_weight_analysis_test_support.dart';

void main() {
  group('current Silver research eligibility', () {
    test('ready Silver is reused verbatim, including zero MAD', () {
      final current = currentWeightAnalysisFixture(median: 100, latest: 102);
      expect(current.canCompare, isTrue);
      expect(current.individualWeightGrams, 100);
      expect(current.latestWeightGrams, 102);
      expect(current.baseline.mad, 0);
      expect(current.reference!.median, 133);
      expect(current.profile.speciesCode, 'syrian');
    });
    test('missing reference does not reuse an immutable report', () {
      final current = currentWeightAnalysisFixture(referenceAvailable: false);
      expect(current.canCompare, isFalse);
      expect(current.omissionReason, 'reference_unavailable');
    });
    test('unknown and missing species stay unknown', () {
      for (final species in [null, '', 'ハイブリッド', '不明']) {
        final current = currentWeightAnalysisFixture(species: species);
        expect(current.canCompare, isFalse);
        expect(current.omissionReason, 'unknown_species');
      }
      expect(CurrentWeightProfile.fromMap({}).speciesCode, isNull);
      expect(
          CurrentWeightProfile.fromMap({'birthday': '2026-02-30'})
              .birthdayDateKey,
          isNull);
      expect(
          CurrentWeightProfile.fromMap({'birthday': '2026-02-30T00:00:00Z'})
              .birthdayDateKey,
          isNull);
    });
    test('learning omits even with available study', () {
      final current = currentWeightAnalysisFixture(ready: false);
      expect(current.canCompare, isFalse);
      expect(current.omissionReason, 'baseline_learning');
    });
    test('future, missing or juvenile birthdays omit research', () {
      final reasons = {
        null: 'age_unknown',
        '2026-10-12': 'invalid_birth_date',
        '2026-08-01': 'not_adult',
        '2026-07-01': 'juvenile_observations',
      };
      for (final entry in reasons.entries) {
        expect(
            currentWeightAnalysisFixture(birthdayDateKey: entry.key)
                .omissionReason,
            entry.value);
      }
    });
    test(
        'adult boundary is strictly after three calendar months, month-end clamped',
        () {
      final features =
          currentWeightFeaturesFixture(evaluationDateKey: '2026-06-20');
      final baseline =
          features['body']['personalBaseline'] as Map<String, dynamic>;
      baseline['firstDateKey'] = '2026-05-31';
      baseline['lastDateKey'] = '2026-06-13';
      expect(
          currentWeightAnalysisFixture(
                  evaluationDateKey: '2026-06-20',
                  birthdayDateKey: '2026-02-28',
                  features: features)
              .canCompare,
          isTrue);
      // August 31 + three months clamps to November 30; that day is not adult.
      final boundary =
          currentWeightFeaturesFixture(evaluationDateKey: '2026-12-20');
      boundary['body']['personalBaseline']['firstDateKey'] = '2026-11-30';
      boundary['body']['personalBaseline']['lastDateKey'] = '2026-12-13';
      expect(
          currentWeightAnalysisFixture(
                  evaluationDateKey: '2026-12-20',
                  birthdayDateKey: '2026-08-31',
                  features: boundary)
              .omissionReason,
          'juvenile_observations');
    });
    test('outside reference IQR remains eligible, not classified as disease',
        () {
      for (final median in [50.0, 100.0, 160.0, 220.0]) {
        expect(currentWeightAnalysisFixture(median: median).canCompare, isTrue);
      }
    });
    test('older/future Silver and unsupported schema are not current', () {
      for (final date in ['2026-10-10', '2026-10-12']) {
        final features = currentWeightFeaturesFixture(evaluationDateKey: date);
        expect(currentWeightAnalysisFixture(features: features).omissionReason,
            'current_silver_unavailable');
      }
      final features = currentWeightFeaturesFixture()..['schemaVersion'] = 4;
      expect(
          currentWeightAnalysisFixture(features: features).canCompare, isFalse);
    });
    test('measurement freshness and quality are enforced independently', () {
      for (final key in ['missingDomains', 'staleDomains']) {
        final features = currentWeightFeaturesFixture();
        features['dataQuality'][key] = ['body'];
        expect(currentWeightAnalysisFixture(features: features).omissionReason,
            'body_data_unavailable');
      }
      final features = currentWeightFeaturesFixture();
      features['body']['latestWeightDate'] = DateTime.utc(2026, 9, 27);
      features['body']['daysSinceMeasurement'] = 14;
      expect(currentWeightAnalysisFixture(features: features).omissionReason,
          'stale_body_measurement');
    });
    test('invalid numeric/dates cannot reach visual comparison', () {
      final invalidValues = [double.nan, double.infinity, -1.0, 0.0, 1001.0];
      for (final value in invalidValues) {
        expect(currentWeightAnalysisFixture(median: value).canCompare, isFalse);
      }
      final features = currentWeightFeaturesFixture();
      features['body']['personalBaseline']['lastDateKey'] = '2026-10-20';
      expect(currentWeightAnalysisFixture(features: features).omissionReason,
          'invalid_observation_dates');
      expect(parseWeightAnalysisDateKey('2026-02-30'), isNull);
    });
    test('JST date differs from UTC at midnight and no profile fields copied',
        () {
      expect(weightAnalysisDateKeyJst(DateTime.utc(2026, 10, 10, 15)),
          '2026-10-11');
      final profile = CurrentWeightProfile.fromMap({
        'species': 'キンクマ',
        'birthday': Timestamp.fromDate(DateTime.utc(2026, 1, 1, 15)),
        'name': 'must-not-copy',
        'memo': 'must-not-copy',
      });
      expect(profile.birthdayDateKey, '2026-01-02');
      expect(profile.speciesCode, 'syrian');
    });
  });
  group('versioned reference data', () {
    test('matches exact species/version and preserves source limitations', () {
      final cohort = ReferenceWeightCohort.fromMap(
          currentWeightReferenceFixture(),
          expectedSpecies: 'syrian',
          expectedVersion: 'vetcompass_uk_2016_adult_weight_v1');
      expect(cohort.p25, 100);
      expect(cohort.p75, 160);
      expect(cohort.weightSampleN, isNull);
      expect(cohort.speciesPopulationN, 12197);
      expect(cohort.sourceDoi, '10.1111/jsap.13527');
      expect(cohort.limitations, isNotEmpty);
    });
    test('malformed, changed definition or misleading quality rejects', () {
      final changes = <Map<String, dynamic>>[
        {'median': double.nan},
        {'p25': 170},
        {'unit': 'kg'},
        {'sourceDOI': 'wrong'},
        {'weightSampleN': 12197},
        {'adultDefinition': 'at_least_3_months'},
        {'measurementDefinition': 'latest_body_weight'},
        {'referenceVersion': 'other'},
        {'speciesCode': 'djungarian'},
      ];
      for (final patch in changes) {
        expect(
            () => ReferenceWeightCohort.fromMap(
                currentWeightReferenceFixture()..addAll(patch),
                expectedSpecies: 'syrian',
                expectedVersion: 'vetcompass_uk_2016_adult_weight_v1'),
            throwsFormatException);
      }
      final data = currentWeightReferenceFixture();
      data['dataQuality']['healthyReferenceRange'] = true;
      expect(
          () => ReferenceWeightCohort.fromMap(data, expectedSpecies: 'syrian'),
          throwsFormatException);
    });
    test('Campbell must retain small population caution', () {
      final data = currentWeightReferenceFixture(species: 'campbell');
      expect(
          ReferenceWeightCohort.fromMap(data, expectedSpecies: 'campbell')
              .sampleSizeCaution,
          isTrue);
      data['sampleSizeCaution'] = false;
      expect(
          () =>
              ReferenceWeightCohort.fromMap(data, expectedSpecies: 'campbell'),
          throwsFormatException);
    });
    test(
        'known Japanese/ASCII aliases normalize, Chinese not invented as Syrian',
        () {
      expect(normalizeWeightReferenceSpecies('ＧＯＬＤＥＮ　ＨＡＭＳＴＥＲ'), 'syrian');
      expect(normalizeWeightReferenceSpecies('ジャンガリアンハムスター'), 'djungarian');
      expect(normalizeWeightReferenceSpecies('チャイニーズ'), 'chinese');
      expect(normalizeWeightReferenceSpecies('その他'), isNull);
    });
  });
}

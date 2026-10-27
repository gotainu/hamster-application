import 'package:cloud_firestore/cloud_firestore.dart';

import 'daily_health_features.dart';
import 'reference_weight_cohort.dart';
import 'weight_insight.dart';

class CurrentWeightProfile {
  final String? rawSpecies;
  final String? birthdayDateKey;
  const CurrentWeightProfile(
      {required this.rawSpecies, required this.birthdayDateKey});
  String? get speciesCode => normalizeWeightReferenceSpecies(rawSpecies);

  factory CurrentWeightProfile.fromMap(Map<String, dynamic> data) {
    final birthday = data['birthday'];
    String? key;
    if (birthday is Timestamp) {
      key = weightAnalysisDateKeyJst(birthday.toDate());
    } else if (birthday is DateTime) {
      key = weightAnalysisDateKeyJst(birthday);
    } else if (birthday is String) {
      if (parseWeightAnalysisDateKey(birthday) != null) {
        key = birthday;
      } else if (birthday.length > 10 &&
          parseWeightAnalysisDateKey(birthday.substring(0, 10)) != null) {
        final instant = DateTime.tryParse(birthday);
        if (instant != null) key = weightAnalysisDateKeyJst(instant);
      }
    }
    return CurrentWeightProfile(
      rawSpecies: data['species'] is String ? data['species'] as String : null,
      birthdayDateKey: key,
    );
  }
}

/// A current, server-confirmed analysis, not a saved personality-report snapshot.
/// Existing Silver statistics are read verbatim; no baselines are recalculated.
class CurrentWeightAnalysis {
  final String ownerId;
  final String evaluationDateKey;
  final DailyHealthFeatures features;
  final CurrentWeightProfile profile;
  final ReferenceWeightCohort? reference;
  final CurrentInsightSet? insights;
  const CurrentWeightAnalysis({
    required this.ownerId,
    required this.evaluationDateKey,
    required this.features,
    required this.profile,
    required this.reference,
    this.insights,
  });

  HealthPersonalBaseline get baseline => features.body.personalBaseline;
  double? get individualWeightGrams => baseline.median;
  double? get latestWeightGrams => features.body.latestWeightGrams;
  bool get canCompare => omissionReason == null;

  /// These are presentation eligibility checks, never a health/score decision.
  String? get omissionReason {
    final evaluation = parseWeightAnalysisDateKey(evaluationDateKey);
    if (ownerId.isEmpty || evaluation == null) return 'invalid_evaluation';
    if (features.schemaVersion != 5 ||
        features.dateKey != evaluationDateKey ||
        features.generatedAt == null ||
        weightAnalysisDateKeyJst(features.generatedAt!) != evaluationDateKey) {
      return 'current_silver_unavailable';
    }
    final quality = features.dataQuality;
    if (!quality.availableDomains.contains('body') ||
        quality.missingDomains.contains('body') ||
        quality.staleDomains.contains('body')) {
      return 'body_data_unavailable';
    }
    final body = features.body;
    final lastMeasurement = body.latestWeightDate == null
        ? null
        : parseWeightAnalysisDateKey(
            weightAnalysisDateKeyJst(body.latestWeightDate!));
    if (lastMeasurement == null ||
        lastMeasurement.isAfter(evaluation) ||
        !_positive(body.latestWeightGrams) ||
        body.latestWeightGrams! > 1000 ||
        body.daysSinceMeasurement == null ||
        body.daysSinceMeasurement! < 0 ||
        body.daysSinceMeasurement !=
            evaluation.difference(lastMeasurement).inDays) {
      return 'invalid_body_measurement';
    }
    if (body.daysSinceMeasurement! >= 14) return 'stale_body_measurement';
    if (baseline.status != 'ready' ||
        baseline.recordCount < 7 ||
        baseline.recordCount < baseline.requiredRecordCount ||
        baseline.spanDays < 14 ||
        baseline.spanDays < baseline.requiredSpanDays) {
      return 'baseline_learning';
    }
    if (baseline.method != 'median_mad_ewma_v1' ||
        baseline.requiredRecordCount < 7 ||
        baseline.requiredSpanDays < 14 ||
        baseline.recordCount > 14 ||
        !_positive(baseline.median) ||
        baseline.median! > 1000 ||
        !_nonNegative(baseline.mad) ||
        !_positive(baseline.ewma) ||
        baseline.ewma! > 1000 ||
        !baseline.ewmaAlpha.isFinite ||
        baseline.ewmaAlpha <= 0 ||
        baseline.ewmaAlpha > 1 ||
        (baseline.deviationPct != null && !baseline.deviationPct!.isFinite) ||
        (baseline.robustZScore != null && !baseline.robustZScore!.isFinite)) {
      return 'invalid_baseline';
    }
    final first = parseWeightAnalysisDateKey(baseline.firstDateKey);
    final last = parseWeightAnalysisDateKey(baseline.lastDateKey);
    if (first == null ||
        last == null ||
        first.isAfter(last) ||
        !last.isBefore(lastMeasurement) ||
        baseline.spanDays != last.difference(first).inDays + 1 ||
        baseline.recordCount > baseline.spanDays ||
        first.isBefore(lastMeasurement.subtract(const Duration(days: 89)))) {
      return 'invalid_observation_dates';
    }
    if (profile.speciesCode == null) return 'unknown_species';
    final birth = parseWeightAnalysisDateKey(profile.birthdayDateKey);
    if (birth == null) return 'age_unknown';
    if (birth.isAfter(evaluation)) return 'invalid_birth_date';
    final boundary = _threeMonthBoundary(birth);
    if (!evaluation.isAfter(boundary)) return 'not_adult';
    if (first.isBefore(birth)) return 'invalid_observation_dates';
    if (!first.isAfter(boundary)) return 'juvenile_observations';
    final cohort = reference;
    if (cohort == null) return 'reference_unavailable';
    if (cohort.speciesCode != profile.speciesCode) return 'reference_mismatch';
    return null;
  }
}

/// Server evaluation days are JST regardless of the phone's current time zone.
String weightAnalysisDateKeyJst(DateTime instant) {
  final value = instant.toUtc().add(const Duration(hours: 9));
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

DateTime? parseWeightAnalysisDateKey(String? key) {
  if (key == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) return null;
  final parts = key.split('-').map(int.parse).toList();
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  return parts[0] > 0 &&
          date.year == parts[0] &&
          date.month == parts[1] &&
          date.day == parts[2]
      ? date
      : null;
}

DateTime _threeMonthBoundary(DateTime birth) {
  final targetMonth = birth.month + 3;
  final lastDay = DateTime.utc(birth.year, targetMonth + 1, 0).day;
  return DateTime.utc(
      birth.year, targetMonth, birth.day < lastDay ? birth.day : lastDay);
}

bool _positive(double? value) => value != null && value.isFinite && value > 0;
bool _nonNegative(double? value) =>
    value != null && value.isFinite && value >= 0;

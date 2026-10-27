import 'package:cloud_firestore/cloud_firestore.dart';

import 'daily_health_features.dart';
import 'checkin_insight.dart';

const weightInsightSpecVersion = 'weight_insights_v1';

enum WeightInsightKind { observedRange, periodDifference }

class WeightInsightRecord {
  final String dateKey;
  final double value;
  const WeightInsightRecord(this.dateKey, this.value);
}

sealed class WeightInsightEvidence {
  const WeightInsightEvidence();
}

class WeightRangeEvidence extends WeightInsightEvidence {
  final double minimumGrams;
  final double maximumGrams;
  final bool allEqual;
  const WeightRangeEvidence(
      this.minimumGrams, this.maximumGrams, this.allEqual);
}

class WeightPeriodEvidence extends WeightInsightEvidence {
  final double startWeightGrams;
  final double endWeightGrams;
  final double differenceGrams;
  final double absoluteDifferenceGrams;
  final String startDateKey;
  final String endDateKey;
  final int windowDays;
  const WeightPeriodEvidence({
    required this.startWeightGrams,
    required this.endWeightGrams,
    required this.differenceGrams,
    required this.absoluteDifferenceGrams,
    required this.startDateKey,
    required this.endDateKey,
    required this.windowDays,
  });
}

class WeightInsightQuality {
  final String baselineStatus;
  final String latestDateKey;
  final int daysSinceMeasurement;
  final bool missingDaysNotImputed;
  const WeightInsightQuality(this.baselineStatus, this.latestDateKey,
      this.daysSinceMeasurement, this.missingDaysNotImputed);
}

/// Server-calculated evidence only. The client validates the contract and formats
/// it; it never estimates missing measurements or recalculates a baseline.
class WeightInsight {
  final String id;
  final WeightInsightKind kind;
  final String metric;
  final String evaluationDateKey;
  final String observationStartDateKey;
  final String observationEndDateKey;
  final List<WeightInsightRecord> records;
  final int validRecordCount;
  final String unit;
  final WeightInsightEvidence evidence;
  final WeightInsightQuality dataQuality;
  final String interpretationCode;
  final bool eligible;
  final int priority;
  final String calculationSpecVersion;
  final DateTime sourceGeneratedAt;
  final List<String> limitations;
  const WeightInsight._({
    required this.id,
    required this.kind,
    required this.metric,
    required this.evaluationDateKey,
    required this.observationStartDateKey,
    required this.observationEndDateKey,
    required this.records,
    required this.validRecordCount,
    required this.unit,
    required this.evidence,
    required this.dataQuality,
    required this.interpretationCode,
    required this.eligible,
    required this.priority,
    required this.calculationSpecVersion,
    required this.sourceGeneratedAt,
    required this.limitations,
  });
}

/// Current Gold for an exact evaluation day, bound to the live Silver generation.
class CurrentInsightSet {
  final int schemaVersion;
  final String calculationSpecVersion;
  final String evaluationDateKey;
  final DateTime generatedAt;
  final String silverDateKey;
  final DateTime silverGeneratedAt;
  final String contentHash;
  final List<WeightInsight> insights;
  final CheckinCurrentInsightSet? checkinInsights;
  CurrentInsightSet._(_InsightSet value, {this.checkinInsights})
      : schemaVersion = 1,
        calculationSpecVersion = weightInsightSpecVersion,
        evaluationDateKey = value.evaluationDateKey,
        generatedAt = value.generatedAt,
        silverDateKey = value.silverDateKey,
        silverGeneratedAt = value.silverGeneratedAt,
        contentHash = value.contentHash,
        insights = value.insights;

  factory CurrentInsightSet.fromMap(Map<String, dynamic> data,
      {required DailyHealthFeatures features,
      required String evaluationDateKey}) {
    final set = _parseSet(data,
        expectedKind: 'current', evaluationDateKey: evaluationDateKey);
    final body = features.body;
    final quality = features.dataQuality;
    final latest =
        body.latestWeightDate == null ? null : _jstDay(body.latestWeightDate!);
    if (features.schemaVersion != 5 ||
        features.dateKey != evaluationDateKey ||
        features.generatedAt == null ||
        _jstDay(features.generatedAt!) != evaluationDateKey ||
        !set.silverGeneratedAt.isAtSameMomentAs(features.generatedAt!) ||
        !quality.availableDomains.contains('body') ||
        quality.missingDomains.contains('body') ||
        quality.staleDomains.contains('body') ||
        latest == null ||
        !_validWeight(body.latestWeightGrams) ||
        body.daysSinceMeasurement == null ||
        body.daysSinceMeasurement! < 0 ||
        body.daysSinceMeasurement! >= 14) {
      throw const FormatException('Current Insight source unavailable');
    }
    for (final insight in set.insights) {
      if (insight.dataQuality.latestDateKey != latest ||
          insight.dataQuality.daysSinceMeasurement !=
              body.daysSinceMeasurement ||
          insight.dataQuality.baselineStatus != body.personalBaseline.status) {
        throw const FormatException('Current Insight source mismatch');
      }
      if (insight.kind == WeightInsightKind.observedRange) {
        final baseline = body.personalBaseline;
        if (baseline.method != 'median_mad_ewma_v1' ||
            baseline.status != 'ready' ||
            insight.validRecordCount != baseline.recordCount ||
            insight.observationStartDateKey != baseline.firstDateKey ||
            insight.observationEndDateKey != baseline.lastDateKey) {
          throw const FormatException('Adopted baseline provenance mismatch');
        }
      } else if (insight.records.last.dateKey != latest ||
          insight.records.last.value != body.latestWeightGrams) {
        throw const FormatException('Endpoint provenance mismatch');
      }
    }
    CheckinCurrentInsightSet? observations;
    if (data['checkinInsights'] is Map) {
      try {
        observations = CheckinCurrentInsightSet.fromMap(data,
            evaluationDateKey: evaluationDateKey,
            silverGeneratedAt: features.generatedAt!);
      } on FormatException {
        observations = null;
      }
    }
    return CurrentInsightSet._(set, checkinInsights: observations);
  }
}

/// Immutable evidence captured from fresh report-cutoff analysis. This type is
/// deliberately separate from CurrentInsightSet and cannot be used as live Gold.
class ReportInsightSnapshot {
  final int schemaVersion;
  final String calculationSpecVersion;
  final String evaluationDateKey;
  final DateTime generatedAt;
  final String silverDateKey;
  final DateTime silverGeneratedAt;
  final List<WeightInsight> insights;
  final CheckinReportInsightSnapshot? checkinInsights;
  ReportInsightSnapshot._(_InsightSet value, {this.checkinInsights})
      : schemaVersion = 1,
        calculationSpecVersion = weightInsightSpecVersion,
        evaluationDateKey = value.evaluationDateKey,
        generatedAt = value.generatedAt,
        silverDateKey = value.silverDateKey,
        silverGeneratedAt = value.silverGeneratedAt,
        insights = value.insights;

  factory ReportInsightSnapshot.fromMap(Map<String, dynamic> data,
      {required String evaluationDateKey,
      required DateTime generatedAt,
      required String cutoffDateKey}) {
    final cutoff = _date(cutoffDateKey);
    final evaluation = _date(evaluationDateKey);
    final set = _parseSet(data,
        expectedKind: 'report_snapshot', evaluationDateKey: evaluationDateKey);
    if (cutoff == null ||
        evaluation == null ||
        evaluation.difference(cutoff).inDays != 1 ||
        !set.generatedAt.isAtSameMomentAs(generatedAt)) {
      throw const FormatException('Snapshot generation or cutoff mismatch');
    }
    for (final insight in set.insights) {
      if (insight.observationEndDateKey.compareTo(cutoffDateKey) > 0 ||
          insight.dataQuality.latestDateKey.compareTo(cutoffDateKey) > 0) {
        throw const FormatException('Snapshot includes post-cutoff records');
      }
    }
    CheckinReportInsightSnapshot? observations;
    if (data['checkinInsights'] is Map) {
      try {
        observations = CheckinReportInsightSnapshot.fromMap(data,
            evaluationDateKey: evaluationDateKey,
            generatedAt: generatedAt,
            cutoffDateKey: cutoffDateKey);
      } on FormatException {
        observations = null;
      }
    }
    return ReportInsightSnapshot._(set, checkinInsights: observations);
  }
}

class _InsightSet {
  final String evaluationDateKey;
  final DateTime generatedAt;
  final String silverDateKey;
  final DateTime silverGeneratedAt;
  final String contentHash;
  final List<WeightInsight> insights;
  const _InsightSet(
      this.evaluationDateKey,
      this.generatedAt,
      this.silverDateKey,
      this.silverGeneratedAt,
      this.contentHash,
      this.insights);
}

_InsightSet _parseSet(Map<String, dynamic> data,
    {required String expectedKind, required String evaluationDateKey}) {
  final source = _map(data['source']);
  final generation = _instant(data['generatedAt']);
  final sourceGeneration = _instant(source['silverGeneratedAt']);
  final rawInsights = data['insights'];
  if (data['schemaVersion'] != 1 ||
      data['kind'] != expectedKind ||
      data['calculationSpecVersion'] != weightInsightSpecVersion ||
      _date(evaluationDateKey) == null ||
      data['evaluationDateKey'] != evaluationDateKey ||
      source['silverDateKey'] != evaluationDateKey ||
      source['silverSchemaVersion'] != 5 ||
      generation == null ||
      sourceGeneration == null ||
      !generation.isAtSameMomentAs(sourceGeneration) ||
      rawInsights is! List ||
      rawInsights.length > 2) {
    throw const FormatException('Invalid weight Insight set');
  }
  final insights = <WeightInsight>[];
  final kinds = <WeightInsightKind>{};
  final ids = <String>{};
  int? previousPriority;
  for (final raw in rawInsights) {
    final insight =
        _parseInsight(_map(raw), evaluationDateKey, sourceGeneration);
    if (!kinds.add(insight.kind) ||
        !ids.add(insight.id) ||
        (previousPriority != null && insight.priority < previousPriority)) {
      throw const FormatException('Duplicate or unordered weight Insights');
    }
    previousPriority = insight.priority;
    insights.add(insight);
  }
  return _InsightSet(
      evaluationDateKey,
      generation.toUtc(),
      evaluationDateKey,
      sourceGeneration.toUtc(),
      data['contentHash'] is String ? data['contentHash'] as String : '',
      List.unmodifiable(insights));
}

WeightInsight _parseInsight(Map<String, dynamic> data, String evaluationDateKey,
    DateTime sourceGeneratedAt) {
  final kind = switch (data['kind']) {
    'weight_observed_range' => WeightInsightKind.observedRange,
    'weight_period_difference' => WeightInsightKind.periodDifference,
    _ => throw const FormatException('Unknown weight Insight kind'),
  };
  final id = data['id'];
  final count = _integer(data['validRecordCount']);
  final priority = _integer(data['priority']);
  final rawRecords = data['records'];
  final ownGeneration = _instant(data['sourceGeneratedAt']);
  final start = _date(data['observationStartDateKey']);
  final end = _date(data['observationEndDateKey']);
  final quality = _map(data['dataQuality']);
  final latest = _date(quality['latestDateKey']);
  final evaluation = _date(evaluationDateKey)!;
  final days = _integer(quality['daysSinceMeasurement']);
  final baselineStatus = quality['baselineStatus'];
  if (id is! String ||
      id.isEmpty ||
      data['metric'] != 'body' ||
      data['unit'] != 'g' ||
      data['eligible'] != true ||
      data['calculationSpecVersion'] != weightInsightSpecVersion ||
      data['evaluationDateKey'] != evaluationDateKey ||
      ownGeneration == null ||
      !ownGeneration.isAtSameMomentAs(sourceGeneratedAt) ||
      count == null ||
      count < 2 ||
      rawRecords is! List ||
      rawRecords.length != count ||
      priority == null ||
      priority < 0 ||
      start == null ||
      end == null ||
      start.isAfter(end) ||
      end.isAfter(evaluation) ||
      latest == null ||
      latest.isAfter(evaluation) ||
      latest.isBefore(end) ||
      days == null ||
      days < 0 ||
      days >= 14 ||
      days != evaluation.difference(latest).inDays ||
      (baselineStatus != 'ready' && baselineStatus != 'learning') ||
      quality['missingDaysNotImputed'] != true) {
    throw const FormatException('Invalid weight Insight provenance');
  }
  final records = <WeightInsightRecord>[];
  String? previous;
  for (final raw in rawRecords) {
    final record = _map(raw);
    final date = record['dateKey'];
    final value = _number(record['value']);
    if (date is! String ||
        _date(date) == null ||
        !_validWeight(value) ||
        date.compareTo(data['observationStartDateKey'] as String) < 0 ||
        date.compareTo(data['observationEndDateKey'] as String) > 0 ||
        (previous != null && date.compareTo(previous) <= 0)) {
      throw const FormatException('Invalid real weight record');
    }
    previous = date;
    records.add(WeightInsightRecord(date, value!));
  }
  if (records.first.dateKey != data['observationStartDateKey'] ||
      records.last.dateKey != data['observationEndDateKey']) {
    throw const FormatException('Insight observation boundaries mismatch');
  }
  final rawEvidence = _map(data['evidence']);
  final code = data['interpretationCode'];
  late WeightInsightEvidence evidence;
  if (kind == WeightInsightKind.observedRange) {
    final minimum = _number(rawEvidence['minimumGrams']);
    final maximum = _number(rawEvidence['maximumGrams']);
    final equal = rawEvidence['allEqual'];
    if (baselineStatus != 'ready' ||
        count < 7 ||
        count > 14 ||
        end.difference(start).inDays + 1 < 14 ||
        !end.isBefore(latest) ||
        latest.difference(start).inDays > 89 ||
        !_validWeight(minimum) ||
        !_validWeight(maximum) ||
        minimum! > maximum! ||
        equal is! bool ||
        equal != (minimum == maximum) ||
        !records.any((r) => r.value == minimum) ||
        !records.any((r) => r.value == maximum) ||
        records.any((r) => r.value < minimum || r.value > maximum) ||
        code != (equal ? 'weight_all_equal' : 'weight_observed_range')) {
      throw const FormatException('Invalid observed range evidence');
    }
    evidence = WeightRangeEvidence(minimum, maximum, equal);
  } else {
    final firstWeight = _number(rawEvidence['startWeightGrams']);
    final lastWeight = _number(rawEvidence['endWeightGrams']);
    final delta = _number(rawEvidence['differenceGrams']);
    final absolute = _number(rawEvidence['absoluteDifferenceGrams']);
    if (rawEvidence['windowDays'] != 30 ||
        count > 30 ||
        evaluation.difference(start).inDays > 29 ||
        rawEvidence['startDateKey'] != records.first.dateKey ||
        rawEvidence['endDateKey'] != records.last.dateKey ||
        firstWeight != records.first.value ||
        lastWeight != records.last.value ||
        delta == null ||
        absolute == null ||
        absolute < 0 ||
        (delta - (lastWeight! - firstWeight!)).abs() > 1e-9 ||
        (absolute - delta.abs()).abs() > 1e-9 ||
        code !=
            (delta > 0
                ? 'weight_increased'
                : delta < 0
                    ? 'weight_decreased'
                    : 'weight_unchanged')) {
      throw const FormatException('Invalid period difference evidence');
    }
    evidence = WeightPeriodEvidence(
        startWeightGrams: firstWeight,
        endWeightGrams: lastWeight,
        differenceGrams: delta,
        absoluteDifferenceGrams: absolute,
        startDateKey: records.first.dateKey,
        endDateKey: records.last.dateKey,
        windowDays: 30);
  }
  return WeightInsight._(
      id: id,
      kind: kind,
      metric: 'body',
      evaluationDateKey: evaluationDateKey,
      observationStartDateKey: records.first.dateKey,
      observationEndDateKey: records.last.dateKey,
      records: List.unmodifiable(records),
      validRecordCount: count,
      unit: 'g',
      evidence: evidence,
      dataQuality: WeightInsightQuality(baselineStatus as String,
          quality['latestDateKey'] as String, days, true),
      interpretationCode: code as String,
      eligible: true,
      priority: priority,
      calculationSpecVersion: weightInsightSpecVersion,
      sourceGeneratedAt: sourceGeneratedAt.toUtc(),
      limitations: List.unmodifiable(data['limitations'] is List
          ? (data['limitations'] as List).whereType<String>()
          : const <String>[]));
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
double? _number(dynamic value) =>
    value is num && value.isFinite ? value.toDouble() : null;
int? _integer(dynamic value) =>
    value is num && value.isFinite && value == value.toInt()
        ? value.toInt()
        : null;
bool _validWeight(double? value) =>
    value != null && value.isFinite && value > 0 && value <= 1000;
DateTime? _instant(dynamic value) => value is Timestamp
    ? value.toDate()
    : value is DateTime
        ? value
        : value is String
            ? DateTime.tryParse(value)
            : null;
DateTime? _date(dynamic value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return null;
  }
  final date = DateTime.tryParse('${value}T00:00:00Z');
  return date != null && _day(date) == value ? date : null;
}

String _day(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String _jstDay(DateTime instant) =>
    _day(instant.toUtc().add(const Duration(hours: 9)));

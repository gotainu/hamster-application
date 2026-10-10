import 'package:cloud_firestore/cloud_firestore.dart';

/// The original immutable milestone IDs and date-keyed daily reports coexist.
bool isPersonalityReportId(String id) {
  if (RegExp(r'^personality_v1_(body|activity|body_activity)$').hasMatch(id)) {
    return true;
  }
  final match = RegExp(r'^daily_(\d{4})-(\d{2})-(\d{2})$').firstMatch(id);
  if (match == null) return false;
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final date = DateTime.utc(year, month, day);
  return year > 0 &&
      date.year == year &&
      date.month == month &&
      date.day == day;
}

enum PersonalityReportType { weightOnly, activityOnly, both }

enum PersonalityReportPhase { loading, learning, available, unavailable }

class PersonalityReportState {
  final String? ownerUid;
  final PersonalityReportPhase phase;
  final PersonalityReport? report;
  const PersonalityReportState.loading(this.ownerUid)
      : phase = PersonalityReportPhase.loading,
        report = null;
  const PersonalityReportState.learning(this.ownerUid)
      : phase = PersonalityReportPhase.learning,
        report = null;
  const PersonalityReportState.unavailable(this.ownerUid)
      : phase = PersonalityReportPhase.unavailable,
        report = null;
  const PersonalityReportState.available(this.ownerUid, this.report)
      : phase = PersonalityReportPhase.available;
}

class PersonalityHistoryCursor {
  final String ownerUid;
  final Timestamp generatedAt;
  final String reportId;
  const PersonalityHistoryCursor(
      this.ownerUid, this.generatedAt, this.reportId);
}

class PersonalityHistoryEntry {
  final PersonalityReport report;
  final bool isViewed;
  const PersonalityHistoryEntry(this.report, {required this.isViewed});
}

class PersonalityHistoryPage {
  final String ownerUid;
  final List<PersonalityHistoryEntry> entries;
  final PersonalityHistoryCursor? nextCursor;
  const PersonalityHistoryPage(this.ownerUid, this.entries, {this.nextCursor});
  bool get hasMore => nextCursor != null;
}

/// Only the committed immutable report is decoded. Current measurements,
/// free-text notes and entitlement data are deliberately not part of this model.
class PersonalityReport {
  final String reportId;
  final String petId;
  final int schemaVersion;
  final String analysisSpecVersion;
  final PersonalityReportType type;
  final DateTime generatedAt;
  final String evaluationDateKey;
  final String silverDateKey;
  final String? cutoffDateKey;
  final PersonalityMetricSnapshot? body;
  final PersonalityMetricSnapshot? activity;
  final List<String> limitations;
  bool get isDaily => reportId.startsWith('daily_');
  const PersonalityReport._({
    required this.reportId,
    required this.petId,
    required this.schemaVersion,
    required this.analysisSpecVersion,
    required this.type,
    required this.generatedAt,
    required this.evaluationDateKey,
    required this.silverDateKey,
    required this.cutoffDateKey,
    required this.body,
    required this.activity,
    required this.limitations,
  });

  factory PersonalityReport.fromMap(Map<String, dynamic> data,
      {String? expectedReportId}) {
    final type = switch (data['reportType']) {
      'weight_only' => PersonalityReportType.weightOnly,
      'activity_only' => PersonalityReportType.activityOnly,
      'both' => PersonalityReportType.both,
      _ => throw const FormatException('Unsupported personality report type'),
    };
    final id = _text(data['reportId']);
    final ready = _strings(data['readyMetrics']);
    final expected = type == PersonalityReportType.both
        ? ['body', 'activity']
        : [type == PersonalityReportType.weightOnly ? 'body' : 'activity'];
    if (data['schemaVersion'] != 1 ||
        data['analysisSpecVersion'] != 'personality_v1' ||
        data['petId'] != 'main_pet' ||
        id == null ||
        !isPersonalityReportId(id) ||
        (!id.startsWith('daily_') &&
            id != 'personality_v1_${expected.join('_')}') ||
        (expectedReportId != null && expectedReportId != id) ||
        ready.length != expected.length ||
        !expected.every(ready.contains)) {
      throw const FormatException('Invalid personality report identity');
    }
    final rawDate = data['generatedAt'];
    final generatedAt = rawDate is Timestamp
        ? rawDate.toDate()
        : rawDate is DateTime
            ? rawDate
            : rawDate is String
                ? DateTime.tryParse(rawDate)
                : null;
    final evaluation = _text(data['evaluationDateKey']);
    final silver = _text(data['silverDateKey']);
    final cutoff = _text(data['cutoffDateKey']);
    if (generatedAt == null ||
        evaluation == null ||
        silver == null ||
        (id.startsWith('daily_') && evaluation != id.substring(6))) {
      throw const FormatException('Missing personality report provenance');
    }
    if (id.startsWith('daily_')) {
      final previous =
          DateTime.parse(evaluation).subtract(const Duration(days: 1));
      final expectedCutoff =
          '${previous.year.toString().padLeft(4, '0')}-${previous.month.toString().padLeft(2, '0')}-${previous.day.toString().padLeft(2, '0')}';
      if (cutoff != expectedCutoff) {
        throw const FormatException('Invalid daily report cutoff');
      }
    }
    final metrics = _map(data['metrics']);
    PersonalityMetricSnapshot metric(String name) {
      final value = _map(metrics[name]);
      return PersonalityMetricSnapshot.fromMap(value, metric: name);
    }

    return PersonalityReport._(
      reportId: id,
      petId: 'main_pet',
      schemaVersion: 1,
      analysisSpecVersion: 'personality_v1',
      type: type,
      generatedAt: generatedAt.toUtc(),
      evaluationDateKey: evaluation,
      silverDateKey: silver,
      cutoffDateKey: cutoff,
      body: expected.contains('body') ? metric('body') : null,
      activity: expected.contains('activity') ? metric('activity') : null,
      limitations: List.unmodifiable(_strings(data['limitations'])),
    );
  }
}

class PersonalityMetricSnapshot {
  final String unit;
  final double median;
  final double? mad;
  final double? latestValue;
  final int recordCount;
  final int spanDays;
  final String firstDateKey;
  final String lastDateKey;
  final String? latestDateKey;
  final List<String> interpretations;
  final PersonalityPopulationContext? population;
  const PersonalityMetricSnapshot._({
    required this.unit,
    required this.median,
    required this.mad,
    required this.latestValue,
    required this.recordCount,
    required this.spanDays,
    required this.firstDateKey,
    required this.lastDateKey,
    required this.latestDateKey,
    required this.interpretations,
    required this.population,
  });
  factory PersonalityMetricSnapshot.fromMap(Map<String, dynamic> data,
      {required String metric}) {
    final baseline = _map(data['baseline']);
    final median = _number(baseline['median']);
    final first = _text(baseline['firstDateKey']);
    final last = _text(baseline['lastDateKey']);
    final count = _number(baseline['recordCount'])?.toInt() ?? 0;
    final span = _number(baseline['spanDays'])?.toInt() ?? 0;
    final unit = metric == 'body' ? 'g' : 'm';
    if (data['unit'] != unit ||
        baseline['status'] != 'ready' ||
        median == null ||
        median < 0 ||
        count < 7 ||
        span < 14 ||
        first == null ||
        last == null) {
      throw const FormatException('Missing ready metric snapshot');
    }
    final rawInterpretations = data['interpretations'];
    final interpretations = rawInterpretations is List
        ? rawInterpretations
            .map((item) => _text(_map(item)['text']))
            .whereType<String>()
            .toList()
        : <String>[];
    final rawPopulation = data['populationComparison'];
    return PersonalityMetricSnapshot._(
      unit: unit,
      median: median,
      mad: _number(baseline['mad']),
      latestValue: _number(data['latestValue']),
      recordCount: count,
      spanDays: span,
      firstDateKey: first,
      lastDateKey: last,
      latestDateKey: _text(data['latestDateKey']),
      interpretations: List.unmodifiable(interpretations),
      population: metric == 'body' && rawPopulation is Map
          ? PersonalityPopulationContext.fromMap(_map(rawPopulation))
          : null,
    );
  }
}

class PersonalityPopulationContext {
  final bool isApplicable;
  final String? reason;
  final String expression;
  final String? position;
  final double? median;
  final double? p25;
  final double? p75;
  final String? referenceVersion;
  final String? sourceVersion;
  final String? sourceTitle;
  final String? sourceDoi;
  final String? population;
  final int? studyYear;
  final int? sourceYear;
  final int? speciesPopulationSize;
  final int? weightSampleSize;
  final bool sampleSizeCaution;
  final List<String> limitations;
  const PersonalityPopulationContext._({
    required this.isApplicable,
    required this.reason,
    required this.expression,
    required this.position,
    required this.median,
    required this.p25,
    required this.p75,
    required this.referenceVersion,
    required this.sourceVersion,
    required this.sourceTitle,
    required this.sourceDoi,
    required this.population,
    required this.studyYear,
    required this.sourceYear,
    required this.speciesPopulationSize,
    required this.weightSampleSize,
    required this.sampleSizeCaution,
    required this.limitations,
  });
  factory PersonalityPopulationContext.fromMap(Map<String, dynamic> data) {
    final cohort = _map(data['cohort']);
    final position = _text(data['position']);
    final median = _number(cohort['median']);
    final lower = _number(cohort['p25']);
    final upper = _number(cohort['p75']);
    return PersonalityPopulationContext._(
      isApplicable: data['applicability'] == 'applicable' &&
          const ['below_iqr', 'within_iqr', 'above_iqr'].contains(position) &&
          data['reason'] == null &&
          median != null &&
          lower != null &&
          upper != null &&
          lower > 0 &&
          lower <= median &&
          median <= upper,
      reason: _text(data['reason']),
      expression: _text(data['expressionJa']) ?? '公開研究との比較は適用していません。',
      position: position,
      median: _number(cohort['median']),
      p25: _number(cohort['p25']),
      p75: _number(cohort['p75']),
      referenceVersion: _text(cohort['referenceVersion']),
      sourceVersion: _text(cohort['sourceVersion']),
      sourceTitle: _text(cohort['sourceTitle']),
      sourceDoi: _text(cohort['sourceDOI']),
      population: _text(cohort['population']),
      studyYear: _number(cohort['studyYear'])?.toInt(),
      sourceYear: _number(cohort['sourceYear'])?.toInt(),
      speciesPopulationSize: _number(cohort['speciesPopulationN'])?.toInt(),
      weightSampleSize: _number(cohort['weightSampleN'])?.toInt(),
      sampleSizeCaution: cohort['sampleSizeCaution'] == true,
      limitations: List.unmodifiable(_strings(data['limitations'])),
    );
  }
  String get summary => switch (position) {
        'below_iqr' => '公開研究の中央50%の範囲より軽め',
        'within_iqr' => '公開研究の中央50%の範囲内',
        'above_iqr' => '公開研究の中央50%の範囲より重め',
        _ => expression,
      };
}

Map<String, dynamic> _map(Object? value) => value is Map
    ? Map.fromEntries(value.entries
        .where((entry) => entry.key is String)
        .map((entry) => MapEntry(entry.key as String, entry.value)))
    : <String, dynamic>{};
String? _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;
double? _number(Object? value) =>
    value is num && value.isFinite ? value.toDouble() : null;
List<String> _strings(Object? value) =>
    value is List ? value.whereType<String>().toList() : const [];

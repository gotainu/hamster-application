import 'package:cloud_firestore/cloud_firestore.dart';

const checkinInsightSpecVersion = 'checkin_insights_v1';

enum CheckinInsightKind { itemRepetition, concernFrequency, recordContinuity }

class CheckinInsightQuality {
  final bool missingDaysNotImputed;
  final bool normalDefaultsAreNotAnswers;
  const CheckinInsightQuality._()
      : missingDaysNotImputed = true,
        normalDefaultsAreNotAnswers = true;
}

class CheckinInsightEvidence {
  final int validRecordDayCount, selectionVerifiedDayCount, concernDayCount;
  final int matchingDayCount, missingDayCount, invalidDayCount;
  final String? itemId, itemLabel;

  /// Existing schema2 normal defaults are never explicit per-item answers.
  final int? itemAnsweredDayCount;
  const CheckinInsightEvidence._(
      this.validRecordDayCount,
      this.selectionVerifiedDayCount,
      this.concernDayCount,
      this.matchingDayCount,
      this.missingDayCount,
      this.invalidDayCount,
      this.itemId,
      this.itemLabel)
      : itemAnsweredDayCount = null;
}

/// Server-selected evidence. The client never aggregates records or infers health.
class CheckinInsight {
  final String id,
      metric,
      evaluationDateKey,
      observationStartDateKey,
      observationEndDateKey;
  final CheckinInsightKind kind;
  final int validRecordCount, priority;
  final CheckinInsightEvidence evidence;
  final String interpretationCode, semanticFingerprint;
  final bool discovery;
  final DateTime sourceGeneratedAt;
  final List<String> limitations;
  String get unit => 'days';
  bool get eligible => true;
  String get calculationSpecVersion => checkinInsightSpecVersion;
  CheckinInsightQuality get dataQuality => const CheckinInsightQuality._();
  const CheckinInsight._(
      {required this.id,
      required this.kind,
      required this.evaluationDateKey,
      required this.observationStartDateKey,
      required this.observationEndDateKey,
      required this.validRecordCount,
      required this.priority,
      required this.evidence,
      required this.interpretationCode,
      required this.semanticFingerprint,
      required this.discovery,
      required this.sourceGeneratedAt,
      required this.limitations})
      : metric = 'condition';
}

sealed class CheckinInsightSet {
  final String catalogVersion,
      evaluationDateKey,
      windowStartDateKey,
      windowEndDateKey,
      evidenceHash;
  final DateTime sourceGeneratedAt;
  final List<CheckinInsight> insights;
  int get schemaVersion => 1;
  String get calculationSpecVersion => checkinInsightSpecVersion;
  CheckinInsightSet._(_ParsedCheckinSet value)
      : catalogVersion = value.catalogVersion,
        evaluationDateKey = value.evaluationDateKey,
        windowStartDateKey = value.windowStartDateKey,
        windowEndDateKey = value.windowEndDateKey,
        evidenceHash = value.evidenceHash,
        sourceGeneratedAt = value.sourceGeneratedAt,
        insights = value.insights;
}

class CheckinCurrentInsightSet extends CheckinInsightSet {
  CheckinCurrentInsightSet._(super.value) : super._();
  factory CheckinCurrentInsightSet.fromMap(Map<String, dynamic> gold,
          {required String evaluationDateKey,
          required DateTime silverGeneratedAt}) =>
      CheckinCurrentInsightSet._(
          _parseSet(gold, evaluationDateKey, silverGeneratedAt, false));
}

/// Immutable report evidence is never enriched from current records/catalog.
class CheckinReportInsightSnapshot extends CheckinInsightSet {
  CheckinReportInsightSnapshot._(super.value) : super._();
  factory CheckinReportInsightSnapshot.fromMap(Map<String, dynamic> gold,
      {required String evaluationDateKey,
      required DateTime generatedAt,
      required String cutoffDateKey}) {
    final parsed = _parseSet(gold, evaluationDateKey, generatedAt, true);
    if (parsed.windowEndDateKey != cutoffDateKey) {
      throw const FormatException('Observation cutoff mismatch');
    }
    return CheckinReportInsightSnapshot._(parsed);
  }
}

/// Weight readiness, species and research references are not prerequisites.
class CurrentCheckinAnalysis {
  final String ownerId, evaluationDateKey;
  final DateTime silverGeneratedAt;
  final CheckinCurrentInsightSet insights;
  const CurrentCheckinAnalysis._(this.ownerId, this.evaluationDateKey,
      this.silverGeneratedAt, this.insights);
  factory CurrentCheckinAnalysis.fromDocuments(
      {required String ownerId,
      required String evaluationDateKey,
      required Map<String, dynamic> silver,
      required Map<String, dynamic> gold}) {
    final generation = checkinInstant(silver['generatedAt']);
    if (ownerId.isEmpty ||
        silver['schemaVersion'] != 5 ||
        silver['dateKey'] != evaluationDateKey ||
        generation == null ||
        _day(generation.toUtc().add(const Duration(hours: 9))) !=
            evaluationDateKey) {
      throw const FormatException('Current observation Silver unavailable');
    }
    final insights = CheckinCurrentInsightSet.fromMap(gold,
        evaluationDateKey: evaluationDateKey, silverGeneratedAt: generation);
    if (_map(silver['checkinInsightEvidence'])['evidenceHash'] !=
        insights.evidenceHash) {
      throw const FormatException('Current observation evidence mismatch');
    }
    return CurrentCheckinAnalysis._(
        ownerId, evaluationDateKey, generation.toUtc(), insights);
  }
}

class _ParsedCheckinSet {
  final String catalogVersion,
      evaluationDateKey,
      windowStartDateKey,
      windowEndDateKey,
      evidenceHash;
  final DateTime sourceGeneratedAt;
  final List<CheckinInsight> insights;
  const _ParsedCheckinSet(
      this.catalogVersion,
      this.evaluationDateKey,
      this.windowStartDateKey,
      this.windowEndDateKey,
      this.evidenceHash,
      this.sourceGeneratedAt,
      this.insights);
}

_ParsedCheckinSet _parseSet(
    Map<String, dynamic> gold, String day, DateTime generation, bool snapshot) {
  final source = _map(gold['source']), value = _map(gold['checkinInsights']);
  final root = checkinInstant(gold['generatedAt']),
      sourceGeneration = checkinInstant(source['silverGeneratedAt']);
  final own = checkinInstant(value['sourceGeneratedAt']);
  final evaluation = _date(day), raw = value['insights'];
  if (gold['schemaVersion'] != 1 ||
      gold['kind'] != (snapshot ? 'report_snapshot' : 'current') ||
      gold['evaluationDateKey'] != day ||
      source['silverDateKey'] != day ||
      source['silverSchemaVersion'] != 5 ||
      evaluation == null ||
      root == null ||
      sourceGeneration == null ||
      own == null ||
      !root.isAtSameMomentAs(generation) ||
      !sourceGeneration.isAtSameMomentAs(generation) ||
      !own.isAtSameMomentAs(generation) ||
      value['schemaVersion'] != 1 ||
      value['calculationSpecVersion'] != checkinInsightSpecVersion ||
      value['evaluationDateKey'] != day ||
      _text(value['catalogVersion']) == null ||
      _text(value['evidenceHash']) == null ||
      raw is! List ||
      raw.length > 1) {
    throw const FormatException('Invalid observation Insight envelope');
  }
  final end = evaluation.subtract(Duration(days: snapshot ? 1 : 0)),
      start = evaluation.subtract(Duration(days: snapshot ? 14 : 13));
  if (value['windowStartDateKey'] != _day(start) ||
      value['windowEndDateKey'] != _day(end)) {
    throw const FormatException('Observation window mismatch');
  }
  return _ParsedCheckinSet(
      value['catalogVersion'] as String,
      day,
      _day(start),
      _day(end),
      value['evidenceHash'] as String,
      generation.toUtc(),
      List.unmodifiable(raw.map((item) =>
          _parseInsight(_map(item), day, _day(start), _day(end), generation))));
}

CheckinInsight _parseInsight(Map<String, dynamic> value, String day,
    String start, String end, DateTime generation) {
  final kind = switch (value['kind']) {
    'checkin_item_repetition' => CheckinInsightKind.itemRepetition,
    'checkin_concern_frequency' => CheckinInsightKind.concernFrequency,
    'checkin_record_continuity' => CheckinInsightKind.recordContinuity,
    _ => throw const FormatException('Unknown observation Insight kind'),
  };
  final evidence = _map(value['evidence']),
      quality = _map(value['dataQuality']);
  final count = _count(evidence['validRecordDayCount']),
      selected = _count(evidence['selectionVerifiedDayCount']);
  final concern = _count(evidence['concernDayCount']),
      matching = _count(evidence['matchingDayCount']);
  final missing = _count(evidence['missingDayCount']),
      invalid = _count(evidence['invalidDayCount']);
  final code = switch (kind) {
    CheckinInsightKind.itemRepetition => 'checkin_item_repeated',
    CheckinInsightKind.concernFrequency => 'checkin_concern_recorded',
    CheckinInsightKind.recordContinuity => 'checkin_records_continued'
  };
  final priority = switch (kind) {
    CheckinInsightKind.itemRepetition => 40,
    CheckinInsightKind.concernFrequency => 50,
    CheckinInsightKind.recordContinuity => 60
  };
  final own = checkinInstant(value['sourceGeneratedAt']);
  if (_text(value['id']) == null ||
      value['metric'] != 'condition' ||
      value['unit'] != 'days' ||
      value['eligible'] != true ||
      value['evaluationDateKey'] != day ||
      value['observationStartDateKey'] != start ||
      value['observationEndDateKey'] != end ||
      evidence['windowDays'] != 14 ||
      count == null ||
      count < 7 ||
      value['validRecordCount'] != count ||
      selected == null ||
      selected > count ||
      concern == null ||
      concern > count ||
      matching == null ||
      matching > count ||
      missing == null ||
      invalid == null ||
      count + invalid + missing != 14 ||
      quality['missingDaysNotImputed'] != true ||
      quality['normalDefaultsAreNotAnswers'] != true ||
      evidence['itemAnsweredDayCount'] != null ||
      own == null ||
      !own.isAtSameMomentAs(generation) ||
      value['interpretationCode'] != code ||
      value['priority'] != priority ||
      value['discovery'] != (kind != CheckinInsightKind.recordContinuity) ||
      _text(value['semanticFingerprint']) == null) {
    throw const FormatException('Invalid observation Insight provenance');
  }
  if ((kind == CheckinInsightKind.itemRepetition &&
          (selected < 7 ||
              matching > selected ||
              matching < 3 ||
              _text(evidence['itemId']) == null ||
              _text(evidence['itemLabel']) == null)) ||
      (kind == CheckinInsightKind.concernFrequency &&
          (concern < 2 || matching != concern)) ||
      (kind == CheckinInsightKind.recordContinuity && matching != count)) {
    throw const FormatException('Ineligible observation Insight');
  }
  return CheckinInsight._(
      id: value['id'] as String,
      kind: kind,
      evaluationDateKey: day,
      observationStartDateKey: start,
      observationEndDateKey: end,
      validRecordCount: count,
      priority: priority,
      evidence: CheckinInsightEvidence._(
          count,
          selected,
          concern,
          matching,
          missing,
          invalid,
          _text(evidence['itemId']),
          _text(evidence['itemLabel'])),
      interpretationCode: code,
      semanticFingerprint: value['semanticFingerprint'] as String,
      discovery: kind != CheckinInsightKind.recordContinuity,
      sourceGeneratedAt: generation.toUtc(),
      limitations: List.unmodifiable(value['limitations'] is List
          ? (value['limitations'] as List).whereType<String>()
          : const <String>[]));
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
String? _text(dynamic value) =>
    value is String && value.trim().isNotEmpty ? value : null;
int? _count(dynamic value) =>
    value is int && value >= 0 && value <= 14 ? value : null;
DateTime? checkinInstant(dynamic value) => value is Timestamp
    ? value.toDate()
    : value is DateTime
        ? value
        : value is String
            ? DateTime.tryParse(value)
            : null;
DateTime? _date(String value) {
  final result = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)
      ? DateTime.tryParse('${value}T00:00:00Z')
      : null;
  return result != null && _day(result) == value ? result : null;
}

String _day(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

import 'package:cloud_firestore/cloud_firestore.dart';

enum ObservationOperation { newObservation, correction, cancel }

enum ObservationTimePrecision { unknown, dateOnly, instant }

DateTime? observationTime(dynamic value) => value is Timestamp
    ? value.toDate().toUtc()
    : value is DateTime
        ? value.toUtc()
        : value is String
            ? DateTime.tryParse(value)?.toUtc()
            : null;
Map<String, dynamic> observationMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

/// A user's timing claim; never the server's receipt time.
class ObservationTiming {
  const ObservationTiming.unknown()
      : precision = ObservationTimePrecision.unknown,
        dateKey = null,
        observedAt = null,
        confirmation = 'unknown';
  const ObservationTiming.dateOnly(this.dateKey)
      : precision = ObservationTimePrecision.dateOnly,
        observedAt = null,
        confirmation = 'date_confirmed';
  ObservationTiming.instant(DateTime time, {bool nowConfirmed = false})
      : precision = ObservationTimePrecision.instant,
        dateKey = null,
        observedAt = time.toUtc(),
        confirmation = nowConfirmed ? 'now_confirmed' : 'time_confirmed';
  final ObservationTimePrecision precision;
  final String? dateKey;
  final DateTime? observedAt;
  final String confirmation;
  factory ObservationTiming.fromMap(Map<String, dynamic> map) {
    if ((map['precision'] ?? map['timePrecision']) == 'date_only' &&
        map['dateKey'] is String) {
      return ObservationTiming.dateOnly(map['dateKey'] as String);
    }
    final time = observationTime(map['observedAt']);
    if ((map['precision'] ?? map['timePrecision']) == 'instant' &&
        time != null) {
      return ObservationTiming.instant(time,
          nowConfirmed: map['confirmation'] == 'now_confirmed');
    }
    return const ObservationTiming.unknown();
  }
  Map<String, dynamic> toMap() => {
        'precision': switch (precision) {
          ObservationTimePrecision.unknown => 'unknown',
          ObservationTimePrecision.dateOnly => 'date_only',
          ObservationTimePrecision.instant => 'instant',
        },
        'confirmation': confirmation,
        if (dateKey != null) 'dateKey': dateKey,
        if (observedAt != null) 'observedAt': observedAt!.toIso8601String(),
      };
}

class ObservationMutation {
  const ObservationMutation({
    required this.mutationId,
    required this.dayKey,
    required this.date,
    required this.expectedRevision,
    required this.subjectId,
    required this.operation,
    required this.timing,
    this.targetEventId,
    this.targetRevision,
    this.condition,
    this.concernTags = const [],
    this.memo = '',
    required this.catalogVersion,
  });
  final String mutationId, dayKey, catalogVersion;
  final String? subjectId;
  final DateTime date;
  final int expectedRevision;
  final ObservationOperation operation;
  final ObservationTiming timing;
  final String? targetEventId, condition;
  final int? targetRevision;
  final List<String> concernTags;
  final String memo;
  Map<String, dynamic> toMap() => {
        'mutationId': mutationId,
        'dayKey': dayKey,
        'date': date.toUtc().toIso8601String(),
        'expectedRevision': expectedRevision,
        'subjectId': subjectId,
        'operation': switch (operation) {
          ObservationOperation.newObservation => 'new_observation',
          ObservationOperation.correction => 'correction',
          ObservationOperation.cancel => 'cancel',
        },
        if (operation != ObservationOperation.cancel) 'timing': timing.toMap(),
        if (operation != ObservationOperation.newObservation)
          'targetEventId': targetEventId,
        if (targetRevision != null) 'targetRevision': targetRevision,
        if (operation != ObservationOperation.cancel) ...{
          'condition': condition,
          'concernTags': concernTags,
          'memo': memo,
        },
        if (operation != ObservationOperation.cancel)
          'observationCatalogVersion': catalogVersion,
        'inputUiVersion': 'daily_checkin_history_v1',
      };
  factory ObservationMutation.fromMap(Map<String, dynamic> map) =>
      ObservationMutation(
          mutationId: map['mutationId'] as String,
          dayKey: map['dayKey'] as String,
          date: DateTime.parse(map['date'] as String),
          expectedRevision: map['expectedRevision'] as int,
          subjectId: map['subjectId'] as String?,
          operation: switch (map['operation']) {
            'correction' => ObservationOperation.correction,
            'cancel' => ObservationOperation.cancel,
            _ => ObservationOperation.newObservation,
          },
          timing: ObservationTiming.fromMap(observationMap(map['timing'])),
          targetEventId: map['targetEventId'] as String?,
          targetRevision: map['targetRevision'] as int?,
          condition: map['condition'] as String?,
          concernTags:
              (map['concernTags'] as List?)?.cast<String>() ?? const [],
          memo: map['memo'] as String? ?? '',
          catalogVersion: map['observationCatalogVersion'] as String? ?? '');
}

class ObservationSaveResult {
  const ObservationSaveResult({
    required this.confirmed,
    required this.mutation,
    this.revision,
    this.eventId,
    this.acceptedAt,
    this.changed = false,
    this.replayed = false,
    this.projection,
    this.subjectId,
  });
  final bool confirmed, changed, replayed;
  final ObservationMutation mutation;
  final int? revision;
  final String? eventId, subjectId;
  final DateTime? acceptedAt;
  final Map<String, dynamic>? projection;
}

/// A server-resolved view as known at the requested cutoff. It does not turn
/// ordinary validity into experimental label eligibility.
class ObservationHistoryRevision {
  ObservationHistoryRevision.fromMap(Map<String, dynamic> value)
      : revision = value['revision'] as int,
        eventId = value['eventId'] as String,
        subjectId = value['subjectId'] as String,
        operation = value['operation'] as String,
        origin = value['origin'] as String,
        acceptedAt = observationTime(value['acceptedAt']),
        acceptedAtEpochNanoseconds =
            value['acceptedAtEpochNanoseconds'] as String?,
        timing = value['timing'] is Map
            ? ObservationTiming.fromMap(observationMap(value['timing']))
            : null,
        answer =
            value['answer'] is Map ? observationMap(value['answer']) : null;
  final int revision;
  final String eventId, subjectId, operation, origin;
  final DateTime? acceptedAt;
  final String? acceptedAtEpochNanoseconds;
  final ObservationTiming? timing;
  final Map<String, dynamic>? answer;
}

class ObservationHistoryEvent {
  ObservationHistoryEvent.fromMap(Map<String, dynamic> value)
      : eventId = value['eventId'] as String,
        cancelled = value['cancelled'] == true,
        original = value['original'] is Map
            ? ObservationHistoryRevision.fromMap(
                observationMap(value['original']))
            : null,
        effective = ObservationHistoryRevision.fromMap(
            observationMap(value['effective']));
  final String eventId;
  final bool cancelled;
  final ObservationHistoryRevision? original;
  final ObservationHistoryRevision effective;
}

class ObservationHistoryAtResult {
  ObservationHistoryAtResult.fromMap(Map<String, dynamic> value)
      : dayKey = value['dayKey'] as String,
        subjectId = value['subjectId'] as String?,
        latestRevision = value['latestRevision'] as int? ?? 0,
        historyExists = value['historyExists'] == true,
        knowledgeCutoff = observationTime(value['knowledgeCutoff']),
        events = (value['events'] as List? ?? [])
            .map((raw) => ObservationHistoryEvent.fromMap(observationMap(raw)))
            .toList(growable: false),
        current = value['current'] is Map
            ? ObservationHistoryRevision.fromMap(
                observationMap(value['current']))
            : null,
        reasons = (observationMap(value['quality'])['reasons'] as List? ?? [])
            .whereType<String>()
            .toList(growable: false),
        researchConsentStatus =
            observationMap(value['quality'])['researchConsentStatus']
                    as String? ??
                'not_assessed';
  final String dayKey, researchConsentStatus;
  final String? subjectId;
  final int latestRevision;
  final bool historyExists;
  final DateTime? knowledgeCutoff;
  final List<ObservationHistoryEvent> events;
  final ObservationHistoryRevision? current;
  final List<String> reasons;
}

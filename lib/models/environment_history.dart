import 'package:cloud_firestore/cloud_firestore.dart';
import 'breeding_environment.dart';

enum EnvironmentOperation { change, correction, cancel }

enum EnvironmentPrecision { unknown, dateOnly, instant }

/// Effective time is intentionally separate from a server's acceptance time.
class EnvironmentEffective {
  const EnvironmentEffective.unknown()
      : precision = EnvironmentPrecision.unknown,
        dateKey = null,
        occurredAt = null;
  const EnvironmentEffective.dateOnly(this.dateKey)
      : precision = EnvironmentPrecision.dateOnly,
        occurredAt = null;
  EnvironmentEffective.instant(DateTime time)
      : precision = EnvironmentPrecision.instant,
        dateKey = null,
        occurredAt = time.toUtc();
  final EnvironmentPrecision precision;
  final String? dateKey;
  final DateTime? occurredAt;
  factory EnvironmentEffective.fromMap(Map<String, dynamic> map) {
    if (map['precision'] == 'date_only' && map['dateKey'] is String) {
      return EnvironmentEffective.dateOnly(map['dateKey'] as String);
    }
    if (map['precision'] == 'instant') {
      final parsed = environmentTime(map['occurredAt']);
      if (parsed != null) return EnvironmentEffective.instant(parsed);
    }
    return const EnvironmentEffective.unknown();
  }
  Map<String, dynamic> toMap() => switch (precision) {
        EnvironmentPrecision.unknown => {'precision': 'unknown'},
        EnvironmentPrecision.dateOnly => {
            'precision': 'date_only',
            'dateKey': dateKey
          },
        EnvironmentPrecision.instant => {
            'precision': 'instant',
            'occurredAt': occurredAt!.toIso8601String()
          },
      };
}

DateTime? environmentTime(dynamic value) => value is Timestamp
    ? value.toDate().toUtc()
    : value is DateTime
        ? value.toUtc()
        : value is String
            ? DateTime.tryParse(value)?.toUtc()
            : null;
Map<String, dynamic> environmentMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

class EnvironmentMutation {
  const EnvironmentMutation(
      {required this.mutationId,
      required this.expectedRevision,
      required this.operation,
      this.values = const {},
      this.effective,
      this.targetRevision});
  final String mutationId;
  final int expectedRevision;
  final EnvironmentOperation operation;
  final Map<String, dynamic> values;
  final EnvironmentEffective? effective;
  final int? targetRevision;
  factory EnvironmentMutation.fromMap(Map<String, dynamic> map) =>
      EnvironmentMutation(
          mutationId: map['mutationId'] as String,
          expectedRevision: map['expectedRevision'] as int,
          operation:
              EnvironmentOperation.values.byName(map['operation'] as String),
          values: environmentMap(map['values']),
          effective: map['effective'] is Map
              ? EnvironmentEffective.fromMap(environmentMap(map['effective']))
              : null,
          targetRevision: map['targetRevision'] as int?);
  Map<String, dynamic> toMap() => {
        'mutationId': mutationId,
        'expectedRevision': expectedRevision,
        'operation': operation.name,
        if (operation != EnvironmentOperation.cancel) 'values': values,
        if (effective != null) 'effective': effective!.toMap(),
        if (targetRevision != null) 'targetRevision': targetRevision,
      };
}

class EnvironmentLoadResult {
  const EnvironmentLoadResult(
      {this.environment, this.pending, this.serverConfirmed = true});
  final BreedingEnvironment? environment;
  final EnvironmentMutation? pending;
  final bool serverConfirmed;
  int get revision => environment?.revision ?? 0;
}

class EnvironmentSaveResult {
  const EnvironmentSaveResult(
      {required this.confirmed,
      required this.mutation,
      this.revision,
      this.replayed = false,
      this.changed = false,
      this.acceptedAt});
  final bool confirmed;
  final EnvironmentMutation mutation;
  final int? revision;
  final bool replayed, changed;
  final DateTime? acceptedAt;
}

class EnvironmentHistoryValue {
  const EnvironmentHistoryValue(this.value, this.unit, this.quality);
  final dynamic value;
  final String? unit;
  final String quality;
  factory EnvironmentHistoryValue.fromMap(dynamic raw) {
    final map = environmentMap(raw);
    return EnvironmentHistoryValue(map['value'], map['unit'] as String?,
        map['quality'] as String? ?? 'unknown');
  }
}

class EnvironmentFieldChange {
  const EnvironmentFieldChange(this.before, this.after);
  final EnvironmentHistoryValue before, after;
}

class EnvironmentHistoryEntry {
  const EnvironmentHistoryEntry(
      {required this.revision,
      required this.kind,
      required this.effective,
      this.acceptedAt,
      this.targetRevision,
      this.values = const {},
      this.changes = const {},
      this.auxiliaryFieldsChanged = const [],
      this.beforeValueMeaning = 'unknown',
      this.schemaVersion = 1,
      this.ownerUid,
      this.petId = 'main_pet',
      this.recordedFieldKeys = const []});
  final int revision;
  final String kind;
  final EnvironmentEffective effective;
  final DateTime? acceptedAt;
  final int? targetRevision;
  final Map<String, EnvironmentHistoryValue> values;
  final Map<String, EnvironmentFieldChange> changes;
  final List<String> auxiliaryFieldsChanged;
  final String beforeValueMeaning;
  final int schemaVersion;
  final String? ownerUid;
  final String petId;
  final List<String> recordedFieldKeys;
  factory EnvironmentHistoryEntry.fromMap(Map<String, dynamic> map) =>
      EnvironmentHistoryEntry(
          revision: map['revision'] as int,
          kind: map['kind'] as String,
          effective:
              EnvironmentEffective.fromMap(environmentMap(map['effective'])),
          acceptedAt: environmentTime(map['acceptedAt']),
          targetRevision: map['targetRevision'] as int?,
          beforeValueMeaning: map['beforeValueMeaning'] as String? ?? 'unknown',
          schemaVersion:
              map['schemaVersion'] is int ? map['schemaVersion'] as int : 1,
          ownerUid: map['ownerUid'] as String?,
          petId: map['petId'] as String? ?? 'main_pet',
          recordedFieldKeys: environmentMap(map['rawValues']).isEmpty
              ? environmentMap(map['changes']).keys.toList()
              : environmentMap(map['rawValues']).keys.toList(),
          values: environmentMap(map['values']).map((key, value) =>
              MapEntry(key, EnvironmentHistoryValue.fromMap(value))),
          changes: environmentMap(map['changes']).map((key, raw) {
            final change = environmentMap(raw);
            return MapEntry(
                key,
                EnvironmentFieldChange(
                    EnvironmentHistoryValue.fromMap(change['before']),
                    EnvironmentHistoryValue.fromMap(change['after'])));
          }),
          auxiliaryFieldsChanged:
              (map['auxiliaryFieldsChanged'] as List? ?? const [])
                  .whereType<String>()
                  .toList());
}

class EnvironmentHistoryPage {
  const EnvironmentHistoryPage(
      {required this.entries, this.beforeRevision, this.hasMore = false});
  final List<EnvironmentHistoryEntry> entries;
  final int? beforeRevision;
  final bool hasMore;
}

/// Analysis reads must carry provenance, not just a convenient current value.
class EnvironmentAtResult {
  EnvironmentAtResult.fromMap(Map<String, dynamic> map)
      : observedAt = environmentTime(map['observedAt']),
        knowledgeCutoff = environmentTime(map['knowledgeCutoff']),
        values = environmentMap(map['values']).map((key, value) =>
            MapEntry(key, EnvironmentHistoryValue.fromMap(value))),
        evidenceRevisionIds = (map['evidenceRevisionIds'] as List? ?? const [])
            .whereType<String>()
            .toList(),
        unknownFields =
            (environmentMap(map['quality'])['unknownFields'] as List? ??
                    const [])
                .whereType<String>()
                .toList(),
        ambiguousFields =
            (environmentMap(map['quality'])['ambiguousFields'] as List? ??
                    const [])
                .whereType<String>()
                .toList(),
        reasons =
            (environmentMap(map['quality'])['reasons'] as List? ?? const [])
                .whereType<String>()
                .toList();
  final Map<String, EnvironmentHistoryValue> values;
  final DateTime? observedAt, knowledgeCutoff;
  final List<String> evidenceRevisionIds,
      unknownFields,
      ambiguousFields,
      reasons;
}

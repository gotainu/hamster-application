import 'package:cloud_firestore/cloud_firestore.dart';

typedef Json = Map<String, dynamic>;

class WeightRecord {
  final String dayKey;
  final DateTime date;
  final double weightGrams;
  final String memo;
  final String? subjectId, recordId;
  final int revision;
  final Map<String, dynamic>? timing;

  const WeightRecord({
    required this.dayKey,
    required this.date,
    required this.weightGrams,
    required this.memo,
    this.subjectId,
    this.recordId,
    this.revision = 0,
    this.timing,
  });

  factory WeightRecord.fromJson(
    Json json, {
    required String fallbackDayKey,
  }) {
    final dateRaw = json['date'];
    final date = dateRaw is Timestamp
        ? dateRaw.toDate().toLocal()
        : dateRaw is String
            ? DateTime.parse(dateRaw).toLocal()
            : DateTime.tryParse(fallbackDayKey)?.toLocal() ?? DateTime.now();

    final weightRaw = json['weightGrams'];

    return WeightRecord(
      dayKey: json['dayKey'] as String? ?? fallbackDayKey,
      date: date,
      weightGrams: weightRaw is num ? weightRaw.toDouble() : 0,
      memo: json['memo'] as String? ?? '',
      subjectId: json['subjectId'] as String?,
      recordId: json['recordId'] as String?,
      revision: json['revision'] is int ? json['revision'] as int : 0,
      timing: json['timing'] is Map
          ? Map<String, dynamic>.from(json['timing'] as Map)
          : null,
    );
  }
}

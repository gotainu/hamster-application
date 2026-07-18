import 'package:cloud_firestore/cloud_firestore.dart';

typedef Json = Map<String, dynamic>;

class WeightRecord {
  final String dayKey;
  final DateTime date;
  final double weightGrams;
  final String memo;

  const WeightRecord({
    required this.dayKey,
    required this.date,
    required this.weightGrams,
    required this.memo,
  });

  factory WeightRecord.fromJson(
    Json json, {
    required String fallbackDayKey,
  }) {
    final dateRaw = json['date'];
    final date = dateRaw is Timestamp
        ? dateRaw.toDate().toLocal()
        : DateTime.tryParse(fallbackDayKey)?.toLocal() ?? DateTime.now();

    final weightRaw = json['weightGrams'];

    return WeightRecord(
      dayKey: json['dayKey'] as String? ?? fallbackDayKey,
      date: date,
      weightGrams: weightRaw is num ? weightRaw.toDouble() : 0,
      memo: json['memo'] as String? ?? '',
    );
  }
}

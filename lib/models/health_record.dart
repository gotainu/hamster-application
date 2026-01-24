// lib/models/health_record.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class HealthRecord {
  final DateTime date;
  final double distance;

  HealthRecord({
    required this.date,
    required this.distance,
  });

  static HealthRecord fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? <String, dynamic>{};

    // date は Timestamp or String(ISO) 両対応
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String)
        return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    final date = parseDate(m['date']);
    final distRaw = m['distance'];
    final distance = (distRaw is num) ? distRaw.toDouble() : 0.0;

    return HealthRecord(
      date: date,
      distance: distance,
    );
  }
}

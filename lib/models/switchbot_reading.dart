// lib/models/switchbot_reading.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SwitchbotReading {
  final DateTime ts;
  final double? temperature; // °C
  final double? humidity; // %
  final int? battery; // 0-100

  SwitchbotReading({
    required this.ts,
    this.temperature,
    this.humidity,
    this.battery,
  });

  static SwitchbotReading fromMap(Map<String, dynamic> m) {
    // Firestoreには ts を ISO文字列で保存している前提（pollOnce 実装と一致）
    final tsStr = (m['ts'] ?? '') as String;
    final dt = DateTime.tryParse(tsStr)?.toLocal();
    return SwitchbotReading(
      ts: dt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal(),
      temperature: (m['temperature'] is num)
          ? (m['temperature'] as num).toDouble()
          : null,
      humidity:
          (m['humidity'] is num) ? (m['humidity'] as num).toDouble() : null,
      battery: (m['battery'] is num) ? (m['battery'] as num).toInt() : null,
    );
  }

  static SwitchbotReading fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return fromMap(data);
  }
}

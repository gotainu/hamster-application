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

  static DateTime _parseTs({
    required Map<String, dynamic> m,
    String? fallbackId,
  }) {
    final v = m['ts'];

    // 1) Timestamp で来るケース
    if (v is Timestamp) return v.toDate().toLocal();

    // 2) ISO String で来るケース
    if (v is String) {
      final dt = DateTime.tryParse(v);
      if (dt != null) return dt.toLocal();
    }

    // 3) ts が無い/壊れてる -> doc.id を ts として使う（func_b と同じ思想）
    if (fallbackId != null && fallbackId.isNotEmpty) {
      final dt = DateTime.tryParse(fallbackId);
      if (dt != null) return dt.toLocal();
    }

    // 4) 最後の保険
    return DateTime.fromMillisecondsSinceEpoch(0).toLocal();
  }

  static double? _asDouble(dynamic v) => (v is num) ? v.toDouble() : null;
  static int? _asInt(dynamic v) => (v is num) ? v.toInt() : null;

  static SwitchbotReading fromMap(
    Map<String, dynamic> m, {
    String? fallbackId,
  }) {
    final dt = _parseTs(m: m, fallbackId: fallbackId);

    return SwitchbotReading(
      ts: dt,
      temperature: _asDouble(m['temperature']),
      humidity: _asDouble(m['humidity']),
      battery: _asInt(m['battery']),
    );
  }

  static SwitchbotReading fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return fromMap(data, fallbackId: doc.id);
  }
}

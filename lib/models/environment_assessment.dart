import 'package:cloud_firestore/cloud_firestore.dart';

class EnvironmentAssessment {
  final String? status;
  final String? level;
  final String? headline;
  final String? todayAction;
  final String? why;

  final double? avgTemp;
  final double? avgHum;
  final double? tempRatio;
  final double? humRatio;

  final String? tempState;
  final String? humState;
  final String? tempInterpretation;
  final String? humInterpretation;

  final List<String> evidence;
  final List<String> notes;

  final int? sourceDocCount;
  final int? windowDays;
  final int? version;

  final DateTime? evaluatedAt;

  EnvironmentAssessment({
    required this.status,
    required this.level,
    required this.headline,
    required this.todayAction,
    required this.why,
    required this.avgTemp,
    required this.avgHum,
    required this.tempRatio,
    required this.humRatio,
    required this.tempState,
    required this.humState,
    required this.tempInterpretation,
    required this.humInterpretation,
    required this.evidence,
    required this.notes,
    required this.sourceDocCount,
    required this.windowDays,
    required this.version,
    required this.evaluatedAt,
  });

  static double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static DateTime? _toDateTime(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static List<String> _toStringList(dynamic v) {
    if (v is List) {
      return v.map((e) => e.toString()).toList();
    }
    return const [];
  }

  factory EnvironmentAssessment.fromMap(Map<String, dynamic> m) {
    return EnvironmentAssessment(
      status: m['status']?.toString(),
      level: m['level']?.toString(),
      headline: m['headline']?.toString(),
      todayAction: m['todayAction']?.toString(),
      why: m['why']?.toString(),
      avgTemp: _toDouble(m['avgTemp']),
      avgHum: _toDouble(m['avgHum']),
      tempRatio: _toDouble(m['tempRatio']),
      humRatio: _toDouble(m['humRatio']),
      tempState: m['tempState']?.toString(),
      humState: m['humState']?.toString(),
      tempInterpretation: m['tempInterpretation']?.toString(),
      humInterpretation: m['humInterpretation']?.toString(),
      evidence: _toStringList(m['evidence']),
      notes: _toStringList(m['notes']),
      sourceDocCount: _toInt(m['sourceDocCount']),
      windowDays: _toInt(m['windowDays']),
      version: _toInt(m['version']),
      evaluatedAt: _toDateTime(m['evaluatedAt']),
    );
  }

  bool get hasData =>
      headline != null ||
      todayAction != null ||
      avgTemp != null ||
      avgHum != null ||
      evidence.isNotEmpty;
}

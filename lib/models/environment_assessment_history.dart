import 'package:cloud_firestore/cloud_firestore.dart';

class EnvironmentAssessmentHistory {
  final String? dateKey;
  final String? date;
  final String? aggregatedUnit;

  final String? status;
  final String? level;
  final String? headline;
  final String? todayAction;
  final String? why;

  final double? avgTemp;
  final double? avgHum;
  final double? tempRatio;
  final double? humRatio;

  final int? dangerMinutes;
  final int? spikesTemp;
  final int? spikesHum;

  final int? sourceDocCount;
  final int? windowDays;
  final int? version;

  final DateTime? lastEvaluatedAt;
  final DateTime? updatedAt;

  EnvironmentAssessmentHistory({
    required this.dateKey,
    required this.date,
    required this.aggregatedUnit,
    required this.status,
    required this.level,
    required this.headline,
    required this.todayAction,
    required this.why,
    required this.avgTemp,
    required this.avgHum,
    required this.tempRatio,
    required this.humRatio,
    required this.dangerMinutes,
    required this.spikesTemp,
    required this.spikesHum,
    required this.sourceDocCount,
    required this.windowDays,
    required this.version,
    required this.lastEvaluatedAt,
    required this.updatedAt,
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

  factory EnvironmentAssessmentHistory.fromMap(Map<String, dynamic> m) {
    return EnvironmentAssessmentHistory(
      dateKey: m['dateKey']?.toString(),
      date: m['date']?.toString(),
      aggregatedUnit: m['aggregatedUnit']?.toString(),
      status: m['status']?.toString(),
      level: m['level']?.toString(),
      headline: m['headline']?.toString(),
      todayAction: m['todayAction']?.toString(),
      why: m['why']?.toString(),
      avgTemp: _toDouble(m['avgTemp']),
      avgHum: _toDouble(m['avgHum']),
      tempRatio: _toDouble(m['tempRatio']),
      humRatio: _toDouble(m['humRatio']),
      dangerMinutes: _toInt(m['dangerMinutes']),
      spikesTemp: _toInt(m['spikesTemp']),
      spikesHum: _toInt(m['spikesHum']),
      sourceDocCount: _toInt(m['sourceDocCount']),
      windowDays: _toInt(m['windowDays']),
      version: _toInt(m['version']),
      lastEvaluatedAt: _toDateTime(m['lastEvaluatedAt']),
      updatedAt: _toDateTime(m['updatedAt']),
    );
  }

  bool get hasCoreData =>
      avgTemp != null ||
      avgHum != null ||
      tempRatio != null ||
      humRatio != null ||
      dangerMinutes != null;
}

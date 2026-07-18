import 'package:cloud_firestore/cloud_firestore.dart';

typedef Json = Map<String, dynamic>;

class DailyHealthFeatures {
  final String dateKey;
  final EnvironmentHealthFeatures environment;
  final ActivityHealthFeatures activity;
  final BodyHealthFeatures body;
  final ConditionHealthFeatures condition;
  final NutritionHealthFeatures nutrition;
  final HealthFeatureDataQuality dataQuality;
  final int schemaVersion;
  final DateTime? generatedAt;

  const DailyHealthFeatures({
    required this.dateKey,
    required this.environment,
    required this.activity,
    required this.body,
    required this.condition,
    required this.nutrition,
    required this.dataQuality,
    required this.schemaVersion,
    required this.generatedAt,
  });

  factory DailyHealthFeatures.fromMap(
    Json map, {
    required String fallbackDateKey,
  }) {
    return DailyHealthFeatures(
      dateKey: _string(map['dateKey']) ?? fallbackDateKey,
      environment: EnvironmentHealthFeatures.fromMap(
        _json(map['environment']),
      ),
      activity: ActivityHealthFeatures.fromMap(
        _json(map['activity']),
      ),
      body: BodyHealthFeatures.fromMap(
        _json(map['body']),
      ),
      condition: ConditionHealthFeatures.fromMap(
        _json(map['condition']),
      ),
      nutrition: NutritionHealthFeatures.fromMap(
        _json(map['nutrition']),
      ),
      dataQuality: HealthFeatureDataQuality.fromMap(
        _json(map['dataQuality']),
      ),
      schemaVersion: _integer(map['schemaVersion']) ?? 1,
      generatedAt: _dateTime(map['generatedAt']),
    );
  }

  bool get hasAnyDomainData =>
      environment.hasData ||
      activity.hasData ||
      body.hasData ||
      condition.recorded ||
      nutrition.recorded;

  Json toMap() {
    return {
      'dateKey': dateKey,
      'environment': environment.toMap(),
      'activity': activity.toMap(),
      'body': body.toMap(),
      'condition': condition.toMap(),
      'nutrition': nutrition.toMap(),
      'dataQuality': dataQuality.toMap(),
      'schemaVersion': schemaVersion,
      if (generatedAt != null) 'generatedAt': generatedAt,
    };
  }
}

class EnvironmentHealthFeatures {
  final double? avgTemp;
  final double? avgHum;
  final double? tempRatio;
  final double? humRatio;
  final int? dangerMinutes;
  final int? spikesTemp;
  final int? spikesHum;
  final int? sourceDocCount;
  final int? assessmentVersion;
  final DateTime? sourceEvaluatedAt;

  const EnvironmentHealthFeatures({
    required this.avgTemp,
    required this.avgHum,
    required this.tempRatio,
    required this.humRatio,
    required this.dangerMinutes,
    required this.spikesTemp,
    required this.spikesHum,
    required this.sourceDocCount,
    required this.assessmentVersion,
    required this.sourceEvaluatedAt,
  });

  factory EnvironmentHealthFeatures.fromMap(Json map) {
    return EnvironmentHealthFeatures(
      avgTemp: _double(map['avgTemp']),
      avgHum: _double(map['avgHum']),
      tempRatio: _double(map['tempRatio']),
      humRatio: _double(map['humRatio']),
      dangerMinutes: _integer(map['dangerMinutes']),
      spikesTemp: _integer(map['spikesTemp']),
      spikesHum: _integer(map['spikesHum']),
      sourceDocCount: _integer(map['sourceDocCount']),
      assessmentVersion: _integer(map['assessmentVersion']),
      sourceEvaluatedAt: _dateTime(map['sourceEvaluatedAt']),
    );
  }

  bool get hasData =>
      avgTemp != null ||
      avgHum != null ||
      tempRatio != null ||
      humRatio != null;

  Json toMap() {
    return {
      'avgTemp': avgTemp,
      'avgHum': avgHum,
      'tempRatio': tempRatio,
      'humRatio': humRatio,
      'dangerMinutes': dangerMinutes,
      'spikesTemp': spikesTemp,
      'spikesHum': spikesHum,
      'sourceDocCount': sourceDocCount,
      'assessmentVersion': assessmentVersion,
      if (sourceEvaluatedAt != null) 'sourceEvaluatedAt': sourceEvaluatedAt,
    };
  }
}

class ActivityHealthFeatures {
  final bool hasRecord;
  final double? distanceMeters;
  final int? rotations;
  final double? wheelDiameterCm;
  final double? avg7DistanceMeters;
  final double? deltaPct;
  final DateTime? recordDate;

  const ActivityHealthFeatures({
    required this.hasRecord,
    required this.distanceMeters,
    required this.rotations,
    required this.wheelDiameterCm,
    required this.avg7DistanceMeters,
    required this.deltaPct,
    required this.recordDate,
  });

  factory ActivityHealthFeatures.fromMap(Json map) {
    return ActivityHealthFeatures(
      hasRecord: _boolean(map['hasRecord']) ?? false,
      distanceMeters: _double(map['distanceMeters']),
      rotations: _integer(map['rotations']),
      wheelDiameterCm: _double(map['wheelDiameterCm']),
      avg7DistanceMeters: _double(map['avg7DistanceMeters']),
      deltaPct: _double(map['deltaPct']),
      recordDate: _dateTime(map['recordDate']),
    );
  }

  bool get hasData => hasRecord || distanceMeters != null;

  Json toMap() {
    return {
      'hasRecord': hasRecord,
      'distanceMeters': distanceMeters,
      'rotations': rotations,
      'wheelDiameterCm': wheelDiameterCm,
      'avg7DistanceMeters': avg7DistanceMeters,
      'deltaPct': deltaPct,
      if (recordDate != null) 'recordDate': recordDate,
    };
  }
}

class BodyHealthFeatures {
  final double? latestWeightGrams;
  final DateTime? latestWeightDate;
  final int? daysSinceMeasurement;
  final double? previousWeightGrams;
  final double? previousDifferenceGrams;
  final double? previousChangeRate;
  final int windowDays;
  final double? windowChangeRate;
  final int windowRecordCount;
  final int totalRecordCount;

  const BodyHealthFeatures({
    required this.latestWeightGrams,
    required this.latestWeightDate,
    required this.daysSinceMeasurement,
    required this.previousWeightGrams,
    required this.previousDifferenceGrams,
    required this.previousChangeRate,
    required this.windowDays,
    required this.windowChangeRate,
    required this.windowRecordCount,
    required this.totalRecordCount,
  });

  factory BodyHealthFeatures.fromMap(Json map) {
    return BodyHealthFeatures(
      latestWeightGrams: _double(map['latestWeightGrams']),
      latestWeightDate: _dateTime(map['latestWeightDate']),
      daysSinceMeasurement: _integer(map['daysSinceMeasurement']),
      previousWeightGrams: _double(map['previousWeightGrams']),
      previousDifferenceGrams: _double(map['previousDifferenceGrams']),
      previousChangeRate: _double(map['previousChangeRate']),
      windowDays: _integer(map['windowDays']) ?? 30,
      windowChangeRate: _double(map['windowChangeRate']),
      windowRecordCount: _integer(map['windowRecordCount']) ?? 0,
      totalRecordCount: _integer(map['totalRecordCount']) ?? 0,
    );
  }

  bool get hasData => latestWeightGrams != null;

  bool get isStale {
    final days = daysSinceMeasurement;
    return days != null && days >= 14;
  }

  Json toMap() {
    return {
      'latestWeightGrams': latestWeightGrams,
      if (latestWeightDate != null) 'latestWeightDate': latestWeightDate,
      'daysSinceMeasurement': daysSinceMeasurement,
      'previousWeightGrams': previousWeightGrams,
      'previousDifferenceGrams': previousDifferenceGrams,
      'previousChangeRate': previousChangeRate,
      'windowDays': windowDays,
      'windowChangeRate': windowChangeRate,
      'windowRecordCount': windowRecordCount,
      'totalRecordCount': totalRecordCount,
    };
  }
}

class ConditionHealthFeatures {
  final bool recorded;
  final String? condition;
  final List<String> concernTags;
  final String memo;
  final DateTime? recordDate;

  const ConditionHealthFeatures({
    required this.recorded,
    required this.condition,
    required this.concernTags,
    required this.memo,
    required this.recordDate,
  });

  factory ConditionHealthFeatures.fromMap(Json map) {
    return ConditionHealthFeatures(
      recorded: _boolean(map['recorded']) ?? false,
      condition: _string(map['condition']),
      concernTags: _stringList(map['concernTags']),
      memo: _string(map['memo']) ?? '',
      recordDate: _dateTime(map['recordDate']),
    );
  }

  Json toMap() {
    return {
      'recorded': recorded,
      'condition': condition,
      'concernTags': concernTags,
      'memo': memo,
      if (recordDate != null) 'recordDate': recordDate,
    };
  }
}

class NutritionHealthFeatures {
  final bool recorded;
  final double? foodOfferedGrams;
  final double? foodRemainingGrams;
  final double? foodConsumedGrams;
  final String memo;
  final DateTime? recordDate;

  const NutritionHealthFeatures({
    required this.recorded,
    required this.foodOfferedGrams,
    required this.foodRemainingGrams,
    required this.foodConsumedGrams,
    required this.memo,
    required this.recordDate,
  });

  factory NutritionHealthFeatures.fromMap(Json map) {
    return NutritionHealthFeatures(
      recorded: _boolean(map['recorded']) ?? false,
      foodOfferedGrams: _double(map['foodOfferedGrams']),
      foodRemainingGrams: _double(map['foodRemainingGrams']),
      foodConsumedGrams: _double(map['foodConsumedGrams']),
      memo: _string(map['memo']) ?? '',
      recordDate: _dateTime(map['recordDate']),
    );
  }

  Json toMap() {
    return {
      'recorded': recorded,
      'foodOfferedGrams': foodOfferedGrams,
      'foodRemainingGrams': foodRemainingGrams,
      'foodConsumedGrams': foodConsumedGrams,
      'memo': memo,
      if (recordDate != null) 'recordDate': recordDate,
    };
  }
}

class HealthFeatureDataQuality {
  final List<String> availableDomains;
  final List<String> missingDomains;
  final List<String> staleDomains;
  final double completeness;

  const HealthFeatureDataQuality({
    required this.availableDomains,
    required this.missingDomains,
    required this.staleDomains,
    required this.completeness,
  });

  factory HealthFeatureDataQuality.fromMap(Json map) {
    return HealthFeatureDataQuality(
      availableDomains: _stringList(map['availableDomains']),
      missingDomains: _stringList(map['missingDomains']),
      staleDomains: _stringList(map['staleDomains']),
      completeness: _double(map['completeness']) ?? 0,
    );
  }

  Json toMap() {
    return {
      'availableDomains': availableDomains,
      'missingDomains': missingDomains,
      'staleDomains': staleDomains,
      'completeness': completeness,
    };
  }
}

Json _json(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key.toString(), item),
    );
  }
  return <String, dynamic>{};
}

String? _string(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

double? _double(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int? _integer(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

bool? _boolean(dynamic value) {
  if (value is bool) return value;
  if (value is String) {
    if (value.toLowerCase() == 'true') return true;
    if (value.toLowerCase() == 'false') return false;
  }
  return null;
}

DateTime? _dateTime(dynamic value) {
  if (value is Timestamp) return value.toDate().toLocal();
  if (value is DateTime) return value.toLocal();
  if (value is String) return DateTime.tryParse(value)?.toLocal();
  return null;
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

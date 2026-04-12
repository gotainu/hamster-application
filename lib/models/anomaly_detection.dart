// /Users/gota/local_dev/flutter_projects/hamster_project/lib/models/anomaly_detection.dart

enum AnomalySeverity {
  info,
  low,
  medium,
  high,
}

enum AnomalyFlag {
  highHumidityStreak,
  lowTemperatureStreak,
  highTemperatureStreak,
  dangerMinutesDetected,
  tempSpikeDetected,
  humiditySpikeDetected,
  tempRatioWorsened,
  humidityRatioWorsened,
  cautionLevelStreak,
  dangerLevelDetected,
}

class DetectedAnomaly {
  final AnomalyFlag flag;
  final AnomalySeverity severity;

  /// UIや通知で使う短い見出し
  final String title;

  /// 詳細説明
  final String description;

  /// 直近何日連続か、何回か、何分か、などの補助値
  final int? count;
  final double? value;

  /// 検知区間
  final String? startDateKey;
  final String? endDateKey;

  const DetectedAnomaly({
    required this.flag,
    required this.severity,
    required this.title,
    required this.description,
    this.count,
    this.value,
    this.startDateKey,
    this.endDateKey,
  });

  bool get isHighSeverity => severity == AnomalySeverity.high;
  bool get isMediumOrHigher => severity.index >= AnomalySeverity.medium.index;
}

class AnomalyDetectionResult {
  final List<DetectedAnomaly> anomalies;

  /// 検知対象期間（日）
  final int windowDays;

  /// 検知実行時刻
  final DateTime detectedAt;

  const AnomalyDetectionResult({
    required this.anomalies,
    required this.windowDays,
    required this.detectedAt,
  });

  bool get hasAnomaly => anomalies.isNotEmpty;

  bool get hasHighSeverity =>
      anomalies.any((a) => a.severity == AnomalySeverity.high);

  List<DetectedAnomaly> get highOrMediumAnomalies => anomalies
      .where((a) => a.severity.index >= AnomalySeverity.medium.index)
      .toList();

  DetectedAnomaly? get topAnomaly {
    if (anomalies.isEmpty) return null;

    final sorted = [...anomalies]..sort((a, b) {
        final severityCompare = b.severity.index.compareTo(a.severity.index);
        if (severityCompare != 0) return severityCompare;

        final countCompare = (b.count ?? 0).compareTo(a.count ?? 0);
        if (countCompare != 0) return countCompare;

        return (b.value ?? 0).compareTo(a.value ?? 0);
      });

    return sorted.first;
  }
}

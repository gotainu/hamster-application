// /Users/gota/local_dev/flutter_projects/hamster_project/lib/services/anomaly_notification_decision_service.dart

import '../models/anomaly_detection.dart';
import '../models/anomaly_notification_decision.dart';

class AnomalyNotificationDecisionService {
  final Duration dedupeWindow;
  final AnomalySeverity minimumSeverity;

  const AnomalyNotificationDecisionService({
    this.dedupeWindow = const Duration(hours: 24),
    this.minimumSeverity = AnomalySeverity.high,
  });

  AnomalyNotificationDecision decide({
    required AnomalyDetectionResult detectionResult,

    /// 同一通知を最後に送った時刻。
    /// 未送信なら null。
    DateTime? lastSentAt,

    /// 「まだ継続中の異常」と見なすかどうか。
    /// 初期実装では true を渡せば十分。
    required bool isStillActive,
  }) {
    final anomaly = detectionResult.topAnomaly;
    if (anomaly == null) {
      return AnomalyNotificationDecision.noAnomaly();
    }

    if (!_meetsSeverityThreshold(anomaly)) {
      return AnomalyNotificationDecision.belowSeverityThreshold(
        anomaly: anomaly,
      );
    }

    if (!isStillActive) {
      return AnomalyNotificationDecision.inactive(
        anomaly: anomaly,
      );
    }

    if (_wasSentRecently(
      lastSentAt: lastSentAt,
      detectedAt: detectionResult.detectedAt,
    )) {
      return AnomalyNotificationDecision.alreadySentRecently(
        anomaly: anomaly,
      );
    }

    return AnomalyNotificationDecision.shouldNotify(
      anomaly: anomaly,
    );
  }

  bool _meetsSeverityThreshold(DetectedAnomaly anomaly) {
    return anomaly.severity.index >= minimumSeverity.index;
  }

  bool _wasSentRecently({
    required DateTime? lastSentAt,
    required DateTime detectedAt,
  }) {
    if (lastSentAt == null) return false;

    final diff = detectedAt.difference(lastSentAt);
    return diff < dedupeWindow;
  }
}

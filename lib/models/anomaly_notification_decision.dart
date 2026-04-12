// /Users/gota/local_dev/flutter_projects/hamster_project/lib/models/anomaly_notification_decision.dart

import 'anomaly_detection.dart';

enum AnomalyNotificationReason {
  noAnomaly,
  belowSeverityThreshold,
  alreadySentRecently,
  inactive,
  shouldNotify,
}

class AnomalyNotificationDecision {
  /// 通知するかどうか
  final bool shouldNotify;

  /// 判定理由
  final AnomalyNotificationReason reason;

  /// 通知対象の異常
  final DetectedAnomaly? anomaly;

  /// 通知履歴の保存・重複判定に使うキー
  final String? notificationKey;

  /// 同一通知かどうかを判定するための簡易 fingerprint
  final String? fingerprint;

  /// 人間がログで見やすい説明
  final String message;

  const AnomalyNotificationDecision({
    required this.shouldNotify,
    required this.reason,
    required this.anomaly,
    required this.notificationKey,
    required this.fingerprint,
    required this.message,
  });

  factory AnomalyNotificationDecision.noAnomaly() {
    return const AnomalyNotificationDecision(
      shouldNotify: false,
      reason: AnomalyNotificationReason.noAnomaly,
      anomaly: null,
      notificationKey: null,
      fingerprint: null,
      message: '通知対象の異常はありません。',
    );
  }

  factory AnomalyNotificationDecision.belowSeverityThreshold({
    required DetectedAnomaly anomaly,
  }) {
    return AnomalyNotificationDecision(
      shouldNotify: false,
      reason: AnomalyNotificationReason.belowSeverityThreshold,
      anomaly: anomaly,
      notificationKey: _buildNotificationKey(anomaly),
      fingerprint: _buildFingerprint(anomaly),
      message: '異常はありますが、通知閾値未満です。',
    );
  }

  factory AnomalyNotificationDecision.alreadySentRecently({
    required DetectedAnomaly anomaly,
  }) {
    return AnomalyNotificationDecision(
      shouldNotify: false,
      reason: AnomalyNotificationReason.alreadySentRecently,
      anomaly: anomaly,
      notificationKey: _buildNotificationKey(anomaly),
      fingerprint: _buildFingerprint(anomaly),
      message: '同種の通知を直近24時間以内に送信済みです。',
    );
  }

  factory AnomalyNotificationDecision.inactive({
    required DetectedAnomaly anomaly,
  }) {
    return AnomalyNotificationDecision(
      shouldNotify: false,
      reason: AnomalyNotificationReason.inactive,
      anomaly: anomaly,
      notificationKey: _buildNotificationKey(anomaly),
      fingerprint: _buildFingerprint(anomaly),
      message: '異常は現在アクティブではないため通知しません。',
    );
  }

  factory AnomalyNotificationDecision.shouldNotify({
    required DetectedAnomaly anomaly,
  }) {
    return AnomalyNotificationDecision(
      shouldNotify: true,
      reason: AnomalyNotificationReason.shouldNotify,
      anomaly: anomaly,
      notificationKey: _buildNotificationKey(anomaly),
      fingerprint: _buildFingerprint(anomaly),
      message: '通知条件を満たしたため送信対象です。',
    );
  }

  static String _buildNotificationKey(DetectedAnomaly anomaly) {
    final start = anomaly.startDateKey ?? 'unknown_start';
    final end = anomaly.endDateKey ?? 'unknown_end';
    return '${anomaly.flag.name}__${start}__$end';
  }

  static String _buildFingerprint(DetectedAnomaly anomaly) {
    final countPart = anomaly.count?.toString() ?? 'null';
    final valuePart = anomaly.value?.toStringAsFixed(2) ?? 'null';
    final start = anomaly.startDateKey ?? 'unknown_start';
    final end = anomaly.endDateKey ?? 'unknown_end';

    return [
      anomaly.flag.name,
      anomaly.severity.name,
      countPart,
      valuePart,
      start,
      end,
    ].join('__');
  }
}

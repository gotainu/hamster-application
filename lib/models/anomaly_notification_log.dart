// /Users/gota/local_dev/flutter_projects/hamster_project/lib/models/anomaly_notification_log.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class AnomalyNotificationLog {
  /// 通知履歴ドキュメントIDに使いやすいキー
  final String notificationKey;

  /// 同一通知判定用 fingerprint
  final String fingerprint;

  /// 異常種別
  final String anomalyFlag;

  /// severity の文字列表現
  final String severity;

  /// 通知タイトル
  final String title;

  /// 通知本文
  final String body;

  /// 検知対象期間
  final String? startDateKey;
  final String? endDateKey;

  /// 通知送信時刻
  final DateTime? sentAt;

  /// 作成/更新時刻
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AnomalyNotificationLog({
    required this.notificationKey,
    required this.fingerprint,
    required this.anomalyFlag,
    required this.severity,
    required this.title,
    required this.body,
    required this.startDateKey,
    required this.endDateKey,
    required this.sentAt,
    required this.createdAt,
    required this.updatedAt,
  });

  static DateTime? _toDateTime(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  factory AnomalyNotificationLog.fromMap(Map<String, dynamic> m) {
    return AnomalyNotificationLog(
      notificationKey: m['notificationKey']?.toString() ?? '',
      fingerprint: m['fingerprint']?.toString() ?? '',
      anomalyFlag: m['anomalyFlag']?.toString() ?? '',
      severity: m['severity']?.toString() ?? '',
      title: m['title']?.toString() ?? '',
      body: m['body']?.toString() ?? '',
      startDateKey: m['startDateKey']?.toString(),
      endDateKey: m['endDateKey']?.toString(),
      sentAt: _toDateTime(m['sentAt']),
      createdAt: _toDateTime(m['createdAt']),
      updatedAt: _toDateTime(m['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationKey': notificationKey,
      'fingerprint': fingerprint,
      'anomalyFlag': anomalyFlag,
      'severity': severity,
      'title': title,
      'body': body,
      'startDateKey': startDateKey,
      'endDateKey': endDateKey,
      'sentAt': sentAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  AnomalyNotificationLog copyWith({
    String? notificationKey,
    String? fingerprint,
    String? anomalyFlag,
    String? severity,
    String? title,
    String? body,
    String? startDateKey,
    String? endDateKey,
    DateTime? sentAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AnomalyNotificationLog(
      notificationKey: notificationKey ?? this.notificationKey,
      fingerprint: fingerprint ?? this.fingerprint,
      anomalyFlag: anomalyFlag ?? this.anomalyFlag,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      body: body ?? this.body,
      startDateKey: startDateKey ?? this.startDateKey,
      endDateKey: endDateKey ?? this.endDateKey,
      sentAt: sentAt ?? this.sentAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

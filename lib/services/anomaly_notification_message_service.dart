// /Users/gota/local_dev/flutter_projects/hamster_project/lib/services/anomaly_notification_message_service.dart

import '../models/anomaly_detection.dart';
import '../models/anomaly_notification_decision.dart';
import '../models/anomaly_notification_log.dart';

class AnomalyNotificationMessage {
  final String title;
  final String body;

  const AnomalyNotificationMessage({
    required this.title,
    required this.body,
  });
}

class AnomalyNotificationMessageService {
  const AnomalyNotificationMessageService();

  AnomalyNotificationMessage buildMessage({
    required DetectedAnomaly anomaly,
  }) {
    return AnomalyNotificationMessage(
      title: _buildTitle(anomaly),
      body: _buildBody(anomaly),
    );
  }

  AnomalyNotificationLog buildLog({
    required AnomalyNotificationDecision decision,
    required DateTime sentAt,
  }) {
    final anomaly = decision.anomaly;
    if (anomaly == null ||
        decision.notificationKey == null ||
        decision.fingerprint == null) {
      throw ArgumentError(
        '通知ログを作るには anomaly / notificationKey / fingerprint が必要です。',
      );
    }

    final message = buildMessage(anomaly: anomaly);

    return AnomalyNotificationLog(
      notificationKey: decision.notificationKey!,
      fingerprint: decision.fingerprint!,
      anomalyFlag: anomaly.flag.name,
      severity: anomaly.severity.name,
      title: message.title,
      body: message.body,
      startDateKey: anomaly.startDateKey,
      endDateKey: anomaly.endDateKey,
      sentAt: sentAt,
      createdAt: sentAt,
      updatedAt: sentAt,
    );
  }

  String _buildTitle(DetectedAnomaly anomaly) {
    switch (anomaly.flag) {
      case AnomalyFlag.highHumidityStreak:
        return '湿度が高めの状態が続いています';
      case AnomalyFlag.lowTemperatureStreak:
        return '温度が低めの状態が続いています';
      case AnomalyFlag.highTemperatureStreak:
        return '温度が高めの状態が続いています';
      case AnomalyFlag.dangerMinutesDetected:
        return '危険域への滞在が検出されました';
      case AnomalyFlag.tempSpikeDetected:
        return '温度の急変が増えています';
      case AnomalyFlag.humiditySpikeDetected:
        return '湿度の急変が増えています';
      case AnomalyFlag.tempRatioWorsened:
        return '温度の適正度が悪化しています';
      case AnomalyFlag.humidityRatioWorsened:
        return '湿度の適正度が悪化しています';
      case AnomalyFlag.cautionLevelStreak:
        return '注意評価が続いています';
      case AnomalyFlag.dangerLevelDetected:
        return '危険評価が検出されました';
    }
  }

  String _buildBody(DetectedAnomaly anomaly) {
    final period = _buildPeriodText(anomaly);
    final severityText = _severityText(anomaly.severity);

    switch (anomaly.flag) {
      case AnomalyFlag.highHumidityStreak:
        final days = anomaly.count ?? 0;
        final hum = anomaly.value?.round();
        return hum != null
            ? '$period湿度が高めの状態が$days日連続です。最新の平均湿度は${hum}%です。状態をご確認ください。[$severityText]'
            : '$period湿度が高めの状態が${days}日連続です。状態をご確認ください。[$severityText]';

      case AnomalyFlag.lowTemperatureStreak:
        final days = anomaly.count ?? 0;
        final temp = anomaly.value;
        return temp != null
            ? '$period温度が低めの状態が$days日連続です。最新の平均温度は${temp.toStringAsFixed(1)}℃です。[$severityText]'
            : '$period温度が低めの状態が${days}日連続です。[$severityText]';

      case AnomalyFlag.highTemperatureStreak:
        final days = anomaly.count ?? 0;
        final temp = anomaly.value;
        return temp != null
            ? '$period温度が高めの状態が$days日連続です。最新の平均温度は${temp.toStringAsFixed(1)}℃です。[$severityText]'
            : '$period温度が高めの状態が${days}日連続です。[$severityText]';

      case AnomalyFlag.dangerMinutesDetected:
        final minutes = anomaly.value?.round() ?? 0;
        return '$period直近の評価で危険域への滞在が検出されました。最大${minutes}分です。早めの確認をおすすめします。[$severityText]';

      case AnomalyFlag.tempSpikeDetected:
        final count = anomaly.count ?? anomaly.value?.round() ?? 0;
        return '$period直近で温度急変が$count回ありました。温度の安定性が崩れている可能性があります。[$severityText]';

      case AnomalyFlag.humiditySpikeDetected:
        final count = anomaly.count ?? anomaly.value?.round() ?? 0;
        return '$period直近で湿度急変が$count回ありました。湿度の安定性が崩れている可能性があります。[$severityText]';

      case AnomalyFlag.tempRatioWorsened:
        final deltaPt =
            anomaly.value != null ? (anomaly.value! * 100).round() : null;
        return deltaPt != null
            ? '$period温度の適正度が前回より${deltaPt}pt悪化しました。[$severityText]'
            : '$period温度の適正度が悪化しています。[$severityText]';

      case AnomalyFlag.humidityRatioWorsened:
        final deltaPt =
            anomaly.value != null ? (anomaly.value! * 100).round() : null;
        return deltaPt != null
            ? '$period湿度の適正度が前回より${deltaPt}pt悪化しました。[$severityText]'
            : '$period湿度の適正度が悪化しています。[$severityText]';

      case AnomalyFlag.cautionLevelStreak:
        final days = anomaly.count ?? 0;
        return '$period環境評価の「注意」が${days}日連続です。状況の固定化にご注意ください。[$severityText]';

      case AnomalyFlag.dangerLevelDetected:
        return '$period直近3日以内に環境評価「危険」が検出されました。至急状態をご確認ください。[$severityText]';
    }
  }

  String _buildPeriodText(DetectedAnomaly anomaly) {
    final start = anomaly.startDateKey;
    final end = anomaly.endDateKey;

    if (start == null && end == null) return '';
    if (start != null && end != null) {
      if (start == end) {
        return '[$start] ';
      }
      return '[$start〜$end] ';
    }
    if (start != null) return '[$start〜] ';
    return '[〜$end] ';
  }

  String _severityText(AnomalySeverity severity) {
    switch (severity) {
      case AnomalySeverity.info:
        return '情報';
      case AnomalySeverity.low:
        return '低';
      case AnomalySeverity.medium:
        return '中';
      case AnomalySeverity.high:
        return '高';
    }
  }
}

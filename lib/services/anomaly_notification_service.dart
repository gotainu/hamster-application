// /Users/gota/local_dev/flutter_projects/hamster_project/lib/services/anomaly_notification_service.dart

import '../models/anomaly_detection.dart';
import '../models/anomaly_notification_decision.dart';
import '../models/anomaly_notification_log.dart';
import '../models/environment_assessment_history.dart';
import 'anomaly_detection_service.dart';
import 'anomaly_notification_decision_service.dart';
import 'anomaly_notification_message_service.dart';
import 'anomaly_notification_log_repo.dart';

class AnomalyNotificationService {
  final AnomalyDetectionService _detectionService;
  final AnomalyNotificationDecisionService _decisionService;
  final AnomalyNotificationMessageService _messageService;
  final AnomalyNotificationLogRepo _logRepo;

  const AnomalyNotificationService({
    AnomalyDetectionService detectionService = const AnomalyDetectionService(),
    AnomalyNotificationDecisionService decisionService =
        const AnomalyNotificationDecisionService(),
    AnomalyNotificationMessageService messageService =
        const AnomalyNotificationMessageService(),
    required AnomalyNotificationLogRepo logRepo,
  })  : _detectionService = detectionService,
        _decisionService = decisionService,
        _messageService = messageService,
        _logRepo = logRepo;

  Future<AnomalyNotificationExecutionResult> execute({
    required List<EnvironmentAssessmentHistory> history,
    int windowDays = 14,

    /// 初期実装では true 固定でもよい
    required bool isStillActive,

    /// true の時だけ sentAt を保存する
    /// 最初は false で dry-run 的に使える
    bool markAsSent = false,
  }) async {
    final detectionResult = _detectionService.detect(
      history: history,
      windowDays: windowDays,
    );

    final topAnomaly = detectionResult.topAnomaly;

    DateTime? lastSentAt;
    if (topAnomaly != null) {
      final tempDecision = AnomalyNotificationDecision.shouldNotify(
        anomaly: topAnomaly,
      );
      final notificationKey = tempDecision.notificationKey;
      if (notificationKey != null) {
        lastSentAt = await _logRepo.fetchLastSentAt(notificationKey);
      }
    }

    final decision = _decisionService.decide(
      detectionResult: detectionResult,
      lastSentAt: lastSentAt,
      isStillActive: isStillActive,
    );

    AnomalyNotificationMessage? message;
    AnomalyNotificationLog? log;

    if (decision.anomaly != null &&
        decision.notificationKey != null &&
        decision.fingerprint != null) {
      message = _messageService.buildMessage(
        anomaly: decision.anomaly!,
      );

      final now = DateTime.now();

      log = AnomalyNotificationLog(
        notificationKey: decision.notificationKey!,
        fingerprint: decision.fingerprint!,
        anomalyFlag: decision.anomaly!.flag.name,
        severity: decision.anomaly!.severity.name,
        title: message.title,
        body: message.body,
        startDateKey: decision.anomaly!.startDateKey,
        endDateKey: decision.anomaly!.endDateKey,
        sentAt: null,
        createdAt: now,
        updatedAt: now,
      );

      await _logRepo.saveLog(log);

      if (markAsSent && decision.shouldNotify) {
        final sentLog = log.copyWith(
          sentAt: now,
          updatedAt: now,
        );
        await _logRepo.markAsSent(sentLog);
        log = sentLog;
      }
    }

    return AnomalyNotificationExecutionResult(
      detectionResult: detectionResult,
      decision: decision,
      message: message,
      log: log,
    );
  }
}

class AnomalyNotificationExecutionResult {
  final AnomalyDetectionResult detectionResult;
  final AnomalyNotificationDecision decision;
  final AnomalyNotificationMessage? message;
  final AnomalyNotificationLog? log;

  const AnomalyNotificationExecutionResult({
    required this.detectionResult,
    required this.decision,
    required this.message,
    required this.log,
  });
}

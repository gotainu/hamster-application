import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Analytics へ送るプロダクトイベントの唯一の入口。
///
/// 自由記述、ユーザーID、メールアドレス、トークン、機器IDは送らない。
final class AppAnalytics {
  AppAnalytics._();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static Future<void> logHomeView({required String source}) {
    return _log('home_view', {'source': source});
  }

  static Future<void> logDailyInputComplete({
    required String condition,
    required int concernTagCount,
    required bool hasMemo,
  }) {
    return _log('daily_input_complete', {
      'condition': condition,
      'concern_tag_count': concernTagCount,
      'has_memo': hasMemo ? 1 : 0,
    });
  }

  static Future<void> logAiConsultationStarted({required bool hasHistory}) {
    return _log('ai_consultation_started', {
      'has_history': hasHistory ? 1 : 0,
    });
  }

  static Future<void> logAiConsultationCompleted({
    required int retrievedChunkCount,
  }) {
    return _log('ai_consultation_completed', {
      'retrieved_chunk_count': retrievedChunkCount,
    });
  }

  static Future<void> logAiConsultationFailed() {
    return _log('ai_consultation_failed');
  }

  static Future<void> logNotificationOpened({
    required String source,
    required String notificationType,
  }) {
    return _log('anomaly_notification_open', {
      'source': source,
      'notification_type': notificationType,
    });
  }

  static Future<void> logNotificationSettingChanged({required bool enabled}) {
    return _log('notification_setting_change', {
      'enabled': enabled ? 1 : 0,
    });
  }

  static Future<void> logCheckoutStarted() {
    return _log('checkout_started', {
      'source': 'subscription_plan',
      'plan': 'monthly',
    });
  }

  static Future<void> logCheckoutOpened() {
    return _log('checkout_opened', {
      'source': 'subscription_plan',
      'plan': 'monthly',
    });
  }

  static Future<void> logCheckoutFailed() {
    return _log('checkout_failed', {
      'source': 'subscription_plan',
      'plan': 'monthly',
    });
  }

  static Future<void> _log(
    String name, [
    Map<String, Object>? parameters,
  ]) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (error) {
      // 計測失敗でユーザー操作を失敗させない。
      debugPrint('[Analytics] $name skipped (${error.runtimeType})');
    }
  }
}

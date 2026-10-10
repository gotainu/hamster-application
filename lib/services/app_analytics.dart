import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Analytics へ送るプロダクトイベントの唯一の入口。
///
/// Firebase Auth UID is set only as Analytics' standard User-ID.  Free text,
/// names, email addresses, tokens, and device identifiers are never event
/// parameters or user properties.
final class AppAnalytics {
  AppAnalytics._();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static const bool _isTestBuild =
      bool.fromEnvironment('HAMCARE_TEST_BUILD', defaultValue: false);
  static Future<void> _identityBarrier = Future<void>.value();
  static String? _requestedUserId;
  static bool _identityReady = false;

  static Future<void> setUserId(String uid) async {
    final normalized = uid.trim();
    if (normalized.isEmpty || normalized == 'null') return;
    await _queueUserId(normalized);
  }

  static Future<void> clearUserId() async {
    await _queueUserId(null);
  }

  /// Serializes login/logout/account-switch updates. Events wait behind this
  /// barrier, so an async A -> B transition cannot be attributed to A after B
  /// is already the current account. Analytics failures stay non-fatal.
  static Future<void> _queueUserId(String? uid) {
    _requestedUserId = uid;
    final target = uid;
    _identityBarrier = _identityBarrier.then((_) async {
      if (_requestedUserId != target) return;
      try {
        await _analytics.setUserId(id: target);
        if (_requestedUserId == target) _identityReady = true;
      } catch (error) {
        if (_requestedUserId == target) _identityReady = false;
        debugPrint('[Analytics] user ID update skipped (${error.runtimeType})');
      }
    });
    return _identityBarrier;
  }

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

  static Future<void> logEntitlementEvent(
    String event, {
    required String flowVersion,
    String? outcome,
  }) =>
      _log(event, {
        'flow_version': flowVersion,
        if (outcome != null) 'outcome': outcome,
      });

  static Future<void> logPaywallPresented({
    required String featureName,
    required String presentationId,
  }) =>
      _log('paywall_presented', {
        'flow_version': 'initial_trial_v2',
        'feature_name': featureName,
        'presentation_id': presentationId,
      });

  static Future<void> logAnalysisReportViewed({
    required String reportId,
    required String petId,
    required int revision,
    required String presentationId,
    required bool autoPresented,
    String? expectedUserId,
  }) =>
      _log(
          'personalized_report_viewed',
          {
            'report_id': reportId,
            'pet_id': petId,
            'analysis_revision': revision,
            'presentation_id': presentationId,
            'auto_presented': autoPresented ? 1 : 0,
          },
          expectedUserId);

  static Future<void> logPersonalityReportViewed({
    required String? expectedUserId,
    required String reportId,
    required String petId,
    required int revision,
    required String presentationId,
    required bool isFirstView,
  }) =>
      _log(
          'personalized_report_viewed',
          {
            'report_id': reportId,
            'pet_id': petId,
            'analysis_revision': revision,
            'presentation_id': presentationId,
            'auto_presented': 0,
            'report_kind': 'personality',
            'is_first_view': isFirstView ? 1 : 0,
          },
          expectedUserId);

  static Future<void> logOnboardingEvent(
    String event, {
    String? method,
  }) {
    return _log(event, {
      'flow_version': 2,
      if (method != null) 'method': method,
    });
  }

  static Future<void> logMonitoringMethodSelected({
    required String method,
    required int position,
    required String presentationId,
  }) =>
      _log('monitoring_method_selected', {
        'flow_version': 3,
        'offer_version': 'monitoring_methods_v1',
        'offered_order': 'switchbot,daily_checkin,weight,wheel',
        'selected_method': method,
        'selected_position': position,
        'presentation_id': presentationId,
      });

  static Future<void> logMonitoringMethodPresented({
    required String presentationId,
  }) =>
      _log('monitoring_method_presented', {
        'flow_version': 3,
        'offer_version': 'monitoring_methods_v1',
        'offered_order': 'switchbot,daily_checkin,weight,wheel',
        'availability':
            'switchbot:available,daily_checkin:available,weight:available,wheel:available',
        'presentation_id': presentationId,
      });

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
    String? expectedUserId,
  ]) async {
    // Do not make callers coordinate authentication and analytics themselves.
    // A failed identity update is caught above and never blocks product UI.
    await _identityBarrier;
    if (expectedUserId != null && _requestedUserId != expectedUserId) return;
    if (!_identityReady) {
      debugPrint(
          '[Analytics] $name skipped because the current user ID is unconfirmed');
      return;
    }
    try {
      await _analytics.logEvent(
        name: name,
        parameters: {
          ...?parameters,
          'analytics_identity_version': 'firebase_uid_v1',
          if (_isTestBuild) 'test_only': 1,
        },
      );
    } catch (error) {
      // 計測失敗でユーザー操作を失敗させない。
      debugPrint('[Analytics] $name skipped (${error.runtimeType})');
    }
  }
}

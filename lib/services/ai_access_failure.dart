import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'pending_chat_request_store.dart';

/// User-facing failures are selected from a fixed vocabulary. Server bodies and
/// plugin exception messages may contain private/internal details and are never
/// displayed or included in this object's diagnostic code.
class AiAccessFailure implements Exception {
  const AiAccessFailure(this.code, this.message, {this.statusCode});

  final String code;
  final String message;
  final int? statusCode;

  static const _messages = <String, String>{
    'trial_not_started': 'AI相談を使うには、無料体験を開始するか利用プランをご確認ください。',
    'trial_expired': '無料体験の利用期間が終了しています。利用プランをご確認ください。',
    'trial_limit_reached': '無料体験のAI相談の利用枠を使い切りました。利用プランをご確認ください。',
    'operator_unavailable': '現在、運営側の利用設定または共通利用枠の確認が必要なため、AI相談を利用できません。',
    'rate_limited': '短時間に送信が集中しています。少し時間をおいて再度お試しください。',
    'auth_required': 'ログイン情報を確認できませんでした。もう一度ログインしてください。',
    'app_check_failed': 'アプリの認証を確認できませんでした。アプリを開き直し、問題が続く場合はお問い合わせください。',
    'access_required': '無料体験または有料プランの利用状態をご確認ください。',
    'invalid_request': '質問または会話履歴が長すぎるか、形式を確認できませんでした。質問を短くして再度お試しください。',
    'request_pending': '前回の相談の処理結果を確認できていません。再送せず、問題が続く場合はお問い合わせください。',
    'network_unavailable': '通信が途切れ、相談の結果を確認できませんでした。別の相談として送り直さず、接続をご確認ください。',
    'ai_provider_unavailable': 'AI相談サービスに問題が発生しています。問題が続く場合はお問い合わせください。',
    'ai_result_unknown': 'AI相談の結果を確認できませんでした。再送せず、問題が続く場合はお問い合わせください。',
    'request_rejected': '現在AI相談を受け付けられません。問題が続く場合はお問い合わせください。',
    'pending_request_unavailable':
        '相談の送信状態を安全に保存できませんでした。相談画面を開き直し、問題が続く場合はお問い合わせください。',
    'unknown': 'AI相談を完了できませんでした。問題が続く場合はお問い合わせください。',
  };

  static const _codeCategories = <String, String>{
    'ai_trial_not_started': 'trial_not_started',
    'ai_trial_expired': 'trial_expired',
    'ai_trial_inactive': 'access_required',
    'ai_personal_limit_reached': 'trial_limit_reached',
    'ai_shared_budget_exhausted': 'operator_unavailable',
    'ai_limits_not_configured': 'operator_unavailable',
    'ai_validation_restricted': 'operator_unavailable',
    'ai_budget_not_configured': 'operator_unavailable',
    'ai_access_unavailable': 'operator_unavailable',
    'ai_request_conflict': 'request_pending',
    'ai_request_unresolved': 'request_pending',
    'ai_provider_unavailable': 'ai_result_unknown',
    'ai_chat_disabled': 'operator_unavailable',
    'trial_not_started': 'trial_not_started',
    'trial_expired': 'trial_expired',
    'trial_request_limit_reached': 'trial_limit_reached',
    'trial_cost_limit_reached': 'trial_limit_reached',
    'trial_limit_reached': 'trial_limit_reached',
    'trial_limits_not_configured': 'operator_unavailable',
    'trial_policy_not_configured': 'operator_unavailable',
    'policy_unconfigured': 'operator_unavailable',
    'validation_budget_exhausted': 'operator_unavailable',
    'shared_budget_exhausted': 'operator_unavailable',
    'validation_not_allowed': 'operator_unavailable',
    'validation_policy_invalid': 'operator_unavailable',
    'reservation_policy_mismatch': 'operator_unavailable',
    'ai_disabled': 'operator_unavailable',
    'entitlement_unavailable': 'operator_unavailable',
    'rate_limited': 'rate_limited',
    'auth_required': 'auth_required',
    'app_check_failed': 'app_check_failed',
    'access_required': 'access_required',
    'invalid_request': 'invalid_request',
    'request_pending': 'request_pending',
    'request_conflict': 'request_pending',
  };

  // Exact legacy response values allow the new client to explain the current
  // deployed service safely while its structured error rollout is pending.
  static const _legacyDetails = <String, String>{
    'AI free usage limit reached.': 'trial_limit_reached',
    'No active subscription or free trial.': 'access_required',
    'AI free usage limits are not configured.': 'operator_unavailable',
    'The limited validation run has reached its server-side budget.':
        'operator_unavailable',
    'This account is not enabled for the limited validation run.':
        'operator_unavailable',
    'Validation AI budget is not configured safely.': 'operator_unavailable',
    'The limited AI allowlist is not configured.': 'operator_unavailable',
    'The validation reservation does not match the trial policy.':
        'operator_unavailable',
    'AI chat is temporarily disabled.': 'operator_unavailable',
    'Unable to verify AI access right now.': 'operator_unavailable',
    'This request is still being resolved. Do not regenerate automatically.':
        'request_pending',
    'requestId cannot be reused for different content.': 'request_pending',
    'AI request reservation is no longer valid.': 'request_pending',
    'Firebase App Check token is required.': 'app_check_failed',
    'Invalid Firebase App Check token.': 'app_check_failed',
  };

  static AiAccessFailure _of(String category, {int? statusCode}) =>
      AiAccessFailure(category, _messages[category]!, statusCode: statusCode);

  static Map? _errorFields(Object? body) {
    if (body is! Map) return null;
    if (body['detail'] is Map) return body['detail'] as Map;
    if (body['error'] is Map) return body['error'] as Map;
    return body;
  }

  static String? _knownCategory(Object? body) {
    final fields = _errorFields(body);
    final code = fields?['code'] ?? fields?['reason'];
    if (code is String && _codeCategories.containsKey(code)) {
      return _codeCategories[code];
    }
    final legacy = body is Map ? body['detail'] : null;
    return legacy is String ? _legacyDetails[legacy] : null;
  }

  static AiAccessFailure fromChatResponse(int statusCode, String body) {
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      // Load balancers and proxies may return HTML rather than an API error.
    }
    final category = _knownCategory(decoded);
    if (category != null) return _of(category, statusCode: statusCode);
    if (statusCode == 401) return _of('auth_required', statusCode: statusCode);
    if (statusCode == 403) {
      return _of('access_required', statusCode: statusCode);
    }
    if (statusCode == 409) {
      return _of('request_pending', statusCode: statusCode);
    }
    if (statusCode == 422) {
      return _of('invalid_request', statusCode: statusCode);
    }
    // HTTP 429 alone does not establish which budget or short-term limit was
    // reached. Never describe it as the current user's exhausted trial.
    if (statusCode == 429) {
      return _of('request_rejected', statusCode: statusCode);
    }
    if (statusCode >= 500) {
      return _of('ai_provider_unavailable', statusCode: statusCode);
    }
    return _of('unknown', statusCode: statusCode);
  }

  static AiAccessFailure fromChatError(Object error) {
    if (error is AiAccessFailure) return error;
    if (error is PendingChatStorageFailure) {
      return _of('pending_request_unavailable');
    }
    if (error is FirebaseAuthException) {
      if (error.code == 'network-request-failed') {
        return _of('network_unavailable');
      }
      return _of('auth_required');
    }
    if (error is FirebaseException) {
      if (error.code == 'unauthenticated') return _of('auth_required');
      if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
        return _of('network_unavailable');
      }
    }
    if (error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException) {
      return _of('network_unavailable');
    }
    return _of('unknown');
  }

  static AiAccessFailure fromTrialStart(Object error) {
    String category = 'unknown';
    if (error is FirebaseFunctionsException) {
      final legacyCategory = switch (error.message) {
        '無料体験は利用上限の設定完了後に開始できます。' => 'operator_unavailable',
        '現在は許可されたテストアカウントのみ無料体験を開始できます。' => 'operator_unavailable',
        _ => null,
      };
      category = _knownCategory(error.details) ??
          legacyCategory ??
          switch (error.code) {
            'unauthenticated' => 'auth_required',
            'resource-exhausted' => 'request_rejected',
            'unavailable' || 'deadline-exceeded' => 'network_unavailable',
            _ => 'unknown',
          };
    } else {
      category = fromChatError(error).code;
    }
    final message = switch (category) {
      'operator_unavailable' => '無料体験を開始できません。運営側の利用設定の確認が必要です。',
      'auth_required' || 'app_check_failed' => _messages[category]!,
      'network_unavailable' => '無料体験の開始を確認できませんでした。接続を確認して、もう一度お試しください。',
      'rate_limited' => '短時間に操作が集中しています。少し時間をおいて再度お試しください。',
      'trial_expired' => _messages['trial_expired']!,
      'trial_limit_reached' => _messages['trial_limit_reached']!,
      _ => '無料体験を開始できませんでした。問題が続く場合はお問い合わせください。',
    };
    return AiAccessFailure(category, message);
  }

  @override
  String toString() => message;
}

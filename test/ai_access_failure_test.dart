import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/services/ai_access_failure.dart';
import 'package:http/http.dart' as http;

void main() {
  AiAccessFailure response(int status, Object detail) =>
      AiAccessFailure.fromChatResponse(status, jsonEncode({'detail': detail}));

  test('personal exhaustion and operations budget do not share advice', () {
    final personal = response(429, 'AI free usage limit reached.');
    final shared = response(
        429, 'The limited validation run has reached its server-side budget.');
    expect(personal.code, 'trial_limit_reached');
    expect(personal.message, contains('使い切りました'));
    expect(shared.code, 'operator_unavailable');
    expect(shared.message, contains('運営側'));
    for (final error in [personal, shared]) {
      expect(error.message, isNot(contains('少し時間')));
    }
  });

  for (final code in [
    'ai_shared_budget_exhausted',
    'ai_limits_not_configured',
    'ai_validation_restricted',
    'ai_budget_not_configured',
    'ai_access_unavailable',
    'ai_chat_disabled',
  ]) {
    test('$code is an operations issue, not user exhaustion or rate limit', () {
      final error = response(503, {'code': code, 'message': 'internal secret'});
      expect(error.code, 'operator_unavailable');
      expect(error.message, contains('運営側'));
      expect(error.message, isNot(contains('使い切')));
      expect(error.message, isNot(contains('少し時間')));
      expect(error.message, isNot(contains('internal secret')));
    });
  }

  test('expired, not-started and consumed trials are different', () {
    expect(response(403, {'code': 'ai_trial_expired'}).code, 'trial_expired');
    expect(response(403, {'code': 'ai_trial_not_started'}).code,
        'trial_not_started');
    expect(response(429, {'code': 'ai_personal_limit_reached'}).code,
        'trial_limit_reached');
  });

  test('only explicit short-term rate limiting recommends waiting', () {
    final explicit = response(429, {'code': 'rate_limited'});
    final unspecified = response(429, 'private internal detail');
    expect(explicit.code, 'rate_limited');
    expect(explicit.message, contains('少し時間'));
    expect(unspecified.code, 'request_rejected');
    expect(unspecified.message, isNot(contains('少し時間')));
    expect(unspecified.message, isNot(contains('利用上限')));
  });

  test('provider unknown outcome and reservation conflict never invite retry',
      () {
    for (final code in [
      'ai_provider_unavailable',
      'ai_request_conflict',
      'ai_request_unresolved',
    ]) {
      final error = response(502, {'code': code});
      expect(error.message, contains('再送せず'));
      expect(error.message, isNot(contains('少し時間')));
    }
  });

  test('authentication and App Check remain separate from usage', () {
    expect(response(401, 'Invalid Firebase ID token: ValueError').code,
        'auth_required');
    expect(response(401, 'Invalid Firebase App Check token.').code,
        'app_check_failed');
  });

  test('untrusted response bodies are never displayed', () {
    for (final body in [
      'Exception: token=secret',
      '<html>provider secret</html>',
      '{"detail":{"code":"token_secret","message":"consultation text"}}'
    ]) {
      final error = AiAccessFailure.fromChatResponse(500, body);
      expect(error.message, isNot(contains('secret')));
      expect(error.message, isNot(contains('consultation')));
      expect(error.toString(), error.message);
    }
  });

  test('network errors do not become usage errors or leak exception messages',
      () {
    for (final cause in [
      const SocketException('private address'),
      TimeoutException('private URL'),
      http.ClientException('private URL'),
    ]) {
      final error = AiAccessFailure.fromChatError(cause);
      expect(error.code, 'network_unavailable');
      expect(error.message, contains('別の相談として送り直さず'));
      expect(error.message, isNot(contains('再度お試し')));
      expect(error.message, isNot(contains('private')));
    }
    expect(
        AiAccessFailure.fromChatError(
                FirebaseAuthException(code: 'network-request-failed'))
            .code,
        'network_unavailable');
    final unknown = AiAccessFailure.fromChatError(Exception('private data'));
    expect(unknown.code, 'unknown');
    expect(unknown.message, isNot(contains('Exception:')));
    expect(unknown.message, isNot(contains('private data')));
  });

  test('trial callable error distinguishes auth, network and operator setup',
      () {
    AiAccessFailure start(String code, {Object? details}) =>
        AiAccessFailure.fromTrialStart(FirebaseFunctionsException(
            code: code, message: 'private internal data', details: details));
    expect(start('unauthenticated').code, 'auth_required');
    expect(start('unavailable').code, 'network_unavailable');
    expect(start('failed-precondition').code, 'unknown');
    expect(start('permission-denied').code, 'unknown');
    final configured = start('failed-precondition',
        details: {'reason': 'policy_unconfigured'});
    expect(configured.message, contains('運営側'));
    final legacy = AiAccessFailure.fromTrialStart(FirebaseFunctionsException(
        code: 'failed-precondition', message: '無料体験は利用上限の設定完了後に開始できます。'));
    expect(legacy.code, 'operator_unavailable');
    expect(configured.message, isNot(contains('設定後に開始')));
    final unknown = start('internal');
    expect(unknown.message, isNot(contains('private internal data')));
  });
}

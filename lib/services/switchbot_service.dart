// lib/services/switchbot_service.dart
// 署名生成（_headerCandidates）と GET 実行（_getJson）を中央集約。
// v1署名 と legacy署名 の両方を自動で試し、通った方を採用します。

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:hamster_project/models/switchbot_reading.dart';

class SwitchBotService {
  // ====== dart-define から遅延取得 ======
  static String? _token;
  static String? _secret;

  static void _ensureEnvLoaded() {
    _token ??=
        const String.fromEnvironment('SWITCHBOT_TOKEN', defaultValue: '');
    _secret ??=
        const String.fromEnvironment('SWITCHBOT_SECRET', defaultValue: '');
    if (_token!.isEmpty || _secret!.isEmpty) {
      throw StateError(
          'SWITCHBOT_TOKEN/SECRET が設定されていません（--dart-define で渡してください）');
    }
  }

  // ====== ランダム nonce ======
  static String _nonce() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random.secure();
    return List.generate(16, (_) => chars[r.nextInt(chars.length)]).join();
  }

  // ====== 署名生成（候補を2通り）======
  // 1) v1:   sign = Base64(HMAC_SHA256( token + t , secret )), signVersion=1, nonce送付
  // 2) legacy: sign = Base64(HMAC_SHA256( token + t + nonce , secret )), signVersion省略
  static List<Map<String, String>> _headerCandidates() {
    _ensureEnvLoaded();
    final token = _token!;
    final secret = _secret!;
    final t = DateTime.now().millisecondsSinceEpoch.toString();
    final nonce = _nonce();

    final v1Sign = base64Encode(
      Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(token + t)).bytes,
    );

    final legacySign = base64Encode(
      Hmac(sha256, utf8.encode(secret))
          .convert(utf8.encode(token + t + nonce))
          .bytes,
    );

    return [
      {
        'Authorization': token,
        'sign': v1Sign,
        't': t,
        'nonce': nonce,
        'signVersion': '1',
        'Content-Type': 'application/json; charset=utf-8',
      },
      {
        'Authorization': token,
        'sign': legacySign,
        't': t,
        'nonce': nonce,
        // signVersion を付けない（古い実装向け）
        'Content-Type': 'application/json; charset=utf-8',
      },
    ];
  }

  // ====== GET 実行（候補ヘッダを順に試す）======
  static const String _base = 'https://api.switch-bot.com/v1.1';

  static Future<Map<String, dynamic>> _getJson(String path) async {
    final uri = Uri.parse('$_base$path');
    Object? lastErr;

    for (final headers in _headerCandidates()) {
      try {
        final res = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) {
          return json.decode(utf8.decode(res.bodyBytes))
              as Map<String, dynamic>;
        } else {
          lastErr = Exception('HTTP ${res.statusCode}: ${res.body}');
        }
      } catch (e) {
        lastErr = e;
      }
    }
    throw lastErr ?? Exception('Request failed');
  }

  // ====== デバイス一覧 ======
  Future<List<Map<String, dynamic>>> listDevices() async {
    final map = await _getJson('/devices');
    final code = map['statusCode'] ?? 0;
    if (code != 100) {
      throw Exception('API $code: ${map['message']}');
    }
    final body = (map['body'] as Map?) ?? const {};
    final list = ((body['deviceList'] as List?) ?? const []).cast();
    return list
        .map<Map<String, dynamic>>(
          (e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)),
        )
        .toList();
  }

  // ====== ステータス取得 ======
  Future<Map<String, dynamic>> getDeviceStatus(String deviceId) async {
    final map = await _getJson('/devices/$deviceId/status');
    final code = map['statusCode'] ?? 0;
    if (code != 100) {
      throw Exception('API $code: ${map['message']}');
    }
    final body = ((map['body'] as Map?) ?? const {})
        .map((k, v) => MapEntry(k.toString(), v));
    return Map<String, dynamic>.from(body);
  }

  /// 温湿度計(Meter/MeterPlus)から現在値を1回取得して返す
  Future<SwitchBotReading> readMeterOnce(String deviceId) async {
    final body = await getDeviceStatus(deviceId);
    final now = DateTime.now();
    return SwitchBotReading(
      ts: now,
      temperature: (body['temperature'] as num?)?.toDouble(),
      humidity: (body['humidity'] as num?)?.toDouble(),
    );
  }
}

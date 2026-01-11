// lib/services/fetch_and_store.dart
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';

class FetchAndStore {
  HttpsCallable _call(String name) =>
      FirebaseFunctions.instanceFor(region: 'asia-northeast1')
          .httpsCallable(name);

  Future<Map<String, dynamic>> pollMineNow() async {
    final r = await _call('pollMySwitchbotNow').call();
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> debugEcho() async {
    final r = await _call('switchbotDebugEcho').call();
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> debugDevicesFromStore() async {
    final r = await _call('switchbotDebugListFromStore').call();
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> debugStatusFromStore() async {
    final r = await _call('switchbotDebugStatusFromStore').call();
    return Map<String, dynamic>.from(r.data as Map);
  }

  static String pretty(Object? v) {
    try {
      return const JsonEncoder.withIndent('  ').convert(v);
    } catch (_) {
      return v.toString();
    }
  }

  FirebaseFunctions get _fns => FirebaseFunctions.instanceFor(
        region: 'asia-northeast1',
      );

  Future<Map<String, dynamic>> debugCallDevices() async {
    try {
      final res = await _fns.httpsCallable('switchbotDebugCallDevices').call();
      final data = res.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return {'ok': false, 'error': 'unexpected response', 'data': data};
    } on FirebaseFunctionsException catch (e) {
      return {
        'ok': false,
        'code': e.code,
        'message': e.message,
        'details': e.details,
      };
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  /// 互換用（古い呼び出し名）
  Future<Map<String, dynamic>> debugListFromStore() => debugDevicesFromStore();
}

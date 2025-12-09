// lib/services/switchbot_service.dart
// Firestore から SwitchBot の温湿度データを読み出すシンプルなサービス。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

typedef Json = Map<String, dynamic>;

class SwitchbotService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// 直近 [limit] 件を新→旧の時系列で返すストリーム
  Stream<List<Json>> watchReadings({int limit = 1000}) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Stream<List<Json>>.empty();
    }
    return _db
        .collection('users')
        .doc(uid)
        .collection('switchbot_readings')
        .orderBy('ts', descending: false)
        .limit(limit)
        .snapshots()
        .map((qs) => qs.docs.map((d) => d.data()).toList());
  }

  /// 指定期間の読み出し（サーバークエリ）
  Future<List<Json>> fetchRange({
    required String fromIso, // 例: "2025-01-01T00:00:00Z"
    required String toIso,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return <Json>[];
    final qs = await _db
        .collection('users')
        .doc(uid)
        .collection('switchbot_readings')
        .where('ts', isGreaterThanOrEqualTo: fromIso)
        .where('ts', isLessThanOrEqualTo: toIso)
        .orderBy('ts', descending: false)
        .get();
    return qs.docs.map((d) => d.data()).toList();
  }
}

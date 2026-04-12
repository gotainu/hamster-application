// /Users/gota/local_dev/flutter_projects/hamster_project/lib/services/anomaly_notification_log_repo.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/anomaly_notification_log.dart';

class AnomalyNotificationLogRepo {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  AnomalyNotificationLogRepo({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? _logsCol() {
    final uid = _uid;
    if (uid == null) return null;

    return _db
        .collection('users')
        .doc(uid)
        .collection('anomaly_notification_logs');
  }

  DocumentReference<Map<String, dynamic>>? _logDoc(String notificationKey) {
    final col = _logsCol();
    if (col == null) return null;
    return col.doc(notificationKey);
  }

  Stream<AnomalyNotificationLog?> watchByNotificationKey(
    String notificationKey,
  ) {
    final doc = _logDoc(notificationKey);
    if (doc == null) {
      return const Stream<AnomalyNotificationLog?>.empty();
    }

    return doc.snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      return AnomalyNotificationLog.fromMap(data);
    });
  }

  Future<AnomalyNotificationLog?> fetchByNotificationKey(
    String notificationKey,
  ) async {
    final doc = _logDoc(notificationKey);
    if (doc == null) return null;

    final snap = await doc.get();
    if (!snap.exists) return null;

    final data = snap.data();
    if (data == null) return null;

    return AnomalyNotificationLog.fromMap(data);
  }

  Future<DateTime?> fetchLastSentAt(String notificationKey) async {
    final log = await fetchByNotificationKey(notificationKey);
    return log?.sentAt;
  }

  Future<void> saveLog(AnomalyNotificationLog log) async {
    final doc = _logDoc(log.notificationKey);
    if (doc == null) {
      throw StateError('ログイン中ユーザーが存在しないため通知ログを保存できません。');
    }

    final now = DateTime.now();

    final existing = await fetchByNotificationKey(log.notificationKey);
    final merged = log.copyWith(
      createdAt: existing?.createdAt ?? log.createdAt ?? now,
      updatedAt: now,
    );

    await doc.set(merged.toMap(), SetOptions(merge: true));
  }

  Future<void> markAsSent(AnomalyNotificationLog log) async {
    final now = DateTime.now();
    await saveLog(
      log.copyWith(
        sentAt: log.sentAt ?? now,
        createdAt: log.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  Stream<List<AnomalyNotificationLog>> watchRecentLogs({
    int limit = 20,
  }) {
    final col = _logsCol();
    if (col == null) {
      return const Stream<List<AnomalyNotificationLog>>.empty();
    }

    return col
        .orderBy('sentAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => AnomalyNotificationLog.fromMap(d.data()))
          .toList();
    });
  }

  Future<List<AnomalyNotificationLog>> fetchRecentLogs({
    int limit = 20,
  }) async {
    final col = _logsCol();
    if (col == null) return const [];

    final snap =
        await col.orderBy('sentAt', descending: true).limit(limit).get();

    return snap.docs
        .map((d) => AnomalyNotificationLog.fromMap(d.data()))
        .toList();
  }
}

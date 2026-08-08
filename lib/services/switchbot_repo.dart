// lib/services/switchbot_repo.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/switchbot_reading.dart';

class SwitchbotRepo {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  SwitchbotRepo({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  FirebaseFunctions get _fns => FirebaseFunctions.instanceFor(
        app: Firebase.app(),
        region: 'asia-northeast1',
      );

  /// （追加）自分のアカウントだけ即時ポーリングして保存
  Future<void> triggerPollNowForMe() async {
    final callable = _fns.httpsCallable('pollMySwitchbotNow');
    await callable.call(); // {saved:1} が返る
  }

  /// UI表示用：選択中デバイス
  Stream<Map<String, String>?> watchSelectedDeviceMeta() {
    final uid = _uid;
    if (uid == null) {
      return const Stream<Map<String, String>?>.empty();
    }
    final doc = _db
        .collection('users')
        .doc(uid)
        .collection('integrations')
        .doc('switchbot');

    return doc.snapshots().map((snap) {
      if (!snap.exists) return null;
      final m = snap.data() ?? {};
      String s(dynamic v) => (v is String) ? v : '';
      return {
        'id': s(m['meterDeviceId']),
        'name': s(m['meterDeviceName']),
        'type': s(m['meterDeviceType'])
      };
    });
  }

  /// 温度/湿度/電池の時系列監視
  Stream<List<SwitchbotReading>> watchReadings({
    DateTime? since,
    DateTime? until,
    int limit = 720,
  }) {
    final uid = _uid;
    if (uid == null) {
      return const Stream<List<SwitchbotReading>>.empty();
    }

    Query<Map<String, dynamic>> q = _db
        .collection('users')
        .doc(uid)
        .collection('switchbot_readings')
        .orderBy('ts');

    if (since != null) {
      q = q.where('ts',
          isGreaterThanOrEqualTo: since.toUtc().toIso8601String());
    }
    if (until != null) {
      q = q.where('ts', isLessThanOrEqualTo: until.toUtc().toIso8601String());
    }

    q = q.limit(limit);

    return q.snapshots().map((snap) {
      final list = snap.docs.map(SwitchbotReading.fromDoc).toList();
      return list;
    });
  }

  /// 直近のみ一括取得
  Future<List<SwitchbotReading>> fetchLatest({int limit = 200}) async {
    final uid = _uid;
    if (uid == null) return <SwitchbotReading>[];
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('switchbot_readings')
        .orderBy('ts', descending: true)
        .limit(limit)
        .get();

    final list = snap.docs.map(SwitchbotReading.fromDoc).toList();
    list.sort((a, b) => a.ts.compareTo(b.ts));
    return list;
  }
}

// lib/services/switchbot_repo.dart に追記（既存は残してOK）

class SwitchbotConfig {
  final bool enabled;
  final bool hasSecrets;
  final String meterDeviceId;
  final String meterDeviceName;
  final String meterDeviceType;

  const SwitchbotConfig({
    required this.enabled,
    required this.hasSecrets,
    required this.meterDeviceId,
    required this.meterDeviceName,
    required this.meterDeviceType,
  });

  bool get hasDevice => meterDeviceId.isNotEmpty;
  bool get isLinked => enabled && hasSecrets;
  bool get isReady => enabled && hasSecrets && hasDevice;
}

extension SwitchbotRepoConfig on SwitchbotRepo {
  /// SwitchBot 連携設定（enabled + device meta）を監視
  Stream<SwitchbotConfig?> watchSwitchbotConfig() {
    final uid = _uid;
    if (uid == null) return const Stream<SwitchbotConfig?>.empty();

    final doc = _db
        .collection('users')
        .doc(uid)
        .collection('integrations')
        .doc('switchbot');

    return doc.snapshots().map((snap) {
      if (!snap.exists) return null;

      final m = snap.data() ?? <String, dynamic>{};

      final enabled = (m['enabled'] as bool?) ?? false;
      final hasSecrets = (m['hasSecrets'] as bool?) ?? false;
      final id = (m['meterDeviceId'] as String?) ?? '';
      final name = (m['meterDeviceName'] as String?) ?? '';
      final type = (m['meterDeviceType'] as String?) ?? '';

      return SwitchbotConfig(
        enabled: enabled,
        hasSecrets: hasSecrets,
        meterDeviceId: id,
        meterDeviceName: name,
        meterDeviceType: type,
      );
    }).handleError((_) {
      return null;
    });
  }

  /// SwitchBot TOKEN/SECRET がサーバー側に保存済みかを監視する。
  /// 秘密情報本体はClientから一切読まず、
  /// integrations/switchbot.hasSecrets のserver-owned markerだけを見る。
  Stream<bool> watchHasSecrets() {
    final uid = _uid;
    if (uid == null) return const Stream<bool>.empty();

    final doc = _db
        .collection('users')
        .doc(uid)
        .collection('integrations')
        .doc('switchbot');

    return doc.snapshots().map((snap) {
      if (!snap.exists) return false;
      final m = snap.data() ?? <String, dynamic>{};
      return m['hasSecrets'] == true;
    }).handleError((_) {
      return false;
    });
  }
}

extension SwitchbotRepoLatest on SwitchbotRepo {
  /// 最新 [limit] 件を取り、描画用に old->new に並べ直して返す
  Stream<List<SwitchbotReading>> watchLatestReadings({int limit = 500}) {
    final uid = _uid;
    if (uid == null) {
      return const Stream<List<SwitchbotReading>>.empty();
    }

    return _db
        .collection('users')
        .doc(uid)
        .collection('switchbot_readings')
        .orderBy('ts', descending: true) // 最新から取る
        .limit(limit)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(SwitchbotReading.fromDoc).toList();
      list.sort((a, b) => a.ts.compareTo(b.ts)); // old->new に整形
      return list;
    });
  }
}

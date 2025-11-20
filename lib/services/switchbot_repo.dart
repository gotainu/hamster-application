import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hamster_project/models/switchbot_reading.dart';

class SwitchBotRepo {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String get _uid => _auth.currentUser!.uid;

  /// 設定（既存の場所をそのまま使う）
  DocumentReference<Map<String, dynamic>> get _cfgDoc => _db
      .collection('users')
      .doc(_uid)
      .collection('integrations')
      .doc('switchbot');

  Future<void> saveSelectedMeter(String deviceId, {String? name}) async {
    await _cfgDoc.set({
      'meterDeviceId': deviceId,
      if (name != null) 'meterName': name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String?> getSelectedMeterId() async {
    final snap = await _cfgDoc.get();
    return snap.data()?['meterDeviceId'] as String?;
  }

  /// 記録コレクション
  CollectionReference<Map<String, dynamic>> get _readingsCol =>
      _db.collection('users').doc(_uid).collection('switchbot_readings');

  /// 1件保存（★ ts を Timestamp で保存 / 数値を double に正規化）
  Future<void> addReading(SwitchBotReading r) async {
    final map = r.toJson();

    // toJson() が ts を文字列で返していても上書きする
    map['ts'] = Timestamp.fromDate(r.ts);

    if (map['temperature'] is num) {
      map['temperature'] = (map['temperature'] as num).toDouble();
    }
    if (map['humidity'] is num) {
      map['humidity'] = (map['humidity'] as num).toDouble();
    }
    map['savedAt'] = FieldValue.serverTimestamp();

    // 既存の“日時文字列をドキュメントID”運用は維持
    await _readingsCol
        .doc(r.ts.toIso8601String())
        .set(map, SetOptions(merge: true));
    // もし衝突の心配を避けたいなら ↑ を ↓ に替えて自動IDでもOK
    // await _readingsCol.add(map);
  }

  /// 期間読み込み（★ クエリも Timestamp ベースに修正）
  Future<List<SwitchBotReading>> loadRange(DateTime from, DateTime to) async {
    final q = await _readingsCol
        .where('ts', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('ts', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .orderBy('ts')
        .get();

    return q.docs.map((d) => SwitchBotReading.fromMap(d.data())).toList();
  }
}

// lib/services/health_records_repo.dart
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/health_record.dart';
import 'wheel_repo.dart';

typedef Json = Map<String, dynamic>;

class MissingWheelDiameterException implements Exception {
  final String message;
  const MissingWheelDiameterException([this.message = '車輪の直径が未設定です']);
  @override
  String toString() => message;
}

class HealthRecordsRepo {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final WheelRepo _wheelRepo;

  double? _cachedWheelDiameterCm;

  HealthRecordsRepo({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    WheelRepo? wheelRepo,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _wheelRepo = wheelRepo ?? WheelRepo();

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Json>? _col() {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('health_records');
  }

  /// ローカル日付の [start, end) をUTCに変換してクエリする
  ({DateTime startUtc, DateTime endUtc}) _dayRangeUtc(DateTime dayLocal) {
    final startLocal = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    final endLocal = startLocal.add(const Duration(days: 1));
    return (startUtc: startLocal.toUtc(), endUtc: endLocal.toUtc());
  }

  /// 指定日の距離合計(m)
  Future<double> fetchDailyTotalDistance(DateTime dayLocal) async {
    final col = _col();
    if (col == null) return 0;

    final r = _dayRangeUtc(dayLocal);

    final qs = await col
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(r.startUtc))
        .where('date', isLessThan: Timestamp.fromDate(r.endUtc))
        .get();

    double sum = 0;
    for (final d in qs.docs) {
      final m = d.data();
      final v = m['distance'];
      if (v is num) sum += v.toDouble();
    }
    return sum;
  }

  /// 直近N日（今日含む）の1日平均(m)
  Future<double> fetchRollingDailyAverage({
    int days = 7,
    DateTime? todayLocal,
  }) async {
    final col = _col();
    if (col == null) return 0;

    final today = todayLocal ?? DateTime.now();
    final startLocal = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: days - 1));
    final endLocal = DateTime(today.year, today.month, today.day)
        .add(const Duration(days: 1));

    final startUtc = startLocal.toUtc();
    final endUtc = endLocal.toUtc();

    final qs = await col
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startUtc))
        .where('date', isLessThan: Timestamp.fromDate(endUtc))
        .get();

    // 日別にバケツ集計（ローカル日付キー）
    final map = <String, double>{};
    for (final d in qs.docs) {
      final m = d.data();
      final ts = m['date'];
      final dist = m['distance'];
      if (ts is! Timestamp || dist is! num) continue;

      final local = ts.toDate().toLocal();
      final key =
          '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
      map[key] = (map[key] ?? 0) + dist.toDouble();
    }

    // days分の「存在しない日は0」として平均を作る（実用上こっちが“感覚”に合う）
    double total = 0;
    for (int i = 0; i < days; i++) {
      final d = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      total += map[key] ?? 0;
    }
    return total / days;
  }

  // -------------------------
  // ★ 直径キャッシュ更新
  // -------------------------
  Future<double?> refreshWheelDiameter() async {
    final d = await _wheelRepo.fetchWheelDiameter();
    _cachedWheelDiameterCm = (d != null && d > 0) ? d : null;
    return _cachedWheelDiameterCm;
  }

  double? get cachedWheelDiameterCm => _cachedWheelDiameterCm;

  // -------------------------
  // ★ (A) プレビュー距離計算（m）
  // -------------------------
  Future<double?> previewDistanceFromRotations(int rotations) async {
    if (rotations < 0) return null;

    // lint対応：if を ??= に
    var d = _cachedWheelDiameterCm;
    d ??= await refreshWheelDiameter();

    if (d == null || d <= 0) return null;

    // 距離(m) = 回転数 * 円周(cm) / 100
    return rotations * (math.pi * d) / 100.0;
  }

  // -------------------------
  // ★ 回転数→距離→保存（推奨）
  // -------------------------
  Future<void> addWheelRotationRecord({
    required int rotations,
    DateTime? date,
    String source = 'wheel_manual',
  }) async {
    final col = _col();
    if (col == null) return;

    if (rotations < 0) {
      throw ArgumentError.value(rotations, 'rotations', '回転数は0以上にしてください');
    }

    var d = _cachedWheelDiameterCm;
    d ??= await refreshWheelDiameter();

    if (d == null || d <= 0) {
      throw const MissingWheelDiameterException();
    }

    final distanceM = rotations * (math.pi * d) / 100.0;

    await col.add({
      'date': Timestamp.fromDate((date ?? DateTime.now()).toUtc()),
      'distance': distanceM,
      'rotations': rotations,
      'wheelDiameterCm': d,
      'createdAt': FieldValue.serverTimestamp(),
      'source': source,
    });
  }

  // -------------------------
  // 既存：距離を直接保存（互換用に残す）
  // -------------------------
  Future<void> addDistanceRecord({
    required DateTime date,
    required double distance,
    String source = 'wheel_manual',
  }) async {
    final col = _col();
    if (col == null) return;

    await col.add({
      'date': Timestamp.fromDate(date.toUtc()),
      'distance': distance,
      'createdAt': FieldValue.serverTimestamp(),
      'source': source,
    });
  }

  // -------------------------
  // グラフ用（※1つだけ！）
  // -------------------------
  Stream<List<HealthRecord>> watchDistanceSeries() {
    final uid = _uid;
    if (uid == null) return const Stream<List<HealthRecord>>.empty();

    return _db
        .collection('users')
        .doc(uid)
        .collection('health_records')
        .orderBy('date')
        .snapshots()
        .map((qs) => qs.docs.map(HealthRecord.fromDoc).toList());
  }
}

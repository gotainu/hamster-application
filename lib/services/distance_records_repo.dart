// lib/services/distance_records_repo.dart
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

class DistanceRecordsRepo {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final WheelRepo _wheelRepo;

  double? _cachedWheelDiameterCm;

  DistanceRecordsRepo({
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
    return _db.collection('users').doc(uid).collection('distance_records');
  }

  DocumentReference<Json>? _docByLocalDate(DateTime dayLocal) {
    final col = _col();
    if (col == null) return null;
    return col.doc(_dateKeyLocal(dayLocal));
  }

  String _dateKeyLocal(DateTime dayLocal) {
    final d = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  DateTime _normalizeLocalDay(DateTime dt) {
    final local = dt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  DateTime? _readLocalDay(Json m) {
    final dayKey = m['dayKey'];
    if (dayKey is String) {
      final parts = dayKey.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final mo = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && mo != null && d != null) {
          return DateTime(y, mo, d);
        }
      }
    }

    final date = m['date'];
    if (date is Timestamp) {
      return _normalizeLocalDay(date.toDate());
    }

    return null;
  }

  double _readDistance(Json m) {
    final v = m['distance'];
    return v is num ? v.toDouble() : 0.0;
  }

  // -------------------------
  // 指定日の距離(m)
  // -------------------------
  Future<double> fetchDailyTotalDistance(DateTime dayLocal) async {
    final doc = _docByLocalDate(dayLocal);
    if (doc == null) return 0;

    final snap = await doc.get();
    if (!snap.exists) return 0;

    final data = snap.data();
    if (data == null) return 0;

    return _readDistance(data);
  }

  // -------------------------
  // 全日分の距離時系列
  // -------------------------
  Future<List<HealthRecord>> fetchAllDailyDistanceSeries() async {
    final col = _col();
    if (col == null) return const [];

    final qs = await col.orderBy('date').get();

    return qs.docs.map((d) {
      final m = d.data();
      final day = _readLocalDay(m);
      final distance = _readDistance(m);

      return HealthRecord(
        date: day ?? DateTime.now(),
        distance: distance,
      );
    }).toList();
  }

  // -------------------------
  // 直近N日（今日含む）の1日平均(m)
  // 存在しない日は0として平均
  // -------------------------
  Future<double> fetchRollingDailyAverage({
    int days = 7,
    DateTime? todayLocal,
  }) async {
    final today = _normalizeLocalDay(todayLocal ?? DateTime.now());
    final series =
        await fetchDailyDistanceSeries(days: days, todayLocal: today);

    if (series.isEmpty) return 0;

    final total = series.fold<double>(0, (sum, e) => sum + e.distance);
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
  // ★ プレビュー距離計算（m）
  // -------------------------
  Future<double?> previewDistanceFromRotations(int rotations) async {
    if (rotations < 0) return null;

    var d = _cachedWheelDiameterCm;
    d ??= await refreshWheelDiameter();

    if (d == null || d <= 0) return null;

    return rotations * (math.pi * d) / 100.0;
  }

  // -------------------------
  // ★ 回転数→距離→日次レコードを上書き保存
  // -------------------------
  Future<void> addWheelRotationRecord({
    required int rotations,
    DateTime? date,
    String source = 'wheel_manual',
  }) async {
    final doc = _docByLocalDate(date ?? DateTime.now());
    if (doc == null) return;

    if (rotations < 0) {
      throw ArgumentError.value(rotations, 'rotations', '回転数は0以上にしてください');
    }

    var d = _cachedWheelDiameterCm;
    d ??= await refreshWheelDiameter();

    if (d == null || d <= 0) {
      throw const MissingWheelDiameterException();
    }

    final localDay = _normalizeLocalDay(date ?? DateTime.now());
    final distanceM = rotations * (math.pi * d) / 100.0;

    await doc.set({
      'dayKey': _dateKeyLocal(localDay),
      'date': Timestamp.fromDate(localDay.toUtc()),
      'distance': distanceM,
      'rotations': rotations,
      'wheelDiameterCm': d,
      'source': source,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // -------------------------
  // 距離を直接、日次レコードへ上書き保存
  // -------------------------
  Future<void> addDistanceRecord({
    required DateTime date,
    required double distance,
    String source = 'wheel_manual',
  }) async {
    final doc = _docByLocalDate(date);
    if (doc == null) return;

    final localDay = _normalizeLocalDay(date);

    await doc.set({
      'dayKey': _dateKeyLocal(localDay),
      'date': Timestamp.fromDate(localDay.toUtc()),
      'distance': distance,
      'source': source,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // -------------------------
  // グラフ用ストリーム
  // -------------------------
  Stream<List<HealthRecord>> watchDistanceSeries() {
    final col = _col();
    if (col == null) return const Stream<List<HealthRecord>>.empty();

    return col.orderBy('date').snapshots().map((qs) {
      return qs.docs.map((d) {
        final m = d.data();
        final day = _readLocalDay(m);
        final distance = _readDistance(m);

        return HealthRecord(
          date: day ?? DateTime.now(),
          distance: distance,
        );
      }).toList();
    });
  }

  // -------------------------
  // 直近N日分の時系列（存在しない日は0で補完）
  // -------------------------
  Future<List<HealthRecord>> fetchDailyDistanceSeries({
    int days = 7,
    DateTime? todayLocal,
  }) async {
    final col = _col();
    if (col == null) return const [];

    final today = _normalizeLocalDay(todayLocal ?? DateTime.now());
    final startLocal = today.subtract(Duration(days: days - 1));
    final endLocal = today.add(const Duration(days: 1));

    final qs = await col
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startLocal.toUtc()))
        .where('date', isLessThan: Timestamp.fromDate(endLocal.toUtc()))
        .orderBy('date')
        .get();

    final map = <String, double>{};
    for (final d in qs.docs) {
      final m = d.data();
      final day = _readLocalDay(m);
      if (day == null) continue;
      map[_dateKeyLocal(day)] = _readDistance(m);
    }

    final result = <HealthRecord>[];
    for (int i = 0; i < days; i++) {
      final d = startLocal.add(Duration(days: i));
      final key = _dateKeyLocal(d);

      result.add(
        HealthRecord(
          date: d,
          distance: map[key] ?? 0,
        ),
      );
    }

    return result;
  }
}

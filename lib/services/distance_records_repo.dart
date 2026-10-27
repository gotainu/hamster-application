// lib/services/distance_records_repo.dart
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/health_record.dart';
import 'wheel_repo.dart';
import 'measurement_history_client.dart';

typedef Json = Map<String, dynamic>;

class MissingWheelDiameterException implements Exception {
  final String message;
  const MissingWheelDiameterException([this.message = '車輪の直径が未設定です']);

  @override
  String toString() => message;
}

class DailyDistanceRecord {
  final String dayKey;
  final DateTime date;
  final double distance;
  final int? rotations;
  final double? wheelDiameterCm;
  final String? subjectId, recordId;
  final int revision;
  final Map<String, dynamic>? timing;

  const DailyDistanceRecord({
    required this.dayKey,
    required this.date,
    required this.distance,
    this.rotations,
    this.wheelDiameterCm,
    this.subjectId,
    this.recordId,
    this.revision = 0,
    this.timing,
  });

  factory DailyDistanceRecord.fromJson(
    Json json, {
    required String fallbackDayKey,
    required DateTime fallbackDate,
  }) {
    final distanceRaw = json['distance'];
    final rotationsRaw = json['rotations'];
    final wheelDiameterRaw = json['wheelDiameterCm'];

    return DailyDistanceRecord(
      subjectId: json['subjectId'] as String?,
      recordId: json['recordId'] as String?,
      revision: json['revision'] is int ? json['revision'] as int : 0,
      timing: json['timing'] is Map
          ? Map<String, dynamic>.from(json['timing'] as Map)
          : null,
      dayKey: json['dayKey'] as String? ?? fallbackDayKey,
      date: fallbackDate,
      distance: distanceRaw is num ? distanceRaw.toDouble() : 0,
      rotations: rotationsRaw is num ? rotationsRaw.toInt() : null,
      wheelDiameterCm:
          wheelDiameterRaw is num ? wheelDiameterRaw.toDouble() : null,
    );
  }
}

class DistanceRecordsRepo {
  final FirebaseFirestore? _db;
  final FirebaseAuth? _auth;
  final MeasurementHistoryClient history;
  final WheelRepo? _wheelRepo;

  double? _cachedWheelDiameterCm;

  DistanceRecordsRepo({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    WheelRepo? wheelRepo,
    MeasurementHistoryClient? historyClient,
  })  : _db = db,
        _auth = auth,
        history = historyClient ??
            MeasurementHistoryClient(kind: 'distance', db: db, auth: auth),
        _wheelRepo = wheelRepo;

  String? get _uid => (_auth ?? FirebaseAuth.instance).currentUser?.uid;

  CollectionReference<Json>? _col() {
    final uid = _uid;
    if (uid == null) return null;
    return (_db ?? FirebaseFirestore.instance)
        .collection('users')
        .doc(uid)
        .collection('distance_records');
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

    final snap = await doc.get(const GetOptions(source: Source.server));
    if (!snap.exists) return 0;

    final data = snap.data();
    if (data == null) return 0;

    return _readDistance(data);
  }

  Future<DailyDistanceRecord?> fetchDailyRecord(DateTime dayLocal) async {
    final doc = _docByLocalDate(dayLocal);
    if (doc == null) return null;

    final snap = await doc.get(const GetOptions(source: Source.server));
    if (!snap.exists) return null;

    final data = snap.data();
    if (data == null) return null;

    final day = _readLocalDay(data) ?? _normalizeLocalDay(dayLocal);

    return DailyDistanceRecord.fromJson(
      data,
      fallbackDayKey: doc.id,
      fallbackDate: day,
    );
  }

  Stream<DailyDistanceRecord?> watchDailyRecord(DateTime dayLocal) {
    final doc = _docByLocalDate(dayLocal);
    if (doc == null) {
      return Stream<DailyDistanceRecord?>.value(null);
    }

    return doc.snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return null;

      final day = _readLocalDay(data) ?? _normalizeLocalDay(dayLocal);

      return DailyDistanceRecord.fromJson(
        data,
        fallbackDayKey: snapshot.id,
        fallbackDate: day,
      );
    });
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

    final total =
        series.fold<double>(0, (total, entry) => total + entry.distance);
    return total / days;
  }

  // -------------------------
  // ★ 直径キャッシュ更新
  // -------------------------
  Future<double?> refreshWheelDiameter() async {
    final d = await (_wheelRepo ?? WheelRepo(db: _db, auth: _auth))
        .fetchWheelDiameter();
    _cachedWheelDiameterCm = (d != null && d > 0) ? d : null;
    return _cachedWheelDiameterCm;
  }

  double? get cachedWheelDiameterCm => _cachedWheelDiameterCm;

  // -------------------------
  // ★ プレビュー距離計算（m）
  // -------------------------
  Future<double?> previewDistanceFromRotations(int rotations,
      {double? wheelDiameterCm}) async {
    if (rotations < 0) return null;

    var d = wheelDiameterCm ?? _cachedWheelDiameterCm;
    d ??= await refreshWheelDiameter();

    if (d == null || d <= 0) return null;

    return rotations * (math.pi * d) / 100.0;
  }

  // -------------------------
  // ★ 回転数→距離→日次レコードを上書き保存
  // -------------------------
  Future<void> addWheelRotationRecord(
      {required int rotations,
      DateTime? date,
      String source = 'wheel_manual'}) async {
    final day = date ?? DateTime.now();
    await saveRotationRecord(
        rotations: rotations,
        date: day,
        expectedRecord: await fetchDailyRecord(day),
        source: source);
  }

  Future<DailyDistanceRecord> saveRotationRecord(
      {required int rotations,
      required DateTime date,
      DailyDistanceRecord? expectedRecord,
      Map<String, dynamic>? timing,
      bool legacyConfirmed = false,
      bool diameterCorrection = false,
      double? wheelDiameterCm,
      String? originalDayKey,
      String source = 'wheel_manual'}) async {
    if (rotations < 0) throw ArgumentError.value(rotations, 'rotations');
    return _saveRecord(
        date: date,
        expectedRecord: expectedRecord,
        timing: timing,
        legacyConfirmed: legacyConfirmed,
        originalDayKey: originalDayKey,
        values: {
          'mode': 'rotations',
          'rotations': rotations,
          'source': source,
          if (diameterCorrection) 'diameterCorrection': true,
          if (diameterCorrection) 'wheelDiameterCm': wheelDiameterCm
        });
  }

  Future<void> addDistanceRecord(
      {required DateTime date,
      required double distance,
      String source = 'wheel_manual'}) async {
    if (!distance.isFinite || distance < 0) {
      throw ArgumentError.value(distance, 'distance');
    }
    await _saveRecord(
        date: date,
        expectedRecord: await fetchDailyRecord(date),
        values: {
          'mode': 'direct_distance',
          'distance': distance,
          'source': source
        });
  }

  Future<DailyDistanceRecord> _saveRecord(
      {required DateTime date,
      required Map<String, dynamic> values,
      DailyDistanceRecord? expectedRecord,
      Map<String, dynamic>? timing,
      bool legacyConfirmed = false,
      String? originalDayKey}) async {
    final day = _dateKeyLocal(date);
    // A selected date identifies the daily record, not its measured coverage.
    final preservedTiming =
        expectedRecord?.dayKey == day ? expectedRecord?.timing : null;
    final result = await history.save({
      'dayKey': day,
      'date': _normalizeLocalDay(date).toUtc().toIso8601String(),
      'subjectId': expectedRecord?.subjectId ?? await history.currentSubject(),
      'expectedRevision':
          expectedRecord?.revision ?? await history.dayRevision(day),
      'operation': 'save',
      'inputUiVersion': 'measurement_history_v1',
      ...values,
      'timing': measurementWireTiming(timing ??
          preservedTiming ??
          {...unknownMeasurementTiming, 'windowMeaning': 'unknown'}),
      if (legacyConfirmed) 'legacyConfirmed': true,
      if (originalDayKey != null) 'originalDayKey': originalDayKey
    });
    return DailyDistanceRecord.fromJson(
        Map<String, dynamic>.from(result['projection'] as Map),
        fallbackDayKey: day,
        fallbackDate: _normalizeLocalDay(date));
  }

  Future<void> cancelRecord(DailyDistanceRecord record,
      {bool legacyConfirmed = false}) async {
    await history.save({
      'dayKey': record.dayKey,
      'date': record.date.toUtc().toIso8601String(),
      'subjectId': record.subjectId ?? await history.currentSubject(),
      'expectedRevision': record.revision,
      'operation': 'cancel',
      'inputUiVersion': 'measurement_history_v1',
      if (legacyConfirmed) 'legacyConfirmed': true
    });
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

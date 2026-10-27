import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/weight_record.dart';
import 'measurement_history_client.dart';

typedef Json = Map<String, dynamic>;

class WeightRecordsRepo {
  final FirebaseFirestore? _db;
  final FirebaseAuth? _auth;
  final MeasurementHistoryClient history;

  WeightRecordsRepo({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    MeasurementHistoryClient? historyClient,
  })  : _db = db,
        _auth = auth,
        history = historyClient ??
            MeasurementHistoryClient(kind: 'weight', db: db, auth: auth);

  String? get _uid => (_auth ?? FirebaseAuth.instance).currentUser?.uid;

  CollectionReference<Json>? _col() {
    final uid = _uid;
    if (uid == null) return null;

    return (_db ?? FirebaseFirestore.instance)
        .collection('users')
        .doc(uid)
        .collection('weight_records');
  }

  DateTime normalizeLocalDay(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  String dateKeyLocal(DateTime value) {
    final day = normalizeLocalDay(value);
    final year = day.year.toString().padLeft(4, '0');
    final month = day.month.toString().padLeft(2, '0');
    final date = day.day.toString().padLeft(2, '0');
    return '$year-$month-$date';
  }

  DocumentReference<Json>? _docByDate(DateTime value) {
    final col = _col();
    if (col == null) return null;
    return col.doc(dateKeyLocal(value));
  }

  Future<WeightRecord?> fetchByDate(DateTime value) async {
    final doc = _docByDate(value);
    if (doc == null) return null;

    final snapshot = await doc.get(const GetOptions(source: Source.server));
    final data = snapshot.data();

    if (!snapshot.exists || data == null) return null;

    return WeightRecord.fromJson(
      data,
      fallbackDayKey: snapshot.id,
    );
  }

  Future<WeightRecord?> fetchLatest() async {
    final col = _col();
    if (col == null) return null;

    final snapshot = await col.orderBy('date', descending: true).limit(1).get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    return WeightRecord.fromJson(
      doc.data(),
      fallbackDayKey: doc.id,
    );
  }

  Future<WeightRecord?> fetchLatestBefore(DateTime value) async {
    final col = _col();
    if (col == null) return null;

    final day = normalizeLocalDay(value);
    final snapshot = await col
        .where('date', isLessThan: Timestamp.fromDate(day.toUtc()))
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    return WeightRecord.fromJson(
      doc.data(),
      fallbackDayKey: doc.id,
    );
  }

  Future<List<WeightRecord>> fetchAll() async {
    final col = _col();
    if (col == null) return const [];

    final snapshot = await col.orderBy('date').get();

    return snapshot.docs
        .map(
          (doc) => WeightRecord.fromJson(
            doc.data(),
            fallbackDayKey: doc.id,
          ),
        )
        .toList();
  }

  Stream<WeightRecord?> watchLatest() {
    final col = _col();
    if (col == null) return Stream<WeightRecord?>.value(null);

    return col
        .orderBy('date', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      return WeightRecord.fromJson(
        doc.data(),
        fallbackDayKey: doc.id,
      );
    });
  }

  Stream<List<WeightRecord>> watchAll() {
    final col = _col();
    if (col == null) return Stream<List<WeightRecord>>.value(const []);

    return col.orderBy('date').snapshots().map((snapshot) {
      return snapshot.docs
          .map(
            (doc) => WeightRecord.fromJson(
              doc.data(),
              fallbackDayKey: doc.id,
            ),
          )
          .toList();
    });
  }

  Future<void> save({
    required DateTime date,
    required double weightGrams,
    String memo = '',
  }) async {
    final existing = await fetchByDate(date);
    await saveRecord(
        date: date,
        weightGrams: weightGrams,
        memo: memo,
        expectedRecord: existing);
  }

  Future<WeightRecord> saveRecord(
      {required DateTime date,
      required double weightGrams,
      String memo = '',
      WeightRecord? expectedRecord,
      Map<String, dynamic>? timing,
      bool legacyConfirmed = false,
      String? originalDayKey}) async {
    if (!weightGrams.isFinite || weightGrams <= 0 || weightGrams > 1000) {
      throw ArgumentError.value(
          weightGrams, 'weightGrams', '体重は0より大きく1000g以下で入力してください');
    }
    final day = dateKeyLocal(date);
    final result = await history.save({
      'dayKey': day,
      'date': normalizeLocalDay(date).toUtc().toIso8601String(),
      'subjectId': expectedRecord?.subjectId ?? await history.currentSubject(),
      'expectedRevision':
          expectedRecord?.revision ?? await history.dayRevision(day),
      'operation': 'save',
      'inputUiVersion': 'measurement_history_v1',
      'weightGrams': weightGrams,
      'memo': memo.trim(),
      'timing': measurementWireTiming(
          timing ?? expectedRecord?.timing ?? measurementDateTiming(day)),
      if (legacyConfirmed) 'legacyConfirmed': true,
      if (originalDayKey != null) 'originalDayKey': originalDayKey,
    });
    return WeightRecord.fromJson(
        Map<String, dynamic>.from(result['projection'] as Map),
        fallbackDayKey: day);
  }

  Future<void> cancelRecord(WeightRecord record,
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
}

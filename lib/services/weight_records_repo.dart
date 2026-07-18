import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/weight_record.dart';

typedef Json = Map<String, dynamic>;

class WeightRecordsRepo {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  WeightRecordsRepo({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Json>? _col() {
    final uid = _uid;
    if (uid == null) return null;

    return _db.collection('users').doc(uid).collection('weight_records');
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

    final snapshot = await doc.get();
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
    if (!weightGrams.isFinite || weightGrams <= 0 || weightGrams > 1000) {
      throw ArgumentError.value(
        weightGrams,
        'weightGrams',
        '体重は0より大きく1000g以下で入力してください',
      );
    }

    final doc = _docByDate(date);
    if (doc == null) return;

    final localDay = normalizeLocalDay(date);
    final snapshot = await doc.get();

    final data = <String, dynamic>{
      'dayKey': dateKeyLocal(localDay),
      'date': Timestamp.fromDate(localDay.toUtc()),
      'weightGrams': weightGrams,
      'memo': memo.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!snapshot.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await doc.set(data, SetOptions(merge: true));
  }
}

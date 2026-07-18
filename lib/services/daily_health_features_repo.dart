import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/daily_health_features.dart';

typedef Json = Map<String, dynamic>;

class DailyHealthFeaturesRepo {
  static const collectionName = 'daily_health_features';

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  DailyHealthFeaturesRepo({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Json>? _collection() {
    final uid = _uid;
    if (uid == null) return null;

    return _db.collection('users').doc(uid).collection(collectionName);
  }

  String dateKeyLocal(DateTime value) {
    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<DailyHealthFeatures?> fetchByDate(DateTime date) async {
    return fetchByDateKey(dateKeyLocal(date));
  }

  Future<DailyHealthFeatures?> fetchByDateKey(
    String dateKey,
  ) async {
    final collection = _collection();
    if (collection == null) return null;

    final snapshot = await collection.doc(dateKey).get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) return null;

    return DailyHealthFeatures.fromMap(
      data,
      fallbackDateKey: snapshot.id,
    );
  }

  Future<DailyHealthFeatures?> fetchLatest() async {
    final collection = _collection();
    if (collection == null) return null;

    final snapshot =
        await collection.orderBy('dateKey', descending: true).limit(1).get();

    if (snapshot.docs.isEmpty) return null;

    final document = snapshot.docs.first;
    return DailyHealthFeatures.fromMap(
      document.data(),
      fallbackDateKey: document.id,
    );
  }

  Future<List<DailyHealthFeatures>> fetchRecent({
    int limit = 30,
  }) async {
    final collection = _collection();
    if (collection == null) return const [];

    final safeLimit = limit.clamp(1, 365);
    final snapshot = await collection
        .orderBy('dateKey', descending: true)
        .limit(safeLimit)
        .get();

    return snapshot.docs
        .map(
          (document) => DailyHealthFeatures.fromMap(
            document.data(),
            fallbackDateKey: document.id,
          ),
        )
        .toList(growable: false);
  }

  Stream<DailyHealthFeatures?> watchByDateKey(
    String dateKey,
  ) {
    final collection = _collection();
    if (collection == null) {
      return Stream<DailyHealthFeatures?>.value(null);
    }

    return collection.doc(dateKey).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return null;

      return DailyHealthFeatures.fromMap(
        data,
        fallbackDateKey: snapshot.id,
      );
    });
  }

  Stream<DailyHealthFeatures?> watchLatest() {
    final collection = _collection();
    if (collection == null) {
      return Stream<DailyHealthFeatures?>.value(null);
    }

    return collection
        .orderBy('dateKey', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;

      final document = snapshot.docs.first;
      return DailyHealthFeatures.fromMap(
        document.data(),
        fallbackDateKey: document.id,
      );
    });
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/health_assessment.dart';

typedef Json = Map<String, dynamic>;

class HealthAssessmentRepo {
  static const latestCollectionName = 'health_assessments';
  static const historyCollectionName = 'health_assessments_history';
  static const latestDocumentId = 'latest';

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  HealthAssessmentRepo({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Json>? _latestDocument() {
    final uid = _uid;
    if (uid == null) return null;

    return _db
        .collection('users')
        .doc(uid)
        .collection(latestCollectionName)
        .doc(latestDocumentId);
  }

  CollectionReference<Json>? _historyCollection() {
    final uid = _uid;
    if (uid == null) return null;

    return _db.collection('users').doc(uid).collection(historyCollectionName);
  }

  Future<HealthAssessment?> fetchLatest() async {
    final document = _latestDocument();
    if (document == null) return null;

    final snapshot = await document.get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) return null;

    return HealthAssessment.fromMap(
      data,
      fallbackDateKey: latestDocumentId,
    );
  }

  Stream<HealthAssessment?> watchLatest() {
    final document = _latestDocument();
    if (document == null) {
      return Stream<HealthAssessment?>.value(null);
    }

    return document.snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return null;

      return HealthAssessment.fromMap(
        data,
        fallbackDateKey: latestDocumentId,
      );
    });
  }

  Future<HealthAssessment?> fetchHistoryByDateKey(
    String dateKey,
  ) async {
    final collection = _historyCollection();
    if (collection == null) return null;

    final snapshot = await collection.doc(dateKey).get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) return null;

    return HealthAssessment.fromMap(
      data,
      fallbackDateKey: snapshot.id,
    );
  }

  Future<List<HealthAssessment>> fetchRecentHistory({
    int limit = 30,
  }) async {
    final collection = _historyCollection();
    if (collection == null) return const [];

    final safeLimit = limit.clamp(1, 365);
    final snapshot = await collection
        .orderBy('dateKey', descending: true)
        .limit(safeLimit)
        .get();

    return snapshot.docs
        .map(
          (document) => HealthAssessment.fromMap(
            document.data(),
            fallbackDateKey: document.id,
          ),
        )
        .toList(growable: false);
  }

  Stream<List<HealthAssessment>> watchRecentHistory({
    int limit = 30,
  }) {
    final collection = _historyCollection();
    if (collection == null) {
      return Stream<List<HealthAssessment>>.value(const []);
    }

    final safeLimit = limit.clamp(1, 365);

    return collection
        .orderBy('dateKey', descending: true)
        .limit(safeLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) => HealthAssessment.fromMap(
                  document.data(),
                  fallbackDateKey: document.id,
                ),
              )
              .toList(growable: false),
        );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/environment_assessment.dart';
import '../models/environment_assessment_history.dart';

class EnvironmentAssessmentRepo {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  EnvironmentAssessmentRepo({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? _latestDoc() {
    final uid = _uid;
    if (uid == null) return null;

    return _db
        .collection('users')
        .doc(uid)
        .collection('environment_assessments')
        .doc('latest');
  }

  Stream<EnvironmentAssessment?> watchLatest() {
    final doc = _latestDoc();
    if (doc == null) return const Stream<EnvironmentAssessment?>.empty();

    return doc.snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      return EnvironmentAssessment.fromMap(data);
    });
  }

  Future<EnvironmentAssessment?> fetchLatest() async {
    final doc = _latestDoc();
    if (doc == null) return null;

    final snap = await doc.get();
    if (!snap.exists) return null;

    final data = snap.data();
    if (data == null) return null;

    return EnvironmentAssessment.fromMap(data);
  }

  CollectionReference<Map<String, dynamic>>? _historyCol() {
    final uid = _uid;
    if (uid == null) return null;

    return _db
        .collection('users')
        .doc(uid)
        .collection('environment_assessments_history');
  }

  Stream<List<EnvironmentAssessmentHistory>> watchRecentHistory({
    int limit = 7,
  }) {
    final col = _historyCol();
    if (col == null) {
      return const Stream<List<EnvironmentAssessmentHistory>>.empty();
    }

    return col
        .orderBy('dateKey', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final items = snap.docs
          .map((d) => EnvironmentAssessmentHistory.fromMap(d.data()))
          .where((e) => e.hasCoreData)
          .toList();

      items.sort((a, b) => (a.dateKey ?? '').compareTo(b.dateKey ?? ''));
      return items;
    });
  }

  Future<List<EnvironmentAssessmentHistory>> fetchRecentHistory({
    int limit = 7,
  }) async {
    final col = _historyCol();
    if (col == null) return const [];

    final snap =
        await col.orderBy('dateKey', descending: true).limit(limit).get();

    final items = snap.docs
        .map((d) => EnvironmentAssessmentHistory.fromMap(d.data()))
        .where((e) => e.hasCoreData)
        .toList();

    items.sort((a, b) => (a.dateKey ?? '').compareTo(b.dateKey ?? ''));
    return items;
  }
}

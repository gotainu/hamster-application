import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PersonalizedAnalysisRepo {
  PersonalizedAnalysisRepo({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  CollectionReference<Map<String, dynamic>>? get _readiness {
    final uid = _auth.currentUser?.uid;
    return uid == null
        ? null
        : _db.collection('users').doc(uid).collection('analysis_readiness');
  }

  Stream<List<Map<String, dynamic>>> watchReadiness() {
    final col = _readiness;
    return col == null
        ? Stream.value(const [])
        : col.snapshots().map(
            (s) => s.docs.map((d) => {...d.data(), 'metric': d.id}).toList());
  }

  Stream<Map<String, dynamic>?> watchFirstReport() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _db
        .collection('users')
        .doc(uid)
        .collection('personalized_reports')
        .doc('first')
        .snapshots()
        .map((s) => s.data());
  }
}

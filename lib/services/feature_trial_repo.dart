import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/feature_trial_access.dart';

class FeatureTrialRepo {
  FeatureTrialRepo(
      {FirebaseFirestore? db, FirebaseAuth? auth, FirebaseFunctions? functions})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-northeast1');
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  DocumentReference<Map<String, dynamic>>? _doc() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _db
        .collection('users')
        .doc(uid)
        .collection('feature_access')
        .doc('trial');
  }

  Stream<FeatureTrialAccess> watch() {
    final doc = _doc();
    if (doc == null) return Stream.value(FeatureTrialAccess.empty());
    return doc
        .snapshots()
        .map((snap) => FeatureTrialAccess.fromMap(snap.data()));
  }

  Future<FeatureTrialAccess> fetch() async {
    final doc = _doc();
    if (doc == null) return FeatureTrialAccess.empty();
    final snap = await doc.get();
    return FeatureTrialAccess.fromMap(snap.data());
  }

  Future<void> activate() async {
    await _functions.httpsCallable('activateFeatureTrial').call();
  }

  Future<void> consumeAiTrial() async {
    await _functions.httpsCallable('consumeAiTrial').call();
  }
}

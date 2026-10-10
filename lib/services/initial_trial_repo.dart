import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/initial_trial_access.dart';

class InitialTrialRepo {
  InitialTrialRepo(
      {FirebaseAuth? auth, FirebaseFirestore? db, FirebaseFunctions? functions})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-northeast1');
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  DocumentReference<Map<String, dynamic>>? get _doc {
    final uid = _auth.currentUser?.uid;
    return uid == null
        ? null
        : _db
            .collection('users')
            .doc(uid)
            .collection('feature_access')
            .doc('initial_trial_v2');
  }

  Stream<InitialTrialAccess> watch() {
    final doc = _doc;
    return doc == null
        ? Stream.value(InitialTrialAccess.empty())
        : doc.snapshots().map((s) => InitialTrialAccess.fromMap(s.data()));
  }

  Future<void> start() async {
    await _functions.httpsCallable('startInitialTrial').call();
  }

  Future<void> consumeAi({required String requestId}) async {
    await _functions
        .httpsCallable('consumeInitialTrialAi')
        .call({'requestId': requestId});
  }
}

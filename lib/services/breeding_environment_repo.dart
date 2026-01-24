// lib/services/breeding_environment_repo.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/breeding_environment.dart';

class BreedingEnvironmentRepo {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  BreedingEnvironmentRepo({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? _mainEnvDoc() {
    final uid = _uid;
    if (uid == null) return null;
    return _db
        .collection('users')
        .doc(uid)
        .collection('breeding_environments')
        .doc('main_env');
  }

  Future<BreedingEnvironment?> fetchMainEnv() async {
    final ref = _mainEnvDoc();
    if (ref == null) return null;
    final snap = await ref.get();
    if (!snap.exists) return null;
    final data = snap.data() ?? <String, dynamic>{};
    return BreedingEnvironment.fromMap(data);
  }

  Future<void> saveMainEnv(BreedingEnvironment env) async {
    final uid = _uid;
    final ref = _mainEnvDoc();
    if (uid == null || ref == null) return;

    await _db.collection('users').doc(uid).set(
      {'has_subcollections': true},
      SetOptions(merge: true),
    );

    await ref.set(
      {
        ...env.toMapForSave(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<double?> fetchWheelDiameter() async {
    final env = await fetchMainEnv();
    return env?.wheelDiameterAsDouble();
  }

  Stream<BreedingEnvironment?> watchMainEnv() {
    final ref = _mainEnvDoc();
    if (ref == null) return const Stream.empty();

    return ref.snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data() ?? <String, dynamic>{};
      return BreedingEnvironment.fromMap(data);
    });
  }
}

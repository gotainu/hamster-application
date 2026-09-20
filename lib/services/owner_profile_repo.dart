import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/owner_profile.dart';

class OwnerProfileRepo {
  OwnerProfileRepo({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>>? _doc() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _db
        .collection('users')
        .doc(uid)
        .collection('owner_profiles')
        .doc('main');
  }

  Future<OwnerProfile?> fetch() async {
    final doc = _doc();
    if (doc == null) return null;
    final snap = await doc.get();
    if (!snap.exists) return null;
    return OwnerProfile.fromMap(snap.data() ?? <String, dynamic>{});
  }

  Future<void> save(OwnerProfile profile) async {
    final doc = _doc();
    if (doc == null) return;
    await doc.set(profile.toMapForSave(), SetOptions(merge: true));
  }
}

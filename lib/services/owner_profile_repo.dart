import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/owner_profile.dart';

class OwnerProfileRepo {
  OwnerProfileRepo({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _ownerUid = (auth ?? FirebaseAuth.instance).currentUser?.uid;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  // An editor must never save one owner's draft into a different account.
  final String? _ownerUid;

  DocumentReference<Map<String, dynamic>>? _doc() {
    final uid = _ownerUid;
    if (uid == null || _auth.currentUser?.uid != uid) return null;
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
    if (_auth.currentUser?.uid != _ownerUid || !snap.exists) return null;
    return OwnerProfile.fromMap(snap.data() ?? <String, dynamic>{});
  }

  Future<void> save(OwnerProfile profile) async {
    final doc = _doc();
    if (doc == null) {
      throw StateError('プロフィールの保存先アカウントを確認できません。');
    }
    await doc.set(profile.toMapForSave(), SetOptions(merge: true));
  }
}

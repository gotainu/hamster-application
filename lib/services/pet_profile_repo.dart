// lib/services/pet_profile_repo.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/pet_profile.dart';

class PetProfileRepo {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  PetProfileRepo({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? _mainPetDoc() {
    final uid = _uid;
    if (uid == null) return null;
    return _db
        .collection('users')
        .doc(uid)
        .collection('pet_profiles')
        .doc('main_pet');
  }

  Stream<PetProfile?> watchMainPet() {
    final doc = _mainPetDoc();
    if (doc == null) return const Stream<PetProfile?>.empty();

    return doc.snapshots().map((snap) {
      if (!snap.exists) return null;
      final m = snap.data() ?? <String, dynamic>{};
      return PetProfile.fromMap(m);
    });
  }

  Future<PetProfile?> fetchMainPet() async {
    final doc = _mainPetDoc();
    if (doc == null) return null;
    final snap = await doc.get();
    if (!snap.exists) return null;
    return PetProfile.fromMap(snap.data() ?? <String, dynamic>{});
  }

  // ★「PetProfileを受け取る版」に統一
  Future<void> saveMainPet(PetProfile p) async {
    final doc = _mainPetDoc();
    if (doc == null) return;

    await doc.set(p.toMapForSave(), SetOptions(merge: true));
  }

  Future<void> deleteImageUrl() async {
    final doc = _mainPetDoc();
    if (doc == null) return;

    await doc.set({
      'imageUrl': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

// lib/services/billing_status_repo.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/billing_status.dart';

class BillingStatusRepo {
  BillingStatusRepo({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? _subscriptionDoc() {
    final uid = _uid;
    if (uid == null) return null;

    return _db
        .collection('users')
        .doc(uid)
        .collection('billing')
        .doc('subscription');
  }

  Stream<BillingStatus> watchBillingStatus() {
    final doc = _subscriptionDoc();

    if (doc == null) {
      return Stream.value(BillingStatus.empty());
    }

    return doc.snapshots().map(
          (snap) => BillingStatus.fromMap(snap.data()),
        );
  }

  Future<BillingStatus> fetchBillingStatus() async {
    final doc = _subscriptionDoc();

    if (doc == null) {
      return BillingStatus.empty();
    }

    final snap = await doc.get();
    return BillingStatus.fromMap(snap.data());
  }
}

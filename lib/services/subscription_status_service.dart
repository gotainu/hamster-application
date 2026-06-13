import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/subscription_status.dart';

class SubscriptionStatusService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  SubscriptionStatusService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

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

  Stream<SubscriptionStatus> watchStatus() {
    final doc = _subscriptionDoc();

    if (doc == null) {
      return Stream.value(SubscriptionStatus.inactive);
    }

    return doc.snapshots().map(SubscriptionStatus.fromDoc);
  }

  Future<SubscriptionStatus> fetchStatus() async {
    final doc = _subscriptionDoc();

    if (doc == null) {
      return SubscriptionStatus.inactive;
    }

    final snap = await doc.get();
    return SubscriptionStatus.fromDoc(snap);
  }
}

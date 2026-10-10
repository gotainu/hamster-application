// lib/services/billing_status_repo.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/billing_status.dart';
import '../models/entitlement_snapshot.dart';
import '../models/initial_trial_access.dart';
import '../models/feature_trial_access.dart';

class BillingStatusRepo {
  BillingStatusRepo({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String? get currentUserId => _auth.currentUser?.uid;
  String? get _uid => currentUserId;

  Stream<String?> watchUserId() =>
      _auth.authStateChanges().map((user) => user?.uid).distinct();

  DocumentReference<Map<String, dynamic>>? _subscriptionDoc() {
    final uid = _uid;
    if (uid == null) return null;

    return _db
        .collection('users')
        .doc(uid)
        .collection('billing')
        .doc('subscription');
  }

  Stream<EntitlementSnapshot<BillingStatus>> watchBillingStatus() =>
      _watchServerDocument(_subscriptionDoc(), BillingStatus.fromMap);

  Stream<EntitlementSnapshot<InitialTrialAccess>> watchInitialTrialAccess() =>
      _watchServerDocument(
        _featureAccessDoc('initial_trial_v2'),
        InitialTrialAccess.fromMap,
      );

  Stream<EntitlementSnapshot<FeatureTrialAccess>> watchFeatureTrialAccess() =>
      _watchServerDocument(
        _featureAccessDoc('trial'),
        FeatureTrialAccess.fromMap,
      );

  DocumentReference<Map<String, dynamic>>? _featureAccessDoc(String name) {
    final uid = _uid;
    if (uid == null) return null;
    return _db
        .collection('users')
        .doc(uid)
        .collection('feature_access')
        .doc(name);
  }

  Stream<EntitlementSnapshot<T>> _watchServerDocument<T>(
    DocumentReference<Map<String, dynamic>>? doc,
    T Function(Map<String, dynamic>?) parse,
  ) {
    final uid = _uid;
    if (doc == null) {
      return Stream.value(EntitlementSnapshot<T>.pending(uid));
    }
    return doc.snapshots(includeMetadataChanges: true).map((snapshot) {
      if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
        return EntitlementSnapshot<T>.pending(uid);
      }
      return EntitlementSnapshot<T>.confirmed(uid, parse(snapshot.data()));
    });
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

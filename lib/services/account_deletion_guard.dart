import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AccountDeletionEligibility { freeAccount, contractPresent, unavailable }

/// Temporary app-side boundary until server-side cancellation and deletion are
/// handled together. This does not certify the absence of a Stripe contract.
class AccountDeletionGuard {
  AccountDeletionGuard({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  Future<AccountDeletionEligibility> check(String expectedUid) async {
    if (expectedUid.isEmpty || _auth.currentUser?.uid != expectedUid) {
      return AccountDeletionEligibility.unavailable;
    }
    try {
      final snapshot = await _db
          .doc('users/$expectedUid/billing/subscription')
          .get(const GetOptions(source: Source.server));
      if (_auth.currentUser?.uid != expectedUid ||
          snapshot.metadata.isFromCache ||
          snapshot.metadata.hasPendingWrites) {
        return AccountDeletionEligibility.unavailable;
      }
      return fromBillingData(snapshot.data());
    } catch (_) {
      return AccountDeletionEligibility.unavailable;
    }
  }

  static AccountDeletionEligibility fromBillingData(
      Map<String, dynamic>? data) {
    if (data == null) return AccountDeletionEligibility.freeAccount;
    final subscriptionId = data['stripeSubscriptionId'];
    final plan = data['plan'];
    final status = data['status'];
    final cancelAtPeriodEnd = data['cancelAtPeriodEnd'];
    if ((subscriptionId != null && subscriptionId != '') ||
        (plan != null && plan != 'none') ||
        (status != null && status != 'none' && status != 'canceled') ||
        (cancelAtPeriodEnd != null && cancelAtPeriodEnd != false)) {
      return AccountDeletionEligibility.contractPresent;
    }
    // A Customer reference alone is setup information, not a subscription.
    return AccountDeletionEligibility.freeAccount;
  }
}

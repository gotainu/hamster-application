/// A cached entitlement is pending, even when the cached document is missing.
/// Only a server-confirmed snapshot may supply an access decision.
class EntitlementSnapshot<T> {
  const EntitlementSnapshot.pending(this.uid) : data = null;
  const EntitlementSnapshot.confirmed(this.uid, T value) : data = value;

  final String? uid;
  final T? data;

  bool get isServerConfirmed => uid != null && data != null;
}

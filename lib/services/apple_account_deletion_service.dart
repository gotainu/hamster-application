import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum AppleDeletionRevocation { notLinked, revoked, cancelled, unavailable }

/// No authentication data is attached to an error shown by the deletion UI.
class AppleDeletionIdentityChanged implements Exception {}

/// Obtains and immediately consumes an Apple authorization code after deletion
/// consent. No code is kept while the server may wait/retry Stripe cancellation.
/// Firebase Auth and account data are still deleted by the existing server flow.
class AppleAccountDeletionService {
  AppleAccountDeletionService({
    FirebaseAuth? auth,
    bool? supportsNativeRevocation,
    Duration revocationTimeout = const Duration(seconds: 30),
  })  : _auth = auth ?? FirebaseAuth.instance,
        _revocationTimeout = revocationTimeout,
        _supportsNativeRevocation = supportsNativeRevocation ??
            (!kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.iOS ||
                    defaultTargetPlatform == TargetPlatform.macOS));

  final FirebaseAuth _auth;
  final bool _supportsNativeRevocation;
  final Duration _revocationTimeout;

  static const _fatalAuthCodes = {
    'user-mismatch',
    'credential-already-in-use',
    'account-exists-with-different-credential',
    'invalid-user-token',
    'user-token-expired',
    'user-disabled',
    'user-not-found',
  };

  String? _appleSubject(User user) {
    final subjects = user.providerData
        .where((provider) => provider.providerId == 'apple.com')
        .map((provider) => provider.uid)
        .toSet();
    if (subjects.isEmpty) return null;
    if (subjects.length != 1) {
      throw AppleDeletionIdentityChanged();
    }
    final subject = subjects.single;
    if (subject == null || subject.trim().isEmpty) {
      throw AppleDeletionIdentityChanged();
    }
    return subject;
  }

  User _sameAccount(String uid, String? appleSubject) {
    final current = _auth.currentUser;
    if (uid.isEmpty ||
        current == null ||
        current.uid != uid ||
        _appleSubject(current) != appleSubject) {
      throw AppleDeletionIdentityChanged();
    }
    return current;
  }

  Future<AppleDeletionRevocation> prepare(String expectedUid) async {
    final original = _auth.currentUser;
    if (expectedUid.isEmpty ||
        original == null ||
        original.uid != expectedUid) {
      throw AppleDeletionIdentityChanged();
    }
    final linkedApple = original.providerData
        .where((provider) => provider.providerId == 'apple.com')
        .toList();
    if (linkedApple.isNotEmpty &&
        linkedApple.every((provider) => provider.uid?.trim().isEmpty ?? true)) {
      // An older linked account may lack a usable subject. Do not attempt to
      // revoke an unknown Apple identity or permanently deny owner deletion.
      if (_auth.currentUser?.uid != expectedUid) {
        throw AppleDeletionIdentityChanged();
      }
      return AppleDeletionRevocation.unavailable;
    }
    final subject = _appleSubject(original);
    _sameAccount(expectedUid, subject);
    if (subject == null) return AppleDeletionRevocation.notLinked;
    if (!_supportsNativeRevocation) return AppleDeletionRevocation.unavailable;

    UserCredential result;
    try {
      result = await original.reauthenticateWithProvider(AppleAuthProvider());
    } on FirebaseAuthException catch (error) {
      _sameAccount(expectedUid, subject);
      if (_fatalAuthCodes.contains(error.code)) {
        throw AppleDeletionIdentityChanged();
      }
      if (const {
        'web-context-cancelled',
        'popup-closed-by-user',
        'canceled',
        'cancelled',
      }.contains(error.code)) {
        return AppleDeletionRevocation.cancelled;
      }
      return AppleDeletionRevocation.unavailable;
    } catch (_) {
      _sameAccount(expectedUid, subject);
      return AppleDeletionRevocation.unavailable;
    }
    _sameAccount(expectedUid, subject);
    final reauthenticated = result.user;
    if (reauthenticated == null ||
        reauthenticated.uid != expectedUid ||
        _appleSubject(reauthenticated) != subject) {
      throw AppleDeletionIdentityChanged();
    }
    final info = result.additionalUserInfo;
    if (info?.providerId != 'apple.com') {
      return AppleDeletionRevocation.unavailable;
    }

    // Apple codes are single-use and short-lived. This value never leaves this
    // operation, is not returned to callers and is never persisted or logged.
    String? code = info?.authorizationCode;
    if (code == null || code.trim().isEmpty) {
      return AppleDeletionRevocation.unavailable;
    }
    try {
      await _auth
          .revokeTokenWithAuthorizationCode(code)
          .timeout(_revocationTimeout);
      _sameAccount(expectedUid, subject);
      return AppleDeletionRevocation.revoked;
    } on AppleDeletionIdentityChanged {
      rethrow;
    } on FirebaseAuthException catch (error) {
      _sameAccount(expectedUid, subject);
      if (_fatalAuthCodes.contains(error.code)) {
        throw AppleDeletionIdentityChanged();
      }
      return AppleDeletionRevocation.unavailable;
    } catch (_) {
      _sameAccount(expectedUid, subject);
      return AppleDeletionRevocation.unavailable;
    } finally {
      code = null;
    }
  }
}

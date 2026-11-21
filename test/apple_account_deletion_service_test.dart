import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/services/apple_account_deletion_service.dart';

class _Provider implements UserInfo {
  _Provider(this.providerId, this.uid);
  @override
  final String providerId;
  @override
  final String? uid;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Info implements AdditionalUserInfo {
  _Info(
      {this.authorizationCode = 'synthetic-one-use-code',
      this.providerId = 'apple.com'});
  @override
  final String? authorizationCode;
  @override
  final String? providerId;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Credential implements UserCredential {
  _Credential(this.user, this.additionalUserInfo);
  @override
  final User? user;
  @override
  final AdditionalUserInfo? additionalUserInfo;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  _User(this.uid, [List<UserInfo>? providers])
      : providerData =
            providers ?? [_Provider('apple.com', 'synthetic-apple-subject')];
  @override
  final String uid;
  @override
  List<UserInfo> providerData;
  int reauthCalls = 0;
  Future<UserCredential> Function()? onReauth;
  @override
  Future<UserCredential> reauthenticateWithProvider(
      AuthProvider provider) async {
    expect(provider, isA<AppleAuthProvider>());
    reauthCalls++;
    return onReauth == null ? _Credential(this, _Info()) : await onReauth!();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  _Auth(this.currentUser);
  @override
  User? currentUser;
  final revokedCodes = <String>[];
  Future<void> Function()? onRevoke;
  @override
  Future<void> revokeTokenWithAuthorizationCode(String code) async {
    revokedCodes.add(code);
    await onRevoke?.call();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const uid = 'synthetic-owner';
  late _User original;
  late _Auth auth;
  late AppleAccountDeletionService service;
  setUp(() {
    original = _User(uid);
    auth = _Auth(original);
    service =
        AppleAccountDeletionService(auth: auth, supportsNativeRevocation: true);
  });

  test('fresh same-UID Apple reauthentication is immediately revoked',
      () async {
    var reauthenticated = false;
    original.onReauth = () async {
      reauthenticated = true;
      return _Credential(original, _Info());
    };
    auth.onRevoke = () async => expect(reauthenticated, isTrue);
    expect(await service.prepare(uid), AppleDeletionRevocation.revoked);
    expect(original.reauthCalls, 1);
    expect(auth.revokedCodes, ['synthetic-one-use-code']);
    expect(auth.currentUser?.uid, uid);
  });

  for (final provider in ['password', 'google.com']) {
    test('$provider without Apple is not reauthenticated or revoked', () async {
      original.providerData = [_Provider(provider, 'synthetic-provider')];
      expect(await service.prepare(uid), AppleDeletionRevocation.notLinked);
      expect(original.reauthCalls, 0);
      expect(auth.revokedCodes, isEmpty);
    });
  }
  test('linked Apple is handled regardless of other linked providers',
      () async {
    original.providerData.insertAll(0, [
      _Provider('password', uid),
      _Provider('google.com', 'synthetic-google'),
    ]);
    expect(await service.prepare(uid), AppleDeletionRevocation.revoked);
    expect(original.reauthCalls, 1);
  });

  for (final info in <AdditionalUserInfo?>[
    null,
    _Info(authorizationCode: null),
    _Info(authorizationCode: ''),
    _Info(authorizationCode: '   '),
    _Info(providerId: 'google.com'),
  ]) {
    test(
        'missing Apple authorization information falls back without revocation: ${info?.authorizationCode?.length}',
        () async {
      original.onReauth = () async => _Credential(original, info);
      expect(await service.prepare(uid), AppleDeletionRevocation.unavailable);
      expect(auth.revokedCodes, isEmpty);
    });
  }
  test(
      'unsupported platform permits manual fallback without an unnecessary Apple prompt',
      () async {
    final unsupported = AppleAccountDeletionService(
        auth: auth, supportsNativeRevocation: false);
    expect(await unsupported.prepare(uid), AppleDeletionRevocation.unavailable);
    expect(original.reauthCalls, 0);
    expect(auth.revokedCodes, isEmpty);
  });
  for (final code in [
    'web-context-cancelled',
    'popup-closed-by-user',
    'canceled',
    'cancelled'
  ]) {
    test('reauthentication cancellation returns a separate decision: $code',
        () async {
      original.onReauth = () async => throw FirebaseAuthException(code: code);
      expect(await service.prepare(uid), AppleDeletionRevocation.cancelled);
      expect(auth.revokedCodes, isEmpty);
    });
  }
  for (final error in [
    FirebaseAuthException(
        code: 'network-request-failed', message: 'synthetic secret'),
    StateError('synthetic authorization details'),
  ]) {
    test(
        'reauthentication failure returns no raw details: ${error.runtimeType}',
        () async {
      original.onReauth = () async => throw error;
      expect(await service.prepare(uid), AppleDeletionRevocation.unavailable);
      expect(auth.revokedCodes, isEmpty);
    });
  }
  test(
      'revocation failure allows explicit manual fallback and retains Firebase user',
      () async {
    auth.onRevoke =
        () async => throw FirebaseAuthException(code: 'network-request-failed');
    expect(await service.prepare(uid), AppleDeletionRevocation.unavailable);
    expect(auth.currentUser?.uid, uid);
  });
  test(
      'revocation wait is bounded so failure cannot indefinitely block deletion',
      () async {
    final never = Completer<void>();
    auth.onRevoke = () => never.future;
    final bounded = AppleAccountDeletionService(
        auth: auth,
        supportsNativeRevocation: true,
        revocationTimeout: const Duration(milliseconds: 1));
    expect(await bounded.prepare(uid), AppleDeletionRevocation.unavailable);
    never.complete();
  });
  for (final code in [
    'user-mismatch',
    'credential-already-in-use',
    'account-exists-with-different-credential',
    'invalid-user-token',
    'user-token-expired',
    'user-disabled',
    'user-not-found',
  ]) {
    test(
        'unsafe reauthentication is fatal and cannot use manual fallback: $code',
        () async {
      original.onReauth = () async =>
          throw FirebaseAuthException(code: code, message: 'synthetic-private');
      await expectLater(
          service.prepare(uid), throwsA(isA<AppleDeletionIdentityChanged>()));
      expect(auth.revokedCodes, isEmpty);
    });
  }
  test('invalid Firebase session during revoke is fatal', () async {
    auth.onRevoke =
        () async => throw FirebaseAuthException(code: 'invalid-user-token');
    await expectLater(
        service.prepare(uid), throwsA(isA<AppleDeletionIdentityChanged>()));
  });
  for (final other in <User?>[null, _User('another-owner')]) {
    test('missing or mismatched original UID stops before Apple', () async {
      auth.currentUser = other;
      await expectLater(
          service.prepare(uid), throwsA(isA<AppleDeletionIdentityChanged>()));
      expect(original.reauthCalls, 0);
      expect(auth.revokedCodes, isEmpty);
    });
  }
  for (final returned in <User?>[
    null,
    _User('another-owner'),
    _User(uid, [_Provider('apple.com', 'another-apple-subject')])
  ]) {
    test('returned credential must keep both UID and Apple identity', () async {
      original.onReauth = () async => _Credential(returned, _Info());
      await expectLater(
          service.prepare(uid), throwsA(isA<AppleDeletionIdentityChanged>()));
      expect(auth.revokedCodes, isEmpty);
    });
  }
  for (final failing in [false, true]) {
    test(
        'account switch during reauthentication never revokes another account: failure=$failing',
        () async {
      original.onReauth = () async {
        auth.currentUser = _User('another-owner');
        if (failing) throw FirebaseAuthException(code: 'web-context-cancelled');
        return _Credential(original, _Info());
      };
      await expectLater(
          service.prepare(uid), throwsA(isA<AppleDeletionIdentityChanged>()));
      expect(auth.revokedCodes, isEmpty);
    });
  }
  test(
      'Apple identity switch on same Firebase UID is rejected before revocation',
      () async {
    original.onReauth = () async {
      original.providerData = [_Provider('apple.com', 'another-apple-subject')];
      return _Credential(original, _Info());
    };
    await expectLater(
        service.prepare(uid), throwsA(isA<AppleDeletionIdentityChanged>()));
    expect(auth.revokedCodes, isEmpty);
  });
  test('account switch while revoking prevents deletion continuation',
      () async {
    auth.onRevoke = () async => auth.currentUser = _User('another-owner');
    await expectLater(
        service.prepare(uid), throwsA(isA<AppleDeletionIdentityChanged>()));
  });
  for (final subject in <String?>[null, '', '   ']) {
    test(
        'initial missing Apple subject permits manual fallback: ${subject?.length}',
        () async {
      original.providerData = [_Provider('apple.com', subject)];
      expect(await service.prepare(uid), AppleDeletionRevocation.unavailable);
      expect(original.reauthCalls, 0);
      expect(auth.revokedCodes, isEmpty);
      expect(auth.currentUser?.uid, uid);
    });
  }
  test('conflicting known Apple subjects cannot use manual fallback', () async {
    original.providerData = [
      _Provider('apple.com', 'known-one'),
      _Provider('apple.com', 'known-two'),
    ];
    await expectLater(
        service.prepare(uid), throwsA(isA<AppleDeletionIdentityChanged>()));
    expect(original.reauthCalls, 0);
    expect(auth.revokedCodes, isEmpty);
  });
  for (final missing in <String?>[null, '', '   ']) {
    test(
        'a known Apple subject cannot disappear during reauthentication: ${missing?.length}',
        () async {
      original.onReauth = () async {
        original.providerData = [_Provider('apple.com', missing)];
        return _Credential(original, _Info());
      };
      await expectLater(
          service.prepare(uid), throwsA(isA<AppleDeletionIdentityChanged>()));
      expect(auth.revokedCodes, isEmpty);
    });
  }
  test(
      'repeated preparation obtains a new code rather than reusing a saved token',
      () async {
    var n = 0;
    original.onReauth = () async => _Credential(
        original, _Info(authorizationCode: 'synthetic-one-use-${++n}'));
    expect(await service.prepare(uid), AppleDeletionRevocation.revoked);
    expect(await service.prepare(uid), AppleDeletionRevocation.revoked);
    expect(auth.revokedCodes, ['synthetic-one-use-1', 'synthetic-one-use-2']);
  });
}

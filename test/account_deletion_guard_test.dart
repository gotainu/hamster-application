// FlutterFire platform adapters keep reads offline and forbid real writes.
// ignore_for_file: depend_on_referenced_packages
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as fp;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart'
    as cp;
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/services/account_deletion_guard.dart';

class _User implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  @override
  User? currentUser = _User('synthetic-owner');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Core extends cp.FirebasePlatform {
  final _app = cp.FirebaseAppPlatform(
    cp.defaultFirebaseAppName,
    const FirebaseOptions(
        apiKey: 'synthetic',
        appId: 'synthetic',
        messagingSenderId: 'synthetic',
        projectId: 'offline-deletion-test'),
  );
  @override
  List<cp.FirebaseAppPlatform> get apps => [_app];
  @override
  cp.FirebaseAppPlatform app([String name = cp.defaultFirebaseAppName]) => _app;
}

class _Document extends fp.DocumentReferencePlatform {
  _Document(this.db) : super(db, 'users/synthetic-owner/billing/subscription');
  final _Db db;
  Map<String, dynamic>? value;
  fp.PigeonSnapshotMetadata metadata =
      fp.PigeonSnapshotMetadata(isFromCache: false, hasPendingWrites: false);
  bool fail = false;
  int reads = 0;
  void Function()? beforeReturn;
  void reset() {
    value = null;
    metadata =
        fp.PigeonSnapshotMetadata(isFromCache: false, hasPendingWrites: false);
    fail = false;
    reads = 0;
    beforeReturn = null;
  }

  @override
  Future<fp.DocumentSnapshotPlatform> get(
      [fp.GetOptions options = const fp.GetOptions()]) async {
    reads++;
    expect(options.source, fp.Source.server);
    if (fail) throw StateError('synthetic read failure');
    beforeReturn?.call();
    return fp.DocumentSnapshotPlatform(db, path, value, metadata);
  }
}

class _Db extends fp.FirebaseFirestorePlatform {
  late final document = _Document(this);
  final paths = <String>[];
  @override
  fp.FirebaseFirestorePlatform delegateFor(
          {required FirebaseApp app, required String databaseId}) =>
      this;
  @override
  fp.Settings get settings => const fp.Settings();
  @override
  fp.DocumentReferencePlatform doc(String documentPath) {
    paths.add(documentPath);
    return document;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = _Db();
  setUpAll(() {
    cp.FirebasePlatform.instance = _Core();
    fp.FirebaseFirestorePlatform.instance = db;
  });
  group('temporary free-account deletion classifier', () {
    for (final data in <Map<String, dynamic>?>[
      null,
      {},
      {'plan': 'none', 'status': 'none'},
      {'plan': 'none', 'status': 'canceled'},
      for (final status in ['canceled', 'incomplete_expired'])
        {
          'plan': 'none',
          'status': status,
          'cancelAtPeriodEnd': false,
          'stripeSubscriptionId': 'sub_synthetic',
          'stripeCustomerId': 'cus_synthetic',
        },
      {'stripeCustomerId': 'synthetic-customer'},
      {'stripeSubscriptionId': '', 'cancelAtPeriodEnd': false},
    ]) {
      test('free state $data remains deletable', () {
        expect(AccountDeletionGuard.fromBillingData(data),
            AccountDeletionEligibility.freeAccount);
      });
    }
    for (final data in [
      {'plan': 'paid', 'status': 'active'},
      {'plan': 'paid', 'status': 'trialing'},
      {'plan': 'paid', 'status': 'active', 'cancelAtPeriodEnd': true},
      {'status': 'past_due'},
      {'status': 'unpaid'},
      {'status': 'incomplete'},
      {'status': 'unknown'},
      {'status': 'unexpected'},
      {'plan': 'unexpected'},
      {'status': ''},
      {'plan': ''},
      {'stripeSubscriptionId': 'synthetic-subscription', 'status': 'canceled'},
      {
        'plan': 'none',
        'status': 'canceled',
        'cancelAtPeriodEnd': false,
        'stripeSubscriptionId': 'malformed',
      },
      {
        'plan': 'paid',
        'status': 'canceled',
        'cancelAtPeriodEnd': false,
        'stripeSubscriptionId': 'sub_synthetic',
      },
      {'stripeSubscriptionId': 42},
      {'stripeSubscriptionId': ' '},
      {'cancelAtPeriodEnd': 'false'},
      {'cancelAtPeriodEnd': true},
    ]) {
      test('contract or unresolved state $data requires billing notice', () {
        expect(AccountDeletionGuard.fromBillingData(data),
            AccountDeletionEligibility.contractPresent);
      });
    }
  });

  group('fresh UID-scoped server read', () {
    late _Auth auth;
    late AccountDeletionGuard guard;
    setUp(() {
      auth = _Auth();
      db.document.reset();
      db.paths.clear();
      guard = AccountDeletionGuard(db: FirebaseFirestore.instance, auth: auth);
    });
    test('reads only the authenticated UID and does not write', () async {
      expect(await guard.check('synthetic-owner'),
          AccountDeletionEligibility.freeAccount);
      expect(db.paths, ['users/synthetic-owner/billing/subscription']);
      expect(db.document.reads, 1);
    });
    test('unauthenticated or different UID never reads', () async {
      expect(await guard.check('another-owner'),
          AccountDeletionEligibility.unavailable);
      auth.currentUser = null;
      expect(await guard.check('synthetic-owner'),
          AccountDeletionEligibility.unavailable);
      expect(db.paths, isEmpty);
    });
    test('account switch during read refuses deletion', () async {
      db.document.beforeReturn =
          () => auth.currentUser = _User('another-owner');
      expect(await guard.check('synthetic-owner'),
          AccountDeletionEligibility.unavailable);
    });
    test('read failure refuses deletion', () async {
      db.document.fail = true;
      expect(await guard.check('synthetic-owner'),
          AccountDeletionEligibility.unavailable);
    });
    for (final metadata in [
      fp.PigeonSnapshotMetadata(isFromCache: true, hasPendingWrites: false),
      fp.PigeonSnapshotMetadata(isFromCache: false, hasPendingWrites: true),
    ]) {
      test('unconfirmed metadata refuses deletion $metadata', () async {
        db.document.metadata = metadata;
        expect(await guard.check('synthetic-owner'),
            AccountDeletionEligibility.unavailable);
      });
    }
  });
}

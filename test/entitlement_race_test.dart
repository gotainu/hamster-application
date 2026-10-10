import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/billing_status.dart';
import 'package:hamster_project/models/entitlement_snapshot.dart';
import 'package:hamster_project/screens/subscription_plan_screen.dart';
import 'package:hamster_project/services/billing_status_repo.dart';
import 'package:hamster_project/widgets/paid_feature_gate.dart';

const _child = Text('対象機能');
const _loading = '利用状態を確認しています';
const _unavailable = '利用状態を確認できませんでした';
const _startTrial = '21日間の無料体験を始める';

Map<String, dynamic> _paid() => {
      'plan': 'paid',
      'status': 'active',
      'currentPeriodEnd': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      ),
    };

Map<String, dynamic> _activeTrial() => {
      'status': 'active',
      'endsAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 21)),
      ),
      'policyVersion': 'initial_trial_v2',
      'aiRequestLimit': 20,
      'aiRequestUsed': 0,
    };

void _expectPending() {
  expect(find.text(_loading), findsOneWidget);
  expect(find.textContaining('未契約'), findsNothing);
  expect(find.text(_startTrial), findsNothing);
  expect(find.text('テスト機能は有料プランの機能です'), findsNothing);
  expect(find.text('対象機能'), findsNothing);
}

Widget _gate(_Fixture fixture, {bool initialTrial = false}) => MaterialApp(
      home: Scaffold(
        body: PaidFeatureGate(
          billingRepo: fixture.repo,
          featureName: 'テスト機能',
          useInitialTrial: initialTrial,
          canStartInitialTrial: initialTrial,
          child: _child,
        ),
      ),
    );

Widget _plan(_Fixture fixture) => MaterialApp(
      home: SubscriptionPlanScreen(billingRepo: fixture.repo),
    );

void main() {
  late _Fixture fixture;
  setUp(() => fixture = _Fixture());
  tearDown(() => fixture.dispose());

  test('repository withholds cached missing and cached paid billing', () async {
    final states = <EntitlementSnapshot<BillingStatus>>[];
    final subscription = fixture.repo.watchBillingStatus().listen(states.add);
    fixture.billing().emit(null, fromCache: true);
    fixture.billing().emit(_paid(), fromCache: true);
    expect(states.every((state) => !state.isServerConfirmed), isTrue);
    expect(states.every((state) => state.data == null), isTrue);

    fixture.billing().emit(_paid());
    expect(states.last.isServerConfirmed, isTrue);
    expect(states.last.data!.canUsePaidFeatures, isTrue);
    await subscription.cancel();
  });

  test('metadata-only server acknowledgment confirms a missing document',
      () async {
    final states = <EntitlementSnapshot<BillingStatus>>[];
    final subscription = fixture.repo.watchBillingStatus().listen(states.add);
    fixture.billing().emit(null, fromCache: true);
    expect(states.single.isServerConfirmed, isFalse);
    fixture.billing().emit(null);
    expect(states.length, 2);
    expect(states.last.isServerConfirmed, isTrue);
    expect(states.last.data!.status, BillingStatusValue.none);
    await subscription.cancel();
  });

  test('pending local writes cannot confirm paid access', () async {
    final states = <EntitlementSnapshot<BillingStatus>>[];
    final subscription = fixture.repo.watchBillingStatus().listen(states.add);
    final paid = _paid();
    fixture.billing().emit(paid, pendingWrites: true);
    expect(states.single.isServerConfirmed, isFalse);
    fixture.billing().emit(paid);
    expect(states.last.data!.canUsePaidFeatures, isTrue);
    await subscription.cancel();
  });

  testWidgets('plan stays loading for cached absence, then displays paid',
      (tester) async {
    await tester.pumpWidget(_plan(fixture));
    _expectPending();
    fixture.billing().emit(null, fromCache: true);
    await tester.pump();
    _expectPending();
    fixture.billing().emit(_paid());
    await tester.pump();
    expect(find.text(_loading), findsNothing);
    expect(find.textContaining('未契約'), findsNothing);
    expect(find.text('有料プランを利用中です'), findsOneWidget);
  });

  testWidgets('initial-trial gate stays loading for cached absence, then paid',
      (tester) async {
    await tester.pumpWidget(_gate(fixture, initialTrial: true));
    _expectPending();
    fixture.billing().emit(null, fromCache: true);
    await tester.pump();
    _expectPending();
    fixture.billing().emit(_paid());
    await tester.pump();
    expect(find.text('対象機能'), findsOneWidget);
    expect(find.text(_startTrial), findsNothing);
    expect(find.text(_loading), findsNothing);
  });

  testWidgets('plan displays none only after server confirms it',
      (tester) async {
    await tester.pumpWidget(_plan(fixture));
    fixture.billing().emit(null, fromCache: true);
    await tester.pump();
    _expectPending();
    fixture.billing().emit(null);
    await tester.pump();
    expect(find.text(_loading), findsNothing);
    expect(find.text('有料プランは未契約です'), findsOneWidget);
  });

  testWidgets('trial CTA requires server-confirmed absence in both documents',
      (tester) async {
    await tester.pumpWidget(_gate(fixture, initialTrial: true));
    fixture.billing().emit(null);
    await tester.pump();
    _expectPending();
    fixture.trial().emit(null, fromCache: true);
    await tester.pump();
    _expectPending();
    fixture.trial().emit(null);
    await tester.pump();
    expect(find.text(_startTrial), findsOneWidget);
    expect(find.text(_loading), findsNothing);
  });

  for (final screen in ['plan', 'gate']) {
    testWidgets('$screen billing error shows unavailable and retry, never none',
        (tester) async {
      await tester.pumpWidget(
        screen == 'plan' ? _plan(fixture) : _gate(fixture, initialTrial: true),
      );
      fixture.billing().fail();
      await tester.pump();
      expect(find.text(_unavailable), findsOneWidget);
      expect(find.text('もう一度確認'), findsOneWidget);
      expect(find.textContaining('未契約'), findsNothing);
      expect(find.text(_startTrial), findsNothing);

      await tester.tap(find.text('もう一度確認'));
      await tester.pump();
      _expectPending();
      expect(fixture.billing().listenCount, 2);
      fixture.billing().emit(_paid());
      await tester.pump();
      expect(find.text(_unavailable), findsNothing);
      expect(
        find.text(screen == 'plan' ? '有料プランを利用中です' : '対象機能'),
        findsOneWidget,
      );
    });
  }

  for (final screen in ['plan', 'gate']) {
    testWidgets('$screen read failure hides previously confirmed paid state',
        (tester) async {
      await tester.pumpWidget(
        screen == 'plan' ? _plan(fixture) : _gate(fixture),
      );
      fixture.billing().emit(_paid());
      await tester.pump();
      fixture.billing().fail();
      await tester.pump();
      expect(find.text(_unavailable), findsOneWidget);
      expect(find.text('もう一度確認'), findsOneWidget);
      expect(find.text('有料プランを利用中です'), findsNothing);
      expect(find.text('対象機能'), findsNothing);
      expect(find.textContaining('未契約'), findsNothing);
    });
  }

  testWidgets('paid active opens the plain paid feature gate', (tester) async {
    await tester.pumpWidget(_gate(fixture));
    fixture.billing().emit(_paid(), fromCache: true);
    await tester.pump();
    _expectPending();
    fixture.billing().emit(_paid());
    await tester.pump();
    expect(find.text('対象機能'), findsOneWidget);
  });

  testWidgets('active initial trial opens only after server confirmation',
      (tester) async {
    await tester.pumpWidget(_gate(fixture, initialTrial: true));
    fixture.billing().emit(null);
    await tester.pump();
    fixture.trial().emit(null, fromCache: true);
    await tester.pump();
    _expectPending();
    fixture.trial().emit(_activeTrial(), fromCache: true);
    await tester.pump();
    _expectPending();
    fixture.trial().emit(_activeTrial());
    await tester.pump();
    expect(find.text('対象機能'), findsOneWidget);
    expect(find.text(_startTrial), findsNothing);
  });

  testWidgets('initial-trial read failure shows unavailable and retries',
      (tester) async {
    await tester.pumpWidget(_gate(fixture, initialTrial: true));
    fixture.billing().emit(null);
    await tester.pump();
    fixture.trial().fail();
    await tester.pump();
    expect(find.text(_unavailable), findsOneWidget);
    expect(find.text(_startTrial), findsNothing);
    await tester.tap(find.text('もう一度確認'));
    await tester.pump();
    _expectPending();
    fixture.billing().emit(null);
    await tester.pump();
    fixture.trial().emit(_activeTrial());
    await tester.pump();
    expect(find.text('対象機能'), findsOneWidget);
    expect(fixture.trial().listenCount, 2);
  });

  for (final screen in ['plan', 'gate']) {
    testWidgets('$screen discards prior paid access on an account switch',
        (tester) async {
      await tester.pumpWidget(
        screen == 'plan' ? _plan(fixture) : _gate(fixture, initialTrial: true),
      );
      fixture.billing().emit(_paid());
      await tester.pump();
      expect(
        find.text(screen == 'plan' ? '有料プランを利用中です' : '対象機能'),
        findsOneWidget,
      );

      fixture.auth.switchUser('user-b');
      await tester.pump();
      _expectPending();
      fixture.billing().emit(_paid()); // A late event from the previous user.
      fixture.billing('user-b').emit(null, fromCache: true);
      await tester.pump();
      _expectPending();
      expect(find.text('有料プランを利用中です'), findsNothing);
      fixture.billing('user-b').emit(_paid());
      await tester.pump();
      expect(
        find.text(screen == 'plan' ? '有料プランを利用中です' : '対象機能'),
        findsOneWidget,
      );
    });
  }

  testWidgets('account switch discards the previous active initial trial',
      (tester) async {
    await tester.pumpWidget(_gate(fixture, initialTrial: true));
    fixture.billing().emit(null);
    await tester.pump();
    fixture.trial().emit(_activeTrial());
    await tester.pump();
    expect(find.text('対象機能'), findsOneWidget);

    fixture.auth.switchUser('user-b');
    await tester.pump();
    _expectPending();
    fixture.billing('user-b').emit(null);
    await tester.pump();
    _expectPending();
    fixture.trial().emit(_activeTrial());
    fixture.trial('user-b').emit(null, fromCache: true);
    await tester.pump();
    _expectPending();
    fixture.trial('user-b').emit(null);
    await tester.pump();
    expect(find.text(_startTrial), findsOneWidget);
    expect(find.text('対象機能'), findsNothing);
  });

  testWidgets('sign-out clears previously confirmed paid access',
      (tester) async {
    await tester.pumpWidget(_gate(fixture));
    fixture.billing().emit(_paid());
    await tester.pump();
    fixture.auth.switchUser(null);
    await tester.pump();
    _expectPending();
  });

  testWidgets('parent rebuild keeps the confirmed billing subscription',
      (tester) async {
    await tester.pumpWidget(_gate(fixture));
    fixture.billing().emit(_paid());
    await tester.pump();
    await tester.pumpWidget(_gate(fixture));
    expect(find.text('対象機能'), findsOneWidget);
    expect(fixture.billing().listenCount, 1);
  });
}

class _Fixture {
  final auth = _Auth();
  final db = _Firestore();
  late final repo = BillingStatusRepo(auth: auth, db: db);

  _Document billing([String uid = 'user-a']) =>
      db.document('users/$uid/billing/subscription');
  _Document trial([String uid = 'user-a']) =>
      db.document('users/$uid/feature_access/initial_trial_v2');

  Future<void> dispose() async {
    await auth.events.close();
    for (final doc in db.documents.values) {
      await doc.events.close();
    }
  }
}

class _Auth extends Fake implements FirebaseAuth {
  final events = StreamController<User?>.broadcast(sync: true);
  User? _user = _User('user-a');
  @override
  User? get currentUser => _user;
  @override
  Stream<User?> authStateChanges() => events.stream;

  void switchUser(String? uid) {
    _user = uid == null ? null : _User(uid);
    events.add(_user);
  }
}

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
}

class _Firestore extends Fake implements FirebaseFirestore {
  final documents = <String, _Document>{};
  _Document document(String path) =>
      documents.putIfAbsent(path, () => _Document(this, path));
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
}

// Test double: Firebase is never initialized or contacted.
// ignore: subtype_of_sealed_class
class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.db, this.path);
  final _Firestore db;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      db.document('${this.path}/$path');
}

// Test double for Firestore metadata and read errors.
// ignore: subtype_of_sealed_class
class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.db, this.path);
  final _Firestore db;
  @override
  final String path;
  final events =
      StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast(
    sync: true,
  );
  final _listens = <bool>[];
  int get listenCount => _listens.length;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(db, '${this.path}/$path');

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    _listens.add(includeMetadataChanges);
    var received = false;
    Map<String, dynamic>? previous;
    // Firestore suppresses metadata-only acknowledgments unless requested.
    return events.stream.where((snapshot) {
      final changed = !received || !mapEquals(previous, snapshot.data());
      received = true;
      previous = snapshot.data();
      return includeMetadataChanges || changed;
    });
  }

  void emit(Map<String, dynamic>? data,
          {bool fromCache = false, bool pendingWrites = false}) =>
      events.add(_Snapshot(data, _Metadata(fromCache, pendingWrites)));

  void fail() => events.addError(StateError('billing read failed'));
}

// Test double for cached and server-confirmed snapshots.
// ignore: subtype_of_sealed_class
class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.value, this.metadata);
  final Map<String, dynamic>? value;
  @override
  final SnapshotMetadata metadata;
  @override
  Map<String, dynamic>? data() => value;
}

class _Metadata extends Fake implements SnapshotMetadata {
  _Metadata(this.isFromCache, this.hasPendingWrites);
  @override
  final bool isFromCache;
  @override
  final bool hasPendingWrites;
}

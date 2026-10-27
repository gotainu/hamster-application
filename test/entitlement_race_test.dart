import 'dart:async';
import 'dart:io';

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

Widget _gate(_Fixture fixture,
        {bool initialTrial = false, DateTime Function()? now}) =>
    MaterialApp(
      home: Scaffold(
        body: PaidFeatureGate(
          billingRepo: fixture.repo,
          featureName: 'テスト機能',
          useInitialTrial: initialTrial,
          canStartInitialTrial: initialTrial,
          now: now,
          child: _child,
        ),
      ),
    );

Widget _plan(_Fixture fixture) => MaterialApp(
      home: SubscriptionPlanScreen(billingRepo: fixture.repo),
    );

void main() {
  test('changes tab uses the shared initial trial gate', () {
    // Pair the gate behavior below with its actual production-tab binding.
    final source = File('lib/screens/tabs.dart').readAsStringSync();
    final feature = source.indexOf("featureName: '変化'");
    final start = source.lastIndexOf('const PaidFeatureGate(', feature);
    final end = source.indexOf(
      'child: GraphFunctionScreen(embeddedInTab: true)',
      feature,
    );
    expect(feature, greaterThanOrEqualTo(0));
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(feature));
    final gate = source.substring(start, end);
    expect(gate, contains('useInitialTrial: true'));
    expect(gate, isNot(contains('trialFeature:')));
    expect(gate, isNot(contains('5日間')));
  });

  late _Fixture fixture;
  setUp(() => fixture = _Fixture());
  tearDown(() => fixture.dispose());

  group('fixed-clock 21-day deadline', () {
    final end = DateTime.utc(2034, 1, 22, 0); // 09:00 JST, not a live trial.
    Map<String, dynamic> trial() => {
          ..._activeTrial(),
          'startedAt':
              Timestamp.fromDate(end.subtract(const Duration(days: 21))),
          'endsAt': Timestamp.fromDate(end),
          // Exhausting the AI count does not shorten record/chart access.
          'aiRequestUsed': 20,
        };

    for (final scenario in [
      (
        name: 'immediately before',
        offset: const Duration(milliseconds: -1),
        allowed: true
      ),
      (name: 'exactly at', offset: Duration.zero, allowed: false),
      (name: 'after', offset: const Duration(milliseconds: 1), allowed: false),
    ]) {
      testWidgets(
          'trial ${scenario.name} expiration uses an exclusive deadline',
          (tester) async {
        final now = end.add(scenario.offset);
        await tester
            .pumpWidget(_gate(fixture, initialTrial: true, now: () => now));
        fixture.billing().emit(null);
        await tester.pump();
        fixture.trial().emit(trial());
        await tester.pump();
        expect(find.text('対象機能'),
            scenario.allowed ? findsOneWidget : findsNothing);
        expect(find.text(_startTrial), findsNothing);
        if (!scenario.allowed) {
          expect(find.textContaining('無料体験は終了しています'), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets('paid access remains available after the trial deadline',
        (tester) async {
      await tester.pumpWidget(_gate(fixture,
          initialTrial: true, now: () => end.add(const Duration(days: 1))));
      fixture.billing().emit({
        ..._paid(),
        'currentPeriodEnd':
            Timestamp.fromDate(end.add(const Duration(days: 30))),
      });
      await tester.pump();
      expect(find.text('対象機能'), findsOneWidget);
      expect(find.textContaining('無料体験は終了しています'), findsNothing);
      expect(find.text(_startTrial), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        'open trial gate closes at its deadline without another snapshot',
        (tester) async {
      var now = end.subtract(const Duration(milliseconds: 1));
      await tester
          .pumpWidget(_gate(fixture, initialTrial: true, now: () => now));
      fixture.billing().emit(null);
      await tester.pump();
      fixture.trial().emit(trial());
      await tester.pump();
      expect(find.text('対象機能'), findsOneWidget);
      final listens = fixture.trial().listenCount;

      now = end;
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('対象機能'), findsNothing);
      expect(find.textContaining('無料体験は終了しています'), findsOneWidget);
      expect(fixture.trial().listenCount, listens);
      now = end.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('対象機能'), findsNothing);
      expect(find.text(_startTrial), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('paid entitlement is closed exactly at its server deadline',
        (tester) async {
      await tester
          .pumpWidget(_gate(fixture, initialTrial: true, now: () => end));
      fixture
          .billing()
          .emit({..._paid(), 'currentPeriodEnd': Timestamp.fromDate(end)});
      await tester.pump();
      fixture.trial().emit(trial());
      await tester.pump();
      expect(find.text('対象機能'), findsNothing);
      expect(find.textContaining('無料体験は終了しています'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        'open paid gate closes at its deadline without another snapshot',
        (tester) async {
      var now = end.subtract(const Duration(milliseconds: 1));
      await tester.pumpWidget(_gate(fixture, now: () => now));
      fixture
          .billing()
          .emit({..._paid(), 'currentPeriodEnd': Timestamp.fromDate(end)});
      await tester.pump();
      expect(find.text('対象機能'), findsOneWidget);
      final listens = fixture.billing().listenCount;

      now = end;
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('対象機能'), findsNothing);
      expect(find.text('テスト機能は有料プランの機能です'), findsOneWidget);
      expect(fixture.billing().listenCount, listens);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

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

  testWidgets('expired active subscription is not shown as paid access',
      (tester) async {
    await tester.pumpWidget(_plan(fixture));
    fixture.billing().emit({
      ..._paid(),
      'currentPeriodEnd': Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 1)),
      ),
    });
    await tester.pump();
    expect(find.text('有料プランを利用中です'), findsNothing);
    expect(find.text('有料プランの利用期間が終了しました'), findsOneWidget);
    expect(find.text('プランを管理する'), findsOneWidget);
    expect(find.text('月額プランに登録する'), findsNothing);
  });

  for (final status in ['past_due', 'unpaid']) {
    testWidgets(
        '$status keeps existing portal management without a new checkout',
        (tester) async {
      await tester.pumpWidget(_plan(fixture));
      fixture.billing().emit({..._paid(), 'status': status});
      await tester.pump();
      expect(find.text('プランを管理する'), findsOneWidget);
      expect(find.text('月額プランに登録する'), findsNothing);
      expect(find.text('有料プランを利用中です'), findsNothing);
    });
  }

  testWidgets('scheduled cancellation retains access and its management action',
      (tester) async {
    await tester.pumpWidget(_plan(fixture));
    fixture.billing().emit({..._paid(), 'cancelAtPeriodEnd': true});
    await tester.pump();
    expect(find.text('解約予約済みです'), findsOneWidget);
    expect(find.text('プランを管理する'), findsOneWidget);
    expect(find.text('月額プランに登録する'), findsNothing);
    expect(find.textContaining('現在の請求期間が終了するまでは'), findsOneWidget);
  });

  testWidgets(
      '21-day feature access remains when only the trial AI quota is used',
      (tester) async {
    await tester.pumpWidget(_gate(fixture, initialTrial: true));
    fixture.billing().emit(null);
    await tester.pump();
    fixture.trial().emit({..._activeTrial(), 'aiRequestUsed': 20});
    await tester.pump();
    expect(find.text('対象機能'), findsOneWidget);
    expect(find.text(_startTrial), findsNothing);
  });

  testWidgets('expired initial trial locks feature without starting it again',
      (tester) async {
    await tester.pumpWidget(_gate(fixture, initialTrial: true));
    fixture.billing().emit(null);
    await tester.pump();
    fixture.trial().emit({
      ..._activeTrial(),
      'endsAt': Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 1)),
      ),
    });
    await tester.pump();
    expect(find.text('対象機能'), findsNothing);
    expect(find.text(_startTrial), findsNothing);
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

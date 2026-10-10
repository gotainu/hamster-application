import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/personality_report.dart';
import 'package:hamster_project/services/personality_reports_repo.dart';

import 'personality_report_fixtures.dart';

class _Auth extends Fake implements FirebaseAuth {
  User? value = _User('owner-a');
  final changes = StreamController<User?>.broadcast(sync: true);
  @override
  User? get currentUser => value;
  @override
  Stream<User?> authStateChanges() => changes.stream;
  void switchTo(String? uid) {
    value = uid == null ? null : _User(uid);
    changes.add(value);
  }
}

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
}

class _Db extends Fake implements FirebaseFirestore {
  final docs = <String, _Doc>{};
  @override
  _Doc doc(String path) => docs.putIfAbsent(path, () => _Doc(this, path));
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Col(this, path);
}

// Fake Firestore references never initialize Firebase or call a network API.
// ignore: subtype_of_sealed_class
class _Col extends Fake implements CollectionReference<Map<String, dynamic>> {
  _Col(this.db, this.path);
  final _Db db;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      db.doc('${this.path}/$path');
}

// ignore: subtype_of_sealed_class
class _Doc extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Doc(this.db, this.path);
  final _Db db;
  @override
  final String path;
  final events =
      StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast(
          sync: true);
  final metadataFlags = <bool>[];
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Col(db, '${this.path}/$path');
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots(
      {bool includeMetadataChanges = false,
      ListenSource source = ListenSource.defaultSource}) {
    metadataFlags.add(includeMetadataChanges);
    return events.stream;
  }

  void emit(Map<String, dynamic>? value,
          {bool cached = false, bool pending = false}) =>
      events.add(_Snap(value, _Meta(cached, pending)));
  void error() => events.addError(StateError('read unavailable'));
}

// ignore: subtype_of_sealed_class
class _Snap extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Snap(this.value, this.metadata);
  final Map<String, dynamic>? value;
  @override
  final SnapshotMetadata metadata;
  @override
  Map<String, dynamic>? data() => value;
}

class _Meta extends Fake implements SnapshotMetadata {
  _Meta(this.isFromCache, this.hasPendingWrites);
  @override
  final bool isFromCache;
  @override
  final bool hasPendingWrites;
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late _Auth auth;
  late _Db db;
  late PersonalityReportsRepo repo;
  late List<PersonalityReportState> states;
  StreamSubscription<PersonalityReportState>? subscription;
  _Doc pointer([String uid = 'owner-a']) =>
      db.doc('users/$uid/report_pointers/personality');
  _Doc dailyPointer([String uid = 'owner-a']) =>
      db.doc('users/$uid/report_pointers/personality_daily');
  _Doc report([String uid = 'owner-a']) =>
      db.doc('users/$uid/personality_reports/personality_v1_body');
  final pointerData = {
    'reportId': 'personality_v1_body',
    'petId': 'main_pet',
    'readyMetrics': ['body']
  };
  setUp(() {
    auth = _Auth();
    db = _Db();
    repo = PersonalityReportsRepo(auth: auth, db: db);
    states = [];
  });
  tearDown(() async {
    await subscription?.cancel();
    subscription = null;
    await auth.changes.close();
    for (final doc in db.docs.values) {
      await doc.events.close();
    }
  });
  Future<void> listen({bool dailyAbsent = true}) async {
    subscription = repo.watchLatest().listen(states.add);
    await _flush();
    if (dailyAbsent) {
      dailyPointer().emit(null);
      await _flush();
    }
  }

  Future<void> publish() async {
    pointer().emit(pointerData);
    await _flush();
    report().emit(personalityFixture());
    await _flush();
  }

  test('cached missing pointer stays loading until metadata confirms absence',
      () async {
    await listen();
    pointer().emit(null, cached: true);
    await _flush();
    expect(states.last.phase, PersonalityReportPhase.loading);
    pointer().emit(null);
    await _flush();
    expect(states.last.phase, PersonalityReportPhase.learning);
    expect(pointer().metadataFlags, everyElement(isTrue));
  });
  test('cached or pending report cannot publish a confirmed report', () async {
    await listen();
    pointer().emit(pointerData);
    await _flush();
    report().emit(personalityFixture(), cached: true);
    await _flush();
    expect(states.last.report, isNull);
    report().emit(personalityFixture(), pending: true);
    await _flush();
    expect(states.last.report, isNull);
    report().emit(personalityFixture());
    await _flush();
    expect(states.last.phase, PersonalityReportPhase.available);
    expect(report().metadataFlags, everyElement(isTrue));
  });
  test('pending pointer never follows an unconfirmed report ID', () async {
    await listen();
    pointer().emit(pointerData, pending: true);
    await _flush();
    expect(states.last.phase, PersonalityReportPhase.loading);
    expect(db.docs.keys.where((key) => key.contains('/personality_reports/')),
        isEmpty);
  });
  test(
      'owner report uses only pointer and immutable report reads after trial expiry',
      () async {
    await listen();
    await publish();
    expect(states.last.report!.reportId, 'personality_v1_body');
    expect(
        db.docs.entries
            .where((entry) => entry.value.metadataFlags.isNotEmpty)
            .map((entry) => entry.key),
        unorderedEquals([
          'users/owner-a/report_pointers/personality_daily',
          'users/owner-a/report_pointers/personality',
          'users/owner-a/personality_reports/personality_v1_body'
        ]));
    expect(
        db.docs.keys
            .any((p) => p.contains('billing') || p.contains('feature_access')),
        isFalse);
  });
  test(
      'pointer or report error clears content into unavailable, never learning',
      () async {
    await listen();
    await publish();
    report().error();
    await _flush();
    expect(states.last.phase, PersonalityReportPhase.unavailable);
    expect(states.last.report, isNull);
    pointer().error();
    await _flush();
    expect(states.last.phase, PersonalityReportPhase.unavailable);
  });
  test('missing referenced report is unavailable, not first-time learning',
      () async {
    await listen();
    pointer().emit(pointerData);
    await _flush();
    report().emit(null);
    await _flush();
    expect(states.last.phase, PersonalityReportPhase.unavailable);
  });
  test('invalid pointer or conflicting report identity is unavailable',
      () async {
    await listen();
    pointer().emit({'reportId': '../unsafe'});
    await _flush();
    expect(states.last.phase, PersonalityReportPhase.unavailable);
    pointer().emit(pointerData);
    await _flush();
    report().emit(personalityFixture(reportId: 'wrong'));
    await _flush();
    expect(states.last.phase, PersonalityReportPhase.unavailable);
  });
  test(
      'account switch immediately discards previous owner and ignores late old events',
      () async {
    await listen();
    await publish();
    auth.switchTo('owner-b');
    await _flush();
    expect(states.last.ownerUid, 'owner-b');
    expect(states.last.phase, PersonalityReportPhase.loading);
    expect(states.last.report, isNull);
    report().emit(personalityFixture());
    await _flush();
    expect(states.last.ownerUid, 'owner-b');
    expect(states.last.report, isNull);
    dailyPointer('owner-b').emit(null);
    await _flush();
    pointer('owner-b').emit(pointerData);
    await _flush();
    report('owner-b').emit(personalityFixture());
    await _flush();
    expect(states.last.ownerUid, 'owner-b');
    expect(states.last.phase, PersonalityReportPhase.available);
  });
  test('sign-out discards data without reading an anonymous owner path',
      () async {
    await listen();
    await publish();
    auth.switchTo(null);
    await _flush();
    expect(states.last.report, isNull);
    expect(states.last.ownerUid, isNull);
    expect(states.last.phase, PersonalityReportPhase.unavailable);
    expect(db.docs.keys.any((path) => path.contains('/null/')), isFalse);
  });
  test('re-subscription retries a failed read without fetching dependencies',
      () async {
    await listen();
    pointer().error();
    await _flush();
    await subscription!.cancel();
    await listen();
    await publish();
    expect(states.last.phase, PersonalityReportPhase.available);
    expect(pointer().metadataFlags, hasLength(2));
  });
  test(
      'pointer change discards partial content before displaying new immutable snapshot',
      () async {
    await listen();
    await publish();
    pointer().emit({
      'reportId': 'personality_v1_body_activity',
      'petId': 'main_pet',
      'readyMetrics': ['body', 'activity']
    });
    await _flush();
    expect(states.last.phase, PersonalityReportPhase.loading);
    report().emit(personalityFixture());
    await _flush();
    expect(states.last.report, isNull);
    db
        .doc('users/owner-a/personality_reports/personality_v1_body_activity')
        .emit(personalityFixture(type: 'both'));
    await _flush();
    expect(states.last.report!.type, PersonalityReportType.both);
  });
  Map<String, dynamic> dailyData() =>
      personalityFixture(reportId: 'daily_2026-10-09')
        ..['evaluationDateKey'] = '2026-10-09'
        ..['silverDateKey'] = '2026-10-09'
        ..['reportKind'] = 'daily'
        ..['cutoffDateKey'] = '2026-10-08';
  test('latest accepts server-confirmed daily pointer and immutable report',
      () async {
    await listen();
    dailyPointer().emit({'reportId': 'daily_2026-10-09', 'petId': 'main_pet'});
    await _flush();
    db
        .doc('users/owner-a/personality_reports/daily_2026-10-09')
        .emit(dailyData());
    await _flush();
    expect(states.last.report!.reportId, 'daily_2026-10-09');
  });
  test('specific history read never follows latest pointer and confirms server',
      () async {
    subscription = repo.watchReport('personality_v1_body').listen(states.add);
    await _flush();
    report().emit(personalityFixture(), cached: true);
    await _flush();
    expect(states.last.phase, PersonalityReportPhase.loading);
    report().emit(personalityFixture());
    await _flush();
    expect(states.last.report!.reportId, 'personality_v1_body');
    expect(pointer().metadataFlags, isEmpty);
    expect(report().metadataFlags, everyElement(isTrue));
  });
  test(
      'specific daily read supports immutable history and rejects missing document',
      () async {
    subscription = repo.watchReport('daily_2026-10-09').listen(states.add);
    await _flush();
    final doc = db.doc('users/owner-a/personality_reports/daily_2026-10-09');
    doc.emit(null);
    await _flush();
    expect(states.last.phase, PersonalityReportPhase.unavailable);
    doc.emit(dailyData());
    await _flush();
    expect(states.last.report!.isDaily, isTrue);
    expect(pointer().metadataFlags, isEmpty);
  });
  test(
      'specific history account switch clears old content and ignores late events',
      () async {
    subscription = repo.watchReport('personality_v1_body').listen(states.add);
    await _flush();
    report().emit(personalityFixture());
    await _flush();
    auth.switchTo('owner-b');
    await _flush();
    expect(states.last.ownerUid, 'owner-b');
    expect(states.last.report, isNull);
    report().emit(personalityFixture());
    await _flush();
    expect(states.last.report, isNull);
    report('owner-b').emit(personalityFixture());
    await _flush();
    expect(states.last.ownerUid, 'owner-b');
    expect(states.last.phase, PersonalityReportPhase.available);
  });
  test('unsafe or impossible history ID never reads Firestore', () async {
    for (final id in ['../unsafe', 'daily_2026-02-30']) {
      final value = await repo.watchReport(id).first;
      expect(value.phase, PersonalityReportPhase.unavailable);
    }
    expect(db.docs, isEmpty);
  });
  _Doc seen([String id = 'personality_v1_body', String uid = 'owner-a']) =>
      db.doc('users/$uid/report_view_states/$id');
  Future<void> unreadListen() async {
    subscription = repo.watchUnreadLatest().listen(states.add);
    await _flush();
    dailyPointer().emit(null);
    await _flush();
    pointer().emit(pointerData);
    await _flush();
    report().emit(personalityFixture());
    await _flush();
  }

  test('latest unread waits for server confirmation of per-report view absence',
      () async {
    await unreadListen();
    expect(states.last.phase, PersonalityReportPhase.loading);
    seen().emit(null, cached: true);
    await _flush();
    expect(states.last.phase, PersonalityReportPhase.loading);
    seen().emit(null);
    await _flush();
    expect(states.last.phase, PersonalityReportPhase.available);
    seen()
        .emit({'reportId': 'personality_v1_body', 'viewedAt': Timestamp.now()});
    await _flush();
    expect(states.last.report, isNull);
    expect(seen().metadataFlags, everyElement(isTrue));
  });
  test('old history view does not consume latest daily unread', () async {
    await unreadListen();
    seen()
        .emit({'reportId': 'personality_v1_body', 'viewedAt': Timestamp.now()});
    await _flush();
    dailyPointer().emit({'reportId': 'daily_2026-10-09', 'petId': 'main_pet'});
    await _flush();
    db
        .doc('users/owner-a/personality_reports/daily_2026-10-09')
        .emit(dailyData());
    await _flush();
    seen('daily_2026-10-09').emit(null);
    await _flush();
    expect(states.last.report!.reportId, 'daily_2026-10-09');
    seen()
        .emit({'reportId': 'personality_v1_body', 'viewedAt': Timestamp.now()});
    await _flush();
    expect(states.last.report!.reportId, 'daily_2026-10-09');
  });
  test('new account and unavailable view read cannot leak prior unread',
      () async {
    await unreadListen();
    seen().emit(null);
    await _flush();
    seen().error();
    await _flush();
    expect(states.last.phase, PersonalityReportPhase.unavailable);
    auth.switchTo('owner-b');
    await _flush();
    expect(states.last.ownerUid, 'owner-b');
    expect(states.last.report, isNull);
    seen().emit(null);
    report().emit(personalityFixture());
    await _flush();
    expect(states.last.report, isNull);
  });
  test('pending or malformed marker never turns a report into confirmed unread',
      () async {
    await unreadListen();
    seen().emit(null, pending: true);
    await _flush();
    expect(states.last.phase, PersonalityReportPhase.loading);
    seen().emit({'reportId': 'other', 'viewedAt': Timestamp.now()});
    await _flush();
    expect(states.last.phase, PersonalityReportPhase.unavailable);
  });

  Future<void> publishDaily() async {
    dailyPointer().emit({'reportId': 'daily_2026-10-09', 'petId': 'main_pet'});
    await _flush();
    db
        .doc('users/owner-a/personality_reports/daily_2026-10-09')
        .emit(dailyData());
    await _flush();
  }

  test('daily cache or pending absence never begins legacy fallback', () async {
    await listen(dailyAbsent: false);
    for (final metadata in [(true, false), (false, true)]) {
      dailyPointer().emit(null, cached: metadata.$1, pending: metadata.$2);
      await _flush();
      expect(states.last.phase, PersonalityReportPhase.loading);
      expect(pointer().metadataFlags, isEmpty);
      pointer().emit(pointerData);
      report().emit(personalityFixture());
      await _flush();
      expect(states.last.report, isNull);
    }
    dailyPointer().emit(null);
    await _flush();
    expect(pointer().metadataFlags, [true]);
    pointer().emit(pointerData);
    await _flush();
    report().emit(personalityFixture());
    await _flush();
    expect(states.last.report!.reportId, 'personality_v1_body');
  });
  test('daily pointer wins without reading legacy and checks server report',
      () async {
    await listen(dailyAbsent: false);
    await publishDaily();
    expect(states.last.report!.isDaily, isTrue);
    expect(pointer().metadataFlags, isEmpty);
    expect(dailyPointer().metadataFlags, everyElement(isTrue));
    pointer().emit(pointerData);
    report().emit(personalityFixture());
    await _flush();
    expect(states.last.report!.reportId, 'daily_2026-10-09');
  });
  test('daily arrival cancels fallback and ignores its late report or error',
      () async {
    await listen();
    await publish();
    dailyPointer().emit({'reportId': 'daily_2026-10-09', 'petId': 'main_pet'});
    await _flush();
    expect(states.last.phase, PersonalityReportPhase.loading);
    pointer().emit(pointerData);
    report().emit(personalityFixture());
    report().error();
    await _flush();
    expect(states.last.report, isNull);
    db
        .doc('users/owner-a/personality_reports/daily_2026-10-09')
        .emit(dailyData(), cached: true);
    await _flush();
    expect(states.last.phase, PersonalityReportPhase.loading);
    db
        .doc('users/owner-a/personality_reports/daily_2026-10-09')
        .emit(dailyData());
    await _flush();
    expect(states.last.report!.isDaily, isTrue);
  });
  test('server-confirmed daily deletion rebinds legacy and rejects late daily',
      () async {
    await listen(dailyAbsent: false);
    await publishDaily();
    dailyPointer().emit(null);
    await _flush();
    expect(states.last.phase, PersonalityReportPhase.loading);
    db
        .doc('users/owner-a/personality_reports/daily_2026-10-09')
        .emit(dailyData());
    await _flush();
    expect(states.last.report, isNull);
    pointer().emit(pointerData);
    await _flush();
    report().emit(personalityFixture());
    await _flush();
    expect(states.last.report!.reportId, 'personality_v1_body');
  });
  test(
      'daily cache event suspends an active fallback until absence is confirmed',
      () async {
    await listen();
    await publish();
    dailyPointer().emit(null, cached: true);
    await _flush();
    expect(states.last.phase, PersonalityReportPhase.loading);
    pointer().emit(pointerData);
    report().emit(personalityFixture());
    await _flush();
    expect(states.last.report, isNull);
    dailyPointer().emit(null);
    await _flush();
    pointer().emit(pointerData);
    await _flush();
    report().emit(personalityFixture());
    await _flush();
    expect(states.last.report!.reportId, 'personality_v1_body');
  });
  test('daily malformed or error cannot silently fall back to a legacy report',
      () async {
    await listen(dailyAbsent: false);
    for (final id in ['personality_v1_body', 'daily_2026-02-30', '../unsafe']) {
      dailyPointer().emit({'reportId': id, 'petId': 'main_pet'});
      await _flush();
      expect(states.last.phase, PersonalityReportPhase.unavailable);
      expect(pointer().metadataFlags, isEmpty);
    }
    dailyPointer().error();
    await _flush();
    expect(states.last.phase, PersonalityReportPhase.unavailable);
    expect(pointer().metadataFlags, isEmpty);
  });
  test('daily error cancels a confirmed fallback and ignores late legacy data',
      () async {
    await listen();
    await publish();
    dailyPointer().error();
    await _flush();
    expect(states.last.phase, PersonalityReportPhase.unavailable);
    pointer().emit(pointerData);
    report().emit(personalityFixture());
    await _flush();
    expect(states.last.phase, PersonalityReportPhase.unavailable);
    expect(states.last.report, isNull);
  });
  test(
      'legacy fallback rejects a daily ID accidentally placed in the v1 pointer',
      () async {
    await listen();
    pointer().emit({'reportId': 'daily_2026-10-09', 'petId': 'main_pet'});
    await _flush();
    expect(states.last.phase, PersonalityReportPhase.unavailable);
    expect(db.docs.keys.where((p) => p.contains('/personality_reports/daily_')),
        isEmpty);
  });
  test(
      'owner switch rejects late fallback and daily events while B waits for server',
      () async {
    await listen();
    await publish();
    auth.switchTo('owner-b');
    await _flush();
    pointer().emit(pointerData);
    report().emit(personalityFixture());
    dailyPointer().emit(null);
    await _flush();
    expect(states.last.ownerUid, 'owner-b');
    expect(states.last.report, isNull);
    dailyPointer('owner-b').emit(null, cached: true);
    await _flush();
    expect(pointer('owner-b').metadataFlags, isEmpty);
    dailyPointer('owner-b').emit(null);
    await _flush();
    pointer('owner-b').emit(pointerData);
    await _flush();
    report('owner-b').emit(personalityFixture());
    await _flush();
    expect(states.last.ownerUid, 'owner-b');
    expect(states.last.report!.reportId, 'personality_v1_body');
  });
  test(
      'v1 reader identity remains readable while v2 independently selects daily',
      () async {
    // Production v1 staging reader (2026-10-08): only personality pointer plus
    // this exact regex. Daily issuance must never change that v1 identity.
    final v1Allowed = RegExp(r'^personality_v1_(body|activity|body_activity)$');
    final legacyBefore = Map<String, dynamic>.from(pointerData);
    final legacyReport = personalityFixture();
    expect(v1Allowed.hasMatch(legacyBefore['reportId'] as String), isTrue);
    expect(v1Allowed.hasMatch('daily_2026-10-09'), isFalse);
    await listen(dailyAbsent: false);
    await publishDaily();
    expect(states.last.report!.reportId, 'daily_2026-10-09');
    expect(pointerData, legacyBefore);
    final v1Read = PersonalityReport.fromMap(legacyReport,
        expectedReportId: legacyBefore['reportId'] as String);
    expect(v1Read.reportId, 'personality_v1_body');
    expect(v1Read.isDaily, isFalse);
    expect(pointer().metadataFlags, isEmpty);
  });
}

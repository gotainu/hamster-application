import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/services/health_assessment_repo.dart';

class _User implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  _Auth(String? uid) : currentUser = uid == null ? null : _User(uid);
  @override
  User? currentUser;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Metadata implements SnapshotMetadata {
  _Metadata({this.isFromCache = false, this.hasPendingWrites = false});
  @override
  final bool isFromCache;
  @override
  final bool hasPendingWrites;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Test-only read doubles, as in existing repository tests.
// ignore: subtype_of_sealed_class
class _Snapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.value, {bool cache = false, bool pending = false})
      : metadata = _Metadata(isFromCache: cache, hasPendingWrites: pending);
  final Map<String, dynamic>? value;
  @override
  bool get exists => value != null;
  @override
  final SnapshotMetadata metadata;
  @override
  Map<String, dynamic>? data() => value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Firestore implements FirebaseFirestore {
  final paths = <String>[];
  final options = <GetOptions?>[];
  DocumentSnapshot<Map<String, dynamic>> response = _Snapshot(_fixture());
  Object? error;
  Future<void> Function()? beforeGet;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Test-only read doubles, as in existing repository tests.
// ignore: subtype_of_sealed_class
class _Collection implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.db, this.path);
  final _Firestore db;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? documentPath]) =>
      _Document(db, '$path/$documentPath');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Test-only read doubles, as in existing repository tests.
// ignore: subtype_of_sealed_class
class _Document implements DocumentReference<Map<String, dynamic>> {
  _Document(this.db, this.path);
  final _Firestore db;
  @override
  final String path;
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _Collection(db, '$path/$collectionPath');
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get(
      [GetOptions? options]) async {
    db.paths.add(path);
    db.options.add(options);
    await db.beforeGet?.call();
    if (db.error != null) throw db.error!;
    return db.response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _fixture() => {
      'dateKey': '2026-10-11',
      'featureDateKey': '2026-10-11',
      'evaluatorVersion': 7,
      'evaluatedAt': DateTime.utc(2026, 10, 11, 2),
      'domains': {
        'body': {'state': 'good', 'score': 100, 'summary': '最近の体重は概ね安定しています'},
      },
      'overall': {'state': 'good', 'score': 100},
    };

void main() {
  test('opt-in health read requests Source.server and preserves server score',
      () async {
    final db = _Firestore();
    final repo = HealthAssessmentRepo(db: db, auth: _Auth('owner'));
    final assessment = await repo.fetchLatestFromServer();
    expect(db.paths, ['users/owner/health_assessments/latest']);
    expect(db.options.single!.source, Source.server);
    expect(assessment!.dateKey, '2026-10-11');
    expect(assessment.domains.body.score, 100);
    expect(assessment.overall.score, 100);
    expect(assessment.evaluatorVersion, 7);
  });

  test('existing default fetch still uses its unchanged read semantics',
      () async {
    final db = _Firestore()..response = _Snapshot(_fixture(), cache: true);
    final repo = HealthAssessmentRepo(db: db, auth: _Auth('owner'));
    expect((await repo.fetchLatest())!.domains.body.score, 100);
    expect(db.options.single, isNull);
  });

  test('server read does not authorize cache or pending writes', () async {
    for (final response in [
      _Snapshot(_fixture(), cache: true),
      _Snapshot(_fixture(), pending: true),
      _Snapshot(null),
    ]) {
      final db = _Firestore()..response = response;
      final repo = HealthAssessmentRepo(db: db, auth: _Auth('owner'));
      expect(await repo.fetchLatestFromServer(), isNull);
      expect(db.options.single!.source, Source.server);
    }
  });

  test('server failure is surfaced without a cached retry', () async {
    final db = _Firestore()..error = StateError('unavailable');
    final repo = HealthAssessmentRepo(db: db, auth: _Auth('owner'));
    await expectLater(repo.fetchLatestFromServer(), throwsStateError);
    expect(db.options.length, 1);
    expect(db.options.single!.source, Source.server);
  });

  test('signed-out server read does not issue a document request', () async {
    final db = _Firestore();
    final repo = HealthAssessmentRepo(db: db, auth: _Auth(null));
    expect(await repo.fetchLatestFromServer(), isNull);
    expect(db.paths, isEmpty);
  });

  test('account changes during server read discard the old-owner assessment',
      () async {
    final db = _Firestore();
    final auth = _Auth('owner-a');
    final waiting = Completer<void>();
    db.beforeGet = () => waiting.future;
    final repo = HealthAssessmentRepo(db: db, auth: auth);
    final pending = repo.fetchLatestFromServer();
    await pumpEventQueue();
    auth.currentUser = _User('owner-b');
    waiting.complete();
    expect(await pending, isNull);
    expect(db.paths, ['users/owner-a/health_assessments/latest']);
  });
}

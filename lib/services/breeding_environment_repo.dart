import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/breeding_environment.dart';
import '../models/environment_history.dart';

abstract interface class EnvironmentStore {
  Future<EnvironmentLoadResult> load();
  Future<EnvironmentSaveResult> save(EnvironmentMutation mutation);
  Future<EnvironmentHistoryPage> history({int limit = 20, int? beforeRevision});
}

abstract interface class EnvironmentPendingStore {
  Future<EnvironmentMutation?> read(String owner);
  Future<void> write(String owner, EnvironmentMutation mutation);
  Future<void> remove(String owner);
}

class SecureEnvironmentPendingStore implements EnvironmentPendingStore {
  SecureEnvironmentPendingStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  String _key(String owner) => 'environment_pending_v1:$owner';
  @override
  Future<EnvironmentMutation?> read(String owner) async {
    final raw = await _storage.read(key: _key(owner));
    return raw == null
        ? null
        : EnvironmentMutation.fromMap(
            Map<String, dynamic>.from(jsonDecode(raw)));
  }

  @override
  Future<void> write(String owner, EnvironmentMutation mutation) =>
      _storage.write(key: _key(owner), value: jsonEncode(mutation.toMap()));
  @override
  Future<void> remove(String owner) => _storage.delete(key: _key(owner));
}

/// Retains the legacy read model. Every save now uses one server transaction.
class BreedingEnvironmentRepo implements EnvironmentStore {
  BreedingEnvironmentRepo(
      {FirebaseFirestore? db,
      FirebaseAuth? auth,
      FirebaseFunctions? functions,
      EnvironmentPendingStore? pendingStore,
      Future<Map<String, dynamic>?> Function()? read,
      Future<Map<String, dynamic>> Function(Map<String, dynamic>)? submit,
      String? Function()? owner})
      : _db = db,
        _auth = auth,
        _functions = functions,
        _pending = pendingStore ?? SecureEnvironmentPendingStore(),
        _readOverride = read,
        _submitOverride = submit,
        _ownerOverride = owner;
  final FirebaseFirestore? _db;
  final FirebaseAuth? _auth;
  final FirebaseFunctions? _functions;
  final EnvironmentPendingStore _pending;
  final Future<Map<String, dynamic>?> Function()? _readOverride;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
      _submitOverride;
  final String? Function()? _ownerOverride;
  String? get _uid => _ownerOverride != null
      ? _ownerOverride()
      : (_auth ?? FirebaseAuth.instance).currentUser?.uid;
  String _owner() => _uid ?? (throw StateError('sign_in_required'));
  FirebaseFirestore get _firestore => _db ?? FirebaseFirestore.instance;
  FirebaseFunctions get _callables =>
      _functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast1');
  DocumentReference<Map<String, dynamic>> _doc(String owner) =>
      _firestore.doc('users/$owner/breeding_environments/main_env');
  Future<BreedingEnvironment?> fetchMainEnv() async {
    final owner = _uid;
    if (owner == null) return null;
    final data = _readOverride != null
        ? await _readOverride()
        : (await _doc(owner).get()).data();
    return data == null ? null : BreedingEnvironment.fromMap(data);
  }

  @override
  Future<EnvironmentLoadResult> load() async {
    final owner = _owner();
    final pending = await _pending.read(owner);
    try {
      final data = _readOverride != null
          ? await _readOverride()
          : (await _doc(owner).get(const GetOptions(source: Source.server)))
              .data();
      if (_owner() != owner) throw StateError('owner_changed');
      return EnvironmentLoadResult(
          environment: data == null ? null : BreedingEnvironment.fromMap(data),
          pending: pending);
    } on FirebaseException catch (error) {
      if (!_isOffline(error)) rethrow;
      return EnvironmentLoadResult(pending: pending, serverConfirmed: false);
    }
  }

  static final _locks = <String, Future<void>>{};
  @override
  Future<EnvironmentSaveResult> save(EnvironmentMutation mutation) async {
    final owner = _owner();
    final prior = _locks[owner] ?? Future<void>.value();
    final gate = Completer<void>();
    _locks[owner] = gate.future;
    await prior;
    try {
      return await _save(owner, mutation);
    } finally {
      gate.complete();
      if (identical(_locks[owner], gate.future)) _locks.remove(owner);
    }
  }

  Future<EnvironmentSaveResult> _save(
      String owner, EnvironmentMutation mutation) async {
    if (_owner() != owner) throw StateError('owner_changed');
    final pending = await _pending.read(owner);
    if (pending != null &&
        jsonEncode(pending.toMap()) != jsonEncode(mutation.toMap())) {
      throw StateError('pending_mutation_must_be_resolved');
    }
    await _pending.write(owner, mutation);
    if (_owner() != owner) throw StateError('owner_changed');
    try {
      final data = _submitOverride != null
          ? await _submitOverride(mutation.toMap())
          : environmentMap((await _callables
                  .httpsCallable('saveBreedingEnvironment')
                  .call(mutation.toMap()))
              .data);
      if (_owner() != owner) throw StateError('owner_changed');
      final acceptedAt = environmentTime(data['acceptedAt']);
      if (data['saved'] != true ||
          data['revision'] is! int ||
          (data['revision'] as int) < mutation.expectedRevision ||
          acceptedAt == null ||
          data['mutationId'] != mutation.mutationId) {
        return EnvironmentSaveResult(confirmed: false, mutation: mutation);
      }
      await _pending.remove(owner);
      return EnvironmentSaveResult(
          confirmed: true,
          mutation: mutation,
          revision: data['revision'] as int,
          changed: data['changed'] == true,
          replayed: data['replayed'] == true,
          acceptedAt: acceptedAt);
    } on FirebaseFunctionsException catch (error) {
      if (_isOffline(error)) {
        return EnvironmentSaveResult(confirmed: false, mutation: mutation);
      }
      // Unknown outcomes retain the ID because the transaction may have committed.
      if (const {
        'invalid-argument',
        'failed-precondition',
        'aborted',
        'unauthenticated',
        'permission-denied',
        'not-found',
        'already-exists'
      }.contains(error.code)) {
        await _pending.remove(owner);
      }
      rethrow;
    }
  }

  @override
  Future<EnvironmentHistoryPage> history(
      {int limit = 20, int? beforeRevision}) async {
    if (limit < 1 || limit > 50) throw ArgumentError.value(limit, 'limit');
    final owner = _owner();
    Query<Map<String, dynamic>> query = _doc(owner)
        .collection('revisions')
        .orderBy('revision', descending: true);
    if (beforeRevision != null) query = query.startAfter([beforeRevision]);
    final rows = await query
        .limit(limit + 1)
        .get(const GetOptions(source: Source.server));
    if (_owner() != owner) throw StateError('owner_changed');
    final entries = rows.docs
        .take(limit)
        .map((row) => EnvironmentHistoryEntry.fromMap(row.data()))
        .toList();
    return EnvironmentHistoryPage(
        entries: entries,
        hasMore: rows.docs.length > limit,
        beforeRevision: entries.lastOrNull?.revision);
  }

  /// Retrospective without a cutoff; point-in-time with an explicit knowledge cutoff.
  Future<EnvironmentAtResult> readAt(
      {required DateTime observedAt, DateTime? knowledgeCutoff}) async {
    final owner = _owner();
    final data = environmentMap(
        (await _callables.httpsCallable('readBreedingEnvironmentAt').call({
      'observedAt': observedAt.toUtc().toIso8601String(),
      if (knowledgeCutoff != null)
        'knowledgeCutoff': knowledgeCutoff.toUtc().toIso8601String(),
    }))
            .data);
    if (_owner() != owner) throw StateError('owner_changed');
    return EnvironmentAtResult.fromMap(data);
  }

  Future<double?> fetchWheelDiameter() async =>
      (await fetchMainEnv())?.wheelDiameterAsDouble();
  Stream<BreedingEnvironment?> watchMainEnv() {
    final owner = _uid;
    if (owner == null) return const Stream.empty();
    return _doc(owner).snapshots().map((snapshot) => snapshot.data() == null
        ? null
        : BreedingEnvironment.fromMap(snapshot.data()!));
  }

  bool _isOffline(FirebaseException error) => const {
        'unavailable',
        'deadline-exceeded',
        'network-request-failed',
        'cancelled'
      }.contains(error.code);
}

import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/daily_care_actions.dart';

abstract interface class CareActionStore {
  Future<CareActionLoadResult> load(String dayKey);
  Future<CareActionSaveResult> save(CareActionMutation mutation);
}

abstract interface class CareActionPendingStore {
  Future<CareActionMutation?> read(String owner, String dayKey);
  Future<void> write(String owner, CareActionMutation mutation);
  Future<void> remove(String owner, String dayKey);
}

class SecureCareActionPendingStore implements CareActionPendingStore {
  SecureCareActionPendingStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  String _key(String owner, String day) => 'care_action_pending_v1:$owner:$day';
  @override
  Future<CareActionMutation?> read(String owner, String dayKey) async {
    final raw = await _storage.read(key: _key(owner, dayKey));
    return raw == null
        ? null
        : CareActionMutation.fromMap(
            Map<String, dynamic>.from(jsonDecode(raw)));
  }

  @override
  Future<void> write(String owner, CareActionMutation mutation) =>
      _storage.write(
          key: _key(owner, mutation.dayKey),
          value: jsonEncode(mutation.toMap()));
  @override
  Future<void> remove(String owner, String dayKey) =>
      _storage.delete(key: _key(owner, dayKey));
}

/// Durable owner-scoped pending payload keeps its mutation ID across restarts.
/// Only a server response confirms the record; local timestamps never earn rewards.
class DailyCareActionsRepo implements CareActionStore {
  DailyCareActionsRepo(
      {FirebaseFirestore? db,
      FirebaseAuth? auth,
      FirebaseFunctions? functions,
      CareActionPendingStore? pendingStore,
      Future<Map<String, dynamic>> Function(Map<String, dynamic>)? submit,
      Future<Map<String, dynamic>?> Function(String)? read,
      String? Function()? owner})
      : _db = db,
        _auth = auth,
        _functions = functions,
        _pending = pendingStore ?? SecureCareActionPendingStore(),
        _submitOverride = submit,
        _readOverride = read,
        _ownerOverride = owner;
  final FirebaseFirestore? _db;
  final FirebaseAuth? _auth;
  final FirebaseFunctions? _functions;
  final CareActionPendingStore _pending;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
      _submitOverride;
  final Future<Map<String, dynamic>?> Function(String)? _readOverride;
  final String? Function()? _ownerOverride;
  String _owner() {
    final owner = _ownerOverride != null
        ? _ownerOverride()
        : (_auth ?? FirebaseAuth.instance).currentUser?.uid;
    if (owner == null) throw StateError('sign_in_required');
    return owner;
  }

  @override
  Future<CareActionLoadResult> load(String dayKey) async {
    final owner = _owner();
    final pending = await _pending.read(owner, dayKey);
    try {
      final read = _readOverride;
      final data = read != null
          ? await read(dayKey)
          : (await (_db ?? FirebaseFirestore.instance)
                  .doc('users/$owner/daily_care_actions/$dayKey')
                  .get(const GetOptions(source: Source.server)))
              .data();
      return CareActionLoadResult(
          record: data == null
              ? null
              : DailyCareActions.fromMap(data, dayKey: dayKey),
          pending: pending);
    } on FirebaseException catch (error) {
      if (!_isOffline(error)) rethrow;
      // A server-inaccessible day can still accept a provisional new draft.
      // expectedRevision=0 is never promoted to a confirmed write locally.
      return CareActionLoadResult(pending: pending, serverConfirmed: false);
    }
  }

  Stream<DailyCareActions?> watchByDay(String dayKey) {
    final owner = _owner();
    return (_db ?? FirebaseFirestore.instance)
        .doc('users/$owner/daily_care_actions/$dayKey')
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
        return null;
      }
      final data = snapshot.data();
      return data == null
          ? null
          : DailyCareActions.fromMap(data, dayKey: dayKey);
    });
  }

  static final _dayLocks = <String, Future<void>>{};
  @override
  Future<CareActionSaveResult> save(CareActionMutation mutation) {
    final owner = _owner();
    return _serial('$owner:${mutation.dayKey}', () => _save(owner, mutation));
  }

  Future<T> _serial<T>(String key, Future<T> Function() task) async {
    final previous = _dayLocks[key] ?? Future<void>.value();
    final gate = Completer<void>();
    _dayLocks[key] = gate.future;
    await previous;
    try {
      return await task();
    } finally {
      gate.complete();
      if (identical(_dayLocks[key], gate.future)) _dayLocks.remove(key);
    }
  }

  Future<CareActionSaveResult> _save(
      String owner, CareActionMutation mutation) async {
    if (_owner() != owner) throw StateError('owner_changed');
    final pending = await _pending.read(owner, mutation.dayKey);
    if (pending != null &&
        (pending.mutationId != mutation.mutationId ||
            jsonEncode(pending.toMap()) != jsonEncode(mutation.toMap()))) {
      throw StateError('pending_mutation_must_be_resolved');
    }
    // Persist before sending: a lost response safely retries the same request.
    await _pending.write(owner, mutation);
    if (_owner() != owner) throw StateError('owner_changed');
    try {
      final submit = _submitOverride;
      final data = submit != null
          ? await submit(mutation.toMap())
          : Map<String, dynamic>.from((await (_functions ??
                      FirebaseFunctions.instanceFor(region: 'asia-northeast1'))
                  .httpsCallable('saveDailyCareActions')
                  .call(mutation.toMap()))
              .data as Map);
      if (_owner() != owner) throw StateError('owner_changed');
      if (data['saved'] != true || data['revision'] is! int) {
        // The outcome is unknown. Keep the same receipt visible for retry.
        return CareActionSaveResult(
            state: CareActionSaveState.pendingSync, mutation: mutation);
      }
      await _pending.remove(owner, mutation.dayKey);
      final reward = data['reward'];
      final continuity = data['continuity'];
      return CareActionSaveResult(
          state: CareActionSaveState.saved,
          mutation: mutation,
          revision: data['revision'] as int,
          replayed: data['replayed'] == true,
          rewardStatus: reward is Map
              ? reward['status'] as String? ?? 'not_processed'
              : 'not_processed',
          achievementRecorded:
              continuity is Map && continuity['achievementRecorded'] == true,
          mirroredAwardCount:
              continuity is Map && continuity['mirroredAwardCount'] is num
                  ? (continuity['mirroredAwardCount'] as num).toInt()
                  : 0,
          confirmationPending:
              continuity is Map && continuity['confirmationPending'] == true);
    } on FirebaseException catch (error) {
      if (_isOffline(error)) {
        return CareActionSaveResult(
            state: CareActionSaveState.pendingSync, mutation: mutation);
      }
      // A definitive validation/conflict response is not a transport retry.
      await _pending.remove(owner, mutation.dayKey);
      rethrow;
    }
  }

  bool _isOffline(FirebaseException error) => const {
        'unavailable',
        'deadline-exceeded',
        'network-request-failed'
      }.contains(error.code);
}

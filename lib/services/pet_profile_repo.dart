// lib/services/pet_profile_repo.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/daily_observation_history.dart';

import '../models/pet_profile.dart';

abstract interface class ProfilePendingStore {
  Future<Map<String, dynamic>?> read(String owner);
  Future<void> write(String owner, Map<String, dynamic> mutation);
  Future<void> remove(String owner);
}

class SecureProfilePendingStore implements ProfilePendingStore {
  SecureProfilePendingStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  String _key(String owner) => 'profile_pending_v1:$owner';
  @override
  Future<Map<String, dynamic>?> read(String owner) async {
    final raw = await _storage.read(key: _key(owner));
    return raw == null ? null : observationMap(jsonDecode(raw));
  }

  @override
  Future<void> write(String owner, Map<String, dynamic> mutation) =>
      _storage.write(key: _key(owner), value: jsonEncode(mutation));
  @override
  Future<void> remove(String owner) => _storage.delete(key: _key(owner));
}

class PetProfileRepo {
  PetProfileRepo(
      {FirebaseFirestore? db,
      FirebaseAuth? auth,
      FirebaseFunctions? functions,
      ProfilePendingStore? pendingStore,
      String? Function()? owner,
      Future<Map<String, dynamic>?> Function()? read,
      Future<Map<String, dynamic>> Function(Map<String, dynamic>)? submit})
      : _db = db,
        _auth = auth,
        _functions = functions,
        _pending = pendingStore ?? SecureProfilePendingStore(),
        _ownerOverride = owner,
        _readOverride = read,
        _submitOverride = submit;
  final FirebaseFirestore? _db;
  final FirebaseAuth? _auth;
  final FirebaseFunctions? _functions;
  final ProfilePendingStore _pending;
  final String? Function()? _ownerOverride;
  final Future<Map<String, dynamic>?> Function()? _readOverride;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
      _submitOverride;
  String? get _uid => _ownerOverride != null
      ? _ownerOverride()
      : (_auth ?? FirebaseAuth.instance).currentUser?.uid;
  String _owner() => _uid ?? (throw StateError('sign_in_required'));
  DocumentReference<Map<String, dynamic>> _doc(String owner) =>
      (_db ?? FirebaseFirestore.instance)
          .doc('users/$owner/pet_profiles/main_pet');
  Stream<PetProfile?> watchMainPet() {
    final owner = _uid;
    if (owner == null) return const Stream.empty();
    return _doc(owner).snapshots().map((snap) => _uid != owner || !snap.exists
        ? null
        : PetProfile.fromMap(snap.data()!));
  }

  Future<PetProfile?> fetchMainPet() async {
    final owner = _uid;
    if (owner == null) return null;
    final data = _readOverride != null
        ? await _readOverride()
        : (await _doc(owner).get(const GetOptions(source: Source.server)))
            .data();
    if (_uid != owner) throw StateError('owner_changed');
    return data == null ? null : PetProfile.fromMap(data);
  }

  Future<PetProfile?> fetchPendingProfile() async {
    final owner = _owner();
    final pending = await _pending.read(owner);
    if (_owner() != owner) throw StateError('owner_changed');
    if (pending == null) return null;
    if (pending['operation'] != 'save') return fetchMainPet();
    final values = observationMap(pending['values']);
    return PetProfile.fromMap({
      ...values,
      'subjectId': pending['expectedSubjectId'],
      'revision': pending['expectedRevision']
    });
  }

  Future<Map<String, dynamic>?> pendingMutation() async {
    final owner = _owner();
    final pending = await _pending.read(owner);
    if (_owner() != owner) throw StateError('owner_changed');
    return pending;
  }

  Future<PetProfile> retryPending() async {
    final owner = _owner(), prior = _locks[_owner()] ?? Future<void>.value();
    final gate = Completer<void>();
    _locks[owner] = gate.future;
    await prior;
    try {
      final pending = await _pending.read(owner);
      if (pending == null) throw StateError('profile_pending_missing');
      await _submit(owner, pending);
      final profile = await fetchMainPet();
      if (profile == null) throw StateError('profile_save_not_confirmed');
      return profile;
    } finally {
      gate.complete();
      if (identical(_locks[owner], gate.future)) _locks.remove(owner);
    }
  }

  static final _locks = <String, Future<void>>{};
  Future<PetProfile> saveMainPet(PetProfile profile) async {
    final owner = _owner(), prior = _locks[_owner()] ?? Future<void>.value();
    final gate = Completer<void>();
    _locks[owner] = gate.future;
    await prior;
    try {
      final values = {
        'name': profile.name.trim(),
        'birthday': profile.birthday?.toUtc().toIso8601String(),
        'birthdayPrecision': profile.birthdayPrecision,
        'species': profile.species,
        'color': profile.color,
        'imageUrl': profile.imageUrl,
      };
      final saved = await _submit(owner, {
        'expectedRevision': profile.revision,
        'expectedSubjectId': profile.subjectId,
        'operation': 'save',
        'values': values
      });
      return PetProfile(
          name: profile.name,
          birthday: profile.birthday,
          species: profile.species,
          color: profile.color,
          imageUrl: profile.imageUrl,
          subjectId: saved['subjectId'] as String,
          revision: saved['revision'] as int,
          birthdayPrecision: profile.birthdayPrecision,
          profileHistoryRevision: saved['historyRevision'] is int
              ? saved['historyRevision'] as int
              : profile.profileHistoryRevision);
    } finally {
      gate.complete();
      if (identical(_locks[owner], gate.future)) _locks.remove(owner);
    }
  }

  Future<Map<String, dynamic>> _submit(
      String owner, Map<String, dynamic> request) async {
    if (_owner() != owner) throw StateError('owner_changed');
    final pending = await _pending.read(owner);
    if (_owner() != owner) throw StateError('owner_changed');
    final comparable = {...request}..remove('mutationId');
    if (pending != null) {
      final old = {...pending}..remove('mutationId');
      if (jsonEncode(old) != jsonEncode(comparable)) {
        throw StateError('profile_pending_must_be_resolved');
      }
    }
    final payload = pending ?? {...request, 'mutationId': const Uuid().v4()};
    await _pending.write(owner, payload);
    if (_owner() != owner) throw StateError('owner_changed');
    try {
      if (_owner() != owner) throw StateError('owner_changed');
      final data = _submitOverride != null
          ? await _submitOverride(payload)
          : observationMap((await (_functions ??
                      FirebaseFunctions.instanceFor(region: 'asia-northeast1'))
                  .httpsCallable('saveMainPetProfile')
                  .call(payload))
              .data);
      if (_owner() != owner) throw StateError('owner_changed');
      if (data['subjectId'] is! String ||
          data['revision'] is! int ||
          (data['revision'] as int) < (request['expectedRevision'] as int) ||
          observationTime(data['acceptedAt']) == null ||
          data['mutationId'] != payload['mutationId'] ||
          (request['expectedSubjectId'] != null &&
              data['subjectId'] != request['expectedSubjectId'])) {
        throw StateError('profile_save_not_confirmed');
      }
      await _pending.remove(owner);
      if (_owner() != owner) throw StateError('owner_changed');
      return data;
    } on FirebaseFunctionsException catch (error) {
      if (const {
        'invalid-argument',
        'failed-precondition',
        'aborted',
        'unauthenticated',
        'permission-denied',
        'not-found',
        'already-exists',
        'resource-exhausted'
      }.contains(error.code)) {
        await _pending.remove(owner);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> readHistoryAt(
      {required String subjectId,
      required String evaluationDateKey,
      String? knowledgeCutoff,
      String? knowledgeCutoffEpochNanoseconds}) async {
    final owner = _owner();
    final result = observationMap((await (_functions ??
                FirebaseFunctions.instanceFor(region: 'asia-northeast1'))
            .httpsCallable('readMainPetProfileHistoryAt')
            .call({
      'subjectId': subjectId,
      'evaluationDateKey': evaluationDateKey,
      if (knowledgeCutoff != null) 'knowledgeCutoff': knowledgeCutoff,
      if (knowledgeCutoffEpochNanoseconds != null)
        'knowledgeCutoffEpochNanoseconds': knowledgeCutoffEpochNanoseconds
    }))
        .data);
    if (_owner() != owner) throw StateError('owner_changed');
    return result;
  }

  Future<PetProfile> cancelAttributeCorrection(PetProfile profile,
      {required int targetHistoryRevision}) async {
    final owner = _owner(), prior = _locks[_owner()] ?? Future<void>.value();
    final gate = Completer<void>();
    _locks[owner] = gate.future;
    await prior;
    try {
      await _submit(owner, {
        'expectedRevision': profile.revision,
        'expectedSubjectId': profile.subjectId,
        'operation': 'cancel_profile_correction',
        'targetHistoryRevision': targetHistoryRevision
      });
      final refreshed = await fetchMainPet();
      if (refreshed == null) throw StateError('profile_save_not_confirmed');
      return refreshed;
    } finally {
      gate.complete();
      if (identical(_locks[owner], gate.future)) _locks.remove(owner);
    }
  }

  Future<PetProfile> deleteImageUrl({PetProfile? expectedProfile}) async {
    final profile = expectedProfile ?? await fetchMainPet();
    if (profile == null) throw StateError('profile_required');
    return saveMainPet(PetProfile(
        name: profile.name,
        birthday: profile.birthday,
        species: profile.species,
        color: profile.color,
        imageUrl: null,
        subjectId: profile.subjectId,
        revision: profile.revision,
        birthdayPrecision: profile.birthdayPrecision,
        profileHistoryRevision: profile.profileHistoryRevision));
  }
}

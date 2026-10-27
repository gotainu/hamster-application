import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/daily_observation_history.dart';

abstract interface class MeasurementPendingStore {
  Future<Map<String, dynamic>?> read(String owner, String kind);
  Future<void> write(String owner, String kind, Map<String, dynamic> value);
  Future<void> remove(String owner, String kind);
}

class SecureMeasurementPendingStore implements MeasurementPendingStore {
  SecureMeasurementPendingStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  String _key(String owner, String kind) =>
      'measurement_pending_v1:$owner:$kind';
  @override
  Future<Map<String, dynamic>?> read(String owner, String kind) async {
    final raw = await _storage.read(key: _key(owner, kind));
    return raw == null ? null : observationMap(jsonDecode(raw));
  }

  @override
  Future<void> write(String owner, String kind, Map<String, dynamic> value) =>
      _storage.write(key: _key(owner, kind), value: jsonEncode(value));
  @override
  Future<void> remove(String owner, String kind) =>
      _storage.delete(key: _key(owner, kind));
}

/// A saved projection is confirmed only by its matching server receipt.
class MeasurementHistoryClient {
  MeasurementHistoryClient({
    required this.kind,
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    MeasurementPendingStore? pendingStore,
    String? Function()? owner,
    Future<Map<String, dynamic>?> Function()? readProfile,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>)? submit,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>)? readHistory,
    Future<int> Function(String)? readDayRevision,
  })  : _db = db,
        _auth = auth,
        _functions = functions,
        _pending = pendingStore ?? SecureMeasurementPendingStore(),
        _ownerOverride = owner,
        _profileOverride = readProfile,
        _submitOverride = submit,
        _historyOverride = readHistory,
        _dayRevisionOverride = readDayRevision;
  final String kind;
  final FirebaseFirestore? _db;
  final FirebaseAuth? _auth;
  final FirebaseFunctions? _functions;
  final MeasurementPendingStore _pending;
  final String? Function()? _ownerOverride;
  final Future<Map<String, dynamic>?> Function()? _profileOverride;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
      _submitOverride;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
      _historyOverride;
  final Future<int> Function(String)? _dayRevisionOverride;
  Future<int> dayRevision(String day) async {
    final owner = _owner();
    final result = _dayRevisionOverride != null
        ? await _dayRevisionOverride(day)
        : (await (_db ?? FirebaseFirestore.instance)
                    .doc('users/$owner/${kind}_record_days/$day')
                    .get(const GetOptions(source: Source.server)))
                .data()?['revision'] as int? ??
            0;
    if (_owner() != owner) throw StateError('owner_changed');
    return result;
  }

  String _owner() =>
      (_ownerOverride != null
          ? _ownerOverride()
          : (_auth ?? FirebaseAuth.instance).currentUser?.uid) ??
      (throw StateError('sign_in_required'));
  Future<Map<String, dynamic>?> pending() async {
    final owner = _owner();
    final value = await _pending.read(owner, kind);
    if (_owner() != owner) throw StateError('owner_changed');
    return value;
  }

  Future<String?> currentSubject() async {
    final owner = _owner();
    final profile = _profileOverride != null
        ? await _profileOverride()
        : (await (_db ?? FirebaseFirestore.instance)
                .doc('users/$owner/pet_profiles/main_pet')
                .get(const GetOptions(source: Source.server)))
            .data();
    if (_owner() != owner) throw StateError('owner_changed');
    if (profile == null) throw StateError('profile_required');
    return profile['subjectId'] as String?;
  }

  Future<Map<String, dynamic>> retryPending() async {
    final request = await pending();
    if (request == null) throw StateError('measurement_pending_missing');
    return save(request);
  }

  static final _locks = <String, Future<void>>{};
  static Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }

  Future<Map<String, dynamic>> save(Map<String, dynamic> request) async {
    final owner = _owner(), key = '$owner:$kind';
    final prior = _locks[key] ?? Future<void>.value();
    final gate = Completer<void>();
    _locks[key] = gate.future;
    await prior;
    try {
      if (_owner() != owner) throw StateError('owner_changed');
      final old = await _pending.read(owner, kind);
      if (_owner() != owner) throw StateError('owner_changed');
      final compare = {...request}..remove('mutationId');
      if (old != null) {
        final oldCompare = {...old}..remove('mutationId');
        if (jsonEncode(_canonical(oldCompare)) !=
            jsonEncode(_canonical(compare))) {
          throw StateError('measurement_pending_must_be_resolved');
        }
      }
      final payload = observationMap(jsonDecode(jsonEncode(old ??
          {
            ...request,
            'mutationId': request['mutationId'] ?? const Uuid().v4()
          })));
      await _pending.write(owner, kind, payload);
      if (_owner() != owner) throw StateError('owner_changed');
      try {
        if (_owner() != owner) throw StateError('owner_changed');
        final result = _submitOverride != null
            ? await _submitOverride(payload)
            : observationMap((await (_functions ??
                        FirebaseFunctions.instanceFor(
                            region: 'asia-northeast1'))
                    .httpsCallable(kind == 'weight'
                        ? 'saveWeightRecord'
                        : 'saveDistanceRecord')
                    .call(payload))
                .data);
        if (_owner() != owner) throw StateError('owner_changed');
        final projection = result['projection'];
        if (result['saved'] != true ||
            result['mutationId'] != payload['mutationId'] ||
            result['dayKey'] != payload['dayKey'] ||
            result['subjectId'] is! String ||
            (payload['subjectId'] != null &&
                result['subjectId'] != payload['subjectId']) ||
            result['recordId'] is! String ||
            result['revision'] is! int ||
            (result['revision'] as int) <
                (payload['expectedRevision'] as int) ||
            observationTime(result['acceptedAt']) == null ||
            (payload['operation'] == 'cancel'
                ? result['recordStatus'] != 'cancelled' || projection != null
                : result['recordStatus'] != 'active' ||
                    projection is! Map ||
                    projection['revision'] != result['revision'] ||
                    projection['recordId'] != result['recordId'] ||
                    projection['subjectId'] != result['subjectId'] ||
                    projection['dayKey'] != result['dayKey'])) {
          throw StateError('measurement_save_not_confirmed');
        }
        await _pending.remove(owner, kind);
        if (_owner() != owner) throw StateError('owner_changed');
        return result;
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
          await _pending.remove(owner, kind);
        }
        rethrow;
      }
    } finally {
      gate.complete();
      if (identical(_locks[key], gate.future)) _locks.remove(key);
    }
  }

  Future<Map<String, dynamic>> historyAt(
      {required String dayKey,
      String? knowledgeCutoff,
      String? knowledgeCutoffEpochNanoseconds}) async {
    final owner = _owner();
    final payload = {
      'kind': kind,
      'dayKey': dayKey,
      if (knowledgeCutoff != null) 'knowledgeCutoff': knowledgeCutoff,
      if (knowledgeCutoffEpochNanoseconds != null)
        'knowledgeCutoffEpochNanoseconds': knowledgeCutoffEpochNanoseconds
    };
    final result = _historyOverride != null
        ? await _historyOverride(payload)
        : observationMap((await (_functions ??
                    FirebaseFunctions.instanceFor(region: 'asia-northeast1'))
                .httpsCallable('readMeasurementHistoryAt')
                .call(payload))
            .data);
    if (_owner() != owner) throw StateError('owner_changed');
    return result;
  }
}

Map<String, dynamic> measurementWireTiming(Map<String, dynamic> timing) {
  final precision = timing['precision'] ?? timing['timePrecision'] ?? 'unknown';
  return {
    'precision': precision,
    'confirmation': timing['confirmation'] ?? 'unknown',
    if (precision == 'date_only') 'dateKey': timing['dateKey'],
    if (precision == 'instant') 'observedAt': timing['observedAt'],
    if (timing['windowMeaning'] != null)
      'windowMeaning': timing['windowMeaning']
  };
}

Map<String, dynamic> measurementDateTiming(String dayKey) => {
      'precision': 'date_only',
      'dateKey': dayKey,
      'confirmation': 'date_confirmed'
    };
const unknownMeasurementTiming = <String, dynamic>{
  'precision': 'unknown',
  'confirmation': 'unknown'
};

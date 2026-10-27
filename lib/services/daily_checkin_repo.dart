import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/daily_observation_history.dart';

import '../models/observation_catalog.dart';

typedef Json = Map<String, dynamic>;

enum DailyCondition {
  normal,
  slightlyConcerned,
  veryConcerned,
}

enum DailyObservationLevel {
  normal,
  changed,
  concerning,
}

final dailyObservationIds = List<String>.unmodifiable(
  activeObservationItems()
      .where((item) => item.defaultNormal)
      .map((item) => item.id),
);

Map<String, DailyObservationLevel> buildDailyObservationLevels({
  required DailyCondition condition,
  required Iterable<String> concernTags,
  List<ObservationCatalogItem> catalog = observationCatalog,
}) {
  final result = <String, DailyObservationLevel>{
    for (final item in activeObservationItems(catalog: catalog))
      if (item.defaultNormal) item.id: DailyObservationLevel.normal,
  };

  if (condition == DailyCondition.normal) return result;

  final concernLevel = condition == DailyCondition.veryConcerned
      ? DailyObservationLevel.concerning
      : DailyObservationLevel.changed;

  for (final id in normalizeObservationIds(concernTags, catalog: catalog)) {
    result[id] = concernLevel;
  }

  return result;
}

class DailyCheckin {
  final String dayKey;
  final DateTime date;
  final DailyCondition condition;
  final List<String> concernTags;
  final Map<String, DailyObservationLevel> observationLevels;
  final String memo;
  final int? schemaVersion;
  final String? observationCatalogVersion;
  final String? observationResponseMode;
  final String? subjectId, eventId;
  final int revision, eventRevision;
  final ObservationTiming? timing;

  const DailyCheckin({
    required this.dayKey,
    required this.date,
    required this.condition,
    required this.concernTags,
    this.observationLevels = const {},
    required this.memo,
    this.schemaVersion,
    this.observationCatalogVersion,
    this.observationResponseMode,
    this.subjectId,
    this.eventId,
    this.revision = 0,
    this.eventRevision = 0,
    this.timing,
  });

  bool get hasConcern => condition != DailyCondition.normal;

  factory DailyCheckin.fromJson(Json json, {required String fallbackDayKey}) {
    final conditionText = json['condition'];

    final condition = DailyCondition.values.firstWhere(
      (e) => e.name == conditionText,
      orElse: () => DailyCondition.normal,
    );

    final tagsRaw = json['concernTags'];
    final tags = tagsRaw is List
        ? normalizeObservationIds(tagsRaw.whereType<String>())
        : const <String>[];

    final levelsRaw = json['observationLevels'];
    final levels = <String, DailyObservationLevel>{};
    if (levelsRaw is Map) {
      for (final entry in levelsRaw.entries) {
        final id = entry.key;
        final value = entry.value;
        if (id is! String || value is! String) continue;

        for (final level in DailyObservationLevel.values) {
          if (level.name == value) {
            final canonicalId = resolveObservationId(id) ?? id;
            final existing = levels[canonicalId];
            if (existing == null || level.index > existing.index) {
              levels[canonicalId] = level;
            }
            break;
          }
        }
      }
    }

    final dateRaw = json['date'];
    final date = observationTime(dateRaw)?.toLocal() ??
        DateTime.tryParse(fallbackDayKey) ??
        DateTime.now();

    return DailyCheckin(
      dayKey: json['dayKey'] as String? ?? fallbackDayKey,
      date: date,
      condition: condition,
      concernTags: tags,
      observationLevels: levels,
      memo: json['memo'] as String? ?? '',
      subjectId: json['subjectId'] as String?,
      eventId: json['eventId'] as String?,
      revision: json['revision'] is int ? json['revision'] as int : 0,
      eventRevision:
          json['eventRevision'] is int ? json['eventRevision'] as int : 0,
      timing: json['timing'] is Map
          ? ObservationTiming.fromMap(observationMap(json['timing']))
          : null,
      schemaVersion:
          json['schemaVersion'] is int ? json['schemaVersion'] as int : null,
      observationCatalogVersion: json['observationCatalogVersion'] is String
          ? json['observationCatalogVersion'] as String
          : null,
      observationResponseMode: json['observationResponseMode'] is String
          ? json['observationResponseMode'] as String
          : null,
    );
  }
}

/// Preserve schema2's overall answer and selected-tags meaning. Automatically
/// generated normal levels are not claims of per-item explicit answers.
Json buildDailyCheckinPayload({
  required String dayKey,
  required DateTime localDay,
  required DailyCondition condition,
  required List<String> concernTags,
  Map<String, DailyObservationLevel>? observationLevels,
  String memo = '',
  required bool isNew,
}) {
  final tags = normalizeObservationIds(concernTags);
  final levels = <String, DailyObservationLevel>{};
  for (final entry in (observationLevels ??
          buildDailyObservationLevels(
            condition: condition,
            concernTags: tags,
          ))
      .entries) {
    final id = resolveObservationId(entry.key) ?? entry.key;
    final previous = levels[id];
    if (previous == null || entry.value.index > previous.index) {
      levels[id] = entry.value;
    }
  }
  return {
    'dayKey': dayKey,
    'date': Timestamp.fromDate(localDay.toUtc()),
    'condition': condition.name,
    'concernTags': tags,
    'observationLevels': levels.map((id, level) => MapEntry(id, level.name)),
    'memo': memo.trim(),
    'schemaVersion': 2,
    'observationCatalogVersion': observationCatalogVersion,
    'observationResponseMode': 'overall_with_selected_tags',
    'updatedAt': FieldValue.serverTimestamp(),
    if (isNew) 'createdAt': FieldValue.serverTimestamp(),
  };
}

abstract interface class DailyCheckinStore {
  String dateKeyLocal(DateTime dayLocal);

  DateTime normalizeLocalDay(DateTime dt);

  Future<DailyCheckin?> fetchByDate(DateTime dayLocal);

  Stream<DailyCheckin?> watchByDate(DateTime dayLocal);

  Future<void> saveDailyCheckin({
    required DateTime date,
    required DailyCondition condition,
    required List<String> concernTags,
    required Map<String, DailyObservationLevel> observationLevels,
    String memo = '',
  });
}

class ObservationLoadResult {
  const ObservationLoadResult(
      {this.current,
      this.pending,
      this.revision = 0,
      this.subjectId,
      this.hasProfile = false,
      this.serverConfirmed = true});
  final DailyCheckin? current;
  final ObservationMutation? pending;
  final int revision;
  final String? subjectId;
  final bool hasProfile, serverConfirmed;
}

abstract interface class DailyObservationStore {
  Future<ObservationLoadResult> loadObservation(DateTime date);
  Future<ObservationSaveResult> saveObservation(ObservationMutation mutation);
}

abstract interface class ObservationPendingStore {
  Future<ObservationMutation?> read(String owner, String dayKey);
  Future<void> write(String owner, ObservationMutation mutation);
  Future<void> remove(String owner, String dayKey);
}

class SecureObservationPendingStore implements ObservationPendingStore {
  SecureObservationPendingStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  String _key(String owner, String day) => 'observation_pending_v1:$owner:$day';
  @override
  Future<ObservationMutation?> read(String owner, String dayKey) async {
    final raw = await _storage.read(key: _key(owner, dayKey));
    return raw == null
        ? null
        : ObservationMutation.fromMap(
            Map<String, dynamic>.from(jsonDecode(raw)));
  }

  @override
  Future<void> write(String owner, ObservationMutation mutation) =>
      _storage.write(
          key: _key(owner, mutation.dayKey),
          value: jsonEncode(mutation.toMap()));
  @override
  Future<void> remove(String owner, String dayKey) =>
      _storage.delete(key: _key(owner, dayKey));
}

/// Legacy daily projection remains readable; writes are accepted server transactions.
class DailyCheckinRepo implements DailyCheckinStore, DailyObservationStore {
  DailyCheckinRepo(
      {FirebaseFirestore? db,
      FirebaseAuth? auth,
      FirebaseFunctions? functions,
      ObservationPendingStore? pendingStore,
      Future<Map<String, dynamic>> Function(String dayKey)? read,
      Future<Map<String, dynamic>> Function(Map<String, dynamic>)? submit,
      String? Function()? owner})
      : _db = db,
        _auth = auth,
        _functions = functions,
        _pending = pendingStore ?? SecureObservationPendingStore(),
        _readOverride = read,
        _submitOverride = submit,
        _ownerOverride = owner;
  final FirebaseFirestore? _db;
  final FirebaseAuth? _auth;
  final FirebaseFunctions? _functions;
  final ObservationPendingStore _pending;
  final Future<Map<String, dynamic>> Function(String)? _readOverride;
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
  DocumentReference<Json> _doc(String owner, String day) =>
      _firestore.doc('users/$owner/daily_checkins/$day');
  @override
  String dateKeyLocal(DateTime dayLocal) {
    final d = normalizeLocalDay(dayLocal);
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  DateTime normalizeLocalDay(DateTime dt) {
    final local = dt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  @override
  Future<DailyCheckin?> fetchByDate(DateTime dayLocal) async {
    final owner = _uid;
    if (owner == null) return null;
    final day = dateKeyLocal(dayLocal);
    final data = _readOverride != null
        ? observationMap((await _readOverride(day))['current'])
        : (await _doc(owner, day).get()).data();
    if (_uid != owner) throw StateError('owner_changed');
    return data == null || data.isEmpty
        ? null
        : DailyCheckin.fromJson(data, fallbackDayKey: day);
  }

  @override
  Stream<DailyCheckin?> watchByDate(DateTime dayLocal) {
    final owner = _uid;
    if (owner == null) return const Stream.empty();
    return _doc(owner, dateKeyLocal(dayLocal)).snapshots().map((snap) {
      if (_uid != owner) return null;
      final data = snap.data();
      return data == null
          ? null
          : DailyCheckin.fromJson(data, fallbackDayKey: snap.id);
    });
  }

  @override
  Future<ObservationLoadResult> loadObservation(DateTime date) async {
    final owner = _owner(), day = dateKeyLocal(date);
    final pending = await _pending.read(owner, day);
    try {
      Map<String, dynamic> envelope = {};
      var coherent = false;
      for (var attempt = 0; attempt < 2; attempt++) {
        envelope = await _loadEnvelope(owner, day);
        if (_owner() != owner) throw StateError('owner_changed');
        coherent = _coherentEnvelope(envelope);
        if (coherent) break;
      }
      if (!coherent) {
        return ObservationLoadResult(pending: pending, serverConfirmed: false);
      }
      if (_owner() != owner) throw StateError('owner_changed');
      final current = observationMap(envelope['current']);
      final ledger = observationMap(envelope['ledger']);
      final profile = observationMap(envelope['profile']);
      return ObservationLoadResult(
          current: current.isEmpty
              ? null
              : DailyCheckin.fromJson(current, fallbackDayKey: day),
          pending: pending,
          revision: ledger['revision'] is int ? ledger['revision'] as int : 0,
          subjectId: profile['subjectId'] as String?,
          hasProfile: profile.isNotEmpty);
    } on FirebaseException catch (error) {
      if (!_offline(error)) rethrow;
      return ObservationLoadResult(pending: pending, serverConfirmed: false);
    }
  }

  Future<Map<String, dynamic>> _loadEnvelope(String owner, String day) async {
    if (_readOverride != null) return _readOverride(day);
    final rows = await Future.wait([
      _doc(owner, day).get(const GetOptions(source: Source.server)),
      _firestore
          .doc('users/$owner/observation_days/$day')
          .get(const GetOptions(source: Source.server)),
      _firestore
          .doc('users/$owner/pet_profiles/main_pet')
          .get(const GetOptions(source: Source.server)),
    ]);
    return {
      'current': rows[0].data(),
      'ledger': rows[1].data(),
      'profile': rows[2].data()
    };
  }

  bool _coherentEnvelope(Map<String, dynamic> envelope) {
    final current = observationMap(envelope['current']);
    final ledger = observationMap(envelope['ledger']);
    final profile = observationMap(envelope['profile']);
    if (ledger.isEmpty) {
      return (current['revision'] == null || current['revision'] == 0) &&
          (current['subjectId'] == null ||
              current['subjectId'] == profile['subjectId']);
    }
    if (ledger['revision'] is! int ||
        ledger['subjectId'] is! String ||
        ledger['subjectId'] != profile['subjectId']) {
      return false;
    }
    if (current.isEmpty) {
      return ledger['currentEventId'] == null &&
          ledger['currentEventRevision'] == null;
    }
    return current['revision'] == ledger['revision'] &&
        current['subjectId'] == ledger['subjectId'] &&
        current['eventId'] != null &&
        current['eventId'] == ledger['currentEventId'] &&
        current['eventRevision'] == ledger['currentEventRevision'];
  }

  static final _locks = <String, Future<void>>{};
  @override
  Future<ObservationSaveResult> saveObservation(
      ObservationMutation mutation) async {
    final owner = _owner(), key = '${_owner()}:${mutation.dayKey}';
    final prior = _locks[key] ?? Future<void>.value();
    final gate = Completer<void>();
    _locks[key] = gate.future;
    await prior;
    try {
      return await _save(owner, mutation);
    } finally {
      gate.complete();
      if (identical(_locks[key], gate.future)) _locks.remove(key);
    }
  }

  Future<ObservationSaveResult> _save(
      String owner, ObservationMutation mutation) async {
    if (_owner() != owner) throw StateError('owner_changed');
    final pending = await _pending.read(owner, mutation.dayKey);
    if (pending != null &&
        jsonEncode(pending.toMap()) != jsonEncode(mutation.toMap())) {
      throw StateError('pending_mutation_must_be_resolved');
    }
    await _pending.write(owner, mutation);
    if (_owner() != owner) throw StateError('owner_changed');
    try {
      final data = _submitOverride != null
          ? await _submitOverride(mutation.toMap())
          : observationMap((await _callables
                  .httpsCallable('saveDailyCheckin')
                  .call(mutation.toMap()))
              .data);
      if (_owner() != owner) throw StateError('owner_changed');
      final acceptedAt = observationTime(data['acceptedAt']);
      if (data['saved'] != true ||
          data['revision'] is! int ||
          (data['revision'] as int) < mutation.expectedRevision ||
          acceptedAt == null ||
          data['dayKey'] != mutation.dayKey ||
          data['mutationId'] != mutation.mutationId ||
          data['subjectId'] is! String ||
          !const {'active', 'cancelled'}.contains(data['recordStatus']) ||
          (data['recordStatus'] == 'active' && data['projection'] is! Map) ||
          (mutation.subjectId != null &&
              data['subjectId'] != mutation.subjectId)) {
        return ObservationSaveResult(confirmed: false, mutation: mutation);
      }
      await _pending.remove(owner, mutation.dayKey);
      return ObservationSaveResult(
          confirmed: true,
          mutation: mutation,
          revision: data['revision'] as int,
          subjectId: data['subjectId'] as String,
          eventId: data['eventId'] as String?,
          acceptedAt: acceptedAt,
          changed: data['changed'] == true,
          replayed: data['replayed'] == true,
          projection: data['projection'] is Map
              ? observationMap(data['projection'])
              : null);
    } on FirebaseFunctionsException catch (error) {
      if (_offline(error)) {
        return ObservationSaveResult(confirmed: false, mutation: mutation);
      }
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
        await _pending.remove(owner, mutation.dayKey);
      }
      rethrow;
    }
  }

  /// The old interface remains for existing readers and test stores. Production
  /// callers must supply explicit intent and timing through saveObservation.
  @override
  Future<void> saveDailyCheckin(
      {required DateTime date,
      required DailyCondition condition,
      required List<String> concernTags,
      Map<String, DailyObservationLevel>? observationLevels,
      String memo = ''}) async {
    throw StateError('observation_explicit_intent_required');
  }

  Future<ObservationHistoryAtResult> readAt(
      {required String dayKey, DateTime? knowledgeCutoff}) async {
    final owner = _owner();
    final data = observationMap(
        (await _callables.httpsCallable('readDailyCheckinHistoryAt').call({
      'dayKey': dayKey,
      if (knowledgeCutoff != null)
        'knowledgeCutoff': knowledgeCutoff.toUtc().toIso8601String(),
    }))
            .data);
    if (_owner() != owner) throw StateError('owner_changed');
    return ObservationHistoryAtResult.fromMap(data);
  }

  bool _offline(FirebaseException error) => const {
        'unavailable',
        'deadline-exceeded',
        'network-request-failed',
        'cancelled'
      }.contains(error.code);
}

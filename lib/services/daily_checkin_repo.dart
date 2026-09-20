import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

const dailyObservationIds = <String>[
  'appetite',
  'water',
  'elimination',
  'breathing',
  'movement',
  'eyesNose',
  'coatSkin',
];

Map<String, DailyObservationLevel> buildDailyObservationLevels({
  required DailyCondition condition,
  required Iterable<String> concernTags,
}) {
  final result = <String, DailyObservationLevel>{
    for (final id in dailyObservationIds) id: DailyObservationLevel.normal,
  };

  if (condition == DailyCondition.normal) return result;

  final concernLevel = condition == DailyCondition.veryConcerned
      ? DailyObservationLevel.concerning
      : DailyObservationLevel.changed;

  for (final id in concernTags) {
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

  const DailyCheckin({
    required this.dayKey,
    required this.date,
    required this.condition,
    required this.concernTags,
    this.observationLevels = const {},
    required this.memo,
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
        ? tagsRaw.whereType<String>().toList()
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
            levels[id] = level;
            break;
          }
        }
      }
    }

    final dateRaw = json['date'];
    final date =
        dateRaw is Timestamp ? dateRaw.toDate().toLocal() : DateTime.now();

    return DailyCheckin(
      dayKey: json['dayKey'] as String? ?? fallbackDayKey,
      date: date,
      condition: condition,
      concernTags: tags,
      observationLevels: levels,
      memo: json['memo'] as String? ?? '',
    );
  }
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

class DailyCheckinRepo implements DailyCheckinStore {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  DailyCheckinRepo({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Json>? _col() {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('daily_checkins');
  }

  @override
  String dateKeyLocal(DateTime dayLocal) {
    final local = dayLocal.toLocal();
    final d = DateTime(local.year, local.month, local.day);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  DateTime normalizeLocalDay(DateTime dt) {
    final local = dt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  DocumentReference<Json>? _docByLocalDate(DateTime dayLocal) {
    final col = _col();
    if (col == null) return null;
    return col.doc(dateKeyLocal(dayLocal));
  }

  @override
  Future<DailyCheckin?> fetchByDate(DateTime dayLocal) async {
    final doc = _docByLocalDate(dayLocal);
    if (doc == null) return null;

    final snap = await doc.get();
    if (!snap.exists) return null;

    final data = snap.data();
    if (data == null) return null;

    return DailyCheckin.fromJson(
      data,
      fallbackDayKey: doc.id,
    );
  }

  @override
  Stream<DailyCheckin?> watchByDate(DateTime dayLocal) {
    final doc = _docByLocalDate(dayLocal);
    if (doc == null) return const Stream<DailyCheckin?>.empty();

    return doc.snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;

      return DailyCheckin.fromJson(
        data,
        fallbackDayKey: snap.id,
      );
    });
  }

  @override
  Future<void> saveDailyCheckin({
    required DateTime date,
    required DailyCondition condition,
    required List<String> concernTags,
    Map<String, DailyObservationLevel>? observationLevels,
    String memo = '',
  }) async {
    final doc = _docByLocalDate(date);
    if (doc == null) return;

    final localDay = normalizeLocalDay(date);
    final snap = await doc.get();

    final data = <String, dynamic>{
      'dayKey': dateKeyLocal(localDay),
      'date': Timestamp.fromDate(localDay.toUtc()),
      'condition': condition.name,
      'concernTags': concernTags,
      'observationLevels': (observationLevels ??
              buildDailyObservationLevels(
                condition: condition,
                concernTags: concernTags,
              ))
          .map((id, level) => MapEntry(id, level.name)),
      'memo': memo.trim(),
      'schemaVersion': 2,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!snap.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await doc.set(data, SetOptions(merge: true));
  }
}

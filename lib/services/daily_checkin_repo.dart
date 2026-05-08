import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

typedef Json = Map<String, dynamic>;

enum DailyCondition {
  normal,
  slightlyConcerned,
  veryConcerned,
}

class DailyCheckin {
  final String dayKey;
  final DateTime date;
  final DailyCondition condition;
  final List<String> concernTags;
  final String memo;

  const DailyCheckin({
    required this.dayKey,
    required this.date,
    required this.condition,
    required this.concernTags,
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

    final dateRaw = json['date'];
    final date =
        dateRaw is Timestamp ? dateRaw.toDate().toLocal() : DateTime.now();

    return DailyCheckin(
      dayKey: json['dayKey'] as String? ?? fallbackDayKey,
      date: date,
      condition: condition,
      concernTags: tags,
      memo: json['memo'] as String? ?? '',
    );
  }
}

class DailyCheckinRepo {
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

  String dateKeyLocal(DateTime dayLocal) {
    final local = dayLocal.toLocal();
    final d = DateTime(local.year, local.month, local.day);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  DateTime normalizeLocalDay(DateTime dt) {
    final local = dt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  DocumentReference<Json>? _docByLocalDate(DateTime dayLocal) {
    final col = _col();
    if (col == null) return null;
    return col.doc(dateKeyLocal(dayLocal));
  }

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

  Future<void> saveDailyCheckin({
    required DateTime date,
    required DailyCondition condition,
    required List<String> concernTags,
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
      'memo': memo.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!snap.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await doc.set(data, SetOptions(merge: true));
  }
}

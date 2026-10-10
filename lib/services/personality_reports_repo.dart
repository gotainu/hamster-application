import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/personality_report.dart';

abstract interface class PersonalityReportsSource {
  Stream<PersonalityReportState> watchLatest();
}

/// Optional extension used by immutable history detail screens. Existing latest
/// sources and their test fakes remain source-compatible.
abstract interface class PersonalitySpecificReportSource
    implements PersonalityReportsSource {
  Stream<PersonalityReportState> watchReport(String reportId);
}

abstract interface class PersonalityUnreadReportsSource {
  Stream<PersonalityReportState> watchUnreadLatest();
}

abstract interface class PersonalityReportsHistorySource
    implements PersonalitySpecificReportSource {
  Stream<String?> watchOwnerUid();
  Future<PersonalityHistoryPage> fetchHistory({
    PersonalityHistoryCursor? after,
    int pageSize = 20,
  });
}

bool _isViewed(Map<String, dynamic>? data, String reportId) {
  if (data == null) return false;
  if (data.length != 2 ||
      data['reportId'] != reportId ||
      data['viewedAt'] is! Timestamp) {
    throw const FormatException('Invalid report view marker');
  }
  return true;
}

/// Owner-only reads of the pointer and its immutable report. Subscription/trial
/// state is deliberately not read: generated reports remain available afterward.
class PersonalityReportsRepo
    implements PersonalityReportsHistorySource, PersonalityUnreadReportsSource {
  PersonalityReportsRepo({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  @override
  Stream<PersonalityReportState> watchLatest() => _watch();

  @override
  Stream<PersonalityReportState> watchReport(String reportId) {
    if (!isPersonalityReportId(reportId)) {
      return Stream.value(
          PersonalityReportState.unavailable(_auth.currentUser?.uid));
    }
    return _watch(fixedReportId: reportId);
  }

  @override
  Stream<String?> watchOwnerUid() => _owners().distinct();

  Stream<String?> _owners() async* {
    yield _auth.currentUser?.uid;
    yield* _auth.authStateChanges().map((user) => user?.uid);
  }

  @override
  Future<PersonalityHistoryPage> fetchHistory({
    PersonalityHistoryCursor? after,
    int pageSize = 20,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || (after != null && after.ownerUid != uid)) {
      throw StateError('Account changed');
    }
    final size = pageSize.clamp(1, 50);
    final user = _db.collection('users').doc(uid);
    Query<Map<String, dynamic>> query = user
        .collection('personality_reports')
        .orderBy('generatedAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
    if (after != null) {
      query = query.startAfter([after.generatedAt, after.reportId]);
    }
    final snapshot = await query
        .limit(size + 1)
        .get(const GetOptions(source: Source.server));
    if (_auth.currentUser?.uid != uid ||
        snapshot.metadata.isFromCache ||
        snapshot.metadata.hasPendingWrites) {
      throw StateError('History is not server confirmed');
    }
    final docs = snapshot.docs.take(size).toList();
    final entries = await Future.wait(docs.map((doc) async {
      final report =
          PersonalityReport.fromMap(doc.data(), expectedReportId: doc.id);
      final view = await user
          .collection('report_view_states')
          .doc(doc.id)
          .get(const GetOptions(source: Source.server));
      if (view.metadata.isFromCache || view.metadata.hasPendingWrites) {
        throw StateError('View state is not server confirmed');
      }
      return PersonalityHistoryEntry(report,
          isViewed: _isViewed(view.data(), doc.id));
    }));
    if (_auth.currentUser?.uid != uid) throw StateError('Account changed');
    PersonalityHistoryCursor? cursor;
    if (snapshot.docs.length > size && docs.isNotEmpty) {
      final last = docs.last;
      final rawTime = last.data()['generatedAt'];
      final time = rawTime is Timestamp
          ? rawTime
          : Timestamp.fromDate(entries.last.report.generatedAt);
      cursor = PersonalityHistoryCursor(uid, time, last.id);
    }
    return PersonalityHistoryPage(uid, List.unmodifiable(entries),
        nextCursor: cursor);
  }

  /// The latest report is visible on Home only once all three reads (pointer,
  /// immutable report, and that report's own marker) are server confirmed.
  @override
  Stream<PersonalityReportState> watchUnreadLatest() {
    late StreamController<PersonalityReportState> controller;
    StreamSubscription<PersonalityReportState>? latestSubscription;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
        markerSubscription;
    PersonalityReportState? latest;
    String? key;
    bool? viewed;
    var version = 0;
    var cancelled = false;
    void add(PersonalityReportState state) {
      if (!cancelled) controller.add(state);
    }

    void clear() {
      version++;
      key = null;
      latest = null;
      viewed = null;
      unawaited(markerSubscription?.cancel());
      markerSubscription = null;
    }

    void emitConfirmed() {
      final value = latest;
      if (value == null || viewed == null) return;
      add(viewed! ? PersonalityReportState.learning(value.ownerUid) : value);
    }

    controller = StreamController<PersonalityReportState>(onListen: () {
      latestSubscription = watchLatest().listen((state) {
        if (cancelled) return;
        if (state.phase != PersonalityReportPhase.available ||
            state.report == null ||
            state.ownerUid == null) {
          clear();
          add(state);
          return;
        }
        final id = state.report!.reportId;
        final uid = state.ownerUid!;
        final nextKey = '$uid:$id';
        if (key == nextKey) {
          latest = state;
          emitConfirmed();
          return;
        }
        clear();
        latest = state;
        key = nextKey;
        final current = version;
        add(PersonalityReportState.loading(uid));
        markerSubscription = _db
            .collection('users')
            .doc(uid)
            .collection('report_view_states')
            .doc(id)
            .snapshots(includeMetadataChanges: true)
            .listen((snapshot) {
          if (cancelled ||
              version != current ||
              _auth.currentUser?.uid != uid) {
            return;
          }
          if (snapshot.metadata.isFromCache ||
              snapshot.metadata.hasPendingWrites) {
            viewed = null;
            add(PersonalityReportState.loading(uid));
            return;
          }
          try {
            viewed = _isViewed(snapshot.data(), id);
            emitConfirmed();
          } on FormatException {
            viewed = null;
            add(PersonalityReportState.unavailable(uid));
          }
        }, onError: (Object error, StackTrace stack) {
          if (!cancelled && version == current) {
            viewed = null;
            add(PersonalityReportState.unavailable(uid));
          }
        });
      }, onError: (Object error, StackTrace stack) {
        final uid = latest?.ownerUid;
        clear();
        add(PersonalityReportState.unavailable(uid));
      });
    }, onCancel: () async {
      cancelled = true;
      version++;
      await Future.wait([
        if (latestSubscription != null) latestSubscription!.cancel(),
        if (markerSubscription != null) markerSubscription!.cancel(),
      ]);
    });
    return controller.stream;
  }

  Stream<PersonalityReportState> _watch({String? fixedReportId}) {
    late StreamController<PersonalityReportState> controller;
    StreamSubscription<User?>? authSubscription;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
        pointerSubscription;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
        legacyPointerSubscription;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
        reportSubscription;
    String? ownerUid;
    String? selectedReportId;
    var hasOwner = false;
    var ownerVersion = 0;
    var legacyVersion = 0;
    var reportVersion = 0;
    var cancelled = false;

    void add(PersonalityReportState state) {
      if (!cancelled) controller.add(state);
    }

    bool current(int owner, int report) =>
        !cancelled &&
        owner == ownerVersion &&
        report == reportVersion &&
        _auth.currentUser?.uid == ownerUid;

    void clearLegacyPointer() {
      legacyVersion++;
      unawaited(legacyPointerSubscription?.cancel());
      legacyPointerSubscription = null;
    }

    void clearReport() {
      reportVersion++;
      selectedReportId = null;
      unawaited(reportSubscription?.cancel());
      reportSubscription = null;
    }

    void bindReport(String uid, DocumentReference<Map<String, dynamic>> user,
        String id, int owner) {
      if (selectedReportId == id) return;
      clearReport();
      selectedReportId = id;
      final report = reportVersion;
      add(PersonalityReportState.loading(uid));
      reportSubscription = user
          .collection('personality_reports')
          .doc(id)
          .snapshots(includeMetadataChanges: true)
          .listen((snapshot) {
        if (!current(owner, report)) return;
        if (snapshot.metadata.isFromCache ||
            snapshot.metadata.hasPendingWrites) {
          add(PersonalityReportState.loading(uid));
          return;
        }
        try {
          final value = snapshot.data();
          if (value == null) {
            throw const FormatException('Referenced report is absent');
          }
          add(PersonalityReportState.available(
              uid, PersonalityReport.fromMap(value, expectedReportId: id)));
        } on FormatException {
          add(PersonalityReportState.unavailable(uid));
        }
      }, onError: (Object error, StackTrace stack) {
        if (current(owner, report)) {
          add(PersonalityReportState.unavailable(uid));
        }
      });
    }

    // Only server-confirmed daily absence enables the original v1 reader path.
    // The extra generation prevents late fallback events from replacing daily.
    void bindLegacyPointer(
        String uid, DocumentReference<Map<String, dynamic>> user, int owner) {
      if (legacyPointerSubscription != null) return;
      final legacy = ++legacyVersion;
      clearReport();
      add(PersonalityReportState.loading(uid));
      bool active() =>
          !cancelled &&
          owner == ownerVersion &&
          legacy == legacyVersion &&
          _auth.currentUser?.uid == uid;
      legacyPointerSubscription = user
          .collection('report_pointers')
          .doc('personality')
          .snapshots(includeMetadataChanges: true)
          .listen((pointer) {
        if (!active()) return;
        if (pointer.metadata.isFromCache || pointer.metadata.hasPendingWrites) {
          clearReport();
          add(PersonalityReportState.loading(uid));
          return;
        }
        final data = pointer.data();
        if (data == null) {
          clearReport();
          add(PersonalityReportState.learning(uid));
          return;
        }
        final id = data['reportId'];
        if (id is! String ||
            !RegExp(r'^personality_v1_(body|activity|body_activity)$')
                .hasMatch(id) ||
            data['petId'] != 'main_pet') {
          clearReport();
          add(PersonalityReportState.unavailable(uid));
          return;
        }
        bindReport(uid, user, id, owner);
      }, onError: (Object error, StackTrace stack) {
        if (!active()) return;
        clearReport();
        add(PersonalityReportState.unavailable(uid));
      });
    }

    void bindOwner(String? uid) {
      if (hasOwner && ownerUid == uid) return;
      hasOwner = true;
      ownerUid = uid;
      ownerVersion++;
      final owner = ownerVersion;
      unawaited(pointerSubscription?.cancel());
      pointerSubscription = null;
      clearLegacyPointer();
      clearReport();
      add(PersonalityReportState.loading(uid));
      if (uid == null) {
        add(const PersonalityReportState.unavailable(null));
        return;
      }
      final user = _db.collection('users').doc(uid);
      if (fixedReportId != null) {
        bindReport(uid, user, fixedReportId, owner);
        return;
      }
      pointerSubscription = user
          .collection('report_pointers')
          .doc('personality_daily')
          .snapshots(includeMetadataChanges: true)
          .listen((pointer) {
        if (cancelled ||
            owner != ownerVersion ||
            _auth.currentUser?.uid != uid) {
          return;
        }
        if (pointer.metadata.isFromCache || pointer.metadata.hasPendingWrites) {
          clearLegacyPointer();
          clearReport();
          add(PersonalityReportState.loading(uid));
          return;
        }
        final data = pointer.data();
        if (data == null) {
          bindLegacyPointer(uid, user, owner);
          return;
        }
        clearLegacyPointer();
        final id = data['reportId'];
        if (id is! String ||
            !id.startsWith('daily_') ||
            !isPersonalityReportId(id) ||
            data['petId'] != 'main_pet') {
          clearReport();
          add(PersonalityReportState.unavailable(uid));
          return;
        }
        bindReport(uid, user, id, owner);
      }, onError: (Object error, StackTrace stack) {
        if (cancelled ||
            owner != ownerVersion ||
            _auth.currentUser?.uid != uid) {
          return;
        }
        clearLegacyPointer();
        clearReport();
        add(PersonalityReportState.unavailable(uid));
      });
    }

    controller = StreamController<PersonalityReportState>(
      onListen: () {
        authSubscription = _auth
            .authStateChanges()
            .listen((user) => bindOwner(user?.uid),
                onError: (Object error, StackTrace stack) {
          ownerVersion++;
          clearLegacyPointer();
          clearReport();
          unawaited(pointerSubscription?.cancel());
          add(PersonalityReportState.unavailable(ownerUid));
        });
        bindOwner(_auth.currentUser?.uid);
      },
      onCancel: () async {
        cancelled = true;
        ownerVersion++;
        legacyVersion++;
        reportVersion++;
        await Future.wait([
          if (authSubscription != null) authSubscription!.cancel(),
          if (pointerSubscription != null) pointerSubscription!.cancel(),
          if (legacyPointerSubscription != null)
            legacyPointerSubscription!.cancel(),
          if (reportSubscription != null) reportSubscription!.cancel(),
        ]);
      },
    );
    return controller.stream;
  }
}

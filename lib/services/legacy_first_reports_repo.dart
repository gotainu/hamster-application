import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum LegacyFirstReportPhase { loading, missing, available, unavailable }

class LegacyFirstReportState {
  final String? ownerUid;
  final LegacyFirstReportPhase phase;
  final Map<String, dynamic>? report;
  const LegacyFirstReportState.loading(this.ownerUid)
      : phase = LegacyFirstReportPhase.loading,
        report = null;
  const LegacyFirstReportState.missing(this.ownerUid)
      : phase = LegacyFirstReportPhase.missing,
        report = null;
  const LegacyFirstReportState.unavailable(this.ownerUid)
      : phase = LegacyFirstReportPhase.unavailable,
        report = null;
  const LegacyFirstReportState.available(this.ownerUid, this.report)
      : phase = LegacyFirstReportPhase.available;
}

abstract interface class LegacyFirstReportSource {
  String? get currentUid;
  Stream<LegacyFirstReportState> watchFirstReport();
}

/// A small owner-bound reader for the existing frozen first document. Cache
/// absence is not treated as a server-confirmed missing report.
class LegacyFirstReportsRepo implements LegacyFirstReportSource {
  LegacyFirstReportsRepo({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  @override
  String? get currentUid => _auth.currentUser?.uid;
  @override
  Stream<LegacyFirstReportState> watchFirstReport() {
    late StreamController<LegacyFirstReportState> controller;
    StreamSubscription<User?>? authSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? reportSub;
    String? owner;
    var bound = false;
    var version = 0;
    var cancelled = false;
    void add(LegacyFirstReportState state) {
      if (!cancelled) controller.add(state);
    }

    void bind(String? uid) {
      if (cancelled || (bound && owner == uid)) return;
      bound = true;
      owner = uid;
      final generation = ++version;
      unawaited(reportSub?.cancel());
      reportSub = null;
      add(LegacyFirstReportState.loading(uid));
      if (uid == null) {
        add(const LegacyFirstReportState.unavailable(null));
        return;
      }
      reportSub = _db
          .collection('users')
          .doc(uid)
          .collection('personalized_reports')
          .doc('first')
          .snapshots(includeMetadataChanges: true)
          .listen((snapshot) {
        if (cancelled || generation != version || currentUid != uid) return;
        if (snapshot.metadata.isFromCache ||
            snapshot.metadata.hasPendingWrites) {
          add(LegacyFirstReportState.loading(uid));
          return;
        }
        final data = snapshot.data();
        add(data == null
            ? LegacyFirstReportState.missing(uid)
            : LegacyFirstReportState.available(uid, data));
      }, onError: (Object error, StackTrace stack) {
        if (!cancelled && generation == version) {
          add(LegacyFirstReportState.unavailable(uid));
        }
      });
    }

    controller = StreamController<LegacyFirstReportState>(onListen: () {
      authSub = _auth.authStateChanges().listen((user) => bind(user?.uid),
          onError: (Object error, StackTrace stack) {
        version++;
        unawaited(reportSub?.cancel());
        add(LegacyFirstReportState.unavailable(owner));
      });
      bind(currentUid);
    }, onCancel: () async {
      cancelled = true;
      version++;
      await Future.wait([
        if (authSub != null) authSub!.cancel(),
        if (reportSub != null) reportSub!.cancel()
      ]);
    });
    return controller.stream;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/personality_report.dart';
import 'app_analytics.dart';

/// A3 retains the earliest actual view of either report kind.
Map<String, dynamic> personalityFirstViewPatch(Map<String, dynamic> current,
        {bool personality = true}) =>
    {
      if (current['firstPersonalizedAnalysisViewedAt'] == null)
        'firstPersonalizedAnalysisViewedAt': FieldValue.serverTimestamp(),
      if (personality && current['firstPersonalityReportViewedAt'] == null)
        'firstPersonalityReportViewedAt': FieldValue.serverTimestamp(),
    };

class PersonalityReportViewService {
  final String? Function() currentUid;
  final Future<bool> Function(String uid) markFirstView;
  final Future<void> Function(Map<String, Object>) logView;
  final Future<void> Function(String uid, String reportId)? markReportViewed;
  final Future<bool> Function(String uid)? markLegacyFirstView;

  const PersonalityReportViewService({
    required this.currentUid,
    required this.markFirstView,
    required this.logView,
    this.markReportViewed,
    this.markLegacyFirstView,
  });

  factory PersonalityReportViewService.production() {
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    Future<bool> markFirst(String uid, {bool personality = true}) =>
        db.runTransaction((transaction) async {
          final doc = db
              .collection('users')
              .doc(uid)
              .collection('app_state')
              .doc('onboarding');
          final snapshot = await transaction.get(doc);
          if (auth.currentUser?.uid != uid) throw StateError('Account changed');
          final data = snapshot.data() ?? <String, dynamic>{};
          final patch =
              personalityFirstViewPatch(data, personality: personality);
          if (patch.isNotEmpty) {
            transaction.set(doc, patch, SetOptions(merge: true));
          }
          return data['firstPersonalizedAnalysisViewedAt'] == null;
        });
    return PersonalityReportViewService(
      currentUid: () => auth.currentUser?.uid,
      markReportViewed: (uid, id) => db.runTransaction((transaction) async {
        if (!isPersonalityReportId(id)) {
          throw const FormatException('Invalid report ID');
        }
        final user = db.collection('users').doc(uid);
        final reportRef = user.collection('personality_reports').doc(id);
        final markerRef = user.collection('report_view_states').doc(id);
        final report = await transaction.get(reportRef);
        final marker = await transaction.get(markerRef);
        if (auth.currentUser?.uid != uid) throw StateError('Account changed');
        final reportData = report.data();
        if (reportData == null) throw StateError('Report absent');
        PersonalityReport.fromMap(reportData, expectedReportId: id);
        final existing = marker.data();
        if (existing != null) {
          if (existing.length != 2 ||
              existing['reportId'] != id ||
              existing['viewedAt'] is! Timestamp) {
            throw const FormatException('Invalid view state');
          }
          return;
        }
        // Create-only, transactional markers cannot replace another report's view.
        transaction.set(markerRef, {
          'reportId': id,
          'viewedAt': FieldValue.serverTimestamp(),
        });
      }),
      markFirstView: (uid) => markFirst(uid),
      markLegacyFirstView: (uid) => markFirst(uid, personality: false),
      logView: (metadata) => AppAnalytics.logPersonalityReportViewed(
        expectedUserId: auth.currentUser?.uid,
        reportId: metadata['report_id']! as String,
        petId: metadata['pet_id']! as String,
        revision: metadata['analysis_revision']! as int,
        presentationId: metadata['presentation_id']! as String,
        isFirstView: metadata['is_first_view'] == 1,
      ),
    );
  }

  /// Only called after successful drawing. Measurement failure never blocks reading.
  Future<bool> recordView({
    required String ownerUid,
    required String reportId,
    required String petId,
    required int schemaVersion,
    required String presentationId,
  }) async {
    if (currentUid() != ownerUid) return false;
    var marked = false;
    try {
      await markReportViewed?.call(ownerUid, reportId);
      if (currentUid() != ownerUid) return false;
      marked = true;
      final first = await markFirstView(ownerUid);
      if (currentUid() != ownerUid) return false;
      await logView({
        'report_id': reportId,
        'pet_id': petId,
        'analysis_revision': schemaVersion,
        'presentation_id': presentationId,
        'auto_presented': 0,
        'report_kind': 'personality',
        'is_first_view': first ? 1 : 0,
      });
    } catch (_) {
      // Failed persistence is never converted into a false first-view event.
    }
    return marked && currentUid() == ownerUid;
  }

  /// The legacy screen retains its Analytics event; this saves only earliest A3.
  Future<void> recordLegacyView({required String ownerUid}) async {
    if (currentUid() != ownerUid) return;
    try {
      await markLegacyFirstView?.call(ownerUid);
    } catch (_) {}
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_analytics.dart';

typedef Json = Map<String, dynamic>;

class OnboardingState {
  final bool introCompleted;
  final bool setupChecklistViewed;
  final bool firstAiConsultationCompleted;
  final int setupCoachMarkStep;
  final bool homeAiOnboardingPending;
  final bool monitoringIntroCtaPending;
  final Set<String> completedSetupSteps;
  final DateTime? firstMonitoringDataRecordedAt;
  final String? firstMonitoringDataSource;
  final DateTime? monitoringIntroductionViewedAt;
  final String? monitoringMethod;
  final DateTime? monitoringMethodSelectedAt;
  final DateTime? personalizedAnalysisAvailableAt;
  final DateTime? firstPersonalizedAnalysisViewedAt;
  final DateTime? updatedAt;

  const OnboardingState({
    required this.introCompleted,
    required this.setupChecklistViewed,
    required this.firstAiConsultationCompleted,
    required this.setupCoachMarkStep,
    required this.homeAiOnboardingPending,
    this.monitoringIntroCtaPending = false,
    required this.completedSetupSteps,
    this.firstMonitoringDataRecordedAt,
    this.firstMonitoringDataSource,
    this.monitoringIntroductionViewedAt,
    this.monitoringMethod,
    this.monitoringMethodSelectedAt,
    this.personalizedAnalysisAvailableAt,
    this.firstPersonalizedAnalysisViewedAt,
    this.updatedAt,
  });

  bool get shouldShowIntro => !introCompleted;
  // 旧テスト・保存形式との後方互換用。新しい導線は step を使います。
  bool get setupCoachMarkSeen => setupCoachMarkStep > 0;
  bool get hasStartedMonitoring => firstMonitoringDataRecordedAt != null;

  /// 最初の実データ保存後から7日間、見守り開始に必要な機能を使えます。
  bool hasActiveOnboardingEntitlement([DateTime? now]) {
    final startedAt = firstMonitoringDataRecordedAt;
    if (startedAt == null) return true;
    return (now ?? DateTime.now()).difference(startedAt) <
        const Duration(days: 7);
  }

  factory OnboardingState.initial() {
    return const OnboardingState(
      introCompleted: false,
      setupChecklistViewed: false,
      firstAiConsultationCompleted: false,
      setupCoachMarkStep: 0,
      homeAiOnboardingPending: false,
      completedSetupSteps: <String>{},
    );
  }

  factory OnboardingState.fromJson(Json json) {
    DateTime? date(String key) {
      final value = json[key];
      return value is Timestamp ? value.toDate().toLocal() : null;
    }

    return OnboardingState(
      introCompleted: json['introCompleted'] == true,
      setupChecklistViewed: json['setupChecklistViewed'] == true,
      firstAiConsultationCompleted:
          json['firstAiConsultationCompleted'] == true,
      // 旧版で最初の案内を閉じた利用者は、次の案内から再開します。
      setupCoachMarkStep: (json['setupCoachMarkStep'] as num?)?.toInt() ??
          (json['setupCoachMarkSeen'] == true ? 1 : 0),
      homeAiOnboardingPending: json['homeAiOnboardingPending'] == true,
      monitoringIntroCtaPending: json['monitoringIntroCtaPending'] == true,
      completedSetupSteps:
          ((json['completedSetupSteps'] as List<dynamic>?) ?? const [])
              .whereType<String>()
              .toSet(),
      firstMonitoringDataRecordedAt: date('firstMonitoringDataRecordedAt'),
      firstMonitoringDataSource: json['firstMonitoringDataSource'] as String?,
      monitoringIntroductionViewedAt: date('monitoringIntroductionViewedAt'),
      monitoringMethod: json['monitoringMethod'] as String?,
      monitoringMethodSelectedAt: date('monitoringMethodSelectedAt'),
      personalizedAnalysisAvailableAt: date('personalizedAnalysisAvailableAt'),
      firstPersonalizedAnalysisViewedAt:
          date('firstPersonalizedAnalysisViewedAt'),
      updatedAt: date('updatedAt'),
    );
  }
}

class OnboardingStateRepo {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  OnboardingStateRepo({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Json>? _doc() {
    final uid = _uid;
    if (uid == null) return null;

    return _db
        .collection('users')
        .doc(uid)
        .collection('app_state')
        .doc('onboarding');
  }

  Future<OnboardingState> fetchState() async {
    final doc = _doc();
    if (doc == null) return OnboardingState.initial();

    final snap = await doc.get();
    if (!snap.exists) return OnboardingState.initial();

    final data = snap.data();
    if (data == null) return OnboardingState.initial();

    return OnboardingState.fromJson(data);
  }

  Stream<OnboardingState> watchState() {
    final doc = _doc();
    if (doc == null) {
      return Stream.value(OnboardingState.initial());
    }

    return doc.snapshots().map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) {
        return OnboardingState.initial();
      }

      return OnboardingState.fromJson(data);
    });
  }

  Future<void> markIntroCompleted() async {
    final doc = _doc();
    if (doc == null) return;

    await doc.set({
      'introCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markSetupChecklistViewed() async {
    final doc = _doc();
    if (doc == null) return;

    await doc.set({
      'setupChecklistViewed': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// AI成功だけを記録します。モニタリングへの移動はユーザー操作で行います。
  Future<void> markFirstAiConsultationCompleted() async {
    final doc = _doc();
    if (doc == null) return;

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(doc);
      final data = snapshot.data() ?? <String, dynamic>{};
      if (data['firstAiConsultationCompleted'] == true) return;
      final wasHomeAiOnboardingPending =
          data['homeAiOnboardingPending'] == true;
      transaction.set(
        doc,
        {
          'firstAiConsultationCompleted': true,
          'homeAiOnboardingPending': false,
          'monitoringIntroCtaPending':
              data['monitoringIntroCtaPending'] == true ||
                  wasHomeAiOnboardingPending,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  /// 既存のプロフィール保存処理から呼ぶ互換エントリポイントです。
  Future<void> markProfileCompleted(String profile) =>
      markSetupStepCompleted(profile);

  Future<void> markMonitoringIntroductionViewed() => _mark({
        'monitoringIntroductionViewedAt': FieldValue.serverTimestamp(),
        'monitoringIntroCtaPending': false,
      });

  Future<void> selectMonitoringMethod(String method) => _mark({
        'monitoringMethod': method,
        'monitoringMethodSelectedAt': FieldValue.serverTimestamp(),
      });

  Future<void> recordFirstMonitoringData(String source) async {
    final doc = _doc();
    if (doc == null) return;

    final current = await doc.get();
    if (current.data()?['firstMonitoringDataRecordedAt'] != null) return;

    await _mark({
      'firstMonitoringDataRecordedAt': FieldValue.serverTimestamp(),
      'firstMonitoringDataSource': source,
    });
    await AppAnalytics.logOnboardingEvent(
      'first_monitoring_data_recorded',
      method: source,
    );
  }

  Future<void> markPersonalizedAnalysisAvailable() => _mark({
        'personalizedAnalysisAvailableAt': FieldValue.serverTimestamp(),
      });

  Future<void> markFirstPersonalizedAnalysisViewed() => _mark({
        'firstPersonalizedAnalysisViewedAt': FieldValue.serverTimestamp(),
      });

  Future<void> markSetupCoachMarkStepSeen(int step) async {
    final doc = _doc();
    if (doc == null) return;

    await doc.set({
      'setupCoachMarkStep': step,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 登録フォームの保存成功を、初回導線の完了条件として記録します。
  Future<void> markSetupStepCompleted(String step) async {
    const allowed = {'pet', 'environment', 'owner'};
    if (!allowed.contains(step)) return;
    final doc = _doc();
    if (doc == null) return;
    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(doc);
      final data = snap.data() ?? <String, dynamic>{};
      final completed = ((data['completedSetupSteps'] as List<dynamic>?) ??
              const [])
          .whereType<String>()
          .toSet()
        ..add(step);
      transaction.set(
          doc,
          {
            'completedSetupSteps': completed.toList()..sort(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });
  }

  /// 準備完了後だけ、Home でAIの最初の一問を案内します。
  Future<void> markJourneyCompleted(
      {required bool startHomeAiOnboarding}) async {
    final doc = _doc();
    if (doc == null) return;

    await doc.set({
      'introCompleted': true,
      'setupChecklistViewed': true,
      'homeAiOnboardingPending': startHomeAiOnboarding,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _mark(Json values) async {
    final doc = _doc();
    if (doc == null) return;
    await doc.set({
      ...values,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> resetForDebug() async {
    final doc = _doc();
    if (doc == null) return;

    await doc.set({
      'introCompleted': false,
      'setupChecklistViewed': false,
      'firstAiConsultationCompleted': false,
      'monitoringIntroCtaPending': false,
      'setupCoachMarkStep': 0,
      'homeAiOnboardingPending': false,
      'completedSetupSteps': <String>[],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

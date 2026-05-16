import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

typedef Json = Map<String, dynamic>;

class OnboardingState {
  final bool introCompleted;
  final bool setupChecklistViewed;
  final DateTime? updatedAt;

  const OnboardingState({
    required this.introCompleted,
    required this.setupChecklistViewed,
    this.updatedAt,
  });

  bool get shouldShowIntro => !introCompleted;

  factory OnboardingState.initial() {
    return const OnboardingState(
      introCompleted: false,
      setupChecklistViewed: false,
    );
  }

  factory OnboardingState.fromJson(Json json) {
    final updatedAtRaw = json['updatedAt'];

    return OnboardingState(
      introCompleted: json['introCompleted'] == true,
      setupChecklistViewed: json['setupChecklistViewed'] == true,
      updatedAt:
          updatedAtRaw is Timestamp ? updatedAtRaw.toDate().toLocal() : null,
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

  Future<void> resetForDebug() async {
    final doc = _doc();
    if (doc == null) return;

    await doc.set({
      'introCompleted': false,
      'setupChecklistViewed': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

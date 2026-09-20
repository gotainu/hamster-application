import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/star_rewards_progress.dart';

class StarRewardsRepo {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final bool _backendEnabled;

  StarRewardsRepo({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    bool backendEnabled =
        const bool.fromEnvironment(
          'STAR_REWARDS_BACKEND_ENABLED',
          defaultValue: true,
        ),
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-northeast1'),
        _backendEnabled = backendEnabled;

  String? get _uid => _auth.currentUser?.uid;

  Stream<StarRewardsProgress?> watchProgress() {
    if (!_backendEnabled) return Stream.value(null);
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return _db.doc('users/$uid/rewards/stars').snapshots().map((snapshot) {
      final data = snapshot.data();
      return data == null ? null : StarRewardsProgress.fromJson(data);
    });
  }

  Stream<bool> watchFiftyStarMilestone() {
    if (!_backendEnabled) return Stream.value(false);
    final uid = _uid;
    if (uid == null) return Stream.value(false);
    return _db
        .doc('users/$uid/star_milestones/50')
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  Stream<bool> watchUnseenFiftyStarMilestone() {
    if (!_backendEnabled) return Stream.value(false);
    final uid = _uid;
    if (uid == null) return Stream.value(false);
    return _db.doc('users/$uid/star_milestones/50').snapshots().map(
        (snapshot) => snapshot.exists && snapshot.data()?['seenAt'] == null);
  }

  Future<void> acknowledgeFiftyStarMilestone() async {
    if (!_backendEnabled) return;
    if (_uid == null) return;
    await _functions.httpsCallable('acknowledgeFiftyStarMilestone').call();
  }

  Future<void> claimDailyOpenStar() async {
    if (!_backendEnabled) return;
    if (_uid == null) return;
    await _functions.httpsCallable('claimDailyOpenStar').call();
  }
}

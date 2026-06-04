import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationSettings {
  const NotificationSettings({
    required this.anomalyNotificationsEnabled,
  });

  final bool anomalyNotificationsEnabled;

  factory NotificationSettings.fromMap(Map<String, dynamic>? data) {
    return NotificationSettings(
      anomalyNotificationsEnabled:
          data?['anomalyNotificationsEnabled'] as bool? ?? true,
    );
  }
}

class NotificationSettingsService {
  NotificationSettingsService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>>? get _ref {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('notifications');
  }

  Stream<NotificationSettings> watchSettings() {
    final ref = _ref;
    if (ref == null) {
      return Stream.value(
        const NotificationSettings(
          anomalyNotificationsEnabled: true,
        ),
      );
    }

    return ref.snapshots().map(
          (snap) => NotificationSettings.fromMap(snap.data()),
        );
  }

  Future<void> setAnomalyNotificationsEnabled(bool enabled) async {
    final ref = _ref;
    if (ref == null) {
      throw StateError('ログインユーザーが見つかりません。');
    }

    await ref.set(
      {
        'anomalyNotificationsEnabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}

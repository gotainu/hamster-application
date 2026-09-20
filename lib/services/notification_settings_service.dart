import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum CautionNotificationFrequency {
  stateChangesOnly,
  everyThreeDays,
  off,
}

extension CautionNotificationFrequencyValue on CautionNotificationFrequency {
  String get firestoreValue {
    switch (this) {
      case CautionNotificationFrequency.stateChangesOnly:
        return 'state_changes_only';
      case CautionNotificationFrequency.everyThreeDays:
        return 'every_three_days';
      case CautionNotificationFrequency.off:
        return 'off';
    }
  }

  String get label {
    switch (this) {
      case CautionNotificationFrequency.stateChangesOnly:
        return '状態が変わったときだけ';
      case CautionNotificationFrequency.everyThreeDays:
        return '継続中は3日ごと';
      case CautionNotificationFrequency.off:
        return '注意通知は受け取らない';
    }
  }
}

class NotificationSettings {
  const NotificationSettings({
    required this.anomalyNotificationsEnabled,
    required this.criticalAlertsEnabled,
    required this.cautionNotificationFrequency,
    required this.quietHoursEnabled,
    required this.resolvedNotificationsEnabled,
    required this.notificationCategories,
  });

  final bool anomalyNotificationsEnabled;
  final bool criticalAlertsEnabled;
  final CautionNotificationFrequency cautionNotificationFrequency;
  final bool quietHoursEnabled;
  final bool resolvedNotificationsEnabled;
  final Map<String, bool> notificationCategories;

  static const defaultNotificationCategories = <String, bool>{
    'environment': true,
    'activity': true,
    'body': true,
    'condition': true,
    'nutrition': true,
  };

  static const defaults = NotificationSettings(
    anomalyNotificationsEnabled: true,
    criticalAlertsEnabled: true,
    cautionNotificationFrequency: CautionNotificationFrequency.stateChangesOnly,
    quietHoursEnabled: true,
    resolvedNotificationsEnabled: true,
    notificationCategories: defaultNotificationCategories,
  );

  factory NotificationSettings.fromMap(Map<String, dynamic>? data) {
    final frequencyValue = data?['cautionNotificationFrequency'] as String?;
    final frequency = CautionNotificationFrequency.values.firstWhere(
      (value) => value.firestoreValue == frequencyValue,
      orElse: () => CautionNotificationFrequency.stateChangesOnly,
    );
    final rawCategories = data?['notificationCategories'];
    final categories = <String, bool>{
      for (final entry in defaultNotificationCategories.entries)
        entry.key: rawCategories is Map && rawCategories[entry.key] is bool
            ? rawCategories[entry.key] as bool
            : entry.value,
    };

    return NotificationSettings(
      anomalyNotificationsEnabled:
          data?['goldHealthNotificationsEnabled'] as bool? ??
              data?['anomalyNotificationsEnabled'] as bool? ??
              true,
      criticalAlertsEnabled: data?['criticalAlertsEnabled'] as bool? ?? true,
      cautionNotificationFrequency: frequency,
      quietHoursEnabled: data?['quietHoursEnabled'] as bool? ?? true,
      resolvedNotificationsEnabled:
          data?['resolvedNotificationsEnabled'] as bool? ?? true,
      notificationCategories: Map.unmodifiable(categories),
    );
  }

  bool isCategoryEnabled(String category) =>
      notificationCategories[category] ?? true;
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
      return Stream.value(NotificationSettings.defaults);
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
        'goldHealthNotificationsEnabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> setCriticalAlertsEnabled(bool enabled) {
    return _update({'criticalAlertsEnabled': enabled});
  }

  Future<void> setCautionNotificationFrequency(
    CautionNotificationFrequency frequency,
  ) {
    return _update({
      'cautionNotificationFrequency': frequency.firestoreValue,
    });
  }

  Future<void> setQuietHoursEnabled(bool enabled) {
    return _update({
      'quietHoursEnabled': enabled,
      'quietHoursStart': 21,
      'quietHoursEnd': 8,
      'timeZone': 'Asia/Tokyo',
    });
  }

  Future<void> setResolvedNotificationsEnabled(bool enabled) {
    return _update({'resolvedNotificationsEnabled': enabled});
  }

  Future<void> setNotificationCategories(Map<String, bool> categories) {
    return _update({'notificationCategories': categories});
  }

  Future<void> _update(Map<String, Object> values) async {
    final ref = _ref;
    if (ref == null) {
      throw StateError('ログインユーザーが見つかりません。');
    }

    await ref.set(
      {
        ...values,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}

const String healthCareNotificationChannelId = 'health_care_v2';
const String healthCriticalNotificationChannelId = 'health_critical_v2';

const Set<String> _healthNotificationTypes = {
  'anomaly',
  'gold_health_alert',
  'health_incident',
};

bool isHealthNotificationPayload(Map<String, dynamic> data) {
  return _healthNotificationTypes.contains(data['type']?.toString());
}

String notificationTypeForAnalytics(Map<String, dynamic> data) {
  final type = data['type']?.toString();
  return _healthNotificationTypes.contains(type) ? type! : 'other';
}

String? healthIncidentIdFromPayload(Map<String, dynamic> data) {
  for (final key in const ['incidentId', 'notificationKey']) {
    final value = data[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

bool isCriticalHealthNotification(Map<String, dynamic> data) {
  return isHealthNotificationPayload(data) && data['severity'] == 'high';
}

int localNotificationIdForPayload(
  Map<String, dynamic> data, {
  required int fallback,
}) {
  final incidentId = healthIncidentIdFromPayload(data);
  if (incidentId == null) return fallback & 0x7fffffff;

  // FNV-1a keeps the same incident on the same Android notification slot,
  // including after an app restart.
  var hash = 0x811c9dc5;
  for (final codeUnit in incidentId.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  final positive = hash & 0x7fffffff;
  return positive == 0 ? 1 : positive;
}

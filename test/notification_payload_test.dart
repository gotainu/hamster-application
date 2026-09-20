import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/services/notification_payload.dart';

void main() {
  test('health incident and legacy health payloads are recognized', () {
    expect(
      isHealthNotificationPayload({'type': 'health_incident'}),
      isTrue,
    );
    expect(
      isHealthNotificationPayload({'type': 'gold_health_alert'}),
      isTrue,
    );
    expect(isHealthNotificationPayload({'type': 'anomaly'}), isTrue);
    expect(isHealthNotificationPayload({'type': 'marketing'}), isFalse);
  });

  test('same incident uses the same local notification id', () {
    final first = localNotificationIdForPayload(
      {
        'type': 'health_incident',
        'incidentId': 'environment:humidity_high',
        'assessmentDateKey': '2026-09-10',
      },
      fallback: 10,
    );
    final nextDay = localNotificationIdForPayload(
      {
        'type': 'health_incident',
        'incidentId': 'environment:humidity_high',
        'assessmentDateKey': '2026-09-11',
      },
      fallback: 20,
    );

    expect(nextDay, first);
  });

  test('critical health payload uses the critical presentation', () {
    expect(
      isCriticalHealthNotification({
        'type': 'health_incident',
        'severity': 'high',
      }),
      isTrue,
    );
    expect(
      isCriticalHealthNotification({
        'type': 'health_incident',
        'severity': 'medium',
      }),
      isFalse,
    );
  });
}

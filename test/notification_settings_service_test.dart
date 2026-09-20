import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/services/notification_settings_service.dart';

void main() {
  test('notification settings default to low-noise preferences', () {
    final settings = NotificationSettings.fromMap(null);

    expect(settings.anomalyNotificationsEnabled, isTrue);
    expect(settings.criticalAlertsEnabled, isTrue);
    expect(
      settings.cautionNotificationFrequency,
      CautionNotificationFrequency.stateChangesOnly,
    );
    expect(settings.quietHoursEnabled, isTrue);
    expect(settings.resolvedNotificationsEnabled, isTrue);
    expect(settings.isCategoryEnabled('environment'), isTrue);
    expect(settings.isCategoryEnabled('nutrition'), isTrue);
  });

  test('notification settings preserve per-category choices', () {
    final settings = NotificationSettings.fromMap({
      'goldHealthNotificationsEnabled': true,
      'resolvedNotificationsEnabled': false,
      'notificationCategories': {
        'environment': false,
        'activity': true,
        'body': false,
      },
    });

    expect(settings.resolvedNotificationsEnabled, isFalse);
    expect(settings.isCategoryEnabled('environment'), isFalse);
    expect(settings.isCategoryEnabled('activity'), isTrue);
    expect(settings.isCategoryEnabled('body'), isFalse);
    expect(settings.isCategoryEnabled('condition'), isTrue);
    expect(settings.isCategoryEnabled('nutrition'), isTrue);
  });
}

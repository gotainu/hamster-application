import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('release app identity', () {
    test('Android uses the Hamster Care display name', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      final strings = File('android/app/src/main/res/values/strings.xml')
          .readAsStringSync();

      expect(manifest, contains('android:label="@string/app_name"'));
      expect(manifest, isNot(contains('<manifest package=')));
      expect(
          strings, contains('<string name="app_name">Hamster Care</string>'));
    });

    test('iOS uses the Hamster Care display and bundle names', () {
      final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

      expect(
        infoPlist,
        contains(
          '<key>CFBundleDisplayName</key>\n\t<string>Hamster Care</string>',
        ),
      );
      expect(
        infoPlist,
        contains('<key>CFBundleName</key>\n\t<string>Hamster Care</string>'),
      );
    });
  });
}

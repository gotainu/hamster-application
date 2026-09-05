import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

    test('Android release targets API 36 without broad media or ad IDs', () {
      final buildConfig =
          File('android/app/build.gradle.kts').readAsStringSync();
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

      expect(buildConfig, contains('compileSdk = 36'));
      expect(buildConfig, contains('targetSdk = 36'));
      expect(buildConfig, contains('versionCode = flutter.versionCode'));
      expect(buildConfig, contains('versionName = flutter.versionName'));
      expect(manifest, isNot(contains('android.permission.CAMERA')));
      expect(manifest, isNot(contains('android.permission.READ_MEDIA_IMAGES')));
      expect(
        manifest,
        isNot(contains('android.permission.READ_EXTERNAL_STORAGE')),
      );
      expect(
        manifest,
        contains('com.google.android.gms.permission.AD_ID'),
      );
      expect(manifest, contains('tools:node="remove"'));
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

    test('iOS enables APNs and background notification delivery', () {
      final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
      final entitlements =
          File('ios/Runner/Runner.entitlements').readAsStringSync();
      final project =
          File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

      expect(
        entitlements,
        contains(
          '<key>aps-environment</key>\n\t<string>development</string>',
        ),
      );
      expect(
        infoPlist,
        contains(
          '<key>UIBackgroundModes</key>\n\t<array>\n'
          '\t\t<string>fetch</string>\n'
          '\t\t<string>remote-notification</string>',
        ),
      );
      expect(project, contains('com.apple.Push = {'));
      expect(project, contains('com.apple.BackgroundModes = {'));
    });

    test('public review and account deletion pages are present', () {
      for (final path in <String>[
        'public/privacy/index.html',
        'public/terms/index.html',
        'public/commercial-transactions/index.html',
        'public/support/index.html',
        'public/account-deletion/index.html',
      ]) {
        expect(File(path).existsSync(), isTrue, reason: '$path is missing');
      }
    });

    test('store metadata and Google Play feature graphic meet limits', () {
      String textAt(String path) => File(path).readAsStringSync().trim();

      final googleTitle = textAt(
        'store_assets/metadata/google_play/ja-JP/title.txt',
      );
      final googleShortDescription = textAt(
        'store_assets/metadata/google_play/ja-JP/short_description.txt',
      );
      final googleFullDescription = textAt(
        'store_assets/metadata/google_play/ja-JP/full_description.txt',
      );
      final appStoreName = textAt(
        'store_assets/metadata/app_store/ja/name.txt',
      );
      final appStoreSubtitle = textAt(
        'store_assets/metadata/app_store/ja/subtitle.txt',
      );
      final promotionalText = textAt(
        'store_assets/metadata/app_store/ja/promotional_text.txt',
      );
      final appStoreDescription = textAt(
        'store_assets/metadata/app_store/ja/description.txt',
      );
      final appStoreKeywords = textAt(
        'store_assets/metadata/app_store/ja/keywords.txt',
      );

      expect(googleTitle.runes.length, lessThanOrEqualTo(30));
      expect(googleShortDescription.runes.length, lessThanOrEqualTo(80));
      expect(googleFullDescription.runes.length, lessThanOrEqualTo(4000));
      expect(appStoreName.runes.length, lessThanOrEqualTo(30));
      expect(appStoreSubtitle.runes.length, lessThanOrEqualTo(30));
      expect(promotionalText.runes.length, lessThanOrEqualTo(170));
      expect(appStoreDescription.runes.length, lessThanOrEqualTo(4000));
      expect(utf8.encode(appStoreKeywords).length, lessThanOrEqualTo(100));

      final featureGraphic = File(
        'store_assets/google_play_feature_graphic_1024x500.png',
      );
      final pngBytes = featureGraphic.readAsBytesSync();
      final dimensions = ByteData.sublistView(pngBytes, 16, 24);
      expect(featureGraphic.lengthSync(), lessThanOrEqualTo(1024 * 1024));
      expect(dimensions.getUint32(0), 1024);
      expect(dimensions.getUint32(4), 500);
    });
  });
}

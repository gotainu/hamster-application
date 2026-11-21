import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A shared-source release boundary for iOS and Android. Purchase and contract
/// management are independent Web flows; Flutter retains status reads only.
Map<String, String> flutterSources() => {
  for (final file
      in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart')))
    file.path.replaceAll('\\', '/'): file.readAsStringSync(),
};

void main() {
  test(
    'shared Flutter source cannot create new Stripe Checkout or launch purchase URLs',
    () {
      final prohibited = RegExp(
        r'createStripeCheckoutSession|checkout\.stripe\.com|buy\.stripe\.com|'
        r'web\.app/(?:account|billing|pricing|checkout|subscribe|purchase)|'
        r'StripeCheckout|_startCheckout',
        caseSensitive: false,
      );
      final violations = <String>[];
      for (final entry in flutterSources().entries) {
        if (prohibited.hasMatch(entry.value)) violations.add(entry.key);
      }
      expect(violations, isEmpty);
    },
  );

  test('new purchase labels and prices are absent from app source', () {
    final prohibited = RegExp(
      r'月額プランに登録する|プレミアムに登録する|有料プランに切り替える|'
      r'Webで購入|ウェブで購入|記録・分析を続けるプランを見る|'
      r'(?:500|550)\s*円|Webの方が安い',
      caseSensitive: false,
    );
    expect([
      for (final entry in flutterSources().entries)
        if (prohibited.hasMatch(entry.value)) entry.key,
    ], isEmpty);
    expect(
      File('lib/widgets/report_continuation_link.dart').existsSync(),
      isFalse,
    );
  });

  test('Flutter cannot invoke Portal or expose contract-management links', () {
    final prohibited = RegExp(
      r'createStripeCustomerPortalSession|billing\.stripe\.com|'
      r'_openCustomerPortal|onOpenCustomerPortal|\bportalUrl\b|'
      r'''['"](?:契約管理|プランを管理する|管理画面を準備中…|支払方法を変更する)['"]|'''
      r'''['"]/(?:account|billing|pricing|checkout|subscribe|purchase)(?:/|['"]|\?)''',
      caseSensitive: false,
    );
    final violations = <String>[];
    for (final entry in flutterSources().entries) {
      if (prohibited.hasMatch(entry.value)) violations.add(entry.key);
    }
    expect(violations, isEmpty);
  });

  test(
    'nonpurchase legal support and content-reference links remain available',
    () {
      final sources = flutterSources();
      expect(
        sources['lib/screens/auth.dart'],
        contains('https://hamster-breeding-app.web.app/terms/'),
      );
      expect(
        sources['lib/screens/auth.dart'],
        contains('https://hamster-breeding-app.web.app/privacy/'),
      );
      expect(
        sources['lib/widgets/ai_text_consent_dialog.dart'],
        contains('https://hamster-breeding-app.web.app/privacy/'),
      );
      expect(
        sources['lib/screens/settings.dart'],
        contains('mailto:gotainu@gmail.com'),
      );
      expect(
        sources['lib/screens/search_function.dart'],
        contains('_openReferenceVideoUrl'),
      );
      expect(
        sources['lib/widgets/weight_research_comparison_card.dart'],
        contains("Uri.https('doi.org'"),
      );
      expect(
        sources['lib/screens/personality_report_screen.dart'],
        contains('_openDoi'),
      );
    },
  );

  test(
    'bundled text assets and names contain no purchase URLs prices or QR implementation',
    () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final assetBlock = pubspec
          .split('  assets:')
          .last
          .split('  # An image asset')
          .first;
      final assetPaths = RegExp(
        r'^\s+-\s+((?:assets|store_assets)/[^\s]+)',
        multiLine: true,
      ).allMatches(assetBlock).map((match) => match.group(1)!).toSet();
      expect(assetPaths, isNotEmpty);
      final prohibited = RegExp(
        r'checkout\.stripe\.com|buy\.stripe\.com|billing\.stripe\.com|'
        r'web\.app/(?:account|billing|pricing|checkout|subscribe|purchase)|'
        r'(?:500|550)\s*円|Webで購入|月額プランに登録する',
      );
      final violations = <String>[];
      for (final assetPath in assetPaths) {
        final pathType = FileSystemEntity.typeSync(assetPath);
        final files = pathType == FileSystemEntityType.directory
            ? Directory(assetPath).listSync(recursive: true).whereType<File>()
            : [File(assetPath)];
        for (final file in files) {
          if (RegExp(
            r'(?:checkout|purchase|stripe|qr[_-]?code)',
            caseSensitive: false,
          ).hasMatch(file.path)) {
            violations.add(file.path);
          }
          if (RegExp(r'\.(?:svg|json|txt|md|yaml|html)$').hasMatch(file.path) &&
              prohibited.hasMatch(file.readAsStringSync())) {
            violations.add(file.path);
          }
        }
      }
      expect(violations.toSet(), isEmpty);
      // Raster assets are catalogued by filename, not claimed to have undergone OCR.
      expect(
        flutterSources().values.any(
          (source) => RegExp(
            r'QrImage|QrCode|QRCode|qr_flutter|WebViewWidget',
          ).hasMatch(source),
        ),
        isFalse,
      );
    },
  );
}

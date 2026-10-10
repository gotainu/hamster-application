import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/personality_report.dart';
import 'package:hamster_project/screens/personality_report_screen.dart';
import 'package:hamster_project/services/personality_reports_repo.dart';
import 'package:hamster_project/theme/app_theme.dart';

import 'personality_report_fixtures.dart';
import 'personality_report_v2_ui_fixtures.dart';

/// Synthetic immutable Gold fixtures. These helpers never initialize Firebase.
Map<String, dynamic> personalityV3Fixture({
  String type = 'both',
  String? reportId,
  double bodyMedian = 100,
  double activityMedian = 628.3185307179587,
  double? activityLatest = 628.3185307179587,
  Map<String, dynamic>? population,
  bool researchAvailable = true,
}) =>
    personalityV2UiFixture(
      type: type,
      reportId: reportId,
      bodyMedian: bodyMedian,
      activityMedian: activityMedian,
      activityLatest: activityLatest,
      population: population ??
          (researchAvailable
              ? applicablePopulation()
              : {
                  'applicability': 'not_applicable',
                  'reason': 'reference_unavailable',
                  'expressionJa': '適用できる比較データがないため公開研究との比較を適用しません。',
                  'cohort': null,
                  'position': null,
                  'limitations': <String>[],
                }),
    );

Map<String, dynamic> savedPersonalityV3Fixture(String type) =>
    jsonDecode(File('test/fixtures/personality_v2_daily_gold_$type.json')
        .readAsStringSync()) as Map<String, dynamic>;

/// Samsung visuals retain the full saved research contract from the synthetic
/// Emulator Gold. Baseline values and identity remain the deterministic UI
/// fixture; this never reads an account or any production Firestore document.
Map<String, dynamic> personalitySamsungV3Fixture() {
  final saved = jsonDecode(
    File('test/fixtures/personality_report_emulator_gold_both.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;
  final body = (saved['metrics'] as Map<String, dynamic>)['body']
      as Map<String, dynamic>;
  final data = personalityV3Fixture(
    population: body['populationComparison'] as Map<String, dynamic>,
  );
  data['limitations'] = saved['limitations'];
  return data;
}

class PersonalityV3Source implements PersonalitySpecificReportSource {
  PersonalityV3Source(this.current);
  PersonalityReportState current;
  final changes =
      StreamController<PersonalityReportState>.broadcast(sync: true);
  int latestReads = 0;
  final requestedIds = <String>[];

  Stream<PersonalityReportState> _watch() => Stream.multi((sink) {
        sink.add(current);
        final subscription = changes.stream.listen(sink.add);
        sink.onCancel = subscription.cancel;
      });

  @override
  Stream<PersonalityReportState> watchLatest() {
    latestReads++;
    return _watch();
  }

  @override
  Stream<PersonalityReportState> watchReport(String reportId) {
    requestedIds.add(reportId);
    return _watch();
  }

  void emit(PersonalityReportState state) {
    current = state;
    changes.add(state);
  }

  Future<void> close() => changes.close();
}

PersonalityReportState personalityV3Ready(Map<String, dynamic> data) =>
    PersonalityReportState.available(
        'synthetic-owner', PersonalityReport.fromMap(data));

const personalityV3GoldenRoot = ValueKey('personality-v3-golden-root');
const personalityV3GoldenFont = 'PersonalityV3GoldenJapanese';

/// Historical Samsung audit: 1080x2340 px, 480 dpi => 360x780 logical px.
/// Insets approximate the supplied screenshots (not a live device measurement).
const personalitySamsungViewport = Size(360, 780);
const double personalitySamsungTopInset = 34;
const double personalitySamsungBottomInset = 48;

Future<PersonalityV3Source> showPersonalityV3(
  WidgetTester tester,
  Map<String, dynamic> data, {
  PersonalityV3Source? source,
  String? reportId,
  String? expectedOwnerUid,
  FutureOr<void> Function(PersonalityReport)? onViewed,
  bool dark = true,
  double width = 400,
  double height = 1100,
  double textScale = 1,
  double bottomInset = 0,
  double topInset = 0,
  bool asPushedRoute = false,
  bool goldenFont = false,
  GlobalKey<NavigatorState>? navigatorKey,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final result = source ?? PersonalityV3Source(personalityV3Ready(data));
  if (source == null) addTearDown(result.close);
  var theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
  if (goldenFont) {
    theme = theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: personalityV3GoldenFont),
      primaryTextTheme:
          theme.primaryTextTheme.apply(fontFamily: personalityV3GoldenFont),
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle: theme.appBarTheme.titleTextStyle
            ?.copyWith(fontFamily: personalityV3GoldenFont),
      ),
    );
  }
  final navigation = navigatorKey ?? GlobalKey<NavigatorState>();
  final reportScreen = PersonalityReportScreen(
    repo: result,
    reportId: reportId,
    expectedOwnerUid: expectedOwnerUid,
    onReportViewed: onViewed,
  );
  await tester.pumpWidget(MaterialApp(
    navigatorKey: navigation,
    debugShowCheckedModeBanner: false,
    locale: const Locale('ja', 'JP'),
    supportedLocales: const [Locale('ja', 'JP')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: theme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
        viewPadding: EdgeInsets.only(top: topInset, bottom: bottomInset),
      ),
      child: RepaintBoundary(key: personalityV3GoldenRoot, child: child!),
    ),
    home: asPushedRoute ? const Scaffold() : reportScreen,
  ));
  await tester.pump();
  if (asPushedRoute) {
    unawaited(navigation.currentState!.push<void>(
      MaterialPageRoute<void>(builder: (_) => reportScreen),
    ));
  }
  await tester.pumpAndSettle();
  return result;
}

Future<void> expandPersonalityV3Details(WidgetTester tester) async {
  final title = find.text('記録の詳細・研究の出典');
  await tester.scrollUntilVisible(title, 250, maxScrolls: 120);
  await tester.ensureVisible(title);
  await tester.pumpAndSettle();
  await tester.tap(title);
  await tester.pumpAndSettle();
}

/// Load a real Japanese font without copying proprietary system assets into Git.
/// Goldens are pinned to these bytes; an alternate installation may supply an
/// identical file via HAMCARE_GOLDEN_JAPANESE_FONT. Missing/different fonts fail.
Future<void> loadPersonalityV3GoldenFonts() async {
  const japaneseHash =
      'ce6d52b962d4f23acc6dae01eb59c2ddae1fd0b561a87240433623f5e76b8a92';
  final japanesePath = Platform.environment['HAMCARE_GOLDEN_JAPANESE_FONT'] ??
      '/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc';
  final bytes = await File(japanesePath).readAsBytes();
  if (sha256.convert(bytes).toString() != japaneseHash) {
    throw StateError(
        'Golden Japanese font SHA-256 does not match the fixture.');
  }
  final loader = FontLoader(personalityV3GoldenFont)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();

  final iconsPath = Platform.environment['HAMCARE_GOLDEN_ICON_FONT'] ??
      '/Users/gota/tools/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  final icons = await File(iconsPath).readAsBytes();
  if (sha256.convert(icons).toString() !=
      'd9865b671a09d683d13a863089d8825e0f61a37696ce5d7d448bc8023aa62453') {
    throw StateError('Golden Material icon font SHA-256 does not match.');
  }
  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(icons)));
  await iconLoader.load();
}

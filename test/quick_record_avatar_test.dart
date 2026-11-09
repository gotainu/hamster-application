// Real QuickRecordSheet with the existing offline FlutterFire adapters.
// No real account, Firebase initialization, network, record write or callable.
// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart'
    as fu;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/hamster_avatar.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/widgets/daily_condition_input_card.dart';
import 'package:hamster_project/widgets/hamster_avatar_view.dart';
import 'package:hamster_project/widgets/paid_feature_gate.dart';
import 'package:hamster_project/widgets/quick_record_sheet.dart';
import 'package:hamster_project/widgets/quick_record_reward.dart';
import 'package:hamster_project/widgets/weight_input_card.dart';
import 'package:hamster_project/widgets/wheel_rotation_input_card.dart';

import 'first_ai_monitoring_cta_test.dart'
    show installRecordCalendarWidgetBackend;

const _captureKey = ValueKey('quick-record-local-capture');
const _captureFont = 'HamCareQuickRecordLayoutJapanese';

// Optional local screenshots use production shadows; regular tests keep the
// normal deterministic binding behaviour.
class _QuickRecordAvatarTestBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows =>
      Platform.environment['HAMCARE_QUICK_RECORD_CAPTURE_DIR'] == null;
}

const _uid = 'onboarding-widget-test';
const _profilePath = 'users/$_uid/pet_profiles/main_pet';
const _states = [
  HamsterAvatarCondition.activityHigh,
  HamsterAvatarCondition.happy,
  HamsterAvatarCondition.stable,
];

class _NoQuickRecordFunctions extends fu.FirebaseFunctionsPlatform {
  _NoQuickRecordFunctions() : super(null, 'asia-northeast1');
  final requests = <String>[];

  @override
  fu.FirebaseFunctionsPlatform delegateFor(
          {FirebaseApp? app, required String region}) =>
      this;

  @override
  fu.HttpsCallablePlatform httpsCallable(
      String? origin, String name, fu.HttpsCallableOptions options) {
    requests.add(name);
    throw StateError('No RPC is allowed in quick-record avatar tests: $name');
  }
}

// All successful loads use the registered real PNG bytes; only named assets
// fail. AssetManifest and the original generic icon remain available.
class _QuickAvatarBundle extends CachingAssetBundle {
  _QuickAvatarBundle({this.missing = const <String>{}});
  final Set<String> missing;
  final requested = <String>[];

  @override
  Future<ByteData> load(String key) async {
    if (key.startsWith('assets/avatars/') && key.endsWith('.png')) {
      requested.add(key);
      if (missing.contains(key)) {
        throw FlutterError('Missing quick-record avatar fixture: $key');
      }
    }
    return rootBundle.load(key);
  }
}

String _canonicalDocuments(Map<String, Map<String, dynamic>> documents) {
  Object? normalize(Object? value) {
    if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {for (final key in keys) key: normalize(value[key])};
    }
    if (value is List) return value.map(normalize).toList();
    return value;
  }

  return jsonEncode(normalize(documents));
}

Future<void> _frames(WidgetTester tester) async {
  // Covers stream delivery, modal transitions and decoding real avatar PNGs.
  // No repeating avatar animation is expected for category illustrations.
  for (var frame = 0; frame < 12; frame++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Finder _avatar(HamsterAvatarCondition condition) =>
    find.byKey(ValueKey('quick-record-avatar-${condition.assetKey}'));

void _expectDecodedAvatar(
    WidgetTester tester, HamsterAvatarCondition condition, String path) {
  final avatar = _avatar(condition);
  expect(avatar, findsOneWidget);
  final view = tester.widget<HamsterAvatarView>(avatar);
  expect(view.showBackdrop, isFalse);
  expect(view.showMessage, isFalse);
  expect(view.showCauseBadge, isFalse);
  expect(view.presentation.animateBreathing, isFalse);
  expect(view.presentation.condition, condition);
  expect(view.presentation.cause, HamsterAvatarCause.none);
  expect(view.size, 58);
  expect(tester.getSize(avatar), const Size(58, 58));
  final image = tester
      .widget<Image>(find.descendant(of: avatar, matching: find.byType(Image)));
  expect((image.image as AssetImage).assetName, path);
  final decoded = tester.widget<RawImage>(
      find.descendant(of: avatar, matching: find.byType(RawImage)));
  expect(decoded.image, isNotNull, reason: 'The real PNG must be decoded');
  expect(decoded.image!.width, greaterThan(0));
  expect(decoded.image!.height, greaterThan(0));
}

void _expectNeutralIconSurfaces(WidgetTester tester) {
  final decorations = [
    for (final condition in _states)
      tester
          .widget<Container>(find.byKey(
              ValueKey('quick-record-icon-surface-${condition.assetKey}')))
          .decoration as BoxDecoration,
  ];
  final context = tester.element(find.byType(QuickRecordSheet));
  for (final decoration in decorations) {
    expect(decoration.color, AppTheme.quickRecordObjectSurface(context));
    expect(decoration.border,
        Border.all(color: AppTheme.quickRecordObjectBorder(context)));
  }
}

Future<void> _showSheet(
  WidgetTester tester, {
  AssetBundle? bundle,
  double width = 390,
  bool dark = false,
  ValueChanged<QuickRecordSheetResult?>? onResult,
}) async {
  tester.view.physicalSize = Size(width, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  var theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
  if (Platform.environment['HAMCARE_QUICK_RECORD_CAPTURE_DIR'] != null &&
      Platform.isMacOS) {
    theme = theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: _captureFont),
    );
  }
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    builder: (context, child) => DefaultAssetBundle(
      bundle: bundle ?? rootBundle,
      child: RepaintBoundary(key: _captureKey, child: child!),
    ),
    home: Builder(builder: (context) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () async {
              final result = await showModalBottomSheet<QuickRecordSheetResult>(
                context: context,
                useSafeArea: true,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const QuickRecordSheet(),
              );
              onResult?.call(result);
            },
            child: const Text('Open quick record fixture'),
          ),
        ),
      );
    }),
  ));
  await tester.tap(find.text('Open quick record fixture'));
  await _frames(tester);
}

Future<void> _captureSheet(WidgetTester tester, String name) async {
  final directory = Platform.environment['HAMCARE_QUICK_RECORD_CAPTURE_DIR'];
  if (directory == null) return;
  await tester.runAsync(() async {
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(_captureKey));
    final image = await boundary.toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$directory/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Future<void> _closeSheet(WidgetTester tester) async {
  await tester.tap(find.byTooltip('閉じる'));
  await _frames(tester);
  expect(find.byType(QuickRecordSheet), findsNothing);
}

void main() {
  _QuickRecordAvatarTestBinding();
  final functions = _NoQuickRecordFunctions();
  late ({
    Map<String, Map<String, dynamic>> documents,
    VoidCallback notify,
    Future<void> Function() close
  }) backend;
  late Map<String, Map<String, dynamic>> initialDocuments;
  late String expectedDocuments;

  void acceptFixtureBaseline() {
    expectedDocuments = _canonicalDocuments(backend.documents);
  }

  void setProfile({
    String species = 'ロボロフスキー',
    String? color = 'パイド',
    String subjectId = 'synthetic-quick-pet-a',
    bool legacy = false,
  }) {
    backend.documents[_profilePath] = {
      'name': '確認用',
      if (!legacy) 'species': species,
      if (!legacy) 'color': color,
      'subjectId': subjectId,
      'revision': 1,
    };
    acceptFixtureBaseline();
    backend.notify();
  }

  setUpAll(() async {
    if (Platform.environment['HAMCARE_QUICK_RECORD_CAPTURE_DIR'] != null &&
        Platform.isMacOS) {
      // Current host font is used only in optional local previews. Historical
      // Golden fonts and production typography are not changed.
      final bytes =
          await File('/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc').readAsBytes();
      await (FontLoader(_captureFont)
            ..addFont(Future.value(ByteData.sublistView(bytes))))
          .load();
      final icons = await File(
              '/Users/gota/tools/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
          .readAsBytes();
      await (FontLoader('MaterialIcons')
            ..addFont(Future.value(ByteData.sublistView(icons))))
          .load();
    }
    backend = installRecordCalendarWidgetBackend(functions: functions);
    initialDocuments = {
      for (final entry in backend.documents.entries)
        entry.key: Map<String, dynamic>.from(entry.value),
    };
  });
  setUp(() {
    functions.requests.clear();
    FlutterSecureStorage.setMockInitialValues({});
    backend.documents
      ..clear()
      ..addAll({
        for (final entry in initialDocuments.entries)
          entry.key: Map<String, dynamic>.from(entry.value),
      });
    acceptFixtureBaseline();
  });
  tearDown(() {
    expect(functions.requests, isEmpty, reason: 'No read/write RPC is needed');
    expect(_canonicalDocuments(backend.documents), expectedDocuments,
        reason: 'Opening icons and forms must not change any synthetic data');
  });
  tearDownAll(() => backend.close());

  for (final appearance in [
    (species: 'シリアン', color: 'ブラック・濃色系', directory: 'syrian/dark'),
    (species: 'ジャンガリアン', color: 'ブルーサファイア系', directory: 'djungarian/sapphire'),
    (species: 'ロボロフスキー', color: 'ノーマルブラウン系', directory: 'roborovski/normal'),
    (species: 'ロボロフスキー', color: 'パイド', directory: 'roborovski/pied'),
  ]) {
    testWidgets('three quick icons decode ${appearance.directory} artwork',
        (tester) async {
      setProfile(species: appearance.species, color: appearance.color);
      final bundle = _QuickAvatarBundle();
      final dark = appearance.directory == 'djungarian/sapphire' ||
          appearance.directory == 'roborovski/normal';
      final width = appearance.directory == 'djungarian/sapphire' ||
              appearance.directory == 'roborovski/pied'
          ? 320.0
          : 390.0;
      await _showSheet(tester, bundle: bundle, width: width, dark: dark);
      expect(find.byType(PaidFeatureGate), findsOneWidget);
      expect(find.byType(HamsterAvatarView), findsNWidgets(3));
      _expectNeutralIconSurfaces(tester);
      for (final condition in _states) {
        final path =
            'assets/avatars/${appearance.directory}/${condition.assetKey}.png';
        _expectDecodedAvatar(tester, condition, path);
        expect(bundle.requested, contains(path));
      }
      expect(tester.takeException(), isNull);
      await _captureSheet(tester,
          '${appearance.directory.replaceAll('/', '_')}_${dark ? 'dark' : 'light'}_${width.toInt()}');
      await _closeSheet(tester);
    });
  }

  testWidgets('open category icons follow main_pet subject and color changes',
      (tester) async {
    setProfile(species: 'シリアン', color: 'ブラック・濃色系');
    final bundle = _QuickAvatarBundle();
    await _showSheet(tester, bundle: bundle);
    final originalState = tester.state(_avatar(HamsterAvatarCondition.happy));
    for (final next in [
      (color: 'パイド', directory: 'roborovski/pied'),
      (color: 'ノーマルブラウン系', directory: 'roborovski/normal'),
    ]) {
      setProfile(color: next.color, subjectId: 'synthetic-quick-pet-b');
      await _frames(tester);
      expect(tester.state(_avatar(HamsterAvatarCondition.happy)),
          same(originalState));
      for (final condition in _states) {
        _expectDecodedAvatar(tester, condition,
            'assets/avatars/${next.directory}/${condition.assetKey}.png');
      }
    }
    expect(tester.takeException(), isNull);
    await _closeSheet(tester);
  });

  for (final profileCase in ['missing', 'legacy', 'blank color']) {
    testWidgets('quick icons preserve the original fallback for $profileCase',
        (tester) async {
      if (profileCase == 'legacy') setProfile(legacy: true);
      if (profileCase == 'blank color') setProfile(color: '  ');
      final bundle = _QuickAvatarBundle();
      await _showSheet(tester, bundle: bundle);
      expect(find.byType(HamsterAvatarView), findsNothing);
      _expectNeutralIconSurfaces(tester);
      expect(find.byIcon(Icons.directions_run_rounded), findsOneWidget);
      expect(find.byIcon(Icons.monitor_weight_outlined), findsOneWidget);
      final brand = find.byWidgetPredicate((widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName ==
              'store_assets/icons/google_play_icon_512.png');
      expect(brand, findsOneWidget);
      final decoded = tester.widget<RawImage>(
          find.descendant(of: brand, matching: find.byType(RawImage)));
      expect(decoded.image, isNotNull);
      expect(bundle.requested, isEmpty);
      expect(tester.takeException(), isNull);
      await _closeSheet(tester);
    });
  }

  testWidgets('missing activity image decodes the same-appearance stable',
      (tester) async {
    setProfile();
    const activity = 'assets/avatars/roborovski/pied/activity_high.png';
    const stable = 'assets/avatars/roborovski/pied/stable.png';
    final bundle = _QuickAvatarBundle(missing: {activity});
    await _showSheet(tester, bundle: bundle);
    _expectDecodedAvatar(tester, HamsterAvatarCondition.activityHigh, stable);
    final view = tester.widget<HamsterAvatarView>(
        _avatar(HamsterAvatarCondition.activityHigh));
    expect(view.presentation.assetCandidates, [activity, stable]);
    expect(bundle.requested, containsAll([activity, stable]));
    expect(
        bundle.requested.any((path) => path.contains('white_face')), isFalse);
    expect(tester.takeException(), isNull);
    await _closeSheet(tester);
  });

  testWidgets(
      'unmade white_face keeps same-appearance candidates and safe icons',
      (tester) async {
    setProfile(color: 'ホワイトフェイス・淡色系');
    final bundle = _QuickAvatarBundle();
    await _showSheet(tester, bundle: bundle);
    expect(find.byType(HamsterAvatarView), findsNWidgets(3));
    expect(find.byIcon(Icons.pets_rounded), findsNWidgets(3));
    expect(bundle.requested.toSet(), {
      for (final condition in _states)
        'assets/avatars/roborovski/white_face/${condition.assetKey}.png',
    });
    expect(tester.takeException(), isNull);
    await _closeSheet(tester);
  });

  testWidgets(
      'all missing prepared artwork ends at safe icons without substitution',
      (tester) async {
    setProfile();
    final missing = {
      for (final condition in _states)
        'assets/avatars/roborovski/pied/${condition.assetKey}.png',
    };
    final bundle = _QuickAvatarBundle(missing: missing);
    await _showSheet(tester, bundle: bundle);
    expect(find.byIcon(Icons.pets_rounded), findsNWidgets(3));
    expect(bundle.requested.toSet(), missing);
    expect(tester.takeException(), isNull);
    await _closeSheet(tester);
  });

  for (final category in [
    (label: '走った記録', type: WheelRotationInputCard),
    (label: '今日の様子', type: DailyConditionInputCard),
    (label: '体重', type: WeightInputCard),
  ]) {
    testWidgets(
        '${category.label} retains its input screen and category return',
        (tester) async {
      setProfile();
      backend.documents['users/$_uid/breeding_environments/main_env'] = {
        'wheelDiameterCm': 20,
      };
      acceptFixtureBaseline();
      await _showSheet(tester);
      await tester.tap(find.text(category.label));
      await _frames(tester);
      expect(find.byType(category.type), findsOneWidget);
      expect(find.byTooltip('項目一覧へ戻る'), findsOneWidget);
      await tester.tap(find.byTooltip('項目一覧へ戻る'));
      await _frames(tester);
      expect(find.byType(category.type), findsNothing);
      for (final condition in _states) {
        expect(_avatar(condition), findsOneWidget);
      }
      expect(find.text('すべての記録を開く'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _closeSheet(tester);
    });
  }

  testWidgets('reward follows the active pet stream without recording data',
      (tester) async {
    setProfile(species: 'シリアン', color: 'クリーム・淡色系');
    await _showSheet(tester);
    await tester.tap(find.text('今日の様子'));
    await _frames(tester);
    // Exercise the existing confirmed-save callback without submitting a record.
    tester
        .widget<DailyConditionInputCard>(find.byType(DailyConditionInputCard))
        .onSaved!();
    await _frames(tester);
    expect(find.byType(QuickRecordRewardView), findsOneWidget);
    final avatar = find.byKey(const ValueKey('quick-record-reward-avatar'));
    expect(
        tester.widget<HamsterAvatarView>(avatar).presentation.assetCandidates, [
      'assets/avatars/syrian/cream/happy.png',
      'assets/avatars/syrian/cream/stable.png'
    ]);
    setProfile(color: 'パイド', subjectId: 'synthetic-quick-pet-b');
    await _frames(tester);
    expect(
        tester.widget<HamsterAvatarView>(avatar).presentation.assetCandidates, [
      'assets/avatars/roborovski/pied/happy.png',
      'assets/avatars/roborovski/pied/stable.png'
    ]);
    final image = tester.widget<Image>(
        find.descendant(of: avatar, matching: find.byType(Image)));
    expect((image.image as AssetImage).assetName,
        'assets/avatars/roborovski/pied/happy.png');
    await _captureSheet(tester, 'reward_roborovski_pied');
    await tester.tap(find.text('ほかも記録'));
    await _frames(tester);
    _expectNeutralIconSurfaces(tester);
    expect(tester.takeException(), isNull);
    await _closeSheet(tester);
  });

  testWidgets('open all records retains the existing modal result',
      (tester) async {
    setProfile();
    QuickRecordSheetResult? result;
    var returned = false;
    await _showSheet(tester, onResult: (value) {
      returned = true;
      result = value;
    });
    await tester.ensureVisible(find.text('すべての記録を開く'));
    await tester.tap(find.text('すべての記録を開く'));
    await _frames(tester);
    expect(returned, isTrue);
    expect(result, QuickRecordSheetResult.openAllRecords);
    expect(find.byType(QuickRecordSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no entitlement still locks categories behind the existing gate',
      (tester) async {
    setProfile();
    backend.documents.remove('users/$_uid/feature_access/initial_trial_v2');
    backend.documents.remove('users/$_uid/billing/subscription');
    acceptFixtureBaseline();
    await _showSheet(tester);
    expect(find.byType(PaidFeatureGate), findsOneWidget);
    expect(find.text('クイック記録は有料プランの機能です'), findsOneWidget);
    expect(find.byType(HamsterAvatarView), findsNothing);
    expect(find.text('すべての記録を開く'), findsNothing);
    expect(tester.takeException(), isNull);
    await _closeSheet(tester);
  });
}

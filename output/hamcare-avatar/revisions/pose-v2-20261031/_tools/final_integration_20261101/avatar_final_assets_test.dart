import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/hamster_avatar.dart';
import 'package:hamster_project/models/pet_profile.dart';
import 'package:hamster_project/services/pet_profile_repo.dart';
import 'package:hamster_project/services/hamster_avatar_appearance_resolver.dart';
import 'package:hamster_project/services/hamster_avatar_asset_resolver.dart';
import 'package:hamster_project/widgets/hamster_avatar_view.dart';

const output =
    'output/hamcare-avatar/revisions/pose-v2-20261031/_tools/final_integration_20261101/checks';
const looks = <_Look>[
  _Look('シリアン', 'ブラック・濃色系', 'syrian/dark'),
  _Look('ロボロフスキー', 'パイド', 'roborovski/pied'),
];
const appearanceResolver = HamsterAvatarAppearanceResolver();
const assetResolver = HamsterAvatarAssetResolver();
final evidence = <String, Object?>{
  'scope':
      '2 newly adopted appearances x 8 existing states; real project assets',
  'profile_mapping': <String, Object?>{},
  'decoded_assets': <Object?>[],
  'widget_checks': <Object?>[],
  'limitations': <String>[
    'Local Flutter asset/Widget verification; not a physical-device or store build.',
    '48/72/150 are requested display samples; actual current Home/profile/edit/Drawer/Chat dimensions are tested separately.',
  ],
};

class _Look {
  final String species;
  final String color;
  final String key;
  const _Look(this.species, this.color, this.key);
  PetProfile get profile => PetProfile(
        name: 'local fixture',
        birthday: null,
        species: species,
        color: color,
        imageUrl: null,
        subjectId: 'unchanged_local_subject',
        revision: 4,
      );
}

String _assetPath(_Look look, HamsterAvatarCondition state) =>
    'assets/avatars/${look.key}/${state.assetKey}.png';

HamsterAvatarPresentation _presentation(
  _Look look,
  HamsterAvatarCondition state,
) =>
    assetResolver.resolve(
      appearance: appearanceResolver.resolve(look.profile),
      conditionResult: HamsterAvatarConditionResult(
        condition: state,
        cause: HamsterAvatarCause.none,
        message: '${look.key}/${state.assetKey}',
        animateBreathing: false,
      ),
    );

void saveEvidence() {
  final dir = Directory(output)..createSync(recursive: true);
  File('${dir.path}/integration-result.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(evidence)}\n',
  );
}

Future<void> _decodeAndMeasure(String path) async {
  final data = await rootBundle.load(path);
  final codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  expect(codec.frameCount, 1, reason: path);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  expect(bytes, isNotNull, reason: path);
  final width = image.width, height = image.height;
  expect(width, greaterThan(0), reason: path);
  expect(height, greaterThan(0), reason: path);
  final rgba = bytes!.buffer.asUint8List(
    bytes.offsetInBytes,
    bytes.lengthInBytes,
  );
  var visible = 0, transparent = 0;
  var left = width, top = height, right = -1, bottom = -1;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final alpha = rgba[(y * width + x) * 4 + 3];
      if (alpha == 0) transparent++;
      if (alpha <= 16) continue;
      visible++;
      if (x < left) left = x;
      if (y < top) top = y;
      if (x > right) right = x;
      if (y > bottom) bottom = y;
    }
  }
  expect(visible, greaterThan(0), reason: path);
  (evidence['decoded_assets'] as List<Object?>).add({
    'path': path,
    'bytes': data.lengthInBytes,
    'width': width,
    'height': height,
    'visible_alpha_pixels': visible,
    'fully_transparent_pixels': transparent,
    'visible_bbox_inclusive': [left, top, right, bottom],
    'png_decode': 'PASS',
  });
  image.dispose();
  codec.dispose();
}

Widget _avatar(
  _Look look,
  HamsterAvatarCondition state,
  double size, {
  bool backdrop = false,
}) =>
    HamsterAvatarView(
      key: ValueKey(_assetPath(look, state)),
      presentation: _presentation(look, state),
      size: size,
      showBackdrop: backdrop,
      showCauseBadge: false,
      showMessage: false,
      showDebugLabel: false,
    );

Future<void> showGallery(
  WidgetTester tester,
  String name, {
  required double size,
  required bool dark,
  bool backdrop = false,
  double? parentSize,
  double? circleFrame,
  double translateY = 0,
  bool stableOnly = false,
}) async {
  final states = stableOnly
      ? [HamsterAvatarCondition.stable]
      : HamsterAvatarCondition.values;
  final cell = (circleFrame ?? parentSize ?? size) + 18;
  final dimensions = Size(
    152 + looks.length * cell,
    46 + states.length * (cell + 4),
  );
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = dimensions;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final boundary = GlobalKey();
  final entries = <Map<String, Object?>>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        brightness: dark ? Brightness.dark : Brightness.light,
        fontFamily: 'HamCareIntegrationLabels',
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: boundary,
            child: SizedBox(
              width: dimensions.width,
              height: dimensions.height,
              child: ColoredBox(
                color: dark ? const Color(0xff272f39) : Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 152),
                        for (final look in looks)
                          SizedBox(
                            width: cell,
                            height: 42,
                            child: Center(
                              child: Text(
                                look.key,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                      ],
                    ),
                    for (final state in states)
                      Row(
                        children: [
                          SizedBox(
                            width: 152,
                            child: Text(
                              state.assetKey,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          for (final look in looks)
                            SizedBox(
                              width: cell,
                              height: cell + 4,
                              child: Center(
                                child: circleFrame == null
                                    ? SizedBox(
                                        width: parentSize ?? size,
                                        height: parentSize ?? size,
                                        child: Center(
                                          child: _avatar(
                                            look,
                                            state,
                                            size,
                                            backdrop: backdrop,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        width: circleFrame,
                                        height: circleFrame,
                                        clipBehavior: Clip.antiAlias,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                        ),
                                        child: OverflowBox(
                                          minWidth: 0,
                                          minHeight: 0,
                                          maxWidth: size,
                                          maxHeight: size,
                                          child: Transform.translate(
                                            offset: Offset(0, translateY),
                                            child: _avatar(
                                              look,
                                              state,
                                              size,
                                              backdrop: backdrop,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  final errors = <String>[];
  final context = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    await Future.wait([
      for (final look in looks)
        for (final state in states)
          precacheImage(
            AssetImage(_assetPath(look, state)),
            context,
            onError: (Object error, StackTrace? stack) =>
                errors.add(error.toString()),
          ),
    ]).timeout(const Duration(seconds: 45));
  });
  await tester.pumpAndSettle();
  expect(errors, isEmpty, reason: name);
  expect(find.byIcon(Icons.pets_rounded), findsNothing, reason: name);
  for (final look in looks) {
    for (final state in states) {
      final path = _assetPath(look, state);
      final view = find.byKey(ValueKey(path));
      expect(view, findsOneWidget);
      final imageFinder = find.descendant(
        of: view,
        matching: find.byType(Image),
      );
      final image = tester.widget<Image>(imageFinder);
      expect(image.image, isA<AssetImage>());
      expect(
        (image.image as AssetImage).assetName,
        path,
        reason: 'The requested state itself must load, not its stable fallback',
      );
      final rawFinder = find.descendant(
        of: view,
        matching: find.byType(RawImage),
      );
      expect(rawFinder, findsOneWidget, reason: path);
      final raw = tester.widget<RawImage>(rawFinder);
      expect(raw.image, isNotNull, reason: path);
      final render = tester.renderObject<RenderImage>(rawFinder);
      expect(render.fit, BoxFit.contain, reason: path);
      final intrinsic = Size(
        raw.image!.width.toDouble(),
        raw.image!.height.toDouble(),
      );
      final fitted = applyBoxFit(render.fit!, intrinsic, render.size);
      expect(fitted.source.width, closeTo(intrinsic.width, .001), reason: path);
      expect(
        fitted.source.height,
        closeTo(intrinsic.height, .001),
        reason: path,
      );
      final rect = Alignment.center.inscribe(
        fitted.destination,
        Offset.zero & render.size,
      );
      expect(rect.left, greaterThanOrEqualTo(-.001));
      expect(rect.top, greaterThanOrEqualTo(-.001));
      expect(rect.right, lessThanOrEqualTo(render.size.width + .001));
      expect(rect.bottom, lessThanOrEqualTo(render.size.height + .001));
      entries.add({
        'path': path,
        'render_size': [render.size.width, render.size.height],
        'image_size': [raw.image!.width, raw.image!.height],
        'full_source_retained_by_contain': true,
        'requested_state_loaded': true,
        'ancestor_circle_clip': circleFrame != null,
      });
    }
  }
  expect(tester.takeException(), isNull, reason: name);
  await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(output).createSync(recursive: true);
    File('$output/$name.png').writeAsBytesSync(
      data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    image.dispose();
  });
  (evidence['widget_checks'] as List<Object?>).add({
    'name': name,
    'avatar_size': size,
    'parent_size': parentSize,
    'circle_frame': circleFrame,
    'translate_y': translateY,
    'dark': dark,
    'requested_state_count': entries.length,
    'no_asset_fallback': true,
    'no_framework_overflow_or_error': true,
    'source_contain': 'PASS',
    'circle_clip_not_overclaimed': circleFrame != null,
    'entries': entries,
    'screenshot': '$output/$name.png',
  });
  saveEvidence();
  await tester.pumpWidget(const SizedBox.shrink());
}

class _MemoryPending implements ProfilePendingStore {
  final values = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(String owner) async => values[owner];
  @override
  Future<void> write(String owner, Map<String, dynamic> mutation) async {
    values[owner] = mutation;
  }

  @override
  Future<void> remove(String owner) async {
    values.remove(owner);
  }
}

class _MissingAvatarBundle extends CachingAssetBundle {
  final requested = <String>[];
  @override
  Future<ByteData> load(String key) async {
    requested.add(key);
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<String, Object>{})!;
    }
    throw FlutterError('No local fixture asset: $key');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Preserve the completed bundle/profile verification when only galleries
    // are rerun to save readable review labels. These fields are not re-tested.
    final prior = File('$output/integration-result.json');
    if (prior.existsSync()) {
      final completed =
          jsonDecode(prior.readAsStringSync()) as Map<String, dynamic>;
      for (final key in [
        'profile_mapping',
        'decoded_assets',
        'bundle_registration',
        'verification_runs',
      ]) {
        if (completed.containsKey(key)) evidence[key] = completed[key];
      }
    }
    // Screenshot captions only: no app font or asset registration is changed.
    const font = '/System/Library/Fonts/Supplemental/Arial.ttf';
    final loader = FontLoader('HamCareIntegrationLabels')
      ..addFont(
        Future.value(ByteData.sublistView(File(font).readAsBytesSync())),
      );
    await loader.load();
    evidence['screenshot_label_font'] = 'macOS Arial (test helper only)';
  });
  tearDownAll(saveEvidence);
  test(
      'existing profile labels roundtrip into the two newly adopted appearance directories',
      () {
    final verified = <String, Object?>{};
    for (final look in looks) {
      expect(
        appearanceResolver.colorOptionsFor(look.species),
        contains(look.color),
      );
      final saved = look.profile.toMapForSave();
      final loaded = PetProfile.fromMap({
        ...saved,
        'subjectId': 'unchanged_local_subject',
        'revision': 4,
      });
      expect(loaded.species, look.species);
      expect(loaded.color, look.color);
      expect(
        appearanceResolver.normalizeColorForSelection(
          species: loaded.species,
          color: loaded.color,
        ),
        look.color,
      );
      expect(appearanceResolver.resolve(loaded).assetDirectory, look.key);
      expect(loaded.subjectId, 'unchanged_local_subject');
      expect(loaded.revision, 4);
      for (final state in HamsterAvatarCondition.values) {
        final candidate = _presentation(look, state);
        expect(candidate.assetCandidates.first, _assetPath(look, state));
        expect(candidate.appearance.assetDirectory, look.key);
      }
      verified[look.key] = {
        'label_roundtrip': 'PASS',
        'resolver_8_states': 'PASS',
      };
    }
    evidence['profile_mapping'] = verified;
    saveEvidence();
  });
  test(
      'all sixteen new runtime assets are registered and fully decode from the real bundle',
      () async {
    final registered = (await AssetManifest.loadFromAssetBundle(rootBundle))
        .listAssets()
        .toSet();
    final expected = [
      for (final look in looks)
        for (final state in HamsterAvatarCondition.values)
          _assetPath(look, state),
    ];
    expect(expected.toSet().length, 16);
    expect(
      expected.where((p) => !registered.contains(p)),
      isEmpty,
      reason:
          'Leaf directory registration must reach the Flutter test asset bundle',
    );
    // A future complete run replaces these measurements rather than appending
    // to preserved evidence from an earlier screenshot-only pass.
    evidence['decoded_assets'] = <Object?>[];
    for (final path in expected) {
      await _decodeAndMeasure(path);
    }
    evidence['bundle_registration'] = '16/16 PASS';
    saveEvidence();
  });
  for (final size in [48.0, 72.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        '16 new states load without fallback and retain source at ${size.toInt()}px ${dark ? 'dark' : 'light'}',
        (tester) async {
          await showGallery(
            tester,
            'gallery_${size.toInt()}_${dark ? 'dark' : 'light'}',
            size: size,
            dark: dark,
          );
        },
      );
    }
  }
  testWidgets(
    'actual Home 190px presentation retains all sixteen new sources',
    (tester) async {
      await showGallery(tester, 'actual_home190_light', size: 190, dark: false);
    },
  );
  testWidgets(
    'actual profile detail 132px backdrop retains all sixteen new sources',
    (tester) async {
      await showGallery(
        tester,
        'actual_detail132_dark',
        size: 132,
        dark: true,
        backdrop: true,
      );
    },
  );
  testWidgets(
    'actual edit preview 142px inside 154px retains all sixteen new sources',
    (tester) async {
      await showGallery(
        tester,
        'actual_edit142_frame154_light',
        size: 142,
        parentSize: 154,
        dark: false,
      );
    },
  );

  // Existing circle crops are explicitly outside this release change.

  test(
      'black and pied persist through the normal profile repository without schema or identity changes',
      () async {
    for (final look in looks) {
      Map<String, dynamic>? stored;
      final requests = <Map<String, dynamic>>[];
      final pending = _MemoryPending();
      final repo = PetProfileRepo(
        owner: () => 'local_fixture_owner',
        pendingStore: pending,
        read: () async => stored,
        submit: (request) async {
          requests.add(request);
          stored = {
            ...request['values'] as Map<String, dynamic>,
            'subjectId': 'unchanged_local_subject',
            'revision': 5,
          };
          return {
            'subjectId': 'unchanged_local_subject',
            'revision': 5,
            'acceptedAt': '2026-11-01T00:00:00Z',
            'mutationId': request['mutationId'],
          };
        },
      );
      await repo.saveMainPet(look.profile);
      final loaded = (await repo.fetchMainPet())!;
      expect(requests.single['values']['color'], look.color);
      expect(requests.single['expectedSubjectId'], 'unchanged_local_subject');
      expect(requests.single['expectedRevision'], 4);
      expect(loaded.species, look.species);
      expect(loaded.color, look.color);
      expect(loaded.subjectId, 'unchanged_local_subject');
      expect(appearanceResolver.resolve(loaded).assetDirectory, look.key);
      expect(pending.values, isEmpty);
    }
    evidence['normal_repo_save_reload'] =
        '2/2 PASS; local mock only; no production writes';
    saveEvidence();
  });
  test(
      'legacy profile labels retain established appearance keys without migration',
      () {
    const cases = <String, List<String>>{
      'ロボロフスキー': ['ノーマルブラウン系', 'ホワイトフェイス・淡色系', 'white_face'],
      'シリアン': ['ゴールデン・茶系', 'ブラック・濃色系', '白黒・ダルメシアン系'],
    };
    for (final entry in cases.entries) {
      for (final color in entry.value) {
        final before = PetProfile.fromMap({
          'name': 'existing',
          'species': entry.key,
          'color': color,
          'subjectId': 'existing_profile',
          'revision': 7
        });
        final key = appearanceResolver.resolve(before).assetDirectory;
        final reloaded = PetProfile.fromMap({
          ...before.toMapForSave(),
          'subjectId': 'existing_profile',
          'revision': 7
        });
        expect(reloaded.color, color);
        expect(reloaded.subjectId, 'existing_profile');
        expect(appearanceResolver.resolve(reloaded).assetDirectory, key);
        if (entry.key == 'ロボロフスキー' && color != 'ノーマルブラウン系') {
          expect(key, 'roborovski/white_face');
          expect(key, isNot('roborovski/pied'));
        }
      }
    }
    evidence['legacy_profile_compatibility'] =
        'PASS; color strings and existing identity retained';
    saveEvidence();
  });
  testWidgets(
      'unmade white-face retains existing pets fallback without pied substitution',
      (tester) async {
    final bundle = _MissingAvatarBundle();
    final result = assetResolver.resolve(
        appearance: appearanceResolver.resolveFromValues(
            species: 'ロボロフスキー', color: 'ホワイトフェイス・淡色系'),
        conditionResult: const HamsterAvatarConditionResult(
            condition: HamsterAvatarCondition.happy,
            cause: HamsterAvatarCause.none,
            message: '',
            animateBreathing: false));
    await tester.pumpWidget(MaterialApp(
        home: DefaultAssetBundle(
            bundle: bundle,
            child:
                HamsterAvatarView(presentation: result, showBackdrop: false))));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.pets_rounded), findsOneWidget);
    expect(
        bundle.requested,
        containsAllInOrder([
          'assets/avatars/roborovski/white_face/happy.png',
          'assets/avatars/roborovski/white_face/stable.png'
        ]));
    expect(bundle.requested.any((p) => p.contains('/pied/')), false);
    expect(tester.takeException(), isNull);
    evidence['white_face_missing_fallback'] =
        'PASS; existing pets icon; no pied substitution';
    saveEvidence();
  });
}

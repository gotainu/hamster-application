// Uses synthetic report/profile streams and registered avatar PNGs only.
// No Firebase initialization, account access, record writes or AI requests.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/hamster_avatar.dart';
import 'package:hamster_project/models/pet_profile.dart';
import 'package:hamster_project/models/personality_report.dart';
import 'package:hamster_project/screens/personality_report_screen.dart';
import 'package:hamster_project/services/personality_reports_repo.dart';
import 'package:hamster_project/widgets/hamster_avatar_view.dart';
import 'package:hamster_project/theme/app_theme.dart';

class _Reports implements PersonalityReportsSource {
  PersonalityReportState current =
      const PersonalityReportState.learning('synthetic-owner-a');
  final changes =
      StreamController<PersonalityReportState>.broadcast(sync: true);

  @override
  Stream<PersonalityReportState> watchLatest() => Stream.multi((sink) {
        sink.add(current);
        final sub = changes.stream.listen(sink.add);
        sink.onCancel = sub.cancel;
      });

  void emit(PersonalityReportState state) {
    current = state;
    changes.add(state);
  }
}

class _AvatarBundle extends CachingAssetBundle {
  _AvatarBundle(this.missing);
  final Set<String> missing;
  final requested = <String>[];

  @override
  Future<ByteData> load(String key) async {
    if (key.startsWith('assets/avatars/') && key.endsWith('.png')) {
      requested.add(key);
      if (missing.contains(key)) {
        throw FlutterError('Missing test avatar: $key');
      }
    }
    return rootBundle.load(key);
  }
}

PetProfile _pet(String species, String? color) => PetProfile(
      name: '確認用',
      birthday: null,
      species: species,
      color: color,
      imageUrl: null,
    );

const _capture = ValueKey('report-learning-local-capture');
const _avatar = ValueKey('report-learning-avatar');

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> _show(
  WidgetTester tester,
  _Reports reports,
  Stream<PetProfile?> pets, {
  AssetBundle? bundle,
  bool dark = true,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  var theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
  if (Platform.environment['HAMCARE_REPORT_LEARNING_CAPTURE_DIR'] != null) {
    theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'HamCareLearningPreview'));
  }
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: RepaintBoundary(
      key: _capture,
      child: DefaultAssetBundle(
        bundle: bundle ?? rootBundle,
        child: PersonalityReportScreen(repo: reports, petStream: pets),
      ),
    ),
  ));
  await _frames(tester);
}

void _expectAvatar(WidgetTester tester, String asset) {
  final finder = find.byKey(_avatar);
  final view = tester.widget<HamsterAvatarView>(finder);
  expect(view.presentation.condition, HamsterAvatarCondition.insufficientData);
  expect(view.presentation.animateBreathing, isFalse);
  expect(view.showBackdrop, isFalse);
  final image = tester
      .widget<Image>(find.descendant(of: finder, matching: find.byType(Image)));
  expect((image.image as AssetImage).assetName, asset);
  final decoded = tester.widget<RawImage>(
      find.descendant(of: finder, matching: find.byType(RawImage)));
  expect(decoded.image, isNotNull);
  expect(find.text('うちの子らしさを集めています'), findsOneWidget);
  expect(tester.takeException(), isNull);
}

Future<void> _captureScreen(WidgetTester tester, String name) async {
  final directory = Platform.environment['HAMCARE_REPORT_LEARNING_CAPTURE_DIR'];
  if (directory == null) return;
  await tester.runAsync(() async {
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(_capture));
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$directory/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (Platform.environment['HAMCARE_REPORT_LEARNING_CAPTURE_DIR'] == null) {
      return;
    }
    final bytes =
        await File('/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc').readAsBytes();
    await (FontLoader('HamCareLearningPreview')
          ..addFont(Future.value(ByteData.sublistView(bytes))))
        .load();
  });

  for (final appearance in [
    (species: 'シリアン', color: 'ブラック・濃色系', directory: 'syrian/dark'),
    (species: 'ジャンガリアン', color: 'パールホワイト系', directory: 'djungarian/pearl'),
    (species: 'ロボロフスキー', color: 'パイド', directory: 'roborovski/pied'),
  ]) {
    testWidgets('learning decodes current ${appearance.directory} avatar',
        (tester) async {
      final reports = _Reports();
      addTearDown(reports.changes.close);
      await _show(tester, reports,
          Stream.value(_pet(appearance.species, appearance.color)),
          width: appearance.directory == 'roborovski/pied' ? 320 : 390,
          dark: appearance.directory != 'djungarian/pearl');
      _expectAvatar(tester,
          'assets/avatars/${appearance.directory}/insufficient_data.png');
      await _captureScreen(tester, appearance.directory.replaceAll('/', '_'));
    });
  }

  testWidgets('learning follows selected pet changes without replacing report',
      (tester) async {
    final reports = _Reports();
    final pets = StreamController<PetProfile?>.broadcast(sync: true);
    addTearDown(reports.changes.close);
    addTearDown(pets.close);
    await _show(tester, reports, pets.stream);
    pets.add(_pet('シリアン', 'クリーム・淡色系'));
    await _frames(tester);
    _expectAvatar(tester, 'assets/avatars/syrian/cream/insufficient_data.png');
    pets.add(_pet('ロボロフスキー', 'パイド'));
    await _frames(tester);
    _expectAvatar(
        tester, 'assets/avatars/roborovski/pied/insufficient_data.png');
  });

  testWidgets('missing learning state uses same appearance stable',
      (tester) async {
    final reports = _Reports();
    addTearDown(reports.changes.close);
    const state = 'assets/avatars/roborovski/pied/insufficient_data.png';
    final bundle = _AvatarBundle({state});
    await _show(tester, reports, Stream.value(_pet('ロボロフスキー', 'パイド')),
        bundle: bundle);
    _expectAvatar(tester, 'assets/avatars/roborovski/pied/stable.png');
    expect(bundle.requested, contains(state));
  });

  testWidgets('unmade appearance retains a safe icon without another pet image',
      (tester) async {
    final reports = _Reports();
    addTearDown(reports.changes.close);
    final bundle = _AvatarBundle({
      'assets/avatars/roborovski/white_face/insufficient_data.png',
      'assets/avatars/roborovski/white_face/stable.png',
    });
    await _show(tester, reports, Stream.value(_pet('ロボロフスキー', 'ホワイトフェイス・淡色系')),
        bundle: bundle);
    expect(find.byIcon(Icons.pets_rounded), findsOneWidget);
    expect(bundle.requested.every((path) => path.contains('/white_face/')),
        isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing old profile and source errors keep the prior safe icon',
      (tester) async {
    final reports = _Reports();
    addTearDown(reports.changes.close);
    await _show(tester, reports, Stream.value(_pet('シリアン', null)));
    expect(find.byKey(_avatar), findsNothing);
    expect(find.byIcon(Icons.pets_rounded), findsOneWidget);
    await _show(
        tester, reports, Stream<PetProfile?>.error(StateError('offline')));
    expect(find.byKey(_avatar), findsNothing);
    expect(find.byIcon(Icons.pets_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner change clears the prior avatar until next profile arrives',
      (tester) async {
    final reports = _Reports();
    final changes = StreamController<PetProfile?>.broadcast(sync: true);
    var listens = 0;
    final pets = Stream<PetProfile?>.multi((sink) {
      if (listens++ == 0) sink.add(_pet('シリアン', 'ブラック・濃色系'));
      final sub = changes.stream.listen(sink.add);
      sink.onCancel = sub.cancel;
    });
    addTearDown(reports.changes.close);
    addTearDown(changes.close);
    await _show(tester, reports, pets);
    _expectAvatar(tester, 'assets/avatars/syrian/dark/insufficient_data.png');
    reports.emit(const PersonalityReportState.learning('synthetic-owner-b'));
    await _frames(tester);
    expect(find.byKey(_avatar), findsNothing);
    expect(find.byIcon(Icons.pets_rounded), findsOneWidget);
    changes.add(_pet('ロボロフスキー', 'パイド'));
    await _frames(tester);
    _expectAvatar(
        tester, 'assets/avatars/roborovski/pied/insufficient_data.png');
    reports.emit(const PersonalityReportState.unavailable('synthetic-owner-b'));
    await _frames(tester);
    expect(find.byKey(_avatar), findsNothing);
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
  });
}

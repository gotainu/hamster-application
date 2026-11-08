// Owner nickname tests use synthetic accounts and in-memory FlutterFire only.
// No SDK initialization, HTTP, callable, Auth mutation or unrelated write.
// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as fp;
import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart'
    as fu;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart'
    as ap;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart'
    as cp;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/main.dart';
import 'package:hamster_project/models/owner_profile.dart';
import 'package:hamster_project/screens/owner_profile_edit_screen.dart';
import 'package:hamster_project/screens/settings.dart';
import 'package:hamster_project/services/owner_profile_repo.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _ownerA = 'synthetic-owner-a';
const _ownerB = 'synthetic-owner-b';
const _emailA = 'owner-a@example.com';
const _emailB = 'owner-b@example.com';
const _authName = 'Synthetic Auth name stays unchanged';
const _font = 'HamCareOwnerNicknameLayoutJapanese';
const _captureKey = ValueKey('owner-nickname-local-capture');
String _path(String uid) => 'users/$uid/owner_profiles/main';

class _NoOwnerNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('External HTTP is forbidden in owner nickname tests');
}

class _OwnerCore extends cp.FirebasePlatform {
  final _app = cp.FirebaseAppPlatform(
    cp.defaultFirebaseAppName,
    const FirebaseOptions(
      apiKey: 'fake-api-key',
      appId: 'fake-owner-app-id',
      messagingSenderId: 'fake-sender',
      projectId: 'offline-owner-profile-test',
    ),
  );
  @override
  List<cp.FirebaseAppPlatform> get apps => [_app];
  @override
  cp.FirebaseAppPlatform app([String name = cp.defaultFirebaseAppName]) => _app;
}

class _OwnerAuth extends ap.FirebaseAuthPlatform {
  String? uid = _ownerA;
  final changes = StreamController<void>.broadcast(sync: true);
  final forbiddenOperations = <String>[];

  void selectFixtureOwner(String? value) {
    uid = value;
    changes.add(null);
  }

  @override
  ap.FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  ap.FirebaseAuthPlatform setInitialValues({
    ap.PigeonUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;
  @override
  ap.UserPlatform? get currentUser =>
      uid == null ? null : _OwnerUser(this, uid!);

  Stream<ap.UserPlatform?> _watch() => Stream.multi((controller) {
        controller.add(currentUser);
        final subscription = changes.stream.listen((_) {
          controller.add(currentUser);
        });
        controller.onCancel = subscription.cancel;
      });

  @override
  Stream<ap.UserPlatform?> authStateChanges() => _watch();
  @override
  Stream<ap.UserPlatform?> idTokenChanges() => _watch();
  @override
  Stream<ap.UserPlatform?> userChanges() => _watch();
  @override
  Future<void> signOut() async {
    forbiddenOperations.add('signOut');
    throw StateError('Auth changes are forbidden in nickname tests');
  }
}

class _OwnerMultiFactor extends ap.MultiFactorPlatform {
  _OwnerMultiFactor(super.auth);
}

class _OwnerUser extends ap.UserPlatform {
  _OwnerUser(this.ownerAuth, String uid)
      : super(
          ownerAuth,
          _OwnerMultiFactor(ownerAuth),
          ap.PigeonUserDetails(
            userInfo: ap.PigeonUserInfo(
              uid: uid,
              email: uid == _ownerA ? _emailA : _emailB,
              displayName: _authName,
              isAnonymous: false,
              isEmailVerified: true,
            ),
            providerData: [],
          ),
        );
  final _OwnerAuth ownerAuth;

  @override
  Future<void> updateProfile(Map<String, String?> profile) async {
    ownerAuth.forbiddenOperations.add('updateProfile');
    throw StateError('Firebase Auth profile must not be updated');
  }
}

class _NoOwnerFunctions extends fu.FirebaseFunctionsPlatform {
  _NoOwnerFunctions() : super(null, 'asia-northeast1');
  final calls = <String>[];
  @override
  fu.FirebaseFunctionsPlatform delegateFor(
          {FirebaseApp? app, required String region}) =>
      this;
  @override
  fu.HttpsCallablePlatform httpsCallable(
      String? origin, String name, fu.HttpsCallableOptions options) {
    calls.add(name);
    throw StateError('No callable belongs to owner nickname editing');
  }
}

class _OwnerFirestore extends fp.FirebaseFirestorePlatform {
  final documents = <String, Map<String, dynamic>>{};
  final changes = StreamController<void>.broadcast(sync: true);
  final writes = <({String path, bool merge})>[];
  final reads = <String>[];
  final delayedReads = <String, Completer<void>>{};
  int _clock = 0;

  @override
  fp.FirebaseFirestorePlatform delegateFor({
    required FirebaseApp app,
    required String databaseId,
  }) =>
      this;
  @override
  fp.Settings get settings => const fp.Settings();
  @override
  fp.DocumentReferencePlatform doc(String path) => _OwnerDocument(this, path);
  @override
  fp.CollectionReferencePlatform collection(String path) =>
      _OwnerCollection(this, path);

  void guardRead(String path) {
    final allowed = [_ownerA, _ownerB].any((owner) =>
        path == _path(owner) || path == 'users/$owner/settings/notifications');
    if (!allowed) throw StateError('Unexpected synthetic read: $path');
    reads.add(path);
  }

  fp.DocumentSnapshotPlatform snapshot(String path) =>
      fp.DocumentSnapshotPlatform(
        this,
        path,
        documents[path] == null
            ? null
            : Map<String, dynamic>.from(documents[path]!),
        fp.PigeonSnapshotMetadata(isFromCache: false, hasPendingWrites: false),
      );

  Stream<fp.DocumentSnapshotPlatform> watch(String path) =>
      Stream.multi((controller) {
        guardRead(path);
        controller.add(snapshot(path));
        final subscription = changes.stream.listen((_) {
          controller.add(snapshot(path));
        });
        controller.onCancel = subscription.cancel;
      });

  void write(String path, Map<String, dynamic> data, fp.SetOptions? options) {
    if (path != _path(_ownerA) && path != _path(_ownerB)) {
      throw StateError('Only owner_profiles/main may be written: $path');
    }
    writes.add((path: path, merge: options?.merge == true));
    documents[path] = {
      if (options?.merge == true) ...?documents[path],
      for (final entry in data.entries)
        entry.key: entry.value is fp.FieldValuePlatform
            ? Timestamp.fromMillisecondsSinceEpoch(1794100000000 + _clock++)
            : entry.value,
    };
    changes.add(null);
  }

  void reset() {
    documents.clear();
    writes.clear();
    reads.clear();
    delayedReads.clear();
  }
}

class _OwnerDocument extends fp.DocumentReferencePlatform {
  _OwnerDocument(this.db, String path) : super(db, path);
  final _OwnerFirestore db;
  @override
  Future<fp.DocumentSnapshotPlatform> get(
      [fp.GetOptions options = const fp.GetOptions()]) async {
    db.guardRead(path);
    final snapshot = db.snapshot(path);
    final delay = db.delayedReads.remove(path);
    if (delay != null) await delay.future;
    return snapshot;
  }

  @override
  Stream<fp.DocumentSnapshotPlatform> snapshots({
    bool includeMetadataChanges = false,
    required fp.ListenSource listenSource,
  }) =>
      db.watch(path);
  @override
  Future<void> set(Map<String, dynamic> data, [fp.SetOptions? options]) async =>
      db.write(path, data, options);
}

class _OwnerCollection extends fp.CollectionReferencePlatform {
  _OwnerCollection(this.db, String path) : super(db, path);
  final _OwnerFirestore db;
  @override
  bool get isCollectionGroupQuery => false;
  @override
  fp.DocumentReferencePlatform doc([String? name]) =>
      db.doc('$path/${name ?? 'synthetic-auto-id'}');
}

// The real Settings UI calls MyApp.of for display preferences. This test-only
// shell retains that ancestor while bypassing application startup/FCM/analytics.
class _OwnerUiApp extends MyApp {
  const _OwnerUiApp({required this.dark, this.captureFont = false});
  final bool dark;
  final bool captureFont;
  @override
  State<MyApp> createState() => _OwnerUiAppState();
}

class _OwnerUiAppState extends MyAppState {
  // Do not invoke production startup or permission/token registration in tests.
  @override
  // ignore: must_call_super
  void initState() {}

  @override
  ThemeMode get themeMode =>
      (widget as _OwnerUiApp).dark ? ThemeMode.dark : ThemeMode.light;

  @override
  void setThemeMode(ThemeMode mode) =>
      throw StateError('Display preferences are not changed by nickname tests');

  @override
  Widget build(BuildContext context) {
    final testApp = widget as _OwnerUiApp;
    var theme = testApp.dark ? AppTheme.darkTheme : AppTheme.lightTheme;
    if (testApp.captureFont) {
      theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: _font),
        primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: _font),
        appBarTheme: theme.appBarTheme.copyWith(
          titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
            fontFamily: _font,
          ),
        ),
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      builder: (context, child) => RepaintBoundary(
        key: _captureKey,
        child: MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
      ),
      home: Builder(builder: (context) {
        return Scaffold(
          body: Column(
            children: [
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingScreen())),
                child: const Text('Open synthetic settings'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const OwnerProfileEditScreen())),
                child: const Text('Open synthetic owner editor'),
              ),
            ],
          ),
        );
      }),
    );
  }
}

OwnerProfile _profile([String? nickname]) => OwnerProfile(
      displayName: nickname,
      prefecture: '滋賀県',
      municipality: '大津市',
      ageRange: '30代',
      hamsterCareYears: 5,
    );

Map<String, dynamic> _savedOwner({String? nickname = 'もかの飼い主'}) => {
      if (nickname != null) 'displayName': nickname,
      'prefecture': '滋賀県',
      'municipality': '大津市',
      'ageRange': '30代',
      'hamsterCareYears': 5,
      'unrecognizedLegacyField': {'keep': true},
    };

Future<void> _frames(WidgetTester tester) async {
  for (var frame = 0; frame < 10; frame++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Future<void> _showApp(WidgetTester tester,
    {double width = 390, bool dark = false}) async {
  // Flutter's test binding installs its error handler after setUp. Scope this
  // exact known, pre-task Settings diagnostic to the actual widget test body.
  final originalErrorHandler = FlutterError.onError;
  var preexistingListTileWarnings = 0;
  FlutterError.onError = (details) {
    if (details.exception is FlutterError &&
        details.exceptionAsString().startsWith(
              'ListTile background color or ink splashes may be invisible.',
            )) {
      preexistingListTileWarnings++;
      return;
    }
    originalErrorHandler?.call(details);
  };
  addTearDown(() {
    FlutterError.onError = originalErrorHandler;
    if (preexistingListTileWarnings > 0) {
      debugPrint('Recorded existing Settings ListTile debug diagnostics: '
          '$preexistingListTileWarnings');
    }
  });
  tester.view.physicalSize = Size(width, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final capture = Platform.environment['HAMCARE_OWNER_NICKNAME_CAPTURE_DIR'];
  await tester.pumpWidget(_OwnerUiApp(
      dark: dark, captureFont: capture != null && Platform.isMacOS));
  await _frames(tester);
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.text('Open synthetic settings'));
  await _frames(tester);
}

Future<void> _openEditor(WidgetTester tester) async {
  await tester.tap(find.text('Open synthetic owner editor'));
  await _frames(tester);
}

Finder _nicknameInput() => find.byWidgetPredicate((widget) =>
    widget is TextField &&
    widget.decoration?.labelText?.startsWith('ニックネーム') == true);

Future<void> _saveEditor(WidgetTester tester) async {
  tester.binding.focusManager.primaryFocus?.unfocus();
  await tester.pump();
  final save = find.text('このプロフィールを保存する');
  await tester.scrollUntilVisible(
    save,
    300,
    scrollable: find
        .descendant(
          of: find.byType(OwnerProfileEditScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await _frames(tester);
  await tester.tap(save);
  await _frames(tester);
  // Let the existing save-feedback overlay finish; no extra UI action.
  await tester.pump(const Duration(seconds: 4));
}

Future<void> _disposeUi(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _frames(tester);
}

Future<void> _capture(WidgetTester tester, String filename) async {
  final directory = Platform.environment['HAMCARE_OWNER_NICKNAME_CAPTURE_DIR'];
  if (directory == null) return;
  await tester.runAsync(() async {
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(_captureKey));
    final image = await boundary.toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$directory/$filename.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final auth = _OwnerAuth();
  final db = _OwnerFirestore();
  final functions = _NoOwnerFunctions();
  HttpOverrides? previousHttp;

  setUpAll(() async {
    previousHttp = HttpOverrides.current;
    HttpOverrides.global = _NoOwnerNetwork();
    cp.FirebasePlatform.instance = _OwnerCore();
    ap.FirebaseAuthPlatform.instance = auth;
    fp.FirebaseFirestorePlatform.instance = db;
    fu.FirebaseFunctionsPlatform.instance = functions;
    PackageInfo.setMockInitialValues(
      appName: 'HamCare',
      packageName: 'com.gotainu.hamster',
      version: '1.0.1',
      buildNumber: '3',
      buildSignature: '',
    );
    if (Platform.environment['HAMCARE_OWNER_NICKNAME_CAPTURE_DIR'] != null &&
        Platform.isMacOS) {
      final bytes =
          await File('/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc').readAsBytes();
      await (FontLoader(_font)
            ..addFont(Future.value(ByteData.sublistView(bytes))))
          .load();
      final icons = await File(
              '/Users/gota/tools/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
          .readAsBytes();
      await (FontLoader('MaterialIcons')
            ..addFont(Future.value(ByteData.sublistView(icons))))
          .load();
    }
  });
  setUp(() {
    db.reset();
    auth.forbiddenOperations.clear();
    functions.calls.clear();
    auth.selectFixtureOwner(_ownerA);
  });
  tearDown(() {
    expect(functions.calls, isEmpty);
    expect(auth.forbiddenOperations, isEmpty);
    expect(FirebaseAuth.instance.currentUser?.displayName,
        anyOf(isNull, _authName));
    expect(db.writes.every((write) => write.merge), isTrue,
        reason: 'Existing merge-save semantics must be retained');
  });
  tearDownAll(() async {
    HttpOverrides.global = previousHttp;
    await db.changes.close();
    await auth.changes.close();
  });

  test('owner nickname trims and empty values remain optional', () {
    expect(_profile('  もかの飼い主  ').displayName, 'もかの飼い主');
    for (final blank in [null, '', ' ', '\n\t']) {
      expect(_profile(blank).displayName, isNull);
    }
  });

  test('legacy and malformed nickname fields preserve existing owner values',
      () {
    for (final invalid in [null, 42, false, <String, dynamic>{}]) {
      final data = _savedOwner(nickname: null);
      if (invalid != null) data['displayName'] = invalid;
      final owner = OwnerProfile.fromMap(data);
      expect(owner.displayName, isNull);
      expect(owner.prefecture, '滋賀県');
      expect(owner.municipality, '大津市');
      expect(owner.ageRange, '30代');
      expect(owner.hamsterCareYears, 5);
    }
  });

  test('nickname save map normalizes content and supports explicit clearing',
      () {
    expect(_profile('  ひまわり  ').toMapForSave()['displayName'], 'ひまわり');
    expect(_profile('  ').toMapForSave()['displayName'], isNull);
    final map = _profile().toMapForSave();
    expect(map['prefecture'], '滋賀県');
    expect(map['municipality'], '大津市');
    expect(map['ageRange'], '30代');
    expect(map['hamsterCareYears'], 5);
    expect(map['updatedAt'], isNotNull);
  });

  test(
      'merge nickname create update and clear persist across repository instances',
      () async {
    db.documents[_path(_ownerA)] = _savedOwner(nickname: null);
    await OwnerProfileRepo().save(_profile('  もか  '));
    expect((await OwnerProfileRepo().fetch())!.displayName, 'もか');
    await OwnerProfileRepo().save(_profile('  ひまわり  '));
    expect((await OwnerProfileRepo().fetch())!.displayName, 'ひまわり');
    await OwnerProfileRepo().save(_profile('  '));
    final reloaded = await OwnerProfileRepo().fetch();
    expect(reloaded!.displayName, isNull);
    expect(reloaded.prefecture, '滋賀県');
    expect(reloaded.municipality, '大津市');
    expect(reloaded.ageRange, '30代');
    expect(reloaded.hamsterCareYears, 5);
    expect(db.documents[_path(_ownerA)]!['unrecognizedLegacyField'],
        {'keep': true});
    expect(db.writes.length, 3);
    expect(db.documents.keys, [_path(_ownerA)]);
  });

  test('repositories isolate owners and reject stale or signed-out saves',
      () async {
    final repoA = OwnerProfileRepo();
    await repoA.save(_profile('Aの呼び名'));
    auth.selectFixtureOwner(_ownerB);
    final repoB = OwnerProfileRepo();
    expect(await repoB.fetch(), isNull);
    await repoB.save(_profile('Bの呼び名'));
    final writeCount = db.writes.length;
    await expectLater(repoA.save(_profile('誤保存してはいけない')), throwsStateError);
    expect(await repoA.fetch(), isNull);
    expect(db.writes.length, writeCount);
    expect((await repoB.fetch())!.displayName, 'Bの呼び名');
    auth.selectFixtureOwner(_ownerA);
    expect((await OwnerProfileRepo().fetch())!.displayName, 'Aの呼び名');
    auth.selectFixtureOwner(null);
    final signedOutRepo = OwnerProfileRepo();
    expect(await signedOutRepo.fetch(), isNull);
    await expectLater(signedOutRepo.save(_profile('禁止')), throwsStateError);
    expect(db.writes.length, writeCount);
    expect(db.documents[_path(_ownerA)]!['displayName'], 'Aの呼び名');
    expect(db.documents[_path(_ownerB)]!['displayName'], 'Bの呼び名');
  });

  test(
      'an asynchronous fetch cannot return the previous owner after UID change',
      () async {
    db.documents[_path(_ownerA)] = _savedOwner(nickname: '前の利用者');
    final barrier = Completer<void>();
    db.delayedReads[_path(_ownerA)] = barrier;
    final pending = OwnerProfileRepo().fetch();
    await Future<void>.delayed(Duration.zero);
    expect(db.reads, contains(_path(_ownerA)));
    auth.selectFixtureOwner(_ownerB);
    barrier.complete();
    expect(await pending, isNull);
    expect(db.writes, isEmpty);
  });

  testWidgets('real editor saves reopens and clears the optional nickname',
      (tester) async {
    db.documents[_path(_ownerA)] = _savedOwner(nickname: '以前の名前');
    await _showApp(tester);
    await _openEditor(tester);
    expect(
        tester.widget<TextField>(_nicknameInput()).controller!.text, '以前の名前');
    // Capture the normal page position, before test input scrolls to the caret.
    // Native IME layout is outside this offline Widget test.
    await _capture(tester, 'owner_nickname_editor_390');
    await tester.enterText(_nicknameInput(), '  新しい呼び名  ');
    await _saveEditor(tester);
    expect(db.documents[_path(_ownerA)]!['displayName'], '新しい呼び名');
    await tester.pageBack();
    await _frames(tester);
    await _openEditor(tester);
    expect(
        tester.widget<TextField>(_nicknameInput()).controller!.text, '新しい呼び名');
    await tester.enterText(_nicknameInput(), '  ');
    await _saveEditor(tester);
    expect(db.documents[_path(_ownerA)]!['displayName'], isNull);
    final owner = await OwnerProfileRepo().fetch();
    expect(owner!.prefecture, '滋賀県');
    expect(owner.municipality, '大津市');
    expect(owner.ageRange, '30代');
    expect(owner.hamsterCareYears, 5);
    expect(db.documents[_path(_ownerA)]!['unrecognizedLegacyField'],
        {'keep': true});
    expect(db.writes.length, 2);
    expect(tester.takeException(), isNull);
    await _disposeUi(tester);
  });

  testWidgets('an open editor cannot save a draft into a different owner',
      (tester) async {
    db.documents[_path(_ownerA)] = _savedOwner(nickname: 'Aの既存名');
    db.documents[_path(_ownerB)] = _savedOwner(nickname: 'Bの既存名');
    await _showApp(tester);
    await _openEditor(tester);
    await tester.enterText(_nicknameInput(), 'Aの編集中の名前');
    auth.selectFixtureOwner(_ownerB);
    await _saveEditor(tester);
    expect(db.writes, isEmpty);
    expect(db.documents[_path(_ownerA)]!['displayName'], 'Aの既存名');
    expect(db.documents[_path(_ownerB)]!['displayName'], 'Bの既存名');
    expect(tester.takeException(), isNull);
    await _disposeUi(tester);
  });

  testWidgets(
      'settings reopens with the nickname saved through the real editor',
      (tester) async {
    db.documents[_path(_ownerA)] = _savedOwner(nickname: '最初の呼び名');
    await _showApp(tester);
    await _openSettings(tester);
    expect(find.text('最初の呼び名'), findsOneWidget);
    expect(find.text(_emailA), findsOneWidget);
    await tester.pageBack();
    await _frames(tester);
    await _openEditor(tester);
    await tester.enterText(_nicknameInput(), '再表示の呼び名');
    await _saveEditor(tester);
    await tester.pageBack();
    await _frames(tester);
    await _openSettings(tester);
    expect(find.text('再表示の呼び名'), findsOneWidget);
    expect(find.text('最初の呼び名'), findsNothing);
    expect(find.text(_emailA), findsOneWidget);
    await _disposeUi(tester);
    // Recreate the entire UI with the same persisted synthetic document.
    await _showApp(tester);
    await _openSettings(tester);
    expect(find.text('再表示の呼び名'), findsOneWidget);
    expect(find.text(_emailA), findsOneWidget);
    expect(db.writes.length, 1);
    expect(tester.takeException(), isNull);
    await _disposeUi(tester);
  });

  for (final legacyName in [null, '  ']) {
    testWidgets(
        'settings keeps account/email fallback for nickname $legacyName',
        (tester) async {
      db.documents[_path(_ownerA)] = _savedOwner(nickname: legacyName);
      await _showApp(tester);
      await _openSettings(tester);
      expect(find.text('アカウント'), findsOneWidget);
      expect(find.text(_emailA), findsOneWidget);
      expect(db.writes, isEmpty);
      expect(tester.takeException(), isNull);
      await _disposeUi(tester);
    });
  }

  testWidgets('open settings replaces nickname and email when UID changes',
      (tester) async {
    db.documents[_path(_ownerA)] = _savedOwner(nickname: 'Aだけの呼び名');
    db.documents[_path(_ownerB)] = _savedOwner(nickname: 'Bだけの呼び名');
    await _showApp(tester);
    await _openSettings(tester);
    expect(find.text('Aだけの呼び名'), findsOneWidget);
    auth.selectFixtureOwner(_ownerB);
    await _frames(tester);
    expect(find.text('Bだけの呼び名'), findsOneWidget);
    expect(find.text(_emailB), findsOneWidget);
    expect(find.text('Aだけの呼び名'), findsNothing);
    expect(find.text(_emailA), findsNothing);
    auth.selectFixtureOwner(null);
    await _frames(tester);
    expect(find.text('Bだけの呼び名'), findsNothing);
    expect(find.text(_emailB), findsNothing);
    expect(db.writes, isEmpty);
    expect(tester.takeException(), isNull);
    await _disposeUi(tester);
  });

  testWidgets('late settings fetch never paints a previous owners nickname',
      (tester) async {
    db.documents[_path(_ownerA)] = _savedOwner(nickname: '遅れたAの呼び名');
    db.documents[_path(_ownerB)] = _savedOwner(nickname: '現在Bの呼び名');
    final barrier = Completer<void>();
    db.delayedReads[_path(_ownerA)] = barrier;
    await _showApp(tester);
    await _openSettings(tester);
    expect(db.reads, contains(_path(_ownerA)));
    auth.selectFixtureOwner(_ownerB);
    await _frames(tester);
    expect(find.text('現在Bの呼び名'), findsOneWidget);
    barrier.complete();
    await _frames(tester);
    expect(find.text('遅れたAの呼び名'), findsNothing);
    expect(find.text('現在Bの呼び名'), findsOneWidget);
    expect(find.text(_emailA), findsNothing);
    expect(db.writes, isEmpty);
    expect(tester.takeException(), isNull);
    await _disposeUi(tester);
  });

  for (final dark in [false, true]) {
    for (final width in [320.0, 390.0]) {
      testWidgets('long nickname remains readable at ${width}px ($dark)',
          (tester) async {
        const nickname = 'ハムスターとゆっくり暮らす飼い主さん';
        db.documents[_path(_ownerA)] = _savedOwner(nickname: nickname);
        await _showApp(tester, width: width, dark: dark);
        await _openSettings(tester);
        expect(find.text(nickname), findsOneWidget);
        expect(find.text(_emailA), findsOneWidget);
        final bounds = tester.getRect(find.text(nickname));
        final screen = tester.getRect(find.byType(SettingScreen));
        expect(bounds.left, greaterThanOrEqualTo(screen.left));
        expect(bounds.right, lessThanOrEqualTo(screen.right));
        expect(bounds.width, greaterThan(0));
        expect(tester.takeException(), isNull);
        expect(db.writes, isEmpty);
        await _capture(tester,
            'owner_nickname_${dark ? 'dark' : 'light'}_${width.toInt()}');
        await _disposeUi(tester);
      });
    }
  }
}

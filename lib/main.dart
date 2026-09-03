import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';
import 'package:hamster_project/screens/auth.dart';
import 'package:hamster_project/screens/onboarding_screen.dart';
import 'package:hamster_project/screens/setup_checklist_screen.dart';
import 'package:hamster_project/screens/splash.dart';
import 'package:hamster_project/screens/tabs.dart';
import 'package:hamster_project/services/app_analytics.dart';
import 'package:hamster_project/services/notification_token_repo.dart';
import 'package:hamster_project/services/onboarding_state_repo.dart';
import 'package:hamster_project/theme/app_theme.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<TabsScreenState> tabsScreenKey = GlobalKey<TabsScreenState>();

const AndroidNotificationChannel _highImportanceChannel =
    AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'Foreground 受信用の通知チャンネルです。',
  importance: Importance.max,
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint(
    '[FCM background] title=${message.notification?.title}, '
    'body=${message.notification?.body}, data=${message.data}',
  );
}

bool _isAnomalyPayload(Map<String, dynamic> data) {
  return data['type'] == 'anomaly';
}

Future<void> _openAnomalyFromNotification(
  Map<String, dynamic> data, {
  required String source,
}) async {
  debugPrint('[notification route] data=$data');

  final isAnomaly = _isAnomalyPayload(data);
  await AppAnalytics.logNotificationOpened(
    source: source,
    notificationType: isAnomaly ? 'anomaly' : 'other',
  );

  if (!isAnomaly) return;

  await Future<void>.delayed(const Duration(milliseconds: 350));

  final tabsState = tabsScreenKey.currentState;
  if (tabsState != null) {
    await tabsState.openHomeAnomalyCard();
    return;
  }

  scaffoldMessengerKey.currentState?.showSnackBar(
    const SnackBar(
      content: Text('通知を開きました。Homeで最近の気になる変化を確認できます。'),
    ),
  );
}

Map<String, dynamic> _payloadToMap(String? payload) {
  if (payload == null || payload.trim().isEmpty) {
    return const <String, dynamic>{};
  }

  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
  } catch (e) {
    debugPrint('[notification payload decode error] $e');
  }

  return const <String, dynamic>{};
}

Future<void> _initLocalNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

  const darwinSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  const settings = InitializationSettings(
    android: androidSettings,
    iOS: darwinSettings,
    macOS: darwinSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(
    settings,
    onDidReceiveNotificationResponse: (response) {
      final data = _payloadToMap(response.payload);
      unawaited(
        _openAnomalyFromNotification(
          data,
          source: 'local_notification',
        ),
      );
    },
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_highImportanceChannel);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAppCheck.instance.activate(
    androidProvider:
        kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
  );

  await _initLocalNotifications();

  FirebaseMessaging.onBackgroundMessage(
    _firebaseMessagingBackgroundHandler,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<MyAppState>()!;

  @override
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  final NotificationTokenRepo _notificationTokenRepo = NotificationTokenRepo();

  ThemeMode _themeMode = ThemeMode.dark;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<String>? _tokenRefreshSub;
  bool _fcmInitialized = false;

  void setThemeMode(ThemeMode mode) => setState(() => _themeMode = mode);
  ThemeMode get themeMode => _themeMode;

  @override
  void initState() {
    super.initState();
    unawaited(_initFcm());
  }

  Future<void> _initFcm() async {
    if (_fcmInitialized) return;
    _fcmInitialized = true;

    final messaging = FirebaseMessaging.instance;

    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint(
        '[FCM permission] authorizationStatus=${settings.authorizationStatus}',
      );
    } catch (e, st) {
      debugPrint('[FCM permission error] $e');
      debugPrint('$st');
    }

    try {
      final initialToken = await _getFcmTokenWhenReady(messaging);
      debugPrint('[FCM initial token] ${initialToken ?? 'null'}');

      if (initialToken != null) {
        await _saveFcmToken(initialToken);
      }
    } catch (e, st) {
      debugPrint('[FCM getToken error] $e');
      debugPrint('$st');
    }

    _tokenRefreshSub = messaging.onTokenRefresh.listen((token) async {
      debugPrint('[FCM token refresh] $token');
      await _saveFcmToken(token);
    });

    FirebaseMessaging.onMessage.listen((message) async {
      debugPrint(
        '[FCM foreground] title=${message.notification?.title}, '
        'body=${message.notification?.body}, data=${message.data}',
      );

      final title = message.notification?.title ?? 'お知らせ';
      final body = message.notification?.body ?? '';
      final payload = jsonEncode(message.data);

      await flutterLocalNotificationsPlugin.show(
        message.hashCode,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'Foreground 受信用の通知チャンネルです。',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: payload,
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint(
        '[FCM opened] title=${message.notification?.title}, '
        'body=${message.notification?.body}, data=${message.data}',
      );

      unawaited(
        _openAnomalyFromNotification(
          message.data,
          source: 'push_background',
        ),
      );
    });

    try {
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint(
          '[FCM initialMessage] title=${initialMessage.notification?.title}, '
          'body=${initialMessage.notification?.body}, data=${initialMessage.data}',
        );

        unawaited(
          _openAnomalyFromNotification(
            initialMessage.data,
            source: 'push_cold_start',
          ),
        );
      }
    } catch (e, st) {
      debugPrint('[FCM getInitialMessage error] $e');
      debugPrint('$st');
    }

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) return;

      try {
        final token = await _getFcmTokenWhenReady(messaging);
        debugPrint('[FCM authState token] ${token ?? 'null'}');

        if (token != null) {
          await _saveFcmToken(token);
        }
      } catch (e, st) {
        debugPrint('[FCM authState getToken error] $e');
        debugPrint('$st');
      }
    });
  }

  Future<String?> _getFcmTokenWhenReady(
    FirebaseMessaging messaging,
  ) async {
    final isApplePlatform = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);

    if (isApplePlatform) {
      final apnsToken = await messaging.getAPNSToken();
      if (apnsToken == null) {
        debugPrint("[FCM token skipped] APNs token is not available yet");
        return null;
      }
    }

    return messaging.getToken();
  }

  Future<void> _saveFcmToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[FCM save skipped] currentUser is null');
      return;
    }

    try {
      await _notificationTokenRepo.saveToken(
        token: token,
        platform: _platformName(),
      );
      debugPrint('[FCM token saved] uid=${user.uid}');
    } catch (e, st) {
      debugPrint('[FCM save error] $e');
      debugPrint('$st');
    }
  }

  String _platformName() {
    if (kIsWeb) return 'web';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _tokenRefreshSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'Hamster Care',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja'),
        Locale('en'),
      ],
      locale: const Locale('ja'),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (!snapshot.hasData) {
          return const AuthScreen();
        }

        return const _OnboardingGate();
      },
    );
  }
}

class _OnboardingGate extends StatelessWidget {
  const _OnboardingGate();

  @override
  Widget build(BuildContext context) {
    final repo = OnboardingStateRepo();

    return StreamBuilder<OnboardingState>(
      stream: repo.watchState(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        final state = snapshot.data ?? OnboardingState.initial();

        if (!state.introCompleted) {
          return OnboardingScreen(
            onFinished: () async {
              await repo.markIntroCompleted();
            },
          );
        }

        if (!state.setupChecklistViewed) {
          return SetupChecklistScreen(
            onFinished: () {
              // SetupChecklistScreen 側で markSetupChecklistViewed() 済み。
              // Stream更新後、このGateが自動でTabsScreenへ切り替える。
            },
          );
        }

        return TabsScreen(key: tabsScreenKey);
      },
    );
  }
}

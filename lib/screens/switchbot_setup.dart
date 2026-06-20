// lib/screens/switchbot_setup.dart
// SwitchBot: TOKEN/SECRET の保存 → デバイス一覧から温湿度計を選ぶ（Device ID 自動保存）

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/widgets/paid_feature_gate.dart';

class _SwitchbotGuideStep {
  const _SwitchbotGuideStep({
    required this.stepLabel,
    required this.title,
    required this.description,
    required this.imageAssetPath,
    required this.fallbackIcon,
  });

  final String stepLabel;
  final String title;
  final String description;
  final String imageAssetPath;
  final IconData fallbackIcon;
}

class SwitchbotSetupScreen extends StatelessWidget {
  const SwitchbotSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'SwitchBot連携設定',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient:
                isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
          ),
          child: const SafeArea(
            top: false,
            child: PaidFeatureGate(
              featureName: 'SwitchBot連携',
              lockedTitle: 'SwitchBot連携は有料プランの機能です',
              lockedMessage:
                  '温湿度の自動記録、環境評価、異常検知通知に使うSwitchBot連携は、有料プランで利用できます。',
              icon: Icons.thermostat_rounded,
              showBackground: false,
              child: _SwitchbotSetupContent(),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchbotSetupContent extends StatefulWidget {
  const _SwitchbotSetupContent();

  @override
  State<_SwitchbotSetupContent> createState() => _SwitchbotSetupContentState();
}

class _SwitchbotSetupContentState extends State<_SwitchbotSetupContent> {
  static const List<_SwitchbotGuideStep> _guideSteps = [
    _SwitchbotGuideStep(
      stepLabel: 'STEP 1',
      title: 'SwitchBotアプリとハブを準備',
      description:
          'SwitchBot公式アプリをインストールし、温湿度計とハブをアプリに追加します。温湿度データをクラウド経由で取得できる状態にしておきます。',
      imageAssetPath: 'assets/images/switchbot_guide_01_prepare_hub_app.png',
      fallbackIcon: Icons.hub_rounded,
    ),
    _SwitchbotGuideStep(
      stepLabel: 'STEP 2',
      title: 'SwitchBotアプリを開く',
      description: 'SwitchBot公式アプリを起動し、画面右下のプロフィールへ進みます。',
      imageAssetPath: 'assets/images/switchbot_guide_02_open_app.png',
      fallbackIcon: Icons.phone_android_rounded,
    ),
    _SwitchbotGuideStep(
      stepLabel: 'STEP 3',
      title: 'プロフィールから設定へ進む',
      description: 'プロフィール画面から設定を開き、アプリ情報を確認できる画面へ進みます。',
      imageAssetPath: 'assets/images/switchbot_guide_03_profile_settings.png',
      fallbackIcon: Icons.account_circle_rounded,
    ),
    _SwitchbotGuideStep(
      stepLabel: 'STEP 4',
      title: 'アプリバージョンを連続タップ',
      description: 'アプリバージョンを5〜15回ほど連続タップすると、開発者向けオプションが表示されます。',
      imageAssetPath: 'assets/images/switchbot_guide_04_tap_version.png',
      fallbackIcon: Icons.touch_app_rounded,
    ),
    _SwitchbotGuideStep(
      stepLabel: 'STEP 5',
      title: 'TOKEN / SECRET をコピー',
      description: '開発者向けオプションを開き、TOKENとSECRETをコピーします。',
      imageAssetPath: 'assets/images/switchbot_guide_05_token_secret.png',
      fallbackIcon: Icons.vpn_key_rounded,
    ),
    _SwitchbotGuideStep(
      stepLabel: 'STEP 6',
      title: 'このアプリで認証する',
      description: 'TOKENとSECRETを貼り付けて保存し、記録に使う温湿度計を選択します。',
      imageAssetPath: 'assets/images/switchbot_guide_06_select_meter.png',
      fallbackIcon: Icons.sensors_rounded,
    ),
  ];

  final _formKey = GlobalKey<FormState>();
  final _tokenCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();

  bool _saving = false;
  bool _canPickDevices = false;
  bool _disabling = false;
  bool _hasSecrets = false;
  bool _loading = false;
  bool _polling = false;

  String? _selectedDeviceId;
  String? _selectedDeviceName;
  String? _selectedDeviceType;

  String? _status;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Map<String, dynamic>? _secretEcho;

  FirebaseFunctions get _fns => FirebaseFunctions.instanceFor(
        app: Firebase.app(),
        region: 'asia-northeast1',
      );

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool get _hasSelectedMeter =>
      _selectedDeviceId != null && _selectedDeviceId!.trim().isNotEmpty;

  int get _completedSetupSteps {
    if (!_hasSecrets) return 0;
    if (!_hasSelectedMeter) return 1;
    return 2;
  }

  String get _connectionStateTitle {
    if (!_hasSecrets) {
      return '未連携です';
    }

    if (!_hasSelectedMeter) {
      return '認証情報は保存済みです';
    }

    return '連携は完了しています';
  }

  String get _connectionStateDescription {
    if (!_hasSecrets) {
      return 'TOKEN/SECRETを保存すると、温湿度計を選択できるようになります。';
    }

    if (!_hasSelectedMeter) {
      return '次に、記録に使うSwitchBot温湿度計を選択してください。';
    }

    return '温湿度計のデータを取得できる状態です。環境評価やAI相談に活用できます。';
  }

  IconData get _connectionStateIcon {
    if (!_hasSecrets) {
      return Icons.link_off_rounded;
    }

    if (!_hasSelectedMeter) {
      return Icons.verified_user_rounded;
    }

    return Icons.check_circle_rounded;
  }

  Color _connectionStateColor(BuildContext context) {
    if (!_hasSecrets) {
      return AppTheme.secondaryText(context);
    }

    if (!_hasSelectedMeter) {
      return AppTheme.accent;
    }

    return const Color(0xFF00D6A3);
  }

  Future<void> _loadCurrent({bool forceServer = false}) async {
    setState(() => _loading = true);

    final userRef = FirebaseFirestore.instance.collection('users').doc(_uid);
    final options = forceServer
        ? const GetOptions(source: Source.server)
        : const GetOptions(source: Source.serverAndCache);

    String? selectedDeviceId;
    String? selectedDeviceName;
    String? selectedDeviceType;

    final devDoc =
        await userRef.collection('integrations').doc('switchbot').get(options);

    if (devDoc.exists) {
      final m = devDoc.data()!;
      selectedDeviceId = m['meterDeviceId'] as String?;
      selectedDeviceName = m['meterDeviceName'] as String?;
      selectedDeviceType = m['meterDeviceType'] as String?;
    }

    final secDoc = await userRef
        .collection('integrations')
        .doc('switchbot_secrets')
        .get(options);

    final data = secDoc.data();

    bool hasSecrets = false;

    final v2 = data?['v2_encrypted'];
    if (v2 is Map) {
      hasSecrets =
          (v2['token'] is String && (v2['token'] as String).isNotEmpty) &&
              (v2['secret'] is String && (v2['secret'] as String).isNotEmpty);
    }

    if (!hasSecrets) {
      final v1p = data?['v1_plain'];
      if (v1p is Map) {
        hasSecrets = (v1p['token'] is String &&
                (v1p['token'] as String).isNotEmpty) &&
            (v1p['secret'] is String && (v1p['secret'] as String).isNotEmpty);
      }
    }

    if (!hasSecrets) {
      final v1 = data?['v1'];
      if (v1 is Map) {
        hasSecrets =
            (v1['token'] is String && (v1['token'] as String).isNotEmpty) &&
                (v1['secret'] is String && (v1['secret'] as String).isNotEmpty);
      }
    }

    Map<String, dynamic>? echo;
    if (hasSecrets) {
      try {
        final callable = _fns.httpsCallable('switchbotDebugEcho');
        final res = await callable.call();
        echo = (res.data is Map)
            ? Map<String, dynamic>.from(res.data as Map)
            : null;
      } catch (_) {}
    }

    if (!mounted) return;

    setState(() {
      _selectedDeviceId = selectedDeviceId;
      _selectedDeviceName = selectedDeviceName;
      _selectedDeviceType = selectedDeviceType;

      _hasSecrets = hasSecrets;
      _canPickDevices = hasSecrets;
      _secretEcho = echo;
      _status = hasSecrets
          ? '資格情報は保存済みです。温湿度計を選択してください。'
          : 'まだ資格情報がありません。TOKEN/SECRET を保存してください。';
      _loading = false;
    });
  }

  Future<void> _saveSecrets() async {
    if (!_formKey.currentState!.validate()) return;

    final token = _tokenCtrl.text.trim();
    final secret = _secretCtrl.text.trim();

    setState(() {
      _saving = true;
      _status = 'SwitchBot 資格情報を検証中...';
    });

    try {
      final callable = _fns.httpsCallable('registerSwitchbotSecrets');
      final res = await callable.call(<String, dynamic>{
        'token': token,
        'secret': secret,
      });

      final data = (res.data is Map)
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};

      final ok = data['ok'] == true;
      final verified = data['verified'] == true;

      if (!ok || !verified) {
        throw FirebaseFunctionsException(
          code: 'unknown',
          message: '検証に失敗しました（サーバ応答が不正です）。',
          details: data,
        );
      }

      final secRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('integrations')
          .doc('switchbot_secrets');

      final secSnap = await secRef.get(const GetOptions(source: Source.server));
      final existsNow = secSnap.exists;

      if (!mounted) return;

      setState(() {
        _hasSecrets = true;
        _canPickDevices = true;
        _status = '認証OK：資格情報を保存しました。次に温湿度計を選択してください。';
      });

      _showSnack(
        existsNow
            ? 'SwitchBot 認証OK：保存確認できました'
            : 'Functionsは成功しましたが、Firestoreの保存確認ができませんでした',
      );

      await _autoPickIfSingleMeter();
      await _loadCurrent(forceServer: true);
    } on FirebaseFunctionsException catch (e) {
      final msg = e.message ?? '不明なエラー';
      _showSnack('検証に失敗: $msg');
      if (mounted) {
        setState(() => _status = '検証に失敗: $msg');
      }
    } catch (e) {
      _showSnack('検証に失敗: $e');
      if (mounted) {
        setState(() => _status = '検証に失敗: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchDevicesOrThrow() async {
    final callable = _fns.httpsCallable('listSwitchbotDevices');
    final res = await callable.call();

    final normalized =
        jsonDecode(jsonEncode(res.data)) as Map<String, dynamic>?;

    final List devices = (normalized?['devices'] is List)
        ? List.from(normalized!['devices'] as List)
        : (normalized?['body'] is Map &&
                (normalized!['body'] as Map)['deviceList'] is List)
            ? List.from(
                (normalized['body'] as Map)['deviceList'] as List,
              )
            : const [];

    if (devices.isEmpty) {
      throw Exception('デバイスが見つかりませんでした');
    }

    return devices
        .whereType<Map>()
        .map(
          (e) => Map<String, dynamic>.fromEntries(
            e.entries.map((kv) => MapEntry(kv.key.toString(), kv.value)),
          ),
        )
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _filterMeters(List<Map<String, dynamic>> all) {
    const meterKeywords = <String>{
      'meter',
      'meterplus',
      'thsensor',
      'woiosensor',
      'temperature',
      'humidity',
    };

    final result = <Map<String, dynamic>>[];

    for (final m in all) {
      final t = (m['deviceType']?.toString() ?? '').toLowerCase();
      if (t.isNotEmpty && meterKeywords.any((k) => t.contains(k))) {
        result.add(m);
      }
    }

    return result;
  }

  Future<void> _autoPickIfSingleMeter() async {
    try {
      final devices = await _fetchDevicesOrThrow();
      final meters = _filterMeters(devices);

      if (meters.length == 1) {
        final m = meters.first;
        await _saveChosenDevice(
          id: (m['deviceId'] ?? '').toString(),
          name: (m['deviceName'] ?? '').toString(),
          type: (m['deviceType'] ?? '').toString(),
        );
        _showSnack(
          '温湿度計を自動選択しました: ${m['deviceName'] ?? m['deviceId']}',
        );
      }
    } catch (_) {}
  }

  Future<void> _pickDeviceFromCloud() async {
    try {
      if (!_canPickDevices) {
        _showSnack('先に TOKEN/SECRET を保存してください。');
        return;
      }

      final all = await _fetchDevicesOrThrow();
      final meters = _filterMeters(all);

      if (meters.isEmpty) {
        _showSnack('温湿度計が見つかりませんでした。SwitchBotアプリで所有デバイスをご確認ください。');
        return;
      }

      if (!mounted) return;

      final picked = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetCtx) {
          return DraggableScrollableSheet(
            expand: false,
            builder: (_, controller) => ListView.builder(
              controller: controller,
              itemCount: meters.length,
              itemBuilder: (_, index) {
                final d = meters[index];
                return ListTile(
                  leading: const Icon(Icons.thermostat_rounded),
                  title: Text(d['deviceName']?.toString() ?? '（名前なし）'),
                  subtitle: Text('${d['deviceType']} • ${d['deviceId']}'),
                  onTap: () => Navigator.of(sheetCtx).pop(d),
                );
              },
            ),
          );
        },
      );

      if (picked != null) {
        final m = Map<String, dynamic>.fromEntries(
          picked.entries.map((kv) => MapEntry(kv.key.toString(), kv.value)),
        );

        await _saveChosenDevice(
          id: (m['deviceId'] ?? '').toString(),
          name: (m['deviceName'] ?? '').toString(),
          type: (m['deviceType'] ?? '').toString(),
        );

        _showSnack('Device ID を保存しました');
      }
    } catch (e) {
      _showSnack('デバイス取得に失敗: $e');
    }
  }

  Future<void> _saveChosenDevice({
    required String id,
    required String name,
    required String type,
  }) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('integrations')
        .doc('switchbot')
        .set(
      {
        'meterDeviceId': id,
        'meterDeviceName': name,
        'meterDeviceType': type,
        'enabled': true,
        'hasSecrets': true,
        'disabledAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (!mounted) return;

    setState(() {
      _selectedDeviceId = id;
      _selectedDeviceName = name;
      _selectedDeviceType = type;
      _status = 'デバイスを保存しました。';
    });

    await _pollNowOnce();
  }

  Future<void> _confirmAndDisableIntegration() async {
    if (_disabling) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('SwitchBot連携を解除しますか？'),
          content: const Text(
            'TOKEN/SECRETと選択中の温湿度計を解除します。過去の温湿度記録は通常残します。\n\n'
            '解除後にもう一度使う場合は、TOKEN/SECRETの保存と温湿度計の選択をやり直してください。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('解除する'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!mounted) return;

    await _disableIntegration();
  }

  Future<void> _disableIntegration({bool deleteReadings = false}) async {
    setState(() {
      _disabling = true;
      _status = 'SwitchBot 連携を解除しています...';
    });

    try {
      final callable = _fns.httpsCallable('disableSwitchbotIntegration');
      await callable.call(<String, dynamic>{
        'deleteReadings': deleteReadings,
      });

      if (!mounted) return;

      setState(() {
        _hasSecrets = false;
        _secretEcho = null;

        _canPickDevices = false;
        _selectedDeviceId = null;
        _selectedDeviceName = null;
        _selectedDeviceType = null;

        _tokenCtrl.clear();
        _secretCtrl.clear();

        _status = 'SwitchBot 連携を解除しました。TOKEN/SECRET を保存し直してください。';
      });

      _showSnack('SwitchBot 連携を解除しました');

      await _loadCurrent(forceServer: true);
    } on FirebaseFunctionsException catch (e) {
      _showSnack('連携解除に失敗: ${e.message}');
      if (mounted) setState(() => _status = 'エラー: ${e.message}');
    } catch (e) {
      _showSnack('連携解除に失敗: $e');
      if (mounted) setState(() => _status = 'エラー: $e');
    } finally {
      if (mounted) setState(() => _disabling = false);
    }
  }

  Future<void> _pollNowOnce() async {
    setState(() {
      _polling = true;
      _status = 'SwitchBotから最新データを取得しています...';
    });

    try {
      final callable = _fns.httpsCallable('pollMySwitchbotNow');
      final res = await callable.call();

      final data = (res.data is Map)
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};

      if (data['ok'] == true) {
        _showSnack('最新データを取得しました');
        if (mounted) {
          setState(() => _status = '最新データを取得しました。グラフに反映されます。');
        }
      } else {
        final msg = data['error']?.toString() ?? '不明なエラー';
        _showSnack('取得できませんでした: $msg');
        if (mounted) setState(() => _status = '取得できませんでした: $msg');
      }
    } on FirebaseFunctionsException catch (e) {
      _showSnack('取得に失敗: ${e.message}');
      if (mounted) setState(() => _status = '取得に失敗: ${e.message}');
    } catch (e) {
      _showSnack('取得に失敗: $e');
      if (mounted) setState(() => _status = '取得に失敗: $e');
    } finally {
      if (mounted) setState(() => _polling = false);
    }
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.secondaryText(context),
                ),
          ),
        ],
      ),
    );
  }

  Widget _surfaceCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardInnerDark : AppTheme.cardInnerLight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.quickActionBorder(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.softShadow(context),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _headerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: AppTheme.cardGradient(
          Theme.of(context).brightness == Brightness.dark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.thermostat_rounded,
            color: AppTheme.accent,
            size: 42,
          ),
          const SizedBox(height: 14),
          Text(
            'SwitchBot連携',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '温湿度計のデータを自動で記録し、環境評価やAI相談に活用します。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.secondaryText(context),
                ),
          ),
        ],
      ),
    );
  }

  Widget _connectionStateCard() {
    final completed = _completedSetupSteps;
    final accentColor = _connectionStateColor(context);

    return _surfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.chipFill(accentColor, context, opacity: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _connectionStateIcon,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _connectionStateTitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _connectionStateDescription,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText(context),
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: completed / 2,
                    minHeight: 7,
                    backgroundColor: AppTheme.chipFill(AppTheme.accent, context,
                        opacity: 0.10),
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$completed / 2 完了',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.tertiaryText(context),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _guideEntryCard() {
    return _surfaceCard(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _showConnectionGuide,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    AppTheme.chipFill(AppTheme.accent, context, opacity: 0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '連携の流れを見る',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SwitchBotアプリの準備からTOKEN/SECRET取得、温湿度計の選択まで確認できます。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.secondaryText(context),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }

  Future<void> _showConnectionGuide() async {
    final pageController = PageController();
    var currentPage = 0;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final isLastPage = currentPage == _guideSteps.length - 1;

            return FractionallySizedBox(
              heightFactor: 0.92,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkBg : AppTheme.lightBg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.weakText(sheetContext),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'SwitchBot連携の流れ',
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: PageView.builder(
                          controller: pageController,
                          itemCount: _guideSteps.length,
                          onPageChanged: (index) {
                            setModalState(() {
                              currentPage = index;
                            });
                          },
                          itemBuilder: (_, index) {
                            return _guidePage(
                              context: sheetContext,
                              step: _guideSteps[index],
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                _guideSteps.length,
                                (index) {
                                  final selected = index == currentPage;

                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: selected ? 22 : 8,
                                    height: 8,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? AppTheme.accent
                                          : AppTheme.weakText(sheetContext),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: currentPage == 0
                                        ? null
                                        : () {
                                            pageController.previousPage(
                                              duration: const Duration(
                                                  milliseconds: 240),
                                              curve: Curves.easeOut,
                                            );
                                          },
                                    child: const Text('戻る'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: FilledButton(
                                    onPressed: () {
                                      if (isLastPage) {
                                        Navigator.of(sheetContext).pop();
                                        return;
                                      }

                                      pageController.nextPage(
                                        duration:
                                            const Duration(milliseconds: 240),
                                        curve: Curves.easeOut,
                                      );
                                    },
                                    child: Text(isLastPage ? '閉じる' : '次へ'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    pageController.dispose();
  }

  Widget _guidePage({
    required BuildContext context,
    required _SwitchbotGuideStep step,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardInnerDark : AppTheme.cardInnerLight,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.quickActionBorder(context),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.stepLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                step.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                step.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.secondaryText(context),
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: double.infinity,
                  height: 300,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(10),
                  color: isDark
                      ? const Color(0xFF20243A)
                      : const Color(0xFFEFF3FA),
                  child: Image.asset(
                    step.imageAssetPath,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) {
                      return SizedBox(
                        height: 260,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              step.fallbackIcon,
                              size: 64,
                              color: AppTheme.accent,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '画像を準備中です',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.secondaryText(context),
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 18),
                              child: Text(
                                step.imageAssetPath,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppTheme.weakText(context),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _secretsForm() {
    return _surfaceCard(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _tokenCtrl,
              decoration: const InputDecoration(
                labelText: 'SwitchBot TOKEN',
                hintText: '例) 9c4b...',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'TOKENを入力してください' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _secretCtrl,
              decoration: const InputDecoration(
                labelText: 'SwitchBot SECRET',
                hintText: '例) 2f6a...',
              ),
              obscureText: true,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'SECRETを入力してください' : null,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveSecrets,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_user_rounded),
                label: Text(_saving ? '検証中...' : '検証して保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _savedSecretsCard() {
    String fmt(dynamic v) {
      if (v is Map) {
        final head = v['head']?.toString() ?? '';
        final tail = v['tail']?.toString() ?? '';
        final len = v['len']?.toString() ?? '?';

        if (head.isEmpty || tail.isEmpty) {
          return '保存済み';
        }

        return '$head…$tail（len:$len）';
      }

      return '保存済み';
    }

    final token = _secretEcho?['token'];
    final secret = _secretEcho?['secret'];

    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF00D6A3),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOKEN / SECRET は保存済みです',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _hasSelectedMeter ? '認証情報は保存されています。' : '次に温湿度計を選択してください。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.secondaryText(context),
                            height: 1.45,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.chipFill(
                AppTheme.accent,
                context,
                opacity: 0.08,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOKEN: ${fmt(token)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText(context),
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'SECRET: ${fmt(secret)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText(context),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _deviceCard() {
    final deviceSummary = _hasSelectedMeter
        ? '$_selectedDeviceName ($_selectedDeviceType)\n$_selectedDeviceId'
        : 'まだ温湿度計が選択されていません';

    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _hasSelectedMeter
                    ? Icons.check_circle_rounded
                    : Icons.sensors_rounded,
                color: _hasSelectedMeter
                    ? const Color(0xFF00D6A3)
                    : AppTheme.accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _hasSelectedMeter ? '温湿度計は選択済みです' : '温湿度計を選択してください',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            deviceSummary,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.secondaryText(context),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  (_canPickDevices && !_polling) ? _pickDeviceFromCloud : null,
              icon: _polling
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _hasSelectedMeter
                          ? Icons.swap_horiz_rounded
                          : Icons.list_alt_rounded,
                    ),
              label: Text(
                _polling
                    ? '取得中...'
                    : _hasSelectedMeter
                        ? '別の温湿度計を選ぶ'
                        : 'デバイス一覧から選ぶ',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard() {
    if (_status == null) return const SizedBox.shrink();

    return _surfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_polling) ...[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ] else ...[
            Icon(
              Icons.info_outline_rounded,
              color: AppTheme.secondaryText(context),
              size: 20,
            ),
          ],
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _status!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.secondaryText(context),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dangerZone() {
    if (!_hasSecrets) return const SizedBox.shrink();

    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '連携を解除',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'TOKEN/SECRETと選択中の温湿度計を解除します。過去の温湿度記録は通常残します。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.secondaryText(context),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: _disabling ? null : _confirmAndDisableIntegration,
              icon: _disabling
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link_off_rounded),
              label: Text(_disabling ? '解除中...' : 'SwitchBot連携を解除'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 96, 20, 32),
      children: [
        _headerCard(),
        _sectionTitle(
          '現在の状態',
          'SwitchBot連携の進み具合を確認できます',
        ),
        _connectionStateCard(),
        _sectionTitle(
          '連携ガイド',
          'SwitchBotアプリの準備から温湿度計の選択まで確認できます',
        ),
        _guideEntryCard(),
        _sectionTitle(
          '認証情報',
          'TOKEN/SECRETはサーバ経由で安全に保存します',
        ),
        if (_loading) ...[
          _surfaceCard(
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ] else if (!_hasSecrets) ...[
          _secretsForm(),
        ] else ...[
          _savedSecretsCard(),
        ],
        if (_hasSecrets) ...[
          _sectionTitle(
            '温湿度計の選択',
            '記録に使うSwitchBot温湿度計を選択します',
          ),
          _deviceCard(),
        ],
        _statusCard(),
        _dangerZone(),
        const SizedBox(height: 8),
        Text(
          '※ TOKEN/SECRET はCloud Functions経由で保存されます。安全のため、アプリでは全文を表示しません。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.tertiaryText(context),
              ),
        ),
      ],
    );
  }
}

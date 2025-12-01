// lib/screens/switchbot_setup.dart
// SwitchBot: TOKEN/SECRETの保存 → デバイス一覧から温湿度計を選ぶ（Device ID自動保存）

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SwitchbotSetupScreen extends StatefulWidget {
  const SwitchbotSetupScreen({super.key});

  @override
  State<SwitchbotSetupScreen> createState() => _SwitchbotSetupScreenState();
}

class _SwitchbotSetupScreenState extends State<SwitchbotSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();

  bool _saving = false;
  bool _canPickDevices = false; // 資格情報保存済みで有効化
  String? _status;

  // 選択済みデバイス表示用
  String? _selectedDeviceId;
  String? _selectedDeviceName;
  String? _selectedDeviceType;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

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

  // ---- UIヘルパ ----
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---- 初期ロード：資格情報の有無と選択済みデバイスを読む ----
  Future<void> _loadCurrent() async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(_uid);

    // 選択済みデバイス（任意）
    final devDoc =
        await userRef.collection('integrations').doc('switchbot').get();
    if (devDoc.exists) {
      final m = devDoc.data()!;
      _selectedDeviceId = (m['meterDeviceId'] ?? '') as String?;
      _selectedDeviceName = (m['meterDeviceName'] ?? '') as String?;
      _selectedDeviceType = (m['meterDeviceType'] ?? '') as String?;
    }

    // 資格情報が保存済みか（暗号化済みの有無だけ確認）
    final secDoc =
        await userRef.collection('integrations').doc('switchbot_secrets').get();
    final hasSecrets = secDoc.exists &&
        (secDoc.data()?['v1']?['token'] != null) &&
        (secDoc.data()?['v1']?['secret'] != null);

    setState(() {
      _canPickDevices = hasSecrets;
      if (hasSecrets) {
        _status = '資格情報は保存済みです。必要なら「デバイス一覧から選ぶ」を押してください。';
      } else {
        _status = 'まだ資格情報がありません。TOKEN/SECRETを保存してから「デバイス一覧から選ぶ」を押してください。';
      }
    });
  }

  // ---- TOKEN/SECRET の検証＋保存（Callable） ----
  Future<void> _saveSecrets() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _status = 'TOKEN/SECRET を検証中...';
    });

    try {
      final callable = _fns.httpsCallable('registerSwitchbotSecrets');
      await callable.call(<String, dynamic>{
        'token': _tokenCtrl.text.trim(),
        'secret': _secretCtrl.text.trim(),
      });

      setState(() {
        _canPickDevices = true;
        _status = '資格情報を保存しました。次に「デバイス一覧から選ぶ」を押してください。';
      });
      _showSnack('SwitchBot 資格情報を保存しました');

      // 1件だけなら自動選択（ベストエフォート）
      await _autoPickIfSingleMeter();
    } on FirebaseFunctionsException catch (e) {
      _showSnack('保存に失敗: ${e.message}');
      setState(() => _status = 'エラー: ${e.message}');
    } catch (e) {
      _showSnack('保存に失敗: $e');
      setState(() => _status = 'エラー: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---- デバイス一覧取得（Callable） ----
  Future<List<dynamic>> _fetchDevicesOrThrow() async {
    final callable = _fns.httpsCallable('listSwitchbotDevices');
    final res = await callable.call();
    final List<dynamic> all = (res.data['devices'] as List<dynamic>? ?? []);
    if (all.isEmpty) {
      throw Exception('デバイスが見つかりませんでした');
    }
    return all;
  }

  // 温湿度計らしいものだけ
  List<Map<String, dynamic>> _filterMeters(List<dynamic> all) {
    const meterKeywords = <String>{
      'meter',
      'meterplus',
      'thsensor',
      'woiosensor',
      'temperature',
      'humidity',
    };

    final result = <Map<String, dynamic>>[];
    for (final e in all) {
      if (e is Map) {
        final m = Map<String, dynamic>.from(e as Map);
        final t = (m['deviceType']?.toString() ?? '').toLowerCase();
        if (t.isNotEmpty && meterKeywords.any((k) => t.contains(k))) {
          result.add(m);
        }
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
          id: m['deviceId'] as String,
          name: (m['deviceName'] ?? '') as String,
          type: (m['deviceType'] ?? '') as String,
        );
        _showSnack('温湿度計を自動選択しました: ${m['deviceName'] ?? m['deviceId']}');
      }
    } catch (_) {
      // 無視（自動選択は任意）
    }
  }

  // ---- 一覧から選ぶ → ボトムシート ----
  Future<void> _pickDeviceFromCloud() async {
    try {
      if (!_canPickDevices) {
        _showSnack('先に TOKEN/SECRET を保存してください。');
        return;
      }

      final all = await _fetchDevicesOrThrow();
      final meters = _filterMeters(all);
      if (meters.isEmpty) {
        _showSnack('温湿度計が見つかりませんでした（SwitchBotアプリで所有デバイスをご確認ください）');
        return;
      }

      if (!mounted) return;
      final picked = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        useRootNavigator: true, // ★ Navigatorロック回避に寄与
        showDragHandle: true,
        builder: (sheetCtx) {
          return SafeArea(
            child: ListView.separated(
              itemCount: meters.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final d = meters[i];
                return ListTile(
                  leading: const Icon(Icons.thermostat),
                  title: Text(
                    (d['deviceName'] as String?)?.isNotEmpty == true
                        ? d['deviceName'] as String
                        : '(no name)',
                  ),
                  subtitle: Text('${d['deviceType']} • ${d['deviceId']}'),
                  onTap: () => Navigator.of(sheetCtx).pop(d), // ★ 1回だけ確実にpop
                );
              },
            ),
          );
        },
      );

      // _pickDeviceFromCloud() 内の picked != null ブロックを置き換え
      if (picked != null) {
        final m = Map<String, dynamic>.from(picked);
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

  // ---- 選択したデバイスを保存（Firestore） ----
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
        .set({
      'meterDeviceId': id,
      'meterDeviceName': name,
      'meterDeviceType': type,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    setState(() {
      _selectedDeviceId = id;
      _selectedDeviceName = name;
      _selectedDeviceType = type;
      _status = 'デバイスを保存しました。';
    });
  }

  @override
  Widget build(BuildContext context) {
    final deviceSummary = (_selectedDeviceId == null ||
            _selectedDeviceId!.isEmpty)
        ? '未選択'
        : '${(_selectedDeviceName?.isNotEmpty ?? false) ? _selectedDeviceName : _selectedDeviceId}\n'
            '(${_selectedDeviceType ?? 'Unknown'} / ID: $_selectedDeviceId)';

    return WillPopScope(
      onWillPop: () async => true, // 物理バック許可
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SwitchBot 連携設定'),
          leading: BackButton(onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          }),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              '手順:\n'
              '1) SwitchBot 公式アプリ → マイページ → 設定 → 開発者向け設定 → Token/Secret を取得\n'
              '2) 下に貼り付けて [検証して保存]\n'
              '3) [デバイス一覧から選ぶ] で温湿度計を選択（Device ID は自動保存）',
            ),
            const SizedBox(height: 16),

            // 資格情報フォーム
            Form(
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
                        (v == null || v.trim().isEmpty) ? '必須です' : null,
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
                        (v == null || v.trim().isEmpty) ? '必須です' : null,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveSecrets,
                    icon: const Icon(Icons.verified_user),
                    label: Text(_saving ? '保存中...' : '検証して保存'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('選択中の温湿度計'),
              subtitle: Text(deviceSummary),
              trailing: ElevatedButton.icon(
                onPressed: _canPickDevices ? _pickDeviceFromCloud : null,
                icon: const Icon(Icons.list_alt),
                label: const Text('デバイス一覧から選ぶ'),
              ),
            ),

            const SizedBox(height: 16),
            if (_status != null)
              Text(
                _status!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
            const SizedBox(height: 8),
            const Divider(),
            const Text(
              '※ TOKEN/SECRET は Functions 側で暗号化保管され、アプリからは参照できません。',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

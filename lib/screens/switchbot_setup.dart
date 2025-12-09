// lib/screens/switchbot_setup.dart
// SwitchBot: TOKEN/SECRET の保存 → デバイス一覧から温湿度計を選ぶ（Device ID 自動保存）

import 'dart:convert'; // JSON 経由で Map<String, dynamic> に揃える
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
  bool _disabling = false;

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

  // ---- UI ヘルパ ----
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

    if (!mounted) return;
    setState(() {
      _canPickDevices = hasSecrets;
      if (hasSecrets) {
        _status = '資格情報は保存済みです。必要なら「デバイス一覧から選ぶ」を押してください。';
      } else {
        _status = 'まだ資格情報がありません。TOKEN/SECRETを保存してから「デバイス一覧から選ぶ」を押してください。';
      }
    });
  }

  // ---- TOKEN/SECRET を Functions に保存 ----
  Future<void> _saveSecrets() async {
    if (!_formKey.currentState!.validate()) return;

    final token = _tokenCtrl.text.trim();
    final secret = _secretCtrl.text.trim();

    setState(() {
      _saving = true;
      _status = 'SwitchBot 資格情報を保存中...';
    });

    try {
      final callable = _fns.httpsCallable('registerSwitchbotSecrets');
      await callable.call(<String, dynamic>{
        'token': token,
        'secret': secret,
      });

      if (!mounted) return;
      setState(() {
        _canPickDevices = true;
        _status = '資格情報を保存しました。次に「デバイス一覧から選ぶ」を押してください。';
      });
      _showSnack('SwitchBot 資格情報を保存しました');

      // 1件だけなら自動選択（ベストエフォート）
      await _autoPickIfSingleMeter();
    } on FirebaseFunctionsException catch (e) {
      _showSnack('保存に失敗: ${e.message}');
      if (mounted) {
        setState(() => _status = 'エラー: ${e.message}');
      }
    } catch (e) {
      _showSnack('保存に失敗: $e');
      if (mounted) {
        setState(() => _status = 'エラー: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---- デバイス一覧取得（Callable） ----
  // listSwitchbotDevices (onCall) を使う。
  // 戻り値の Map が dynamic キーになり得るので、JSON round-trip で正規化する。
  Future<List<Map<String, dynamic>>> _fetchDevicesOrThrow() async {
    final callable = _fns.httpsCallable('listSwitchbotDevices');
    final res = await callable.call();

    // JSON round-trip で Map<String, dynamic> に揃える
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

    // すべて Map<String, dynamic> に
    return devices
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.fromEntries(
              e.entries.map((kv) => MapEntry(kv.key.toString(), kv.value)),
            ))
        .toList(growable: false);
  }

  // 温湿度計らしいものだけフィルター
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
    } catch (_) {
      // 自動選択はあくまでベストエフォートなので失敗しても無視
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
        _showSnack(
          '温湿度計が見つかりませんでした（SwitchBotアプリで所有デバイスをご確認ください）',
        );
        return;
      }

      if (!mounted) return;

      final picked = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        builder: (sheetCtx) {
          return DraggableScrollableSheet(
            expand: false,
            builder: (_, controller) => ListView.builder(
              controller: controller,
              itemCount: meters.length,
              itemBuilder: (_, index) {
                final d = meters[index];
                return ListTile(
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
        // 念のためキーを文字列に正規化
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
        .set(
      {
        'meterDeviceId': id,
        'meterDeviceName': name,
        'meterDeviceType': type,
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
        _canPickDevices = false;
        _selectedDeviceId = null;
        _selectedDeviceName = null;
        _selectedDeviceType = null;
        _status = 'SwitchBot 連携を解除しました。再度使う場合は TOKEN/SECRET を保存し直してください。';
      });

      _showSnack('SwitchBot 連携を解除しました');
    } on FirebaseFunctionsException catch (e) {
      _showSnack('連携解除に失敗: ${e.message}');
      if (mounted) {
        setState(() => _status = 'エラー: ${e.message}');
      }
    } catch (e) {
      _showSnack('連携解除に失敗: $e');
      if (mounted) {
        setState(() => _status = 'エラー: $e');
      }
    } finally {
      if (mounted) setState(() => _disabling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceSummary = (_selectedDeviceId == null)
        ? '未選択'
        : '$_selectedDeviceName ($_selectedDeviceType)\n$_selectedDeviceId';

    return Scaffold(
      appBar: AppBar(
        title: const Text('SwitchBot 連携設定'),
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
            title: const Text(
              'SwitchBot 連携を解除する',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              '連携を解除しても、これまで保存した温湿度データ（switchbot_readings）は残ります。\n'
              '完全に消したい場合は、後から「データも削除する」ボタンを実装して対応できます。',
              style: TextStyle(fontSize: 12),
            ),
            trailing: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: _disabling ? null : () => _disableIntegration(),
              icon: const Icon(Icons.link_off),
              label: Text(_disabling ? '解除中...' : '連携を解除'),
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
    );
  }
}

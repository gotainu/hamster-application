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
  bool _disabling = false;
  bool _hasSecrets = false;
  bool _loading = false;
  bool _polling = false;

  // 選択済みデバイス表示用
  String? _selectedDeviceId;
  String? _selectedDeviceName;
  String? _selectedDeviceType;

  String? _status;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Map<String, dynamic>? _secretEcho; // {token:{head,len,tail}, secret:{...}}

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
    setState(() => _loading = true);

    final userRef = FirebaseFirestore.instance.collection('users').doc(_uid);

    // 選択済みデバイス（任意）
    final devDoc =
        await userRef.collection('integrations').doc('switchbot').get();
    if (devDoc.exists) {
      final m = devDoc.data()!;
      _selectedDeviceId = (m['meterDeviceId'] as String?);
      _selectedDeviceName = (m['meterDeviceName'] as String?);
      _selectedDeviceType = (m['meterDeviceType'] as String?);
    }

    // 資格情報（v1_plain 優先、なければ v1）
    final secDoc =
        await userRef.collection('integrations').doc('switchbot_secrets').get();
    final data = secDoc.data();

    bool hasSecrets = false;
    final v1p = data?['v1_plain'];
    if (v1p is Map) {
      hasSecrets =
          (v1p['token'] is String && (v1p['token'] as String).isNotEmpty) &&
              (v1p['secret'] is String && (v1p['secret'] as String).isNotEmpty);
    }
    if (!hasSecrets) {
      final v1 = data?['v1'];
      if (v1 is Map) {
        hasSecrets =
            (v1['token'] is String && (v1['token'] as String).isNotEmpty) &&
                (v1['secret'] is String && (v1['secret'] as String).isNotEmpty);
      }
    }

    // 保存済みなら head/tail を取得（表示用）
    Map<String, dynamic>? echo;
    if (hasSecrets) {
      try {
        final callable = _fns.httpsCallable('switchbotDebugEcho');
        final res = await callable.call();
        echo = (res.data is Map)
            ? Map<String, dynamic>.from(res.data as Map)
            : null;
      } catch (_) {
        // 表示の補助なので失敗してもOK
      }
    }

    if (!mounted) return;
    setState(() {
      _hasSecrets = hasSecrets;
      _canPickDevices = hasSecrets;
      _secretEcho = echo;
      _status = hasSecrets
          ? '✅ 資格情報は保存済みです。温湿度計を選択してください。'
          : 'まだ資格情報がありません。TOKEN/SECRET を保存してください。';
      _loading = false;
    });
  } // ---- TOKEN/SECRET を Functions に保存（=保存前にFunctions側で検証される） ----

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

      // ✅ 念のため戻り値も見る（Functionsが変な成功を返しても弾ける）
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

      if (!mounted) return;
      setState(() {
        _canPickDevices = true;
        _status = '✅ 認証OK：資格情報を保存しました。次に「デバイス一覧から選ぶ」を押してください。';
      });
      _showSnack('✅ SwitchBot 認証OK：資格情報を保存しました');

      // 1件だけなら自動選択（ベストエフォート）
      await _autoPickIfSingleMeter();
      await _loadCurrent();
    } on FirebaseFunctionsException catch (e) {
      // permission-denied / invalid-argument / unavailable などがここに来る
      final msg = e.message ?? '不明なエラー';
      _showSnack('❌ 検証に失敗: $msg');
      if (mounted) {
        setState(() => _status = '❌ 検証に失敗: $msg');
      }
    } catch (e) {
      _showSnack('❌ 検証に失敗: $e');
      if (mounted) {
        setState(() => _status = '❌ 検証に失敗: $e');
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
    // ✅ 初回の設定が保存できた瞬間に1回取得して、readingsを早速1件作る
    await _pollNowOnce();
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

      // ✅ まずローカル状態を “解除済み” に倒す（古いカードが残らない）
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

      // ✅ Firestoreの最新状態と同期（ここが本命）
      await _loadCurrent();
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
        _showSnack('✅ 最新データを取得しました');
        if (mounted) {
          setState(() => _status = '✅ 最新データを取得しました（グラフに反映されます）');
        }
      } else {
        final msg = data['error']?.toString() ?? '不明なエラー';
        _showSnack('⚠️ 取得できませんでした: $msg');
        if (mounted) setState(() => _status = '⚠️ 取得できませんでした: $msg');
      }
    } on FirebaseFunctionsException catch (e) {
      _showSnack('❌ 取得に失敗: ${e.message}');
      if (mounted) setState(() => _status = '❌ 取得に失敗: ${e.message}');
    } catch (e) {
      _showSnack('❌ 取得に失敗: $e');
      if (mounted) setState(() => _status = '❌ 取得に失敗: $e');
    } finally {
      if (mounted) setState(() => _polling = false);
    }
  }

  Widget _secretsForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _tokenCtrl,
            decoration: const InputDecoration(
              labelText: 'SwitchBot TOKEN',
              hintText: '例) 9c4b...',
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? '必須です' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _secretCtrl,
            decoration: const InputDecoration(
              labelText: 'SwitchBot SECRET',
              hintText: '例) 2f6a...',
            ),
            obscureText: true,
            validator: (v) => (v == null || v.trim().isEmpty) ? '必須です' : null,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _saveSecrets,
            icon: const Icon(Icons.verified_user),
            label: Text(_saving ? '保存中...' : '検証して保存'),
          ),
        ],
      ),
    );
  }

  Widget _savedSecretsCard() {
    String fmt(dynamic v) {
      if (v is Map) {
        final head = v['head']?.toString() ?? '';
        final tail = v['tail']?.toString() ?? '';
        final len = v['len']?.toString() ?? '?';
        if (head.isEmpty || tail.isEmpty) return '保存済み（詳細取得不可）';
        return '$head…$tail（len:$len）';
      }
      return '保存済み';
    }

    final token = _secretEcho?['token'];
    final secret = _secretEcho?['secret'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surface,
        boxShadow: const [
          BoxShadow(
            blurRadius: 16,
            offset: Offset(0, 8),
            color: Color(0x1A000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SwitchBot 資格情報（保存済み）',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('TOKEN: ${fmt(token)}'),
          const SizedBox(height: 4),
          Text('SECRET: ${fmt(secret)}'),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: _disabling ? null : () => _disableIntegration(),
            icon: const Icon(Icons.link_off),
            label: Text(_disabling ? '解除中...' : '連携を解除'),
          ),
        ],
      ),
    );
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

          // 資格情報（未保存: フォーム / 保存済み: 表示カード）
          if (_loading) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 24),
          ] else if (!_hasSecrets) ...[
            _secretsForm(),
          ] else ...[
            _savedSecretsCard(),
          ],

          if (_hasSecrets) ...[
            const SizedBox(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('選択中の温湿度計'),
              subtitle: Text(deviceSummary),
              trailing: ElevatedButton.icon(
                onPressed: (_canPickDevices && !_polling)
                    ? _pickDeviceFromCloud
                    : null,
                icon: const Icon(Icons.list_alt),
                label: const Text('デバイス一覧から選ぶ'),
              ),
            ),
          ],

          const SizedBox(height: 16),
          if (_status != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_polling) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    _status!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          const Divider(),
          const Text(
            '※ TOKEN/SECRET はサーバ（Cloud Functions）経由で保存されます。'
            '安全のため、アプリでは全文を表示しません（先頭/末尾のみ表示）。',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

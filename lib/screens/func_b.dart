// lib/screens/func_b.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hamster_project/services/switchbot_service.dart';
import 'package:hamster_project/services/fetch_and_store.dart';
import 'package:hamster_project/services/switchbot_repo.dart';
import 'package:hamster_project/theme/app_theme.dart';

class FuncBScreen extends StatefulWidget {
  const FuncBScreen({super.key});

  @override
  State<FuncBScreen> createState() => _FuncBScreenState();
}

class _FuncBScreenState extends State<FuncBScreen> {
  bool _loading = false;
  bool _requestedOnce = false;
  List<Map<String, dynamic>> _devices = const [];
  String? _selectedId;
  String _log = '未実行';

  // dart-define から読み込み
  final String _envToken =
      const String.fromEnvironment('SWITCHBOT_TOKEN', defaultValue: '');
  final String _envSecret =
      const String.fromEnvironment('SWITCHBOT_SECRET', defaultValue: '');

  @override
  void initState() {
    super.initState();
    // トークンが揃っていれば、自動で1回だけ一覧取得
    if (_envToken.isNotEmpty && _envSecret.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDevices());
    }
  }

  Widget _envBanner(BuildContext context) {
    final ok = _envToken.isNotEmpty && _envSecret.isNotEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:
            ok ? Colors.green.withOpacity(.15) : Colors.orange.withOpacity(.15),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: ok ? Colors.greenAccent : Colors.orangeAccent),
      ),
      child: Text(
        ok
            ? 'SWITCHBOT_TOKEN/SECRET 検出済み（dart-define）→「デバイス一覧」を押してください'
            : 'SWITCHBOT_TOKEN/SECRET が未設定です。--dart-define-from-file=env.json で実行してください。',
        style: TextStyle(
          color: ok ? Colors.greenAccent : Colors.orangeAccent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _loadDevices() async {
    setState(() {
      _loading = true;
      _requestedOnce = true;
      _log = '一覧取得中…';
    });
    try {
      final list = await SwitchBotService().listDevices();
      setState(() {
        _devices = list;
        _log = 'デバイス ${list.length} 件';
        // 1件だけなら自動選択（好みで外してOK）
        if (_devices.length == 1) {
          _selectedId = _devices.first['deviceId']?.toString();
        }
      });
    } catch (e) {
      setState(() => _log = '失敗: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadStatus() async {
    if (_selectedId == null) {
      setState(() => _log = '先にデバイスを選択してください');
      return;
    }
    setState(() {
      _loading = true;
      _log = '$_selectedId のステータス取得中…';
    });
    try {
      final body = await SwitchBotService().getDeviceStatus(_selectedId!);
      final pretty = JsonEncoder.withIndent('  ');
      setState(() => _log = pretty.convert(body));
    } catch (e) {
      setState(() => _log = '失敗: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _placeholder(BuildContext themeCtx) {
    final theme = Theme.of(themeCtx);
    final text = !_requestedOnce ? '左上の「デバイス一覧」を押して取得します' : 'デバイスが見つかりませんでした';
    return Center(
      child: Text(
        text,
        style: theme.textTheme.bodyMedium,
      ),
    );
  }

  Future<void> _fetchAndStoreNow() async {
    setState(() => _loading = true);
    try {
      await fetchAndStoreOnce();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('温湿度を1件保存しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失敗: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('FuncB（SwitchBot 接続テスト）'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _envBanner(context),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.tonal(
                      onPressed: _loading ? null : _loadDevices,
                      child: const Text('デバイス一覧'),
                    ),
                    FilledButton(
                      onPressed: (_loading || _selectedId == null)
                          ? null
                          : _loadStatus,
                      child: const Text('選択デバイスのステータス'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _fetchAndStoreNow,
                      icon: const Icon(Icons.download),
                      label: const Text('今すぐ取得して保存'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    children: [
                      // 左：デバイス一覧
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _devices.isEmpty
                              ? _placeholder(context)
                              : ListView.separated(
                                  itemCount: _devices.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (_, i) {
                                    final d = _devices[i];
                                    final id = d['deviceId']?.toString() ?? '';
                                    final name = d['deviceName']?.toString() ??
                                        '(no name)';
                                    final devType =
                                        d['deviceType']?.toString() ?? '';
                                    final selected = id == _selectedId;
                                    return ListTile(
                                      dense: true,
                                      title: Text(name),
                                      subtitle: Text('$devType • $id'),
                                      selected: selected,
                                      trailing: selected
                                          ? const Icon(Icons.check, size: 18)
                                          : null,
                                      onTap: () =>
                                          setState(() => _selectedId = id),
                                      onLongPress: () async {
                                        if (devType == 'Meter' ||
                                            devType == 'MeterPlus') {
                                          await SwitchBotRepo()
                                              .saveSelectedMeter(id,
                                                  name: name);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      '「$name」を監視対象として保存しました')),
                                            );
                                          }
                                        } else {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    '温湿度計(Meter)のみ保存できます')),
                                          );
                                        }
                                      },
                                    );
                                  },
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 右：ログパネル
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              _log,
                              style: theme.textTheme.bodyMedium!
                                  .copyWith(fontFamily: 'monospace'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

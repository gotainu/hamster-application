import 'package:flutter/material.dart';
import 'package:hamster_project/main.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  @override
  Widget build(BuildContext context) {
    // 現在モードがダークかどうかを取得 (true=ダーク、false=ライト)
    final isDark = MyApp.of(context).themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('アプリ設定'),
      ),
      body: Center(
        child: SwitchListTile(
          title: const Text('ダークモード ON/OFF'),
          value: isDark,
          onChanged: (bool newValue) {
            // ONならダーク、OFFならライトモードに切り替え
            final newMode = newValue ? ThemeMode.dark : ThemeMode.light;
            MyApp.of(context).setThemeMode(newMode);

            // 自身の画面も再ビルドさせて、スイッチの見た目を更新
            setState(() {});
          },
        ),
      ),
    );
  }
}

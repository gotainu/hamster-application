import 'package:flutter/material.dart';
import 'package:hamster_project/main.dart';
import 'package:hamster_project/theme/app_theme.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = MyApp.of(context).themeMode == ThemeMode.dark;
    final textStyle = Theme.of(context).textTheme.bodyMedium;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'アプリ設定',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: Center(
          child: Container(
            width: 380,
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
            decoration: AppTheme.cardGradient(isDark),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isDark ? Icons.dark_mode : Icons.light_mode,
                  color: AppTheme.accent,
                  size: 42,
                ),
                const SizedBox(height: 12),
                Text(
                  isDark ? "ダークモード" : "ライトモード",
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  title: Text(
                    'ダークモード ON/OFF',
                    style: textStyle,
                  ),
                  value: isDark,
                  activeColor: AppTheme.accent,
                  onChanged: (bool newValue) {
                    final newMode = newValue ? ThemeMode.dark : ThemeMode.light;
                    MyApp.of(context).setThemeMode(newMode);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 12),
                // 必要に応じて追加設定
                // Text("バージョン: 1.0.0", style: textStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

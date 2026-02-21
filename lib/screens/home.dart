// lib/screens/home.dart
import 'package:flutter/material.dart';
import 'package:hamster_project/widgets/shine_border.dart';
import 'package:hamster_project/theme/app_theme.dart';
import 'package:hamster_project/screens/switchbot_setup.dart';
// ★ FuncB を直接開くルート用に追加
import 'package:hamster_project/screens/func_b.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int) onTabSelected;
  const HomeScreen({super.key, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // グラデ背景をテーマで出し分け
    final gradient =
        isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: null,
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        width: double.infinity,
        height: double.infinity,
        child: Column(
          children: [
            const SizedBox(height: 100),
            // --- カード部分 ---
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: AnimatedShiningBorder(
                  borderRadius: 32,
                  borderWidth: 2.5,
                  active: true, // ←常にシャイン
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 32),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.cardInnerDark
                          : AppTheme.cardInnerLight,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withOpacity(0.25),
                          blurRadius: 32,
                          spreadRadius: 0,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.pets,
                            color: AppTheme.accent, size: 42),
                        const SizedBox(height: 12),
                        Text(
                          "Welcome!",
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '本アプリのメイン機能を選択してください',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // ① AI チャット
                        _HomeMenuButton(
                          icon: Icons.search,
                          label: "AIに相談",
                          onTap: () => onTabSelected(1),
                        ),
                        const SizedBox(height: 16),

                        // ② 走った記録（既存のタブ遷移はそのまま維持）
                        _HomeMenuButton(
                          icon: Icons.show_chart_outlined,
                          label: "走った記録",
                          onTap: () => onTabSelected(2),
                        ),
                        const SizedBox(height: 12),

                        // ③ 同じ“走った記録”を別画面としてダイレクト起動（タブ構成に依存しない保険ルート）
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.accent,
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const FuncBScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.open_in_new),
                            label: const Flexible(
                              child: Text(
                                "走った記録を直接開く（別画面）",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ③.5 SwitchBot 連携設定（新規）
                        _HomeMenuButton(
                          icon: Icons.link,
                          label: "SwitchBot 連携設定",
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const SwitchbotSetupScreen()),
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        // ④ マイページ
                        _HomeMenuButton(
                          icon: Icons.person_2_outlined,
                          label: "マイページ",
                          onTap: () => onTabSelected(3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                '© 2025 Hamster Project',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ボタン部品（グラデあり！）
class _HomeMenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HomeMenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity, // ★親幅いっぱい
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: isDark
                ? [AppTheme.accent.withOpacity(0.15), Colors.transparent]
                : [AppTheme.accent.withOpacity(0.10), Colors.transparent],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.accent),
            const SizedBox(width: 12),
            Expanded(
              // ★ここが本命
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

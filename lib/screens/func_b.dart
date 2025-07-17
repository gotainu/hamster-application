import 'package:flutter/material.dart';
import 'package:hamster_project/theme/app_theme.dart';

class FuncBScreen extends StatelessWidget {
  const FuncBScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgGradient =
        isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('機能B', style: Theme.of(context).textTheme.titleLarge),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 背景グラデーション
          Container(
            decoration: BoxDecoration(gradient: bgGradient),
          ),
          // メインカード
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 38),
              decoration: BoxDecoration(
                color:
                    isDark ? AppTheme.cardInnerDark : AppTheme.cardInnerLight,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.19),
                    blurRadius: 36,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: AppTheme.accent, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    '機能B',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'これは機能Bのページです',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 18,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  // ここに今後ボタンや追加説明があれば並べる
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

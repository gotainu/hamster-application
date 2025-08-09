import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hamster_project/theme/app_theme.dart';

class FuncMyPageScreen extends StatelessWidget {
  const FuncMyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgGradient =
        isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: null,
      // appBar: AppBar(
      //   title: Text(
      //     'マイページ',
      //     style: Theme.of(context).textTheme.titleLarge,
      //   ),
      //   backgroundColor: Colors.transparent,
      //   elevation: 0,
      //   actions: [
      //     IconButton(
      //       onPressed: () {
      //         FirebaseAuth.instance.signOut();
      //       },
      //       icon: Icon(
      //         Icons.exit_to_app,
      //         color: Theme.of(context).colorScheme.primary,
      //       ),
      //     ),
      //   ],
      // ),
      body: Stack(
        children: [
          // グラデーション背景
          Container(decoration: BoxDecoration(gradient: bgGradient)),
          // 中央カード
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
                  const Icon(Icons.person, color: AppTheme.accent, size: 44),
                  const SizedBox(height: 20),
                  Text(
                    'ようこそ、マイページへ！',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'これはマイページです',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 18,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.logout, size: 22),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      backgroundColor: AppTheme.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () {
                      FirebaseAuth.instance.signOut();
                    },
                    label: Text(
                      'ログアウトすっぞ！😇',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

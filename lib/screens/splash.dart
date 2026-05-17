import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 132,
                    height: 132,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.chipFill(
                        AppTheme.accent,
                        context,
                        opacity: isDark ? 0.14 : 0.10,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withValues(
                            alpha: isDark ? 0.22 : 0.14,
                          ),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/roiroi.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Hamster Well-being',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryText(context),
                          letterSpacing: -0.4,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'うちの子の毎日を見守っています',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.secondaryText(context),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppTheme.accent,
                      backgroundColor: AppTheme.chipFill(
                        AppTheme.accent,
                        context,
                        opacity: isDark ? 0.12 : 0.08,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

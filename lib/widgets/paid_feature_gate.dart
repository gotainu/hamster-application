import 'package:flutter/material.dart';

import '../models/billing_status.dart';
import '../screens/subscription_plan_screen.dart';
import '../services/billing_status_repo.dart';
import '../theme/app_theme.dart';

class PaidFeatureGate extends StatelessWidget {
  const PaidFeatureGate({
    super.key,
    required this.child,
    this.featureName = 'この機能',
    this.lockedTitle,
    this.lockedMessage,
    this.icon = Icons.workspace_premium_rounded,
    this.actionLabel = '利用プランを確認する',
    this.showBackground = true,
  });

  final Widget child;
  final String featureName;
  final String? lockedTitle;
  final String? lockedMessage;
  final IconData icon;
  final String actionLabel;

  /// true:
  ///   ロック画面側で背景グラデーションを描く。
  ///
  /// false:
  ///   親画面の背景をそのまま使う。
  ///
  /// 画面全体をガードする場合は true、
  /// カードや一部Widgetだけをガードする場合は false が使いやすいです。
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    final repo = BillingStatusRepo();

    return StreamBuilder<BillingStatus>(
      stream: repo.watchBillingStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final billing = snapshot.data ?? BillingStatus.empty();

        if (billing.canUsePaidFeatures) {
          return child;
        }

        return _PaidFeatureLockedView(
          icon: icon,
          title: lockedTitle ?? '$featureNameは有料プランの機能です',
          message: lockedMessage ?? 'ハムスターの環境管理を継続的に支援するため、この機能は有料プランで利用できます。',
          actionLabel: actionLabel,
          showBackground: showBackground,
        );
      },
    );
  }
}

class _PaidFeatureLockedView extends StatelessWidget {
  const _PaidFeatureLockedView({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.showBackground,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final bool showBackground;

  void _openPlanPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SubscriptionPlanScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    final content = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(24),
          decoration: AppTheme.cardGradient(isDark),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: AppTheme.accent,
                size: 48,
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.secondaryText(context),
                      height: 1.6,
                    ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openPlanPage(context),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(actionLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!showBackground) {
      return content;
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
      ),
      child: SafeArea(
        child: content,
      ),
    );
  }
}

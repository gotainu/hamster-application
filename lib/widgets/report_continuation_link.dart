import 'package:flutter/material.dart';
import '../screens/subscription_plan_screen.dart';
import '../theme/app_theme.dart';

/// Optional continuation route. Generated reports stay freely readable.
class ReportContinuationLink extends StatelessWidget {
  const ReportContinuationLink({super.key});
  @override
  Widget build(BuildContext context) => TextButton(
      style: TextButton.styleFrom(
          foregroundColor: AppTheme.isDark(context)
              ? AppTheme.quickRecordGlow(context)
              : AppTheme.accent),
      onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SubscriptionPlanScreen())),
      child: const Text('記録・分析を続けるプランを見る'));
}

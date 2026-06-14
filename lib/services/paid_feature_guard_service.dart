import 'package:flutter/material.dart';

import '../models/billing_status.dart';
import '../screens/subscription_plan_screen.dart';
import 'billing_status_repo.dart';

class PaidFeatureGuardService {
  PaidFeatureGuardService({
    BillingStatusRepo? billingStatusRepo,
  }) : _billingStatusRepo = billingStatusRepo ?? BillingStatusRepo();

  final BillingStatusRepo _billingStatusRepo;

  Future<bool> ensureCanUsePaidFeature(
    BuildContext context, {
    required String featureName,
    String? description,
  }) async {
    final billing = await _billingStatusRepo.fetchBillingStatus();

    if (billing.canUsePaidFeatures) {
      return true;
    }

    if (!context.mounted) {
      return false;
    }

    final shouldOpenPlan = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return _PaidFeatureDialog(
          billing: billing,
          featureName: featureName,
          description: description,
        );
      },
    );

    if (shouldOpenPlan == true && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const SubscriptionPlanScreen(),
        ),
      );
    }

    return false;
  }
}

class _PaidFeatureDialog extends StatelessWidget {
  const _PaidFeatureDialog({
    required this.billing,
    required this.featureName,
    this.description,
  });

  final BillingStatus billing;
  final String featureName;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final title = billing.needsPaymentAttention
        ? 'お支払いの確認が必要です'
        : '$featureNameは有料プランの機能です';

    final body = description ??
        (billing.needsPaymentAttention
            ? '現在のお支払い状態では、この機能を利用できません。利用プラン画面で状態を確認してください。'
            : 'ハムスターの環境管理を継続的に支援するため、この機能は有料プランで利用できます。');

    return AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('閉じる'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('利用プランを見る'),
        ),
      ],
    );
  }
}

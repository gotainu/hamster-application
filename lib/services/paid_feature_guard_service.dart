import 'package:flutter/material.dart';

import '../models/billing_status.dart';
import 'billing_status_repo.dart';
import 'onboarding_state_repo.dart';

class PaidFeatureGuardService {
  PaidFeatureGuardService({BillingStatusRepo? billingStatusRepo})
    : _billingStatusRepo = billingStatusRepo ?? BillingStatusRepo();

  final BillingStatusRepo _billingStatusRepo;

  Future<bool> ensureCanUsePaidFeature(
    BuildContext context, {
    required String featureName,
    String? description,
    bool allowDuringOnboarding = false,
  }) async {
    final billing = await _billingStatusRepo.fetchBillingStatus();

    if (billing.canUsePaidFeatures) {
      return true;
    }

    if (allowDuringOnboarding) {
      final onboarding = await OnboardingStateRepo().fetchState();
      if (onboarding.hasActiveOnboardingEntitlement()) return true;
    }

    if (!context.mounted) {
      return false;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _PaidFeatureDialog(
          billing: billing,
          featureName: featureName,
          description: description,
        );
      },
    );

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
        : '$featureNameの利用状況';

    final body =
        description ?? 'このアカウントでは、現在この機能を利用できません。';

    return AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/billing_status.dart';
import '../models/entitlement_snapshot.dart';
import '../models/feature_trial_access.dart';
import '../models/initial_trial_gate_state.dart';
import '../models/initial_trial_access.dart';
import '../screens/subscription_plan_screen.dart';
import '../services/billing_status_repo.dart';
import '../services/feature_trial_repo.dart';
import '../services/onboarding_state_repo.dart';
import '../services/initial_trial_repo.dart';
import '../services/app_analytics.dart';
import '../theme/app_theme.dart';
import 'hamster_feedback_popup.dart';

class PaidFeatureGate extends StatefulWidget {
  const PaidFeatureGate({
    super.key,
    required this.child,
    this.featureName = 'この機能',
    this.lockedTitle,
    this.lockedMessage,
    this.icon = Icons.workspace_premium_rounded,
    this.showBackground = true,
    this.trialFeature,
    this.allowDuringOnboarding = false,
    this.useInitialTrial = false,
    this.canStartInitialTrial = false,
    this.billingRepo,
  });

  final Widget child;
  final String featureName;
  final String? lockedTitle;
  final String? lockedMessage;
  final IconData icon;
  final bool showBackground;
  final TrialFeature? trialFeature;
  final bool allowDuringOnboarding;
  final bool useInitialTrial;
  final bool canStartInitialTrial;

  final BillingStatusRepo? billingRepo;

  @override
  State<PaidFeatureGate> createState() => _PaidFeatureGateState();
}

class _PaidFeatureGateState extends State<PaidFeatureGate> {
  late BillingStatusRepo _repo;
  late Stream<EntitlementSnapshot<BillingStatus>> _billingStream;
  StreamSubscription<String?>? _authSubscription;
  String? _streamUid;
  int _readVersion = 0;

  @override
  void initState() {
    super.initState();
    _bindRepo();
  }

  void _bindRepo() {
    final repo = _repo = widget.billingRepo ?? BillingStatusRepo();
    _streamUid = repo.currentUserId;
    _billingStream = repo.watchBillingStatus();
    _authSubscription = repo.watchUserId().listen((uid) {
      if (!mounted || !identical(repo, _repo) || uid == _streamUid) return;
      setState(() {
        _streamUid = uid;
        _readVersion++;
        _billingStream = repo.watchBillingStatus();
      });
    });
  }

  @override
  void didUpdateWidget(covariant PaidFeatureGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.billingRepo != widget.billingRepo) {
      unawaited(_authSubscription?.cancel());
      _readVersion++;
      _bindRepo();
    }
  }

  void _retryEntitlementRead() {
    setState(() {
      _readVersion++;
      _billingStream = _repo.watchBillingStatus();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Widget _readStatus({bool unavailable = false}) => _InitialTrialStatusView(
        icon: widget.icon,
        showBackground: widget.showBackground,
        title: unavailable ? '利用状態を確認できませんでした' : '利用状態を確認しています',
        message: unavailable ? '通信状態を確認して、もう一度お試しください。' : '確認が終わるまでお待ちください。',
        loading: !unavailable,
        onRetry: unavailable ? _retryEntitlementRead : null,
      );

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<EntitlementSnapshot<BillingStatus>>(
        key: ValueKey((_streamUid, _readVersion)),
        stream: _billingStream,
        builder: (context, snapshot) {
          if (_streamUid != _repo.currentUserId) return _readStatus();
          if (snapshot.hasError) return _readStatus(unavailable: true);
          final read = snapshot.data;
          if (read == null ||
              !read.isServerConfirmed ||
              read.uid != _repo.currentUserId) {
            return _readStatus();
          }
          final billing = read.data!;
          if (billing.canUsePaidFeatures) return widget.child;

          if (widget.trialFeature != null) {
            return _TrialAwareFeatureGate(
              billingRepo: _repo,
              billing: billing,
              onRetry: _retryEntitlementRead,
              trialFeature: widget.trialFeature!,
              featureName: widget.featureName,
              lockedTitle: widget.lockedTitle,
              lockedMessage: widget.lockedMessage,
              icon: widget.icon,
              showBackground: widget.showBackground,
              child: widget.child,
            );
          }

          if (widget.useInitialTrial) {
            return _InitialTrialFeatureGate(
              billingRepo: _repo,
              billing: billing,
              onRetry: _retryEntitlementRead,
              featureName: widget.featureName,
              lockedTitle: widget.lockedTitle,
              lockedMessage: widget.lockedMessage,
              icon: widget.icon,
              showBackground: widget.showBackground,
              canStart: widget.canStartInitialTrial,
              child: widget.child,
            );
          }

          if (widget.allowDuringOnboarding) {
            return StreamBuilder<OnboardingState>(
              stream: OnboardingStateRepo().watchState(),
              builder: (context, onboardingSnapshot) {
                final onboarding =
                    onboardingSnapshot.data ?? OnboardingState.initial();
                if (onboarding.hasActiveOnboardingEntitlement()) {
                  return widget.child;
                }
                return _PaidFeatureLockedView(
                  featureName: widget.featureName,
                  title:
                      widget.lockedTitle ?? '${widget.featureName}は有料プランの機能です',
                  message: widget.lockedMessage ??
                      '無料オンボーディング期間は終了しました。続けるには有料プランをご利用ください。',
                  icon: widget.icon,
                  showBackground: widget.showBackground,
                );
              },
            );
          }

          return _PaidFeatureLockedView(
            featureName: widget.featureName,
            title: widget.lockedTitle ?? '${widget.featureName}は有料プランの機能です',
            message: widget.lockedMessage ??
                'ハムスターの環境管理を継続的に支援するため、この機能は有料プランで利用できます。',
            icon: widget.icon,
            showBackground: widget.showBackground,
          );
        },
      );
}

class _InitialTrialFeatureGate extends StatefulWidget {
  const _InitialTrialFeatureGate(
      {required this.billingRepo,
      required this.billing,
      required this.onRetry,
      required this.featureName,
      required this.lockedTitle,
      required this.lockedMessage,
      required this.icon,
      required this.showBackground,
      required this.canStart,
      required this.child});
  final BillingStatusRepo billingRepo;
  final BillingStatus billing;
  final VoidCallback onRetry;
  final String featureName;
  final String? lockedTitle;
  final String? lockedMessage;
  final IconData icon;
  final bool showBackground;
  final bool canStart;
  final Widget child;
  @override
  State<_InitialTrialFeatureGate> createState() =>
      _InitialTrialFeatureGateState();
}

class _InitialTrialFeatureGateState extends State<_InitialTrialFeatureGate> {
  InitialTrialRepo? _trialRepo;
  bool _starting = false;
  late final Stream<EntitlementSnapshot<InitialTrialAccess>> _trialStream;

  @override
  void initState() {
    super.initState();
    _trialStream = widget.billingRepo.watchInitialTrialAccess();
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    try {
      await (_trialRepo ??= InitialTrialRepo()).start();
      unawaited(AppAnalytics.logEntitlementEvent('initial_trial_start_attempt',
          flowVersion: 'initial_trial_v2', outcome: 'success'));
    } catch (_) {
      unawaited(AppAnalytics.logEntitlementEvent('initial_trial_start_attempt',
          flowVersion: 'initial_trial_v2', outcome: 'failed'));
      if (mounted) {
        HamsterFeedbackPopup.show(
          context,
          message: '無料体験は利用上限の設定後に開始できます。',
          tone: HamsterFeedbackTone.warning,
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<EntitlementSnapshot<InitialTrialAccess>>(
        stream: _trialStream,
        builder: (context, trialSnapshot) {
          final read = trialSnapshot.data;
          final trial = read?.data;
          final phase = resolveInitialTrialGateState(
            billingHasData: true,
            billingHasError: false,
            trialHasData: read?.isServerConfirmed == true &&
                read?.uid == widget.billingRepo.currentUserId,
            trialHasError: trialSnapshot.hasError,
            hasPaidAccess: widget.billing.canUsePaidFeatures,
            hasActiveTrial: trial?.isActive ?? false,
            trialStatus: trial?.status,
            canStart: widget.canStart,
          );

          switch (phase) {
            case InitialTrialGateState.loading:
              return _InitialTrialStatusView(
                icon: widget.icon,
                showBackground: widget.showBackground,
                title: '利用状態を確認しています',
                message: '確認が終わるまでお待ちください。',
                loading: true,
              );
            case InitialTrialGateState.unavailable:
              return _InitialTrialStatusView(
                icon: widget.icon,
                showBackground: widget.showBackground,
                title: '利用状態を確認できませんでした',
                message: '通信状態を確認して、もう一度お試しください。',
                onRetry: widget.onRetry,
              );
            case InitialTrialGateState.paid:
            case InitialTrialGateState.activeTrial:
              return widget.child;
            case InitialTrialGateState.canStart:
              return _InitialTrialStartView(
                  featureName: widget.featureName,
                  icon: widget.icon,
                  showBackground: widget.showBackground,
                  starting: _starting,
                  onStart: _start);
            case InitialTrialGateState.locked:
              return _PaidFeatureLockedView(
                  featureName: widget.featureName,
                  title:
                      widget.lockedTitle ?? '${widget.featureName}は有料プランの機能です',
                  message: widget.lockedMessage ??
                      '無料体験は終了しています。続けるには有料プランをご利用ください。',
                  icon: widget.icon,
                  showBackground: widget.showBackground);
          }
        },
      );
}

class _InitialTrialStatusView extends StatelessWidget {
  const _InitialTrialStatusView({
    required this.icon,
    required this.showBackground,
    required this.title,
    required this.message,
    this.loading = false,
    this.onRetry,
  });

  final IconData icon;
  final bool showBackground;
  final String title;
  final String message;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: AppTheme.cardGradient(isDark),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (loading)
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              else
                Icon(icon, color: AppTheme.accent, size: 36),
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
              if (onRetry != null) ...[
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('もう一度確認'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (!showBackground) return content;
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
      ),
      child: SafeArea(child: content),
    );
  }
}

class _InitialTrialStartView extends StatelessWidget {
  const _InitialTrialStartView(
      {required this.featureName,
      required this.icon,
      required this.showBackground,
      required this.starting,
      required this.onStart});
  final String featureName;
  final IconData icon;
  final bool showBackground;
  final bool starting;
  final Future<void> Function() onStart;
  @override
  Widget build(BuildContext context) => _PaidFeatureLockedView(
        featureName: featureName,
        title: '$featureNameを無料で試す',
        message: '「無料体験を始める」を押すと、21日間の体験期間と終了日時を確定します。記録の有無にかかわらず期間は延長されません。',
        icon: icon,
        showBackground: showBackground,
        primaryLabel: starting ? '開始しています…' : '21日間の無料体験を始める',
        onPrimary: starting ? null : () => onStart(),
        trackPaywall: false,
      );
}

class _TrialAwareFeatureGate extends StatefulWidget {
  const _TrialAwareFeatureGate(
      {required this.billingRepo,
      required this.billing,
      required this.onRetry,
      required this.trialFeature,
      required this.child,
      required this.featureName,
      required this.lockedTitle,
      required this.lockedMessage,
      required this.icon,
      required this.showBackground});
  final BillingStatusRepo billingRepo;
  final BillingStatus billing;
  final VoidCallback onRetry;
  final TrialFeature trialFeature;
  final Widget child;
  final String featureName;
  final String? lockedTitle;
  final String? lockedMessage;
  final IconData icon;
  final bool showBackground;
  @override
  State<_TrialAwareFeatureGate> createState() => _TrialAwareFeatureGateState();
}

class _TrialAwareFeatureGateState extends State<_TrialAwareFeatureGate> {
  late final FeatureTrialRepo _trialRepo;
  late final Future<void> _activation;
  late final Stream<EntitlementSnapshot<FeatureTrialAccess>> _trialStream;
  @override
  void initState() {
    super.initState();
    _trialRepo = FeatureTrialRepo();
    _activation = _trialRepo.activate();
    _trialStream = widget.billingRepo.watchFeatureTrialAccess();
  }

  Widget _readStatus({bool unavailable = false}) => _InitialTrialStatusView(
        icon: widget.icon,
        showBackground: widget.showBackground,
        title: unavailable ? '利用状態を確認できませんでした' : '利用状態を確認しています',
        message: unavailable ? '通信状態を確認して、もう一度お試しください。' : '確認が終わるまでお待ちください。',
        loading: !unavailable,
        onRetry: unavailable ? widget.onRetry : null,
      );

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: _activation,
        builder: (context, activation) {
          if (activation.connectionState != ConnectionState.done) {
            return _readStatus();
          }
          return StreamBuilder<EntitlementSnapshot<FeatureTrialAccess>>(
            stream: _trialStream,
            builder: (context, trialSnapshot) {
              if (trialSnapshot.hasError) return _readStatus(unavailable: true);
              final read = trialSnapshot.data;
              if (read == null ||
                  !read.isServerConfirmed ||
                  read.uid != widget.billingRepo.currentUserId) {
                return _readStatus();
              }
              if (widget.billing.canUsePaidFeatures ||
                  read.data!.allows(widget.trialFeature)) {
                return widget.child;
              }
              return _PaidFeatureLockedView(
                featureName: widget.featureName,
                title: widget.lockedTitle ?? '${widget.featureName}は有料プランの機能です',
                message:
                    widget.lockedMessage ?? '無料体験を使い切りました。続けるには有料プランをご利用ください。',
                icon: widget.icon,
                showBackground: widget.showBackground,
              );
            },
          );
        },
      );
}

class _PaidFeatureLockedView extends StatelessWidget {
  const _PaidFeatureLockedView({
    required this.featureName,
    required this.title,
    required this.message,
    required this.icon,
    required this.showBackground,
    this.primaryLabel,
    this.onPrimary,
    this.trackPaywall = true,
  });

  final String featureName;
  final String title;
  final String message;
  final IconData icon;
  final bool showBackground;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final bool trackPaywall;

  void _openPlanPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SubscriptionPlanScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final lockedCard = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
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
                  onPressed: onPrimary ?? () => _openPlanPage(context),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(primaryLabel ?? '利用プランを確認する'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final trackedCard = trackPaywall
        ? _PaywallShownTracker(featureName: featureName, child: lockedCard)
        : lockedCard;
    if (!showBackground) return trackedCard;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
      ),
      child: SafeArea(
        child: trackedCard,
      ),
    );
  }
}

class _PaywallShownTracker extends StatefulWidget {
  const _PaywallShownTracker({required this.featureName, required this.child});
  final String featureName;
  final Widget child;
  @override
  State<_PaywallShownTracker> createState() => _PaywallShownTrackerState();
}

class _PaywallShownTrackerState extends State<_PaywallShownTracker> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(AppAnalytics.logPaywallPresented(
        featureName: widget.featureName,
        presentationId: DateTime.now().microsecondsSinceEpoch.toString(),
      ));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

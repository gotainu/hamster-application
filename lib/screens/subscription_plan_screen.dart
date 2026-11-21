// lib/screens/subscription_plan_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/billing_status.dart';
import '../models/entitlement_snapshot.dart';
import '../models/initial_trial_access.dart';
import '../services/billing_status_repo.dart';
import '../theme/app_theme.dart';
import '../widgets/hamster_feedback_popup.dart';

/// Account usage only. New purchases are not started from the application.
class SubscriptionPlanScreen extends StatefulWidget {
  const SubscriptionPlanScreen({super.key, this.billingRepo, this.now});

  final BillingStatusRepo? billingRepo;
  final DateTime Function()? now;

  @override
  State<SubscriptionPlanScreen> createState() => _SubscriptionPlanScreenState();
}

class _SubscriptionPlanScreenState extends State<SubscriptionPlanScreen>
    with WidgetsBindingObserver {
  static final Uri _privacyPolicyUrl =
      Uri.parse('https://hamster-breeding-app.web.app/privacy/');
  static final Uri _termsOfUseUrl =
      Uri.parse('https://hamster-breeding-app.web.app/terms/');

  late BillingStatusRepo _repo;
  late Stream<EntitlementSnapshot<BillingStatus>> _billingStream;
  late Stream<EntitlementSnapshot<InitialTrialAccess>> _trialStream;
  StreamSubscription<String?>? _authSubscription;
  final _billingDeadline = _UsageDeadline();
  final _trialDeadline = _UsageDeadline();
  String? _streamUid;
  int _readVersion = 0;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _bindRepo();
    WidgetsBinding.instance.addObserver(this);
  }

  void _bindRepo() {
    final repo = _repo = widget.billingRepo ?? BillingStatusRepo();
    _streamUid = repo.currentUserId;
    _bindUsageStreams();
    _authSubscription = repo.watchUserId().listen((uid) {
      if (!mounted || !identical(repo, _repo) || uid == _streamUid) return;
      setState(() {
        _streamUid = uid;
        _readVersion++;
        _bindUsageStreams();
      });
    });
  }

  void _bindUsageStreams() {
    _billingDeadline.clear();
    _trialDeadline.clear();
    _billingStream = _repo.watchBillingStatus();
    _trialStream = _repo.watchInitialTrialAccess();
  }

  @override
  void didUpdateWidget(covariant SubscriptionPlanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.billingRepo != widget.billingRepo) {
      unawaited(_authSubscription?.cancel());
      _readVersion++;
      _bindRepo();
    }
  }

  void _retryUsageRead() {
    setState(() {
      _readVersion++;
      _bindUsageStreams();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _retryUsageRead();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _billingDeadline.clear();
    _trialDeadline.clear();
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openLegalPage(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('legal_page');
      }
    } catch (_) {
      if (mounted) {
        HamsterFeedbackPopup.show(context, message: 'ページを開けませんでした。');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('利用状況', style: Theme.of(context).textTheme.titleLarge),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient:
                isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
          ),
          child: SafeArea(
            child: StreamBuilder<EntitlementSnapshot<BillingStatus>>(
              key: ValueKey((_streamUid, _readVersion)),
              stream: _billingStream,
              builder: (context, snapshot) {
                final read = snapshot.data;
                final sameUser = _streamUid == _repo.currentUserId;
                final confirmed = sameUser &&
                    read?.isServerConfirmed == true &&
                    read?.uid == _repo.currentUserId;
                final billing = confirmed ? read!.data : null;
                _billingDeadline.schedule(
                  billing?.isPaid == true ? billing?.currentPeriodEnd : null,
                  _now(),
                  () {
                    if (mounted) setState(() {});
                  },
                );
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    if (!confirmed || snapshot.hasError)
                      _ReadStatusCard(
                        unavailable: sameUser && snapshot.hasError,
                        onRetry: _retryUsageRead,
                      )
                    else ...[
                      _BillingUsageCard(
                        billing: billing!,
                        now: _now(),
                      ),
                      if (!billing.canUsePaidFeaturesAt(_now())) ...[
                        const SizedBox(height: 16),
                        _trialStatus(),
                      ],
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _retryUsageRead,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('利用状況を再確認'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => _openLegalPage(_termsOfUseUrl),
                          child: const Text('利用規約'),
                        ),
                        TextButton(
                          onPressed: () => _openLegalPage(_privacyPolicyUrl),
                          child: const Text('プライバシーポリシー'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _trialStatus() =>
      StreamBuilder<EntitlementSnapshot<InitialTrialAccess>>(
        key: ValueKey((_streamUid, _readVersion, 'initial_trial')),
        stream: _trialStream,
        builder: (context, snapshot) {
          final read = snapshot.data;
          final confirmed = _streamUid == _repo.currentUserId &&
              read?.isServerConfirmed == true &&
              read?.uid == _repo.currentUserId;
          final trial = confirmed ? read!.data : null;
          _trialDeadline.schedule(
            trial?.status == 'active' ? trial?.endsAt : null,
            _now(),
            () {
              if (mounted) setState(() {});
            },
          );
          if (!confirmed || snapshot.hasError) {
            return _ReadStatusCard(
              unavailable: snapshot.hasError,
              trialOnly: true,
              onRetry: _retryUsageRead,
            );
          }
          final access = trial!;
          if (access.isActiveAt(_now())) {
            final remaining =
                (access.endsAt!.difference(_now()).inMilliseconds /
                        Duration.millisecondsPerDay)
                    .ceil();
            return _UsageCard(
              icon: Icons.timelapse_rounded,
              title: '無料体験中です',
              message: 'カード登録不要・自動課金なしの21日間無料体験です。',
              detail: '残り$remaining日\n無料体験の終了日時：${_formatDate(access.endsAt!)}',
            );
          }
          if ((access.status == null && access.endsAt == null) ||
              access.status == 'not_started') {
            return const _UsageCard(
              icon: Icons.hourglass_empty_rounded,
              title: '無料体験は未開始です',
              message: '無料体験は21日間です。カード登録は不要で、自動課金はありません。',
            );
          }
          if (access.status == 'expired' ||
              access.status == 'ended' ||
              (access.status == 'active' &&
                  access.endsAt != null &&
                  !_now().isBefore(access.endsAt!))) {
            return _UsageCard(
              icon: Icons.event_busy_rounded,
              title: '無料体験は終了しました。',
              message: 'このアカウントでは、現在プレミアム機能を利用できません。',
              detail: access.endsAt == null
                  ? null
                  : '無料体験の終了日時：${_formatDate(access.endsAt!)}',
            );
          }
          return _ReadStatusCard(
            unavailable: true,
            trialOnly: true,
            onRetry: _retryUsageRead,
          );
        },
      );
}

String _formatDate(DateTime value) =>
    DateFormat('yyyy年M月d日 HH:mm').format(value.toLocal());

class _BillingUsageCard extends StatelessWidget {
  const _BillingUsageCard({
    required this.billing,
    required this.now,
  });
  final BillingStatus billing;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final active = billing.canUsePaidFeaturesAt(now);
    final canceledAtEnd = active && billing.cancelAtPeriodEnd;
    final String title;
    final String message;
    if (canceledAtEnd) {
      title = '解約予定です';
      message = '現在の契約期間が終了するまではプレミアム機能を利用できます。';
    } else if (active) {
      title = 'プレミアム利用中です';
      message = 'このアカウントではプレミアム機能を利用できます。';
    } else if (billing.isPaid) {
      title = 'プレミアムの利用期間が終了しています';
      message = '現在の契約状態をご確認ください。';
    } else {
      switch (billing.status) {
        case BillingStatusValue.pastDue:
        case BillingStatusValue.unpaid:
          title = 'お支払いの確認が必要です';
          message = '現在のお支払い状態を確認できていません。';
        case BillingStatusValue.canceled:
          title = 'プレミアム契約は終了しています';
          message = '現在の契約状態を表示しています。';
        case BillingStatusValue.incomplete:
          title = '契約状態は未完了です';
          message = '利用状況を再確認してください。';
        case BillingStatusValue.none:
          title = '現在の契約はありません';
          message = '無料体験の利用状況は下に表示されます。';
        case BillingStatusValue.unknown:
        case BillingStatusValue.active:
        case BillingStatusValue.trialing:
          title = '契約状態を確認できません';
          message = '時間をおいて利用状況を再確認してください。';
      }
    }
    final end =
        canceledAtEnd ? billing.effectiveCancelAt : billing.currentPeriodEnd;
    return _UsageCard(
      icon: active ? Icons.verified_rounded : Icons.info_outline_rounded,
      title: title,
      message: message,
      detail: end == null
          ? null
          : '${active ? '利用可能期限' : '契約期間の終了日時'}：${_formatDate(end)}',
    );
  }
}

class _ReadStatusCard extends StatelessWidget {
  const _ReadStatusCard({
    required this.unavailable,
    required this.onRetry,
    this.trialOnly = false,
  });
  final bool unavailable;
  final VoidCallback onRetry;
  final bool trialOnly;

  @override
  Widget build(BuildContext context) => _UsageCard(
        icon: Icons.sync_rounded,
        title: trialOnly
            ? (unavailable ? '無料体験の状態を確認できませんでした' : '無料体験の状態を確認しています')
            : (unavailable ? '利用状態を確認できませんでした' : '利用状態を確認しています'),
        message: unavailable ? '通信状態を確認して、もう一度お試しください。' : '確認が終わるまでお待ちください。',
        extra: unavailable
            ? OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('利用状況を再確認'),
              )
            : const Padding(
                padding: EdgeInsets.only(top: 16),
                child: CircularProgressIndicator(),
              ),
      );
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.detail,
    this.extra,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? detail;
  final Widget? extra;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: AppTheme.cardGradient(
            Theme.of(context).brightness == Brightness.dark),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.accent, size: 38),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(message),
            if (detail != null) ...[
              const SizedBox(height: 12),
              Text(detail!),
            ],
            if (extra != null) ...[
              const SizedBox(height: 16),
              extra!,
            ],
          ],
        ),
      );
}

class _UsageDeadline {
  Timer? _timer;
  DateTime? _deadline;
  void schedule(DateTime? deadline, DateTime now, VoidCallback onExpiry) {
    if (_deadline == deadline) return;
    clear();
    _deadline = deadline;
    if (deadline == null || !now.isBefore(deadline)) return;
    _timer = Timer(deadline.difference(now), () {
      _deadline = null;
      onExpiry();
    });
  }

  void clear() {
    _timer?.cancel();
    _timer = null;
    _deadline = null;
  }
}

// lib/screens/subscription_plan_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/billing_status.dart';
import '../services/app_analytics.dart';
import '../services/billing_status_repo.dart';
import '../theme/app_theme.dart';

class SubscriptionPlanScreen extends StatefulWidget {
  const SubscriptionPlanScreen({super.key});

  @override
  State<SubscriptionPlanScreen> createState() => _SubscriptionPlanScreenState();
}

class _SubscriptionPlanScreenState extends State<SubscriptionPlanScreen> {
  final BillingStatusRepo _repo = BillingStatusRepo();

  bool _isOpeningCheckout = false;
  bool _isOpeningPortal = false;

  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(
        app: Firebase.app(),
        region: 'asia-northeast1',
      );

  Future<void> _startCheckout() async {
    if (_isOpeningCheckout) return;

    setState(() {
      _isOpeningCheckout = true;
    });
    await AppAnalytics.logCheckoutStarted();

    try {
      final callable = _functions.httpsCallable('createStripeCheckoutSession');
      final result = await callable.call();

      final data = result.data;
      final checkoutUrl = data is Map ? data['checkoutUrl']?.toString() : null;

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception('Checkout URL を取得できませんでした。');
      }

      final uri = Uri.parse(checkoutUrl);

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Stripe Checkout を開けませんでした。');
      }
      await AppAnalytics.logCheckoutOpened();
    } on FirebaseFunctionsException catch (e) {
      await AppAnalytics.logCheckoutFailed();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('購入ページの作成に失敗しました: ${e.message ?? e.code}'),
        ),
      );
    } catch (e) {
      await AppAnalytics.logCheckoutFailed();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('購入ページを開けませんでした: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningCheckout = false;
        });
      }
    }
  }

  Future<void> _openCustomerPortal() async {
    if (_isOpeningPortal) return;

    setState(() {
      _isOpeningPortal = true;
    });

    try {
      final callable =
          _functions.httpsCallable('createStripeCustomerPortalSession');

      final result = await callable.call();

      final data = result.data;
      final portalUrl = data is Map ? data['portalUrl']?.toString() : null;

      if (portalUrl == null || portalUrl.isEmpty) {
        throw Exception('Customer Portal URL を取得できませんでした。');
      }

      final uri = Uri.parse(portalUrl);

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Stripe Customer Portal を開けませんでした。');
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('利用プラン管理画面の作成に失敗しました: ${e.message ?? e.code}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('利用プラン管理画面を開けませんでした: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningPortal = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = _repo;
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
          title: Text(
            '利用プラン',
            style: Theme.of(context).textTheme.titleLarge,
          ),
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
            child: StreamBuilder<BillingStatus>(
              stream: repo.watchBillingStatus(),
              builder: (context, snapshot) {
                final billing = snapshot.data ?? BillingStatus.empty();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    _BillingStatusHeroCard(
                      billing: billing,
                      isOpeningCheckout: _isOpeningCheckout,
                      isOpeningPortal: _isOpeningPortal,
                      onStartCheckout: _startCheckout,
                      onOpenCustomerPortal: _openCustomerPortal,
                    ),
                    const SizedBox(height: 16),
                    const _PaidPlanFeatureCard(
                      icon: Icons.thermostat_rounded,
                      title: '温湿度の自動記録',
                      body:
                          'SwitchBot温湿度計と連携し、温度・湿度の変化を自動で記録します。手入力では見落としやすい夜間や外出中の変化も確認しやすくなります。',
                    ),
                    const _PaidPlanFeatureCard(
                      icon: Icons.insights_rounded,
                      title: '環境評価',
                      body:
                          '記録された温湿度データをもとに、ハムスターにとって過ごしやすい環境かどうかを評価します。単なる数値ではなく、飼育判断に使いやすい形で確認できます。',
                    ),
                    const _PaidPlanFeatureCard(
                      icon: Icons.notifications_active_rounded,
                      title: '異常検知通知',
                      body:
                          '高温・高湿・危険評価など、注意が必要な変化を検知したときに通知します。ケージ環境の異変に早く気づくための補助機能です。',
                    ),
                    const _PaidPlanFeatureCard(
                      icon: Icons.smart_toy_rounded,
                      title: 'AI相談',
                      body:
                          'ペットプロフィール、飼育環境、温湿度データなどを踏まえて、日々の飼育で確認すべきポイントをAIに相談できます。',
                    ),
                    const _PaidPlanFeatureCard(
                      icon: Icons.favorite_rounded,
                      title: 'このアプリの考え方',
                      body:
                          'このアプリは、ハムスターの体調を診断するものではありません。日々の観察と環境管理を続けやすくし、異変に気づくきっかけを増やすための飼育支援アプリです。',
                    ),
                    const _PaidPlanNoticeCard(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BillingStatusHeroCard extends StatelessWidget {
  const _BillingStatusHeroCard({
    required this.billing,
    required this.isOpeningCheckout,
    required this.isOpeningPortal,
    required this.onStartCheckout,
    required this.onOpenCustomerPortal,
  });

  final BillingStatus billing;
  final bool isOpeningCheckout;
  final bool isOpeningPortal;
  final VoidCallback onStartCheckout;
  final VoidCallback onOpenCustomerPortal;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPaid = billing.isPaid;
    final visual = _visualForBillingStatus();

    final periodEndText = billing.currentPeriodEnd == null
        ? null
        : DateFormat('yyyy年M月d日').format(billing.currentPeriodEnd!);

    final cancellationEndText = billing.effectiveCancelAt == null
        ? null
        : DateFormat('yyyy年M月d日').format(billing.effectiveCancelAt!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: AppTheme.cardGradient(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            visual.icon,
            color: visual.accentColor,
            size: 46,
          ),
          const SizedBox(height: 16),
          Text(
            visual.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            visual.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.secondaryText(context),
                  height: 1.55,
                ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.chipFill(
                visual.accentColor,
                context,
                opacity: 0.14,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              _statusText(
                periodEndText: periodEndText,
                cancellationEndText: cancellationEndText,
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: visual.accentColor,
                    fontWeight: FontWeight.w800,
                    height: 1.45,
                  ),
            ),
          ),
          if (isPaid) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isOpeningPortal ? null : onOpenCustomerPortal,
                icon: isOpeningPortal
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.manage_accounts_rounded),
                label: Text(
                  isOpeningPortal ? '管理画面を準備中...' : 'プランを管理する',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '解約、支払い方法の変更、請求履歴の確認はStripeの安全な管理画面で行えます。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.secondaryText(context),
                    height: 1.45,
                  ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isOpeningCheckout ? null : onStartCheckout,
                icon: isOpeningCheckout
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.open_in_new_rounded),
                label: Text(
                  isOpeningCheckout ? '購入ページを準備中...' : '月額プランに登録する',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              visual.checkoutNote,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.secondaryText(context),
                    height: 1.45,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  String _statusText({
    required String? periodEndText,
    required String? cancellationEndText,
  }) {
    final base = '現在の状態: ${billing.planLabel} / ${billing.statusLabel}';

    if (billing.isCancellationScheduled) {
      final endText = cancellationEndText ?? periodEndText;
      if (endText == null) {
        return '$base\n解約予約済みです';
      }

      return '$base\n解約予定日: $endText\nこの日までは有料機能を利用できます';
    }

    if (periodEndText == null) {
      return base;
    }

    final status = billing.status;

    if (status == BillingStatusValue.active ||
        status == BillingStatusValue.trialing) {
      return '$base\n有効期限: $periodEndText';
    }

    if (status == BillingStatusValue.pastDue) {
      return '$base\n確認対象の期限: $periodEndText';
    }

    if (status == BillingStatusValue.unpaid) {
      return '$base\n最終確認期限: $periodEndText';
    }

    if (status == BillingStatusValue.canceled) {
      return '$base\n終了日: $periodEndText';
    }

    return base;
  }

  _BillingStatusVisual _visualForBillingStatus() {
    switch (billing.status) {
      case BillingStatusValue.active:
      case BillingStatusValue.trialing:
        if (billing.isCancellationScheduled) {
          return const _BillingStatusVisual(
            icon: Icons.event_busy_rounded,
            accentColor: Color(0xFFFFB020),
            title: '解約予約済みです',
            description: '現在の請求期間が終了するまでは、有料機能を利用できます。',
            checkoutNote: 'Stripeの安全な管理画面で、解約予約の取り消しや支払い方法の変更ができます。',
          );
        }

        return const _BillingStatusVisual(
          icon: Icons.verified_rounded,
          accentColor: Color(0xFF00D6A3),
          title: '有料プランを利用中です',
          description: '温湿度の自動記録、環境評価、異常検知通知、AI相談を利用できます。',
          checkoutNote: 'Stripeの安全な決済ページで手続きします。テスト中は実際の請求は発生しません。',
        );

      case BillingStatusValue.pastDue:
        return const _BillingStatusVisual(
          icon: Icons.error_rounded,
          accentColor: Color(0xFFFFB020),
          title: 'お支払いの確認が必要です',
          description:
              '前回のお支払いを確認できませんでした。有料機能は一時停止されています。再度登録するか、支払い方法を確認してください。',
          checkoutNote: '支払い状態を復旧するには、Stripeの決済ページで再度手続きしてください。',
        );

      case BillingStatusValue.unpaid:
        return const _BillingStatusVisual(
          icon: Icons.block_rounded,
          accentColor: Color(0xFFFF6B6B),
          title: '有料プランは停止中です',
          description: 'お支払いを確認できなかったため、有料機能は停止されています。再度登録すると、有料機能を利用できます。',
          checkoutNote: 'Stripeの安全な決済ページで再登録できます。',
        );

      case BillingStatusValue.canceled:
        return const _BillingStatusVisual(
          icon: Icons.workspace_premium_rounded,
          accentColor: AppTheme.accent,
          title: '有料プランは未契約です',
          description: '有料プランはキャンセルされています。再度登録すると、有料機能を利用できます。',
          checkoutNote: 'Stripeの安全な決済ページで手続きします。テスト中は実際の請求は発生しません。',
        );

      case BillingStatusValue.incomplete:
        return const _BillingStatusVisual(
          icon: Icons.pending_actions_rounded,
          accentColor: AppTheme.accent,
          title: '登録は完了していません',
          description: '有料プランの登録が完了していません。支払いページで手続きを完了してください。',
          checkoutNote: 'Stripeの安全な決済ページで手続きを再開できます。',
        );

      case BillingStatusValue.none:
        return const _BillingStatusVisual(
          icon: Icons.workspace_premium_rounded,
          accentColor: AppTheme.accent,
          title: '有料プランは未契約です',
          description: '有料プランに登録すると、温湿度の自動記録、環境評価、異常検知通知、AI相談を利用できます。',
          checkoutNote: 'Stripeの安全な決済ページで手続きします。テスト中は実際の請求は発生しません。',
        );

      case BillingStatusValue.unknown:
        return const _BillingStatusVisual(
          icon: Icons.help_rounded,
          accentColor: AppTheme.accent,
          title: '契約状態を確認できません',
          description: '現在の契約状態を確認できませんでした。時間をおいて再度確認してください。',
          checkoutNote: '必要に応じて、Stripeの決済ページから再度手続きできます。',
        );
    }
  }
}

class _BillingStatusVisual {
  const _BillingStatusVisual({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.description,
    required this.checkoutNote,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String description;
  final String checkoutNote;
}

class _PaidPlanFeatureCard extends StatelessWidget {
  const _PaidPlanFeatureCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardInnerDark : AppTheme.cardInnerLight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.quickActionBorder(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.softShadow(context),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.chipFill(
                AppTheme.accent,
                context,
                opacity: 0.14,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText(context),
                        height: 1.55,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaidPlanNoticeCard extends StatelessWidget {
  const _PaidPlanNoticeCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardInnerDark : AppTheme.cardInnerLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.quickActionBorder(context)),
      ),
      child: Text(
        '※ 本アプリは、獣医師による診断や治療の代替ではありません。体調不良、食欲不振、呼吸異常、ぐったりしているなどの異変がある場合は、動物病院への相談を優先してください。',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.secondaryText(context),
              height: 1.55,
            ),
      ),
    );
  }
}

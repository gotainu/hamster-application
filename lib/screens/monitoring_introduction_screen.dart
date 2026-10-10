import 'dart:async';

import 'package:flutter/material.dart';

import '../services/onboarding_state_repo.dart';
import '../services/app_analytics.dart';
import '../theme/app_theme.dart';
import '../widgets/daily_condition_input_card.dart';
import '../widgets/weight_input_card.dart';
import '../widgets/wheel_rotation_input_card.dart';
import 'switchbot_setup.dart';

class MonitoringIntroductionScreen extends StatelessWidget {
  const MonitoringIntroductionScreen({super.key});

  Future<void> _continue(BuildContext context) async {
    await OnboardingStateRepo().markMonitoringIntroductionViewed();
    await AppAnalytics.logOnboardingEvent('monitoring_intro_viewed');
    if (context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const MonitoringMethodSelectionScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.isDark(context)
              ? AppTheme.darkBgGradient
              : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Icon(
                  Icons.auto_graph_rounded,
                  size: 64,
                  color: AppTheme.accent,
                ),
                const SizedBox(height: 28),
                Text(
                  'これから、うちの子の\n普段の状態を集めていきます',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                ),
                const SizedBox(height: 18),
                Text(
                  'HamCareは毎日の記録をもとに、普段の状態との違いを確認しやすくします。まずは一つ、記録を始めましょう。',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.secondaryText(context),
                        height: 1.65,
                      ),
                ),
                const SizedBox(height: 14),
                Text(
                  '体重・活動量は、それぞれ有効な記録7件と14日以上の観察期間がそろうと、準備が整った指標から個体別分析に使えます。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.secondaryText(context),
                        height: 1.55,
                      ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _continue(context),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('記録方法を選ぶ'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MonitoringMethodSelectionScreen extends StatefulWidget {
  const MonitoringMethodSelectionScreen({super.key});

  @override
  State<MonitoringMethodSelectionScreen> createState() =>
      _MonitoringMethodSelectionScreenState();
}

class _MonitoringMethodSelectionScreenState
    extends State<MonitoringMethodSelectionScreen> {
  late final String _presentationId;

  @override
  void initState() {
    super.initState();
    _presentationId = 'method_${DateTime.now().microsecondsSinceEpoch}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        AppAnalytics.logMonitoringMethodPresented(
          presentationId: _presentationId,
        ),
      );
    });
  }

  Future<void> _open(BuildContext context, String method) async {
    await OnboardingStateRepo().selectMonitoringMethod(method);
    const positions = {
      'switchbot': 1,
      'daily_checkin': 2,
      'weight': 3,
      'wheel': 4
    };
    await AppAnalytics.logMonitoringMethodSelected(
      method: method,
      position: positions[method] ?? 0,
      presentationId: _presentationId,
    );
    if (!context.mounted) return;
    final Widget next = switch (method) {
      'switchbot' => const SwitchbotSetupScreen(),
      'daily_checkin' => const FirstMonitoringRecordScreen(
          method: 'daily_checkin',
        ),
      'weight' => const FirstMonitoringRecordScreen(method: 'weight'),
      _ => const FirstMonitoringRecordScreen(method: 'wheel'),
    };
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => next));
  }

  Widget _option(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    String method,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppTheme.accent),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _open(context, method),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('記録方法を選ぶ')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '続けやすい方法から始めましょう',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'SwitchBotがなくても、手入力で見守りを始められます。',
            style: TextStyle(color: AppTheme.secondaryText(context)),
          ),
          const SizedBox(height: 18),
          _option(
            context,
            Icons.thermostat_rounded,
            'SwitchBotを連携',
            '温度・湿度を自動で記録します',
            'switchbot',
          ),
          _option(
            context,
            Icons.favorite_outline_rounded,
            '今日の様子を記録',
            '食欲や動きなど、今日感じたことを残します',
            'daily_checkin',
          ),
          _option(
            context,
            Icons.monitor_weight_outlined,
            '体重を記録',
            '測定した体重とメモを残します',
            'weight',
          ),
          _option(
            context,
            Icons.directions_run_rounded,
            '回し車の記録',
            '昨日走った回転数を記録します',
            'wheel',
          ),
        ],
      ),
    );
  }
}

class FirstMonitoringRecordScreen extends StatelessWidget {
  const FirstMonitoringRecordScreen({super.key, required this.method});
  final String method;

  Future<void> _finished(BuildContext context) async {
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final Widget form = switch (method) {
      'daily_checkin' => DailyConditionInputCard(
          onSaved: () => _finished(context),
        ),
      'weight' => WeightInputCard(onSaved: (_) => _finished(context)),
      _ => WheelRotationInputCard(
          onSaved: ({required date, required rotations, distanceMeters}) =>
              _finished(context),
        ),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('最初の記録')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            '最初のデータを記録しましょう',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            '保存すると、HamCareの見守りが始まります。',
            style: TextStyle(color: AppTheme.secondaryText(context)),
          ),
          const SizedBox(height: 18),
          form,
        ],
      ),
    );
  }
}

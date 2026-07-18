import 'package:flutter/material.dart';

import '../services/distance_records_repo.dart';
import '../theme/app_theme.dart';
import '../widgets/daily_condition_input_card.dart';
import '../widgets/wheel_rotation_input_card.dart';
import '../widgets/weight_input_card.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final DistanceRecordsRepo _distanceRepo = DistanceRecordsRepo();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 84, 18, 28),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '日々の記録',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '今日の様子や走った記録を残して、変化に気づきやすくします。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.secondaryText(context),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            WheelRotationInputCard(
              distanceRepo: _distanceRepo,
              title: '昨日の走った記録',
              subtitle: '昨晩〜今朝の回転数を入れると、活動量評価に反映されます。',
            ),
            const SizedBox(height: 14),
            DailyConditionInputCard(
              onSaved: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('今日の様子を保存しました。'),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '定期的な記録',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            const SizedBox(height: 10),
            WeightInputCard(
              onSaved: (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('体重を保存しました。'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

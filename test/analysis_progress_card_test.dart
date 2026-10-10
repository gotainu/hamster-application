import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/widgets/analysis_progress_card.dart';

void main() {
  Future<void> show(WidgetTester t, List<Map<String, dynamic>> states) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AnalysisProgressCard(
                readinessStream: Stream.value(states),
                onOpenRecord: () {},
                onOpenSwitchbot: () {}))));
    await t.pump();
  }

  testWidgets(
      'all metrics ready removes old constant first report and progress',
      (t) async {
    await show(t, [
      {'metric': 'body', 'currentStatus': 'ready'},
      {'metric': 'activity', 'currentStatus': 'ready'}
    ]);
    expect(find.byType(Card), findsNothing);
    expect(find.text('個体別コンディションレポート'), findsNothing);
  });
  testWidgets('partial readiness keeps missing metric progress', (t) async {
    await show(t, [
      {'metric': 'body', 'currentStatus': 'ready'},
      {
        'metric': 'activity',
        'currentStatus': 'learning',
        'validRecordCount': 5,
        'observationSpanDays': 5
      }
    ]);
    expect(find.text('個体別コンディション分析を準備中'), findsOneWidget);
    expect(find.textContaining('活動量: 有効記録 5/7'), findsOneWidget);
    expect(find.text('レポートを見る'), findsNothing);
  });
  testWidgets('one ready document does not invent missing metric readiness',
      (t) async {
    await show(t, [
      {'metric': 'body', 'currentStatus': 'ready'}
    ]);
    expect(find.textContaining('活動量: 有効記録 0/7'), findsOneWidget);
  });
}

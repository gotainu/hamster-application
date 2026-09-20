import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:hamster_project/models/daily_record_completion.dart';
import 'package:hamster_project/models/daily_star_progress.dart';
import 'package:hamster_project/models/weight_record.dart';
import 'package:hamster_project/screens/daily_stars.dart';

void main() {
  final today = DateTime(2026, 9, 15);

  DailyRecordCompletion completion({
    bool wheel = false,
    bool condition = false,
    DateTime? weightDate,
  }) {
    return DailyRecordCompletion(
      wheelCompleted: wheel,
      conditionCompleted: condition,
      latestWeight: weightDate == null
          ? null
          : WeightRecord(
              dayKey: 'weight',
              date: weightDate,
              weightGrams: 105,
              memo: '',
            ),
      weightReminderDays: 7,
      referenceDate: today,
    );
  }

  test('daily slots follow records, not save counts', () {
    final empty = DailyStarProgress.fromCompletion(
      completion(weightDate: today.subtract(const Duration(days: 2))),
    );
    final recorded = DailyStarProgress.fromCompletion(
      completion(
        wheel: true,
        weightDate: today.subtract(const Duration(days: 2)),
      ),
    );
    expect(empty.slots.length, 3);
    expect(empty.filledCount, 1);
    expect(recorded.filledCount, 2);
    expect(recorded.slots.first.kind, DailyStarSlotKind.openApp);
  });

  test('weekly weight is not a daily star mission', () {
    final due = DailyStarProgress.fromCompletion(
      completion(weightDate: today.subtract(const Duration(days: 7))),
    );
    final saved = DailyStarProgress.fromCompletion(
      completion(weightDate: today),
    );
    expect(due.slots.length, 3);
    expect(due.filledCount, 1);
    expect(saved.slots.length, 3);
    expect(saved.filledCount, 1);
  });

  testWidgets('home strip shows only tappable stars', (tester) async {
    var tapped = false;
    final progress = DailyStarProgress.fromCompletion(completion());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DailyStarsStrip(
            progress: progress,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(2));
    expect(find.text('昨日の走った記録'), findsNothing);
    await tester.tap(find.byType(DailyStarsStrip));
    expect(tapped, isTrue);
  });

  testWidgets('detail screen names the three missions', (tester) async {
    final notifier = ValueNotifier<DailyRecordCompletion>(completion());
    addTearDown(notifier.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: DailyStarsScreen(completionListenable: notifier),
      ),
    );

    expect(find.text('アプリを開く'), findsOneWidget);
    expect(find.text('昨日の走った記録'), findsOneWidget);
    expect(find.text('今日の様子'), findsOneWidget);
    expect(find.text('体重'), findsNothing);
  });
}

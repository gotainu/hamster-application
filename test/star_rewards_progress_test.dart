import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/models/star_rewards_progress.dart';
import 'package:hamster_project/screens/star_collection.dart';

void main() {
  test('cumulative total rejects negative values', () {
    expect(StarRewardsProgress.fromJson({'total': 50}).total, 50);
    expect(StarRewardsProgress.fromJson({'total': -5}).total, 0);
  });

  test('current balance and lifetime earnings are stored separately', () {
    final progress = StarRewardsProgress.fromJson({
      'balance': 0,
      'lifetimeEarned': 50,
    });
    expect(progress.total, 0);
    expect(progress.lifetimeEarned, 50);
  });

  testWidgets('50-star message is gated by milestone state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StarCollectionScreen(
          progressStream: Stream.value(const StarRewardsProgress(total: 50)),
          milestoneStream: Stream.value(false),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('星が合計50個貯まりました！'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: StarCollectionScreen(
          progressStream: Stream.value(const StarRewardsProgress(total: 50)),
          milestoneStream: Stream.value(true),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('星が合計50個貯まりました！'), findsOneWidget);
  });
}

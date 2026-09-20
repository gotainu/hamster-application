import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/widgets/quick_record_reward.dart';

void main() {
  test('activity reward formats meters and kilometers', () {
    final meters = QuickRecordRewardData.activity(
      rotations: 613,
      distanceMeters: 481,
    );
    final kilometers = QuickRecordRewardData.activity(
      rotations: 2400,
      distanceMeters: 1280,
    );

    expect(meters.value, '481 m');
    expect(kilometers.value, '1.28 km');
    expect(meters.progressLabel, '活動記録を保存');
  });

  test('weight reward preserves one decimal place when needed', () {
    expect(QuickRecordRewardData.weight(105).value, '105g');
    expect(QuickRecordRewardData.weight(105.4).value, '105.4g');
  });

  testWidgets('reward explains value and offers a next action', (tester) async {
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickRecordRewardView(
            reward: QuickRecordRewardData.activity(
              rotations: 613,
              distanceMeters: 481,
            ),
            onContinue: () => continued = true,
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('記録が育ちました'), findsOneWidget);
    expect(find.text('481 m'), findsOneWidget);
    expect(find.text('活動量の比較データが増えました'), findsOneWidget);

    await tester.tap(find.text('ほかも記録'));
    expect(continued, isTrue);
  });
}

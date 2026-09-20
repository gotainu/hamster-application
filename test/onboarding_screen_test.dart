import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/screens/onboarding_screen.dart';

void main() {
  testWidgets('value slides lead into the preparation journey', (tester) async {
    var finished = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          onFinished: () => finished = true,
        ),
      ),
    );

    expect(find.text('小さな変化を\n見逃さない'), findsOneWidget);
    expect(find.text('見守りを始める'), findsNothing);

    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();
    expect(find.text('うちの子に合わせて\n見守る'), findsOneWidget);

    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();
    expect(find.text('迷ったら\nすぐ相談できる'), findsOneWidget);
    expect(find.text('見守りを始める'), findsOneWidget);

    await tester.tap(find.text('見守りを始める'));
    expect(finished, isTrue);
  });
}
